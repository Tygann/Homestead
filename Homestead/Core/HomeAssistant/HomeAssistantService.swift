import Foundation
@preconcurrency import Network
import Observation

@MainActor
@Observable
final class HomeAssistantService {
    private(set) var connectionStatus: HAConnectionStatus = .disconnected
    private(set) var dataFreshness: HADataFreshness = .empty
    private(set) var lastErrorMessage: String?
    private(set) var smokeTestState: HAConnectionSmokeTestState = .idle
    private(set) var serviceFeedback: HAServiceFeedback?
    private(set) var isLoadingCachedStates = false
    private(set) var hasCompletedInitialCacheLoad = false
    private(set) var mobileAppRegistrationState: HAMobileAppRegistrationState = .unregistered
    private(set) var mobileAppPushNotificationState: HAMobileAppPushNotificationState = .unavailable
    private(set) var authState: HAAuthState = .signedOut
    private(set) var currentUserDisplayName: String?
    private(set) var currentUserEntityPicturePath: String?
    private(set) var isNetworkAvailable = true
    private(set) var suppressesTransientConnectionHealth = false
    private(set) var serviceRegistry: HAServiceRegistry = .empty
    private(set) var serverConfiguration: HAServerConfigurationSnapshot?
    private(set) var serverConfigurationStatus: HAServerConfigurationStatus = .unavailable
    private(set) var stateCacheMetadata: HAStateCacheMetadata?
    private(set) var activeRouteSummary: HAConnectionRouteSummary?

    @ObservationIgnored private let client: any HAWebSocketClientProtocol
    @ObservationIgnored private let httpClient: any HAHTTPClientProtocol
    @ObservationIgnored private let mobileAppClient: any HAMobileAppClientProtocol
    @ObservationIgnored private let mobileAppRegistrationStore: any HAMobileAppRegistrationStore
    @ObservationIgnored private let nativeNotificationService: NativeNotificationService
    @ObservationIgnored private let authManager: HAOAuthManager
    @ObservationIgnored private let oauthAuthorizer: any HAOAuthAuthorizing
    @ObservationIgnored private let stateStore: HAStateStore
    @ObservationIgnored private let stateCache: HAStateCache
    @ObservationIgnored private let stateEventBatcher = HAStateEventBatcher()
    @ObservationIgnored private var activeConfiguration: HAConnectionConfiguration?
    @ObservationIgnored private var currentUserID: String?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var stateSyncTask: Task<Void, Never>?
    @ObservationIgnored private var stateEnrichmentTask: Task<Void, Never>?
    @ObservationIgnored private var connectionHealthGraceTask: Task<Void, Never>?
    @ObservationIgnored private var pendingCommandTasksByID: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var bufferedStateChangesByID: [String: HAStateChangedEventDTO] = [:]
    @ObservationIgnored private var isBufferingStateChanges = false
    @ObservationIgnored private var lastSuspendedAt: Date?
    @ObservationIgnored private var shouldReconnect = false
    @ObservationIgnored private weak var currentConnectionSettings: HAConnectionSettings?
    @ObservationIgnored private var networkContext: HAConnectionNetworkContext
    @ObservationIgnored private var reachabilityMonitor: NWPathMonitor?
    @ObservationIgnored private let reachabilityQueue = DispatchQueue(label: "com.tyler.Homestead.homeAssistantReachability")
    @ObservationIgnored private let reconnectDelaySeconds = [1, 2, 5, 10, 30]
    @ObservationIgnored private let pendingCommandTimeout: Duration = .seconds(3)
    @ObservationIgnored private let resumeRefreshInterval: TimeInterval = 5
    @ObservationIgnored private let foregroundConnectionHealthGrace: Duration = .seconds(2)

    init(
        stateStore: HAStateStore,
        client: any HAWebSocketClientProtocol = HAWebSocketClient(),
        stateCache: HAStateCache = HAStateCache(),
        connectionStatus: HAConnectionStatus = .disconnected,
        authState: HAAuthState = .signedOut,
        httpClient: (any HAHTTPClientProtocol)? = nil,
        mobileAppClient: (any HAMobileAppClientProtocol)? = nil,
        mobileAppRegistrationStore: (any HAMobileAppRegistrationStore)? = nil,
        nativeNotificationService: NativeNotificationService? = nil,
        authManager: HAOAuthManager? = nil,
        oauthAuthorizer: (any HAOAuthAuthorizing)? = nil,
        networkContext: HAConnectionNetworkContext = .availableExternal
    ) {
        self.stateStore = stateStore
        self.client = client
        self.httpClient = httpClient ?? HAHTTPClient()
        self.mobileAppClient = mobileAppClient ?? HAMobileAppClient()
        self.mobileAppRegistrationStore = mobileAppRegistrationStore ?? KeychainHAMobileAppRegistrationStore()
        self.nativeNotificationService = nativeNotificationService ?? NativeNotificationService()
        self.authManager = authManager ?? HAOAuthManager()
        self.oauthAuthorizer = oauthAuthorizer ?? HAWebAuthenticationSession()
        self.stateCache = stateCache
        self.networkContext = networkContext
        self.connectionStatus = connectionStatus
        self.authState = authState
        refreshMobileAppRegistrationState()
    }

    func connectIfPossible(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        guard settings.hasServerURL,
              authState.isSignedIn,
              connectionStatus != .connected,
              connectionStatus != .connecting,
              connectionStatus != .reconnecting,
              !isLoadingCachedStates else {
            return
        }

        await connect(settings: settings)
    }

    func startNetworkMonitoring(settings: HAConnectionSettings) {
        guard reachabilityMonitor == nil,
              !RuntimeEnvironment.isRunningForPreviews else {
            return
        }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self, weak settings] path in
            Task { @MainActor in
                guard let self, let settings else { return }
                await self.handleNetworkPathUpdate(path, settings: settings)
            }
        }
        reachabilityMonitor = monitor
        monitor.start(queue: reachabilityQueue)
    }

    func refreshOrReconnect(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        switch connectionStatus {
        case .connected:
            await refreshStates()
        case .preparing:
            await connectIfPossible(settings: settings)
        case .connecting:
            return
        case .reconnecting:
            reconnectTask?.cancel()
            reconnectTask = nil
            await connect(settings: settings)
        case .disconnected, .failed:
            await connectIfPossible(settings: settings)
        }
    }

    func loadCachedStatesIfPossible(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        let configuration: HAConnectionConfiguration?
        do {
            let selection = routeSelection(for: settings)
            configuration = try await authManager
                .storedConfiguration(baseURLString: selection.authenticationBaseURLString)?
                .routed(to: selection.preferredCandidate?.baseURLString ?? selection.authenticationBaseURLString)
            authState = await authManager.status()
        } catch {
            authState = .refreshFailed(error.localizedDescription)
            configuration = nil
        }

        guard settings.hasServerURL,
              let configuration,
              stateStore.dataSourceID != configuration.dataSourceID || !stateStore.hasLoadedInitialSnapshot else {
            #if DEBUG
            if !settings.hasServerURL {
                print("Home Assistant state cache skipped: missing server URL")
            } else if configuration == nil {
                print("Home Assistant state cache skipped: missing Home Assistant sign-in")
            } else {
                print("Home Assistant state cache skipped: state store already has an initial snapshot")
            }
            #endif
            return
        }

        await applyCachedStatesIfAvailable(for: configuration)
    }

    func connect(baseURLString: String) async {
        await connect(routeSelection: HAConnectionRouteResolver.explicit(baseURLString: baseURLString))
    }

    func connect(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        await connect(routeSelection: routeSelection(for: settings))
    }

    private func connect(routeSelection: HAConnectionRouteSelection) async {
        reconnectTask?.cancel()
        reconnectTask = nil
        stateSyncTask?.cancel()
        stateSyncTask = nil
        stateEnrichmentTask?.cancel()
        stateEnrichmentTask = nil
        discardBufferedStateChanges()
        await stateEventBatcher.discardPendingUpdates()
        let previousDataSourceID = activeConfiguration?.dataSourceID
        if activeConfiguration != nil {
            await client.disconnect()
            activeConfiguration = nil
            mobileAppPushNotificationState = .unavailable
        }
        shouldReconnect = true
        connectionStatus = .connecting

        let baseConfiguration: HAConnectionConfiguration
        do {
            baseConfiguration = try await validConfiguration(
                baseURLString: routeSelection.authenticationBaseURLString
            )
        } catch {
            shouldReconnect = false
            lastErrorMessage = error.localizedDescription
            authState = authFailureState(for: error)
            dataFreshness = staleFreshness(error.localizedDescription)
            connectionStatus = .failed(error.localizedDescription)
            return
        }

        if previousDataSourceID != baseConfiguration.dataSourceID {
            serviceRegistry = .empty
            serverConfiguration = nil
            serverConfigurationStatus = .unavailable
        }
        let preferredConfiguration = baseConfiguration.routed(
            to: routeSelection.preferredCandidate?.baseURLString ?? baseConfiguration.baseURLString
        )
        await applyCachedStatesIfAvailable(for: preferredConfiguration)

        var lastConnectionError: Error?
        for candidate in routeSelection.candidates {
            let routeConfiguration = baseConfiguration.routed(to: candidate.baseURLString)
            activeRouteSummary = HAConnectionRouteSummary(
                route: candidate.route,
                baseURLString: candidate.baseURLString
            )

            do {
                let connectedConfiguration = try await establishTransportConnectionWithAuthRecovery(
                    configuration: routeConfiguration
                )
                activeConfiguration = connectedConfiguration
                activeRouteSummary = HAConnectionRouteSummary(
                    route: candidate.route,
                    baseURLString: connectedConfiguration.baseURLString
                )
                refreshMobileAppRegistrationState(for: connectedConfiguration)
                lastErrorMessage = nil
                connectionStatus = .connected
                dataFreshness = .refreshing(lastUpdated: dataFreshness.lastKnownUpdateDate)
                startStateSync(configuration: connectedConfiguration)
                await registerMobileAppIfNeeded(configuration: connectedConfiguration)
                await startMobileAppPushNotificationChannel(configuration: connectedConfiguration)
                return
            } catch {
                lastConnectionError = error
                guard shouldTryFallbackRoute(after: error) else {
                    break
                }
            }
        }

        if routeSelection.candidates.isEmpty {
            lastConnectionError = HAWebSocketError.invalidURL
        }

        if let error = lastConnectionError {
            shouldReconnect = false
            lastErrorMessage = error.localizedDescription
            authState = authFailureState(for: error)
            dataFreshness = staleFreshness(error.localizedDescription)
            connectionStatus = .failed(error.localizedDescription)
        }
    }

    func testConnection(baseURLString: String) async {
        let smokeClient = HAWebSocketClient()

        smokeTestState = .testing

        do {
            let configuration = try await validConfiguration(baseURLString: baseURLString)
            try await smokeClient.connect(configuration: configuration)
            let states = try await smokeClient.fetchStates()
            await smokeClient.disconnect()

            smokeTestState = .succeeded(entityCount: states.count)
            lastErrorMessage = nil
        } catch {
            await smokeClient.disconnect()
            smokeTestState = .failed(error.localizedDescription)
        }
    }

    func disconnect() async {
        shouldReconnect = false
        endConnectionHealthGrace()
        reconnectTask?.cancel()
        reconnectTask = nil
        stateSyncTask?.cancel()
        stateSyncTask = nil
        stateEnrichmentTask?.cancel()
        stateEnrichmentTask = nil
        discardBufferedStateChanges()
        await stateEventBatcher.discardPendingUpdates()
        cancelPendingCommandTasks()
        await client.disconnect()
        activeConfiguration = nil
        activeRouteSummary = nil
        mobileAppPushNotificationState = .unavailable
        currentUserID = nil
        currentUserDisplayName = nil
        currentUserEntityPicturePath = nil
        serviceRegistry = .empty
        serverConfiguration = nil
        serverConfigurationStatus = .unavailable
        stateCacheMetadata = nil
        dataFreshness = staleFreshness(nil)
        connectionStatus = .disconnected
    }

    func refreshAuthState() async {
        let refreshedAuthState = await authManager.status()
        if refreshedAuthState.isSignedIn {
            if connectionStatus == .disconnected,
               activeConfiguration == nil {
                connectionStatus = .preparing
            }
            authState = refreshedAuthState
        } else {
            authState = refreshedAuthState
            if connectionStatus == .preparing {
                connectionStatus = .disconnected
            }
        }
    }

    func signInWithHomeAssistant(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        let baseURLString = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty else {
            authState = .refreshFailed(HAWebSocketError.invalidURL.localizedDescription)
            return
        }

        let state = UUID().uuidString
        authState = .signingIn

        do {
            let authorizationURL = try await authManager.authorizeURL(
                baseURLString: baseURLString,
                state: state
            )
            let callbackURL = try await oauthAuthorizer.authorize(
                authorizationURL: authorizationURL,
                callbackScheme: HAOAuthClientMetadata.callbackScheme
            )
            let authorizationCode = try authorizationCode(from: callbackURL, expectedState: state)
            _ = try await authManager.signIn(
                baseURLString: baseURLString,
                authorizationCode: authorizationCode
            )

            authState = await authManager.status()
            lastErrorMessage = nil
            await connect(settings: settings)
        } catch {
            authState = .refreshFailed(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await authManager.signOut()
            try mobileAppRegistrationStore.deleteRegistration()
            await disconnect()
            authState = .signedOut
            mobileAppRegistrationState = .unregistered
            lastErrorMessage = nil
        } catch {
            authState = .refreshFailed(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
        }
    }

    func applicationDidEnterBackground() {
        lastSuspendedAt = Date()
    }

    func applicationWillEnterForeground() {
        guard lastSuspendedAt != nil else {
            return
        }

        beginConnectionHealthGrace()
    }

    func resume(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        guard !RuntimeEnvironment.isRunningForPreviews else {
            return
        }

        switch connectionStatus {
        case .disconnected, .failed:
            await connectIfPossible(settings: settings)
        case .reconnecting:
            guard settings.hasServerURL, authState.isSignedIn else { return }
            reconnectTask?.cancel()
            reconnectTask = nil
            await connect(settings: settings)
        case .preparing:
            await connectIfPossible(settings: settings)
        case .connected:
            guard shouldRefreshAfterResume else { return }
            await refreshStates()
        case .connecting:
            return
        }
    }

    func toggleLight(entityID: String) async {
        guard let light = stateStore.lightEntity(for: entityID) else {
            return
        }

        if light.isOn {
            await turnOffLight(entityID: entityID)
        } else {
            await turnOnLight(entityID: entityID)
        }
    }

    func turnOnLight(entityID: String) async {
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: "on"
        )
        let succeeded = await callService(
            domain: "light",
            service: "turn_on",
            entityID: entityID
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func turnOffLight(entityID: String) async {
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: "off"
        )
        let succeeded = await callService(
            domain: "light",
            service: "turn_off",
            entityID: entityID
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setLightBrightness(entityID: String, brightnessPercentage: Double) async {
        let clampedPercentage = min(max(brightnessPercentage, 1), 100)
        let brightness = Int((clampedPercentage / 100) * 255)
        let serviceData = ["brightness": JSONValue.number(Double(max(1, brightness)))]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: "on",
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "light",
            service: "turn_on",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func perform(_ action: DashboardEntityPrimaryAction, entityID: String) async {
        switch action {
        case .toggleLight:
            await toggleLight(entityID: entityID)
        case .toggleCover:
            await toggleCover(entityID: entityID)
        case .toggleSwitch:
            await toggleSwitch(entityID: entityID)
        case .toggleFan:
            await toggleFan(entityID: entityID)
        case .toggleLock:
            await toggleLock(entityID: entityID)
        case .toggleAutomation:
            await toggleAutomation(entityID: entityID)
        case .activateScene:
            await activateScene(entityID: entityID)
        case .runScript:
            await runScript(entityID: entityID)
        }
    }

    func activateScene(entityID: String) async {
        await callTransientEntityService(
            domain: "scene",
            service: "turn_on",
            entityID: entityID,
            successTitle: "Scene activated"
        )
    }

    func runScript(entityID: String) async {
        await callTransientEntityService(
            domain: "script",
            service: "turn_on",
            entityID: entityID,
            successTitle: "Script started"
        )
    }

    func playPauseMedia(entityID: String) async {
        await callTransientEntityService(
            domain: "media_player",
            service: "media_play_pause",
            entityID: entityID,
            successTitle: "Media updated"
        )
    }

    func setMediaVolume(entityID: String, volumePercentage: Double) async {
        let clampedPercentage = min(max(volumePercentage, 0), 100)
        let volumeLevel = clampedPercentage / 100
        let serviceData = ["volume_level": JSONValue.number(volumeLevel)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil,
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "media_player",
            service: "volume_set",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func selectMediaSource(entityID: String, source: String) async {
        let serviceData = ["source": JSONValue.string(source)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil,
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "media_player",
            service: "select_source",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func startVacuum(entityID: String) async {
        await callTransientEntityService(
            domain: "vacuum",
            service: "start",
            entityID: entityID,
            expectedState: "cleaning",
            successTitle: "Vacuum started"
        )
    }

    func stopVacuum(entityID: String) async {
        await callTransientEntityService(
            domain: "vacuum",
            service: "stop",
            entityID: entityID,
            successTitle: "Vacuum stopped"
        )
    }

    func returnVacuumToBase(entityID: String) async {
        await callTransientEntityService(
            domain: "vacuum",
            service: "return_to_base",
            entityID: entityID,
            successTitle: "Vacuum returning"
        )
    }

    func installUpdate(entityID: String, backup: Bool? = nil, version: String? = nil) async {
        var serviceData: [String: JSONValue] = [:]

        if let backup {
            serviceData["backup"] = .bool(backup)
        }

        if let version = version?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
            serviceData["version"] = .string(version)
        }

        await callTransientEntityService(
            domain: "update",
            service: "install",
            entityID: entityID,
            serviceData: serviceData,
            successTitle: "Update installing"
        )
    }

    func installAvailableUpdates(_ updates: [HAUpdateEntity], backup: Bool) async {
        for update in updates where update.status == .available {
            await installUpdate(entityID: update.entityID, backup: backup)
        }
    }

    func skipUpdate(entityID: String) async {
        await callTransientEntityService(
            domain: "update",
            service: "skip",
            entityID: entityID,
            successTitle: "Update skipped"
        )
    }

    func clearSkippedUpdate(entityID: String) async {
        await callTransientEntityService(
            domain: "update",
            service: "clear_skipped",
            entityID: entityID,
            successTitle: "Skipped update cleared"
        )
    }

    func fetchCameraSnapshot(entityID: String) async throws -> Data {
        let configuration = try cameraConfiguration(for: entityID)
        let validConfiguration = try await validConfiguration(baseURLString: configuration.tokenRefreshBaseURLString)
            .routed(to: configuration.baseURLString)
        activeConfiguration = validConfiguration

        return try await httpClient.fetchCameraSnapshot(
            configuration: validConfiguration,
            entityID: entityID
        )
    }

    func fetchLogbook(settings: HAConnectionSettings, request: HALogbookRequest) async throws -> [HAActivityRow] {
        currentConnectionSettings = settings
        guard settings.hasServerURL else {
            throw HAWebSocketError.invalidURL
        }

        let configuration = try await preferredConfiguration(for: settings)
        activeConfiguration = configuration
        let entries = try await httpClient.fetchLogbook(configuration: configuration, request: request)

        return HAActivityRow.makeRows(from: entries) { [stateStore] entityID in
            stateStore.entity(for: entityID)?.displayName
        }
    }

    func fetchHistory(
        settings: HAConnectionSettings,
        request: HAHistoryRequest,
        range: HAHistoryRangePreset
    ) async throws -> HAHistoryChartSeries {
        currentConnectionSettings = settings
        guard settings.hasServerURL, !request.entityID.isEmpty else {
            throw HAWebSocketError.invalidURL
        }

        let configuration = try await preferredConfiguration(for: settings)
        activeConfiguration = configuration
        let response = try await httpClient.fetchHistory(configuration: configuration, request: request)
        let sensor = stateStore.entityBox(for: request.entityID)?.sensorEntity
        let entity = stateStore.entity(for: request.entityID)

        return HAHistoryChartSeries.make(
            response: response,
            request: request,
            displayName: sensor?.displayName ?? entity?.displayName ?? request.entityID,
            unit: sensor?.unitText,
            range: range
        )
    }

    func fetchTimeline(
        settings: HAConnectionSettings,
        request: HAHistoryRequest,
        range: HAHistoryRangePreset
    ) async throws -> HAHistoryTimeline {
        currentConnectionSettings = settings
        guard settings.hasServerURL, !request.entityID.isEmpty else {
            throw HAWebSocketError.invalidURL
        }

        let configuration = try await preferredConfiguration(for: settings)
        activeConfiguration = configuration
        let response = try await httpClient.fetchHistory(configuration: configuration, request: request)
        let entityBox = stateStore.entityBox(for: request.entityID)
        let entity = entityBox?.homeEntity ?? stateStore.entity(for: request.entityID)
        let binarySensor = entityBox?.binarySensorEntity
        let cover = entityBox?.coverEntity
        let domain = entity?.domain ?? EntityDomain(entityID: request.entityID)

        switch domain {
        case .binarySensor:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: binarySensor?.displayName ?? entity?.displayName ?? request.entityID,
                domain: .binarySensor(BinarySensorDisplayKind(deviceClass: binarySensor?.deviceClass)),
                range: range
            )
        case .lock:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: entity?.displayName ?? request.entityID,
                domain: .lock,
                range: range
            )
        case .switch:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: entity?.displayName ?? request.entityID,
                domain: .switch,
                range: range
            )
        case .automation:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: entity?.displayName ?? request.entityID,
                domain: .automation,
                range: range
            )
        case .cover:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: cover?.displayName ?? entity?.displayName ?? request.entityID,
                domain: .cover(deviceClass: cover?.deviceClass),
                range: range
            )
        case .person:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: entity?.displayName ?? request.entityID,
                domain: .person,
                range: range
            )
        case .deviceTracker:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: entity?.displayName ?? request.entityID,
                domain: .deviceTracker,
                range: range
            )
        default:
            return HAHistoryTimeline.makeTimeline(
                response: response,
                request: request,
                displayName: entity?.displayName ?? request.entityID,
                domain: .binarySensor(.generic),
                range: range
            )
        }
    }

    func fetchDashboardHistory(
        settings: HAConnectionSettings,
        entityID: String,
        range: HAHistoryRangePreset = .sixHours,
        endingAt endDate: Date = Date()
    ) async throws -> HAHistoryChartSeries {
        let interval = range.interval(endingAt: endDate)
        let request = HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: entityID
        )

        return try await fetchHistory(settings: settings, request: request, range: range)
    }

    func fetchCameraCapabilities(entityID: String) async throws -> HACameraCapabilities {
        _ = try cameraConfiguration(for: entityID)
        return try await client.fetchCameraCapabilities(entityID: entityID)
    }

    func serviceActionAvailable(domain: String, service: String) -> Bool {
        !serviceRegistry.hasLoaded || serviceRegistry.hasService(domain: domain, service: service)
    }

    func refreshServerConfiguration() async {
        guard connectionStatus == .connected else {
            serverConfiguration = nil
            serverConfigurationStatus = .unavailable
            return
        }

        serverConfigurationStatus = .loading

        do {
            let config = try await client.fetchConfig()
            let snapshot = HAServerConfigurationSnapshot(dto: config)
            serverConfiguration = snapshot
            serverConfigurationStatus = .loaded(snapshot.loadedAt)
        } catch {
            serverConfigurationStatus = .failed(error.localizedDescription)
        }
    }

    func serviceActionAvailable(_ action: DashboardEntityPrimaryAction, entityID: String) -> Bool {
        switch action {
        case .toggleLight:
            return serviceActionAvailable(domain: "light", service: toggleServiceName(for: entityID))
        case .toggleSwitch:
            return serviceActionAvailable(domain: "switch", service: toggleServiceName(for: entityID))
        case .toggleFan:
            return serviceActionAvailable(domain: "fan", service: toggleServiceName(for: entityID))
        case .toggleAutomation:
            return serviceActionAvailable(domain: "automation", service: toggleServiceName(for: entityID))
        case .toggleCover:
            guard let cover = stateStore.coverEntity(for: entityID) else {
                return true
            }
            return serviceActionAvailable(domain: "cover", service: cover.isOpen ? "close_cover" : "open_cover")
        case .toggleLock:
            guard let entity = stateStore.entity(for: entityID) else {
                return true
            }
            return serviceActionAvailable(domain: "lock", service: entity.state == "locked" ? "unlock" : "lock")
        case .activateScene:
            return serviceActionAvailable(domain: "scene", service: "turn_on")
        case .runScript:
            return serviceActionAvailable(domain: "script", service: "turn_on")
        }
    }

    func refreshMobileAppRegistrationState(settings: HAConnectionSettings? = nil) {
        if let settings {
            currentConnectionSettings = settings
        }
        do {
            let registration = try mobileAppRegistrationStore.readRegistration()
            guard let registration else {
                mobileAppRegistrationState = .unregistered
                return
            }

            if let settings, settings.hasServerURL {
                guard registration.serverIdentifier == HAConnectionConfiguration(
                    baseURLString: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    accessToken: ""
                ).dataSourceID else {
                    mobileAppRegistrationState = .unregistered
                    return
                }
            }

            mobileAppRegistrationState = .registered(HAMobileAppRegistrationSummary(info: registration))
        } catch {
            mobileAppRegistrationState = .failed(error.localizedDescription)
        }
    }

    private func refreshMobileAppRegistrationState(for configuration: HAConnectionConfiguration) {
        do {
            guard let registration = try mobileAppRegistrationStore.readRegistration(),
                  registration.serverIdentifier == configuration.dataSourceID else {
                mobileAppRegistrationState = .unregistered
                return
            }

            mobileAppRegistrationState = .registered(HAMobileAppRegistrationSummary(info: registration))
        } catch {
            mobileAppRegistrationState = .failed(error.localizedDescription)
        }
    }

    func registerMobileApp(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        guard settings.hasServerURL else {
            mobileAppRegistrationState = .failed("Add your Home Assistant URL before registering Homestead.")
            return
        }

        let configuration: HAConnectionConfiguration
        do {
            configuration = try await preferredConfiguration(for: settings)
        } catch {
            mobileAppRegistrationState = .failed(error.localizedDescription)
            authState = authFailureState(for: error)
            return
        }
        mobileAppRegistrationState = .registering

        await registerMobileAppIfNeeded(configuration: configuration, force: true)
    }

    private func registerMobileAppIfNeeded(
        configuration: HAConnectionConfiguration,
        force: Bool = false
    ) async {
        if !force,
           let registration = try? mobileAppRegistrationStore.readRegistration(),
           registration.serverIdentifier == configuration.dataSourceID,
           registration.supportsWebSocketNotifications == true {
            mobileAppRegistrationState = .registered(HAMobileAppRegistrationSummary(info: registration))
            return
        }

        mobileAppRegistrationState = .registering

        do {
            let request = HAMobileAppRegistrationRequestFactory.makeRequest()
            let response = try await mobileAppClient.register(
                configuration: configuration,
                request: request
            )
            let registration = HAMobileAppRegistrationInfo(
                serverIdentifier: configuration.dataSourceID,
                request: request,
                response: response
            )
            try mobileAppRegistrationStore.saveRegistration(registration)
            mobileAppRegistrationState = .registered(HAMobileAppRegistrationSummary(info: registration))
            lastErrorMessage = nil
        } catch {
            mobileAppRegistrationState = .failed(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
            serviceFeedback = HAServiceFeedback(
                title: "Registration failed",
                message: error.localizedDescription,
                style: .failure
            )
        }
    }

    func prepareCameraStreamHandoff(entityID: String) async throws -> HACameraStreamHandoff {
        let configuration = try cameraConfiguration(for: entityID)
        let registration = try currentMobileAppRegistration(for: configuration)
        let response = try await mobileAppClient.requestCameraStream(
            configuration: configuration,
            registration: registration,
            entityID: entityID
        )
        return HACameraStreamHandoff(entityID: entityID, response: response)
    }

    func cameraStreamURL(pathOrURL: String, entityID: String) throws -> URL {
        let configuration = try cameraConfiguration(for: entityID)
        return try HomeAssistantEndpointBuilder.httpURL(
            from: configuration.baseURLString,
            pathOrURL: pathOrURL
        )
    }

    func homeAssistantProfileImageRequest(settings: HAConnectionSettings) async -> URLRequest? {
        currentConnectionSettings = settings
        guard settings.hasServerURL,
              let currentUserID,
              let entityPicture = personEntityPicture(forUserID: currentUserID) else {
            return nil
        }

        return await homeAssistantImageRequest(settings: settings, pathOrURL: entityPicture)
    }

    func homeAssistantImageRequest(settings: HAConnectionSettings, pathOrURL: String) async -> URLRequest? {
        currentConnectionSettings = settings
        let trimmedPathOrURL = pathOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.hasServerURL, !trimmedPathOrURL.isEmpty else {
            return nil
        }

        do {
            let selection = routeSelection(for: settings)
            guard let configuration = try await authManager
                .storedConfiguration(baseURLString: selection.authenticationBaseURLString)?
                .routed(to: selection.preferredCandidate?.baseURLString ?? selection.authenticationBaseURLString) else {
                return nil
            }

            let url = try HomeAssistantEndpointBuilder.httpURL(
                from: configuration.baseURLString,
                pathOrURL: trimmedPathOrURL
            )
            var request = URLRequest(url: url)
            request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
            return request
        } catch {
            return nil
        }
    }

    func toggleSwitch(entityID: String) async {
        await callToggleService(
            domain: "switch",
            entityID: entityID,
            onState: "on",
            offState: "off"
        )
    }

    func toggleFan(entityID: String) async {
        await callToggleService(
            domain: "fan",
            entityID: entityID,
            onState: "on",
            offState: "off"
        )
    }

    func toggleAutomation(entityID: String) async {
        await callToggleService(
            domain: "automation",
            entityID: entityID,
            onState: "on",
            offState: "off"
        )
    }

    func pressButton(entityID: String) async {
        await callTransientEntityService(
            domain: "button",
            service: "press",
            entityID: entityID,
            successTitle: "Button pressed"
        )
    }

    func selectOption(entityID: String, option: String) async {
        let serviceData = ["option": JSONValue.string(option)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: option
        )

        let succeeded = await callService(
            domain: Self.selectServiceDomain(for: entityID),
            service: "select_option",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    nonisolated static func selectServiceDomain(for entityID: String) -> String {
        entityID.hasPrefix("input_select.") ? "input_select" : "select"
    }

    func setNumberValue(entityID: String, value: Double) async {
        let serviceData = ["value": JSONValue.number(value)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil
        )

        let succeeded = await callService(
            domain: "number",
            service: "set_value",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setAlarmControlPanelMode(entityID: String, service: String, code: String? = nil) async {
        var serviceData: [String: JSONValue] = [:]
        if let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            serviceData["code"] = .string(code)
        }

        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: expectedAlarmState(forService: service)
        )

        let succeeded = await callService(
            domain: "alarm_control_panel",
            service: service,
            entityID: entityID,
            serviceData: serviceData,
            successTitle: "Alarm updated"
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setFanPercentage(entityID: String, percentage: Double) async {
        let roundedPercentage = Int(min(max(percentage, 0), 100).rounded())
        let serviceData = ["percentage": JSONValue.number(Double(roundedPercentage))]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: roundedPercentage > 0 ? "on" : "off",
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "fan",
            service: "set_percentage",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setFanPresetMode(entityID: String, presetMode: String) async {
        let serviceData = ["preset_mode": JSONValue.string(presetMode)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil,
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "fan",
            service: "set_preset_mode",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func toggleLock(entityID: String) async {
        guard let entity = stateStore.entity(for: entityID), entity.isAvailable else {
            return
        }

        let shouldUnlock = entity.state == "locked"
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: shouldUnlock ? "unlocked" : "locked"
        )
        let succeeded = await callService(
            domain: "lock",
            service: shouldUnlock ? "unlock" : "lock",
            entityID: entityID
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setClimateTemperature(entityID: String, temperature: Double) async {
        guard let climate = stateStore.climateEntity(for: entityID) else {
            return
        }

        let step = climate.resolvedTemperatureStep
        let roundedTemperature = (temperature / step).rounded() * step
        let clampedTemperature = min(
            max(roundedTemperature, climate.resolvedMinimumTemperature),
            climate.resolvedMaximumTemperature
        )
        let serviceData = ["temperature": JSONValue.number(clampedTemperature)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil,
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "climate",
            service: "set_temperature",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setClimateTemperatureRange(entityID: String, lowTemperature: Double, highTemperature: Double) async {
        guard let climate = stateStore.climateEntity(for: entityID) else {
            return
        }

        let step = climate.resolvedTemperatureStep
        let roundedLowTemperature = (lowTemperature / step).rounded() * step
        let roundedHighTemperature = (highTemperature / step).rounded() * step
        let clampedLowTemperature = min(
            max(roundedLowTemperature, climate.resolvedMinimumTemperature),
            climate.resolvedMaximumTemperature
        )
        let clampedHighTemperature = min(
            max(roundedHighTemperature, clampedLowTemperature),
            climate.resolvedMaximumTemperature
        )
        let serviceData = [
            "target_temp_low": JSONValue.number(clampedLowTemperature),
            "target_temp_high": JSONValue.number(clampedHighTemperature)
        ]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil,
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "climate",
            service: "set_temperature",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    private func callToggleService(
        domain: String,
        entityID: String,
        onState: String,
        offState: String
    ) async {
        guard let entity = stateStore.entity(for: entityID), entity.isAvailable else {
            return
        }

        let shouldTurnOff = entity.state == onState
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: shouldTurnOff ? offState : onState
        )
        let succeeded = await callService(
            domain: domain,
            service: shouldTurnOff ? "turn_off" : "turn_on",
            entityID: entityID
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    private func expectedAlarmState(forService service: String) -> String? {
        switch service {
        case "alarm_disarm":
            return "disarmed"
        case "alarm_arm_home":
            return "armed_home"
        case "alarm_arm_away":
            return "armed_away"
        case "alarm_arm_night":
            return "armed_night"
        case "alarm_arm_vacation":
            return "armed_vacation"
        case "alarm_arm_custom_bypass":
            return "armed_custom_bypass"
        default:
            return nil
        }
    }

    private func personEntityPicture(forUserID userID: String) -> String? {
        let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserID.isEmpty else {
            return nil
        }

        return stateStore.rawEntitySnapshot()
            .filter { $0.entityID.hasPrefix("person.") }
            .compactMap { entity -> String? in
                let entityUserID = entity.attributes["user_id"]?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard entityUserID == trimmedUserID else {
                    return nil
                }

                let value = entity.attributes["entity_picture"]?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return value?.isEmpty == false ? value : nil
            }
            .first
    }

    private func applyCurrentUser(_ currentUser: HACurrentUserDTO) {
        currentUserID = currentUser.id
        let displayName = currentUser.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentUserDisplayName = displayName?.isEmpty == false ? displayName : nil
        refreshCurrentUserEntityPicturePath()
    }

    private func applyCachedCurrentUser(_ currentUser: HAStateCacheCurrentUser?) {
        guard let currentUser else {
            refreshCurrentUserEntityPicturePath()
            return
        }

        currentUserID = currentUser.id
        let displayName = currentUser.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentUserDisplayName = displayName?.isEmpty == false ? displayName : nil
        refreshCurrentUserEntityPicturePath()
    }

    private func refreshCurrentUserEntityPicturePath() {
        currentUserEntityPicturePath = currentUserID.flatMap { personEntityPicture(forUserID: $0) }
    }

    private func stateCacheCurrentUserSnapshot() -> HAStateCacheCurrentUser? {
        guard let currentUserID,
              !currentUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return HAStateCacheCurrentUser(id: currentUserID, name: currentUserDisplayName)
    }

    private func cameraConfiguration(for entityID: String) throws -> HAConnectionConfiguration {
        guard let configuration = activeConfiguration else {
            throw HAWebSocketError.notConnected
        }
        guard let entity = stateStore.entity(for: entityID),
              entity.domain == .camera,
              entity.isAvailable else {
            throw HAWebSocketError.requestFailed("Camera is unavailable.")
        }

        return configuration
    }

    private func currentMobileAppRegistration(for configuration: HAConnectionConfiguration) throws -> HAMobileAppRegistrationInfo {
        guard let registration = try mobileAppRegistrationStore.readRegistration(),
              registration.serverIdentifier == configuration.dataSourceID else {
            throw HAWebSocketError.requestFailed("Register Homestead as a Home Assistant mobile app before starting a live camera stream.")
        }

        return registration
    }

    func setClimateHVACMode(entityID: String, hvacMode: String) async {
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: hvacMode
        )
        let succeeded = await callService(
            domain: "climate",
            service: "set_hvac_mode",
            entityID: entityID,
            serviceData: ["hvac_mode": .string(hvacMode)]
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setClimateFanMode(entityID: String, fanMode: String) async {
        let serviceData = ["fan_mode": JSONValue.string(fanMode)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil,
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "climate",
            service: "set_fan_mode",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setClimatePresetMode(entityID: String, presetMode: String) async {
        let serviceData = ["preset_mode": JSONValue.string(presetMode)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil,
            expectedAttributes: serviceData
        )

        let succeeded = await callService(
            domain: "climate",
            service: "set_preset_mode",
            entityID: entityID,
            serviceData: serviceData
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func toggleCover(entityID: String) async {
        guard let cover = stateStore.coverEntity(for: entityID) else {
            return
        }

        if cover.isOpen {
            await closeCover(entityID: entityID)
        } else {
            await openCover(entityID: entityID)
        }
    }

    func openCover(entityID: String) async {
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: "open"
        )
        let succeeded = await callService(
            domain: "cover",
            service: "open_cover",
            entityID: entityID
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func closeCover(entityID: String) async {
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: "closed"
        )
        let succeeded = await callService(
            domain: "cover",
            service: "close_cover",
            entityID: entityID
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func stopCover(entityID: String) async {
        await callTransientEntityService(
            domain: "cover",
            service: "stop_cover",
            entityID: entityID,
            successTitle: "Cover stopped"
        )
    }

    func setCoverPosition(entityID: String, position: Double) async {
        let clampedPosition = min(max(position, 0), 100)
        let roundedPosition = Int(clampedPosition.rounded())
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: roundedPosition == 0 ? "closed" : nil,
            expectedAttributes: ["current_position": .number(Double(roundedPosition))]
        )

        let succeeded = await callService(
            domain: "cover",
            service: "set_cover_position",
            entityID: entityID,
            serviceData: ["position": .number(Double(roundedPosition))]
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    @discardableResult
    private func callTransientEntityService(
        domain: String,
        service: String,
        entityID: String,
        expectedState: String? = nil,
        serviceData: [String: JSONValue] = [:],
        successTitle: String? = nil
    ) async -> Bool {
        guard let entity = stateStore.entity(for: entityID), entity.isAvailable else {
            serviceFeedback = HAServiceFeedback(
                title: "Action unavailable",
                message: entityDisplayName(for: entityID) ?? entityID,
                style: .failure
            )
            return false
        }

        let pendingCommand = setPendingCommand(entityID: entityID, expectedState: expectedState)
        let succeeded = await callService(
            domain: domain,
            service: service,
            entityID: entityID,
            serviceData: serviceData,
            successTitle: successTitle
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }

        return succeeded
    }

    @discardableResult
    func callService(
        domain: String,
        service: String,
        entityID: String?,
        serviceData: [String: JSONValue] = [:],
        successTitle: String? = nil
    ) async -> Bool {
        guard serviceActionAvailable(domain: domain, service: service) else {
            serviceFeedback = HAServiceFeedback(
                title: "Action unavailable",
                message: "\(domain).\(service) is not available on this Home Assistant server.",
                style: .failure
            )
            return false
        }

        do {
            try await client.callService(
                domain: domain,
                service: service,
                entityID: entityID,
                serviceData: serviceData
            )
            lastErrorMessage = nil
            if let successTitle {
                serviceFeedback = HAServiceFeedback(
                    title: successTitle,
                    message: entityDisplayName(for: entityID),
                    style: .success
                )
            }
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            let isRecoveringConnection = await recoverConnectionIfNeeded(after: error)
            serviceFeedback = HAServiceFeedback(
                title: isRecoveringConnection ? "Action failed, reconnecting" : "Action failed",
                message: serviceFailureMessage(
                    domain: domain,
                    service: service,
                    entityID: entityID,
                    error: error,
                    isRecoveringConnection: isRecoveringConnection
                ),
                style: .failure
            )
            return false
        }
    }

    func clearServiceFeedback(id: HAServiceFeedback.ID) {
        guard serviceFeedback?.id == id else { return }
        serviceFeedback = nil
    }

    private func applyCachedStatesIfAvailable(for configuration: HAConnectionConfiguration) async {
        if stateStore.dataSourceID != configuration.dataSourceID {
            stateStore.replaceDataSourceIfNeeded(configuration.dataSourceID)
            stateCacheMetadata = nil
        }

        guard !stateStore.hasLoadedInitialSnapshot else {
            hasCompletedInitialCacheLoad = true
            return
        }
        guard !isLoadingCachedStates else {
            #if DEBUG
            print("Home Assistant state cache skipped: load already in progress")
            #endif
            return
        }

        isLoadingCachedStates = true
        defer {
            isLoadingCachedStates = false
            hasCompletedInitialCacheLoad = true
        }

        guard let snapshot = await stateCache.load(for: configuration), !snapshot.entities.isEmpty else {
            stateCacheMetadata = nil
            dataFreshness = .empty
            return
        }

        #if DEBUG
        let startDate = Date()
        #endif
        stateStore.applySnapshot(snapshot.entities, dataSourceID: configuration.dataSourceID)
        applyCachedCurrentUser(snapshot.currentUser)
        if let registryMetadata = snapshot.registryMetadata {
            stateStore.applyRegistryMetadata(registryMetadata)
        }
        #if DEBUG
        print(
            "Home Assistant cached snapshot applied: \(snapshot.entities.count) entities in \(String(format: "%.3f", Date().timeIntervalSince(startDate)))s"
        )
        #endif
        stateCacheMetadata = HAStateCacheMetadata(
            scopeIdentifier: HAStateCache.cacheScopeIdentifier(for: configuration),
            savedAt: snapshot.savedAt,
            entityCount: snapshot.entities.count,
            entityRegistryCount: snapshot.registryMetadata?.entities.count,
            deviceRegistryCount: snapshot.registryMetadata?.devices.count,
            areaRegistryCount: snapshot.registryMetadata?.areas.count,
            floorRegistryCount: snapshot.registryMetadata?.floors.count
        )
        dataFreshness = .cached(snapshot.savedAt)
    }

    private func staleFreshness(_ errorMessage: String?, lastUpdated: Date? = nil) -> HADataFreshness {
        guard stateStore.hasLoadedInitialSnapshot else {
            return .empty
        }

        return .stale(errorMessage, lastUpdated: lastUpdated ?? dataFreshness.lastKnownUpdateDate)
    }

    private func handleNetworkPathUpdate(
        _ path: NWPath,
        settings: HAConnectionSettings
    ) async {
        currentConnectionSettings = settings
        let previousSelection = routeSelection(for: settings).preferredCandidate
        let previousNetworkAvailability = isNetworkAvailable
        let nextNetworkContext = HAConnectionNetworkContext(path: path)
        let networkIsAvailable = nextNetworkContext.isNetworkAvailable
        networkContext = nextNetworkContext
        let nextSelection = routeSelection(for: settings).preferredCandidate
        let routePreferenceChanged = previousSelection != nextSelection

        isNetworkAvailable = networkIsAvailable

        guard previousNetworkAvailability != networkIsAvailable || routePreferenceChanged else {
            return
        }

        if networkIsAvailable {
            guard settings.hasServerURL, authState.isSignedIn else {
                return
            }

            switch connectionStatus {
            case .preparing:
                await connectIfPossible(settings: settings)
            case .connecting:
                return
            case .connected:
                guard routePreferenceChanged else {
                    return
                }
                await connect(settings: settings)
            case .reconnecting:
                reconnectTask?.cancel()
                reconnectTask = nil
                await connect(settings: settings)
            case .disconnected, .failed:
                await connectIfPossible(settings: settings)
            }
        } else {
            lastErrorMessage = "Network unavailable"
            dataFreshness = staleFreshness(lastErrorMessage)

            if connectionStatus == .connected, let activeConfiguration {
                await client.disconnect()
                scheduleReconnect(configuration: activeConfiguration)
            }
        }
    }

    private func establishTransportConnection(configuration: HAConnectionConfiguration) async throws {
        await configureClientCallbacks()
        try await client.connect(configuration: configuration)
        let currentUser = try? await client.fetchCurrentUser()
        if let currentUser {
            applyCurrentUser(currentUser)
        } else {
            refreshCurrentUserEntityPicturePath()
        }
    }

    private func establishTransportConnectionWithAuthRecovery(
        configuration: HAConnectionConfiguration
    ) async throws -> HAConnectionConfiguration {
        do {
            try await establishTransportConnection(configuration: configuration)
            return configuration
        } catch HAWebSocketError.authenticationFailed(_) {
            let refreshedConfiguration = try await refreshConfiguration(
                baseURLString: configuration.tokenRefreshBaseURLString
            )
            .routed(to: configuration.baseURLString)
            try await establishTransportConnection(configuration: refreshedConfiguration)
            return refreshedConfiguration
        }
    }

    private func preferredConfiguration(for settings: HAConnectionSettings) async throws -> HAConnectionConfiguration {
        let selection = routeSelection(for: settings)
        let configuration = try await validConfiguration(baseURLString: selection.authenticationBaseURLString)
        return configuration.routed(
            to: selection.preferredCandidate?.baseURLString ?? selection.authenticationBaseURLString
        )
    }

    private func routeSelection(for settings: HAConnectionSettings) -> HAConnectionRouteSelection {
        HAConnectionRouteResolver.resolve(
            settings: settings.routingSnapshot,
            networkContext: networkContext
        )
    }

    private func shouldTryFallbackRoute(after error: Error) -> Bool {
        guard let webSocketError = error as? HAWebSocketError else {
            return false
        }

        switch webSocketError {
        case .invalidURL, .notConnected, .requestTimedOut, .transportFailure:
            return true
        case .unexpectedMessage, .authenticationFailed, .requestFailed, .missingResult:
            return false
        }
    }

    private func validConfiguration(baseURLString: String) async throws -> HAConnectionConfiguration {
        do {
            let configuration = try await authManager.validConfiguration(baseURLString: baseURLString)
            authState = await authManager.status()
            return configuration
        } catch {
            authState = authFailureState(for: error)
            throw error
        }
    }

    private func refreshConfiguration(baseURLString: String) async throws -> HAConnectionConfiguration {
        authState = .refreshing(authSummary)
        do {
            let configuration = try await authManager.refreshConfiguration(baseURLString: baseURLString)
            authState = await authManager.status()
            return configuration
        } catch {
            authState = .refreshFailed(error.localizedDescription)
            throw error
        }
    }

    private var authSummary: HAAuthSessionSummary? {
        switch authState {
        case .signedIn(let summary), .accessTokenExpired(let summary):
            summary
        case .refreshing(let summary):
            summary
        case .signedOut, .signingIn, .refreshFailed:
            nil
        }
    }

    private func authFailureState(for error: Error) -> HAAuthState {
        if error as? HAOAuthError == .signedOut {
            return .signedOut
        }
        return .refreshFailed(error.localizedDescription)
    }

    private func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw HAOAuthError.missingAuthorizationCode
        }

        let returnedState = components.queryItems?.first { $0.name == "state" }?.value
        guard returnedState == expectedState else {
            throw HAOAuthError.stateMismatch
        }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            throw HAOAuthError.missingAuthorizationCode
        }

        return code
    }

    private func startStateSync(configuration: HAConnectionConfiguration) {
        stateSyncTask?.cancel()
        stateSyncTask = Task { [weak self] in
            await self?.syncInitialStates(configuration: configuration)
        }
    }

    private func syncInitialStates(configuration: HAConnectionConfiguration) async {
        beginBufferingStateChanges()

        do {
            try await client.subscribeToStateChanges()
            let states = try await client.fetchStates()
            stateStore.applySnapshot(states, dataSourceID: configuration.dataSourceID)
            applyBufferedStateChanges()
            lastErrorMessage = nil
            dataFreshness = .live(Date())
            scheduleStateCacheSave(configuration: configuration)
            scheduleStateEnrichment(configuration: configuration)
        } catch {
            discardBufferedStateChanges()
            lastErrorMessage = error.localizedDescription
            dataFreshness = staleFreshness(error.localizedDescription)
            await recoverConnectionIfNeeded(after: error)
        }
    }

    func refreshStates() async {
        guard connectionStatus == .connected, let activeConfiguration else {
            return
        }

        let previousUpdateDate = dataFreshness.lastKnownUpdateDate
        beginBufferingStateChanges()
        dataFreshness = .refreshing(lastUpdated: previousUpdateDate)

        do {
            let states = try await client.fetchStates()
            stateStore.applySnapshot(states, dataSourceID: activeConfiguration.dataSourceID)
            applyBufferedStateChanges()
            lastErrorMessage = nil
            dataFreshness = .live(Date())
            scheduleStateCacheSave(configuration: activeConfiguration)
            scheduleStateEnrichment(configuration: activeConfiguration)
        } catch {
            applyBufferedStateChanges()
            lastErrorMessage = error.localizedDescription
            dataFreshness = staleFreshness(error.localizedDescription, lastUpdated: previousUpdateDate)
            await recoverConnectionIfNeeded(after: error)
        }
    }

    private func scheduleStateEnrichment(configuration: HAConnectionConfiguration) {
        stateEnrichmentTask?.cancel()
        stateEnrichmentTask = Task { [weak self] in
            await self?.enrichLiveState(configuration: configuration)
        }
    }

    private func scheduleStateCacheSave(configuration: HAConnectionConfiguration) {
        let entities = stateStore.rawEntitySnapshot()
        let registryMetadata = stateStore.registryMetadataSnapshot()
        let currentUser = stateCacheCurrentUserSnapshot()
        stateCacheMetadata = HAStateCacheMetadata(
            scopeIdentifier: HAStateCache.cacheScopeIdentifier(for: configuration),
            savedAt: Date(),
            entityCount: entities.count,
            entityRegistryCount: registryMetadata?.entities.count,
            deviceRegistryCount: registryMetadata?.devices.count,
            areaRegistryCount: registryMetadata?.areas.count,
            floorRegistryCount: registryMetadata?.floors.count
        )
        Task { [stateCache] in
            await stateCache.save(
                entities,
                registryMetadata: registryMetadata,
                currentUser: currentUser,
                for: configuration
            )
        }
    }

    private func enrichLiveState(configuration: HAConnectionConfiguration) async {
        guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
            return
        }

        let registryMetadata = await fetchRegistryMetadataIfAvailable(configuration: configuration)
        await refreshServiceRegistryIfAvailable(configuration: configuration)
        await refreshServerConfigurationIfAvailable(configuration: configuration)

        guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
            return
        }

        await stateCache.save(
            stateStore.rawEntitySnapshot(),
            registryMetadata: registryMetadata ?? stateStore.registryMetadataSnapshot(),
            currentUser: stateCacheCurrentUserSnapshot(),
            for: configuration
        )
    }

    private func fetchRegistryMetadataIfAvailable(configuration: HAConnectionConfiguration) async -> HARegistryMetadataSnapshot? {
        do {
            async let entityRegistry = client.fetchEntityRegistryForDisplay()
            async let deviceRegistry = client.fetchDeviceRegistry()

            let registryMetadata = try await (entityRegistry, deviceRegistry)
            let areas: [HAAreaRegistryDTO]
            let floors: [HAFloorRegistryDTO]

            do {
                areas = try await client.fetchAreaRegistry()
            } catch {
                areas = []
                #if DEBUG
                print("Home Assistant area registry metadata failed: \(error.localizedDescription)")
                #endif
            }

            do {
                floors = try await client.fetchFloorRegistry()
            } catch {
                floors = []
                #if DEBUG
                print("Home Assistant floor registry metadata failed: \(error.localizedDescription)")
                #endif
            }

            let metadata = HARegistryMetadataSnapshot(
                entities: registryMetadata.0.entities,
                devices: registryMetadata.1,
                areas: areas,
                floors: floors
            )
            guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
                return nil
            }
            stateStore.applyRegistryMetadata(metadata)
            return metadata
        } catch {
            // Entity/device metadata improves organization, but live state should still work without it.
            #if DEBUG
            print("Home Assistant entity/device registry metadata failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private func refreshServiceRegistryIfAvailable(configuration: HAConnectionConfiguration) async {
        do {
            let registry = try await client.fetchServices()
            guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
                return
            }
            serviceRegistry = registry
        } catch {
            // Service metadata helps tailor controls, but state sync should remain WebSocket-first and resilient.
            #if DEBUG
            print("Home Assistant service metadata failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func refreshServerConfigurationIfAvailable(configuration: HAConnectionConfiguration) async {
        serverConfigurationStatus = .loading

        do {
            let config = try await client.fetchConfig()
            guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
                return
            }

            let snapshot = HAServerConfigurationSnapshot(dto: config)
            serverConfiguration = snapshot
            serverConfigurationStatus = .loaded(snapshot.loadedAt)
        } catch {
            guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
                return
            }

            serverConfigurationStatus = .failed(error.localizedDescription)
            #if DEBUG
            print("Home Assistant server configuration failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func configureClientCallbacks() async {
        await stateEventBatcher.setFlushHandler { [weak stateStore] updates in
            stateStore?.applyStateChanges(updates)
        }

        await client.setEventHandler { [weak self] event in
            await self?.handleStateEvent(event)
        }

        await client.setMobileAppPushNotificationHandler { [weak self] event in
            await self?.handleMobileAppPushNotificationEvent(event)
        }

        await client.setDisconnectHandler { [weak self] error in
            self?.handleUnexpectedDisconnect(error)
        }
    }

    private func startMobileAppPushNotificationChannel(configuration: HAConnectionConfiguration) async {
        guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
            return
        }

        do {
            let registration = try currentMobileAppRegistration(for: configuration)
            guard registration.supportsWebSocketNotifications == true else {
                mobileAppPushNotificationState = .failed("Register Homestead again to enable Home Assistant WebSocket notification delivery.")
                return
            }

            mobileAppPushNotificationState = .subscribing
            try await client.subscribeToMobileAppPushNotifications(
                webhookID: registration.webhookID,
                supportConfirm: true
            )
            mobileAppPushNotificationState = .subscribed(Date())
        } catch {
            mobileAppPushNotificationState = .failed(error.localizedDescription)
            #if DEBUG
            print("Home Assistant mobile-app notification channel failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func handleMobileAppPushNotificationEvent(_ event: HAMobileAppPushNotificationEventDTO) async {
        guard let activeConfiguration else {
            return
        }

        do {
            let registration = try currentMobileAppRegistration(for: activeConfiguration)
            try await nativeNotificationService.presentNotification(event.notificationRequest)

            if let confirmID = event.hassConfirmID {
                try await client.confirmMobileAppPushNotification(
                    webhookID: registration.webhookID,
                    confirmID: confirmID
                )
            }
        } catch {
            mobileAppPushNotificationState = .failed(error.localizedDescription)
            #if DEBUG
            print("Home Assistant mobile-app notification delivery failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func handleStateEvent(_ event: HAEventDTO) async {
        guard let stateChanged = event.stateChanged else {
            return
        }

        if isBufferingStateChanges {
            bufferedStateChangesByID[stateChanged.entityID] = stateChanged
            return
        }

        if stateStore.pendingCommand(for: stateChanged.entityID) != nil {
            stateStore.applyStateChanged(stateChanged)
        } else {
            await stateEventBatcher.enqueue(stateChanged)
        }
    }

    private func beginBufferingStateChanges() {
        isBufferingStateChanges = true
        bufferedStateChangesByID.removeAll()
    }

    private func applyBufferedStateChanges() {
        let bufferedStateChanges = Array(bufferedStateChangesByID.values)
        bufferedStateChangesByID.removeAll()
        isBufferingStateChanges = false
        stateStore.applyStateChanges(bufferedStateChanges)
    }

    private func discardBufferedStateChanges() {
        bufferedStateChangesByID.removeAll()
        isBufferingStateChanges = false
    }

    private func handleUnexpectedDisconnect(_ error: Error) {
        guard shouldReconnect, let activeConfiguration else {
            return
        }

        lastErrorMessage = error.localizedDescription
        dataFreshness = staleFreshness(error.localizedDescription)
        scheduleReconnect(configuration: activeConfiguration)
    }

    @discardableResult
    private func recoverConnectionIfNeeded(after error: Error) async -> Bool {
        guard shouldReconnect,
              reconnectTask == nil,
              let activeConfiguration,
              error.shouldReconnectHomeAssistantSocket else {
            return false
        }

        await client.disconnect()
        scheduleReconnect(configuration: activeConfiguration)
        return true
    }

    private func scheduleReconnect(configuration: HAConnectionConfiguration) {
        guard reconnectTask == nil else {
            return
        }

        stateSyncTask?.cancel()
        stateSyncTask = nil
        stateEnrichmentTask?.cancel()
        stateEnrichmentTask = nil
        discardBufferedStateChanges()
        Task {
            await stateEventBatcher.discardPendingUpdates()
        }
        connectionStatus = .reconnecting
        reconnectTask = Task { [weak self] in
            await self?.runReconnectLoop(configuration: configuration)
        }
    }

    private func runReconnectLoop(configuration: HAConnectionConfiguration) async {
        var attempt = 0

        while shouldReconnect, !Task.isCancelled {
            let delay = reconnectDelaySeconds[min(attempt, reconnectDelaySeconds.count - 1)]

            do {
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                guard isNetworkAvailable else {
                    attempt += 1
                    continue
                }
                var connectedRoute: (
                    candidate: HAConnectionRouteCandidate?,
                    configuration: HAConnectionConfiguration
                )?
                var routeError: Error?

                for routeConfiguration in try await reconnectRouteConfigurations(fallback: configuration) {
                    do {
                        let connectedConfiguration = try await establishTransportConnectionWithAuthRecovery(
                            configuration: routeConfiguration.configuration
                        )
                        connectedRoute = (routeConfiguration.candidate, connectedConfiguration)
                        break
                    } catch {
                        routeError = error
                        guard shouldTryFallbackRoute(after: error) else {
                            break
                        }
                    }
                }

                guard let connectedRoute else {
                    throw routeError ?? HAWebSocketError.transportFailure("Home Assistant connection failed.")
                }
                let connectedConfiguration = connectedRoute.configuration

                activeConfiguration = connectedConfiguration
                activeRouteSummary = connectedRoute.candidate.map {
                    HAConnectionRouteSummary(route: $0.route, baseURLString: connectedConfiguration.baseURLString)
                } ?? activeRouteSummary
                refreshMobileAppRegistrationState(for: connectedConfiguration)
                lastErrorMessage = nil
                connectionStatus = .connected
                reconnectTask = nil
                dataFreshness = .refreshing(lastUpdated: dataFreshness.lastKnownUpdateDate)
                startStateSync(configuration: connectedConfiguration)
                return
            } catch is CancellationError {
                break
            } catch {
                lastErrorMessage = error.localizedDescription
                dataFreshness = staleFreshness(error.localizedDescription)
                connectionStatus = .reconnecting
                attempt += 1
            }
        }

        reconnectTask = nil
        if connectionStatus == .reconnecting {
            connectionStatus = .disconnected
        }
    }

    private func beginConnectionHealthGrace() {
        connectionHealthGraceTask?.cancel()
        let graceDuration = foregroundConnectionHealthGrace
        suppressesTransientConnectionHealth = true
        connectionHealthGraceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: graceDuration)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            self?.suppressesTransientConnectionHealth = false
            self?.connectionHealthGraceTask = nil
        }
    }

    private func endConnectionHealthGrace() {
        connectionHealthGraceTask?.cancel()
        connectionHealthGraceTask = nil
        suppressesTransientConnectionHealth = false
    }

    private func reconnectRouteConfigurations(
        fallback configuration: HAConnectionConfiguration
    ) async throws -> [(candidate: HAConnectionRouteCandidate?, configuration: HAConnectionConfiguration)] {
        guard let settings = currentConnectionSettings, settings.hasServerURL else {
            return [(nil, configuration)]
        }

        let selection = routeSelection(for: settings)
        let baseConfiguration = try await validConfiguration(baseURLString: selection.authenticationBaseURLString)
        let candidates = selection.candidates.isEmpty
            ? [HAConnectionRouteCandidate(route: .current, baseURLString: configuration.baseURLString)]
            : selection.candidates

        return candidates.map { candidate in
            (candidate, baseConfiguration.routed(to: candidate.baseURLString))
        }
    }

    private var shouldRefreshAfterResume: Bool {
        guard let lastSuspendedAt else {
            return false
        }

        return Date().timeIntervalSince(lastSuspendedAt) >= resumeRefreshInterval
    }

    private func setPendingCommand(
        entityID: String,
        expectedState: String?,
        expectedAttributes: [String: JSONValue] = [:]
    ) -> HAEntityPendingCommand {
        let pendingCommand = HAEntityPendingCommand(
            entityID: entityID,
            expectedState: expectedState,
            expectedAttributes: expectedAttributes
        )
        pendingCommandTasksByID[entityID]?.cancel()
        pendingCommandTasksByID[entityID] = nil
        stateStore.setPendingCommand(pendingCommand)
        return pendingCommand
    }

    private func schedulePendingResolution(for pendingCommand: HAEntityPendingCommand) {
        let timeout = pendingCommandTimeout
        pendingCommandTasksByID[pendingCommand.entityID]?.cancel()
        pendingCommandTasksByID[pendingCommand.entityID] = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }

            await self?.resolvePendingCommand(pendingCommand)
        }
    }

    private func resolvePendingCommand(_ pendingCommand: HAEntityPendingCommand) async {
        guard stateStore.pendingCommand(for: pendingCommand.entityID) == pendingCommand else {
            pendingCommandTasksByID[pendingCommand.entityID] = nil
            return
        }

        await refreshStates()

        guard stateStore.pendingCommand(for: pendingCommand.entityID) == pendingCommand else {
            pendingCommandTasksByID[pendingCommand.entityID] = nil
            return
        }

        clearPendingCommand(pendingCommand)
        serviceFeedback = HAServiceFeedback(
            title: "State not confirmed",
            message: entityDisplayName(for: pendingCommand.entityID),
            style: .failure
        )
    }

    private func clearPendingCommand(_ pendingCommand: HAEntityPendingCommand) {
        guard stateStore.pendingCommand(for: pendingCommand.entityID) == pendingCommand else {
            return
        }

        stateStore.clearPendingCommand(entityID: pendingCommand.entityID)
        pendingCommandTasksByID[pendingCommand.entityID]?.cancel()
        pendingCommandTasksByID[pendingCommand.entityID] = nil
    }

    private func cancelPendingCommandTasks() {
        for task in pendingCommandTasksByID.values {
            task.cancel()
        }
        pendingCommandTasksByID.removeAll()
    }

    private func entityDisplayName(for entityID: String?) -> String? {
        guard let entityID else { return nil }
        return stateStore.entity(for: entityID)?.displayName ?? entityID
    }

    private func serviceFailureMessage(
        domain: String,
        service: String,
        entityID: String?,
        error: Error,
        isRecoveringConnection: Bool = false
    ) -> String {
        let target = entityDisplayName(for: entityID) ?? "\(domain).\(service)"
        let actionName = readableServiceName(service)

        if isRecoveringConnection {
            return "\(target): \(actionName) did not finish because the connection dropped. Homestead is reconnecting now."
        }

        return "\(target): \(actionName) failed. \(serviceFailureRecoveryText(for: error))"
    }

    private func serviceFailureRecoveryText(for error: Error) -> String {
        if let webSocketError = error as? HAWebSocketError {
            switch webSocketError {
            case .notConnected:
                return "Reconnect to Home Assistant, then try again."
            case .requestTimedOut:
                return "Home Assistant did not respond in time. Try again in a moment."
            case .transportFailure:
                return "The Home Assistant connection is unavailable. Try again after reconnecting."
            case .authenticationFailed:
                return "Sign in again from Settings > Account."
            case .invalidURL, .unexpectedMessage, .requestFailed, .missingResult:
                return webSocketError.localizedDescription
            }
        }

        return error.localizedDescription
    }

    private func readableServiceName(_ service: String) -> String {
        service
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggleServiceName(for entityID: String) -> String {
        stateStore.entity(for: entityID)?.state == "on" ? "turn_off" : "turn_on"
    }
}

actor HAStateEventBatcher {
    private let flushInterval: Duration
    private var pendingUpdatesByID: [String: HAStateChangedEventDTO] = [:]
    private var flushTask: Task<Void, Never>?
    private var flushHandler: (@MainActor @Sendable ([HAStateChangedEventDTO]) -> Void)?

    init(flushInterval: Duration = .milliseconds(200)) {
        self.flushInterval = flushInterval
    }

    func setFlushHandler(_ handler: (@MainActor @Sendable ([HAStateChangedEventDTO]) -> Void)?) {
        flushHandler = handler
    }

    func enqueue(_ update: HAStateChangedEventDTO) {
        pendingUpdatesByID[update.entityID] = update
        scheduleFlushIfNeeded()
    }

    private func scheduleFlushIfNeeded() {
        guard flushTask == nil else {
            return
        }

        flushTask = Task {
            do {
                try await Task.sleep(for: flushInterval)
            } catch {
                return
            }

            await flush()
        }
    }

    private func flush() async {
        let updates = Array(pendingUpdatesByID.values)
        pendingUpdatesByID.removeAll()
        flushTask = nil

        guard !updates.isEmpty, let flushHandler else {
            return
        }

        await flushHandler(updates)
    }

    func discardPendingUpdates() {
        flushTask?.cancel()
        flushTask = nil
        pendingUpdatesByID.removeAll()
    }
}

private extension Error {
    var shouldReconnectHomeAssistantSocket: Bool {
        guard let webSocketError = self as? HAWebSocketError else {
            return false
        }

        switch webSocketError {
        case .notConnected, .requestTimedOut, .transportFailure:
            return true
        case .invalidURL, .unexpectedMessage, .authenticationFailed, .requestFailed, .missingResult:
            return false
        }
    }
}
