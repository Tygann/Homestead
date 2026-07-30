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
    private(set) var hasKnownSession = false
    private(set) var mobileAppRegistrationState: HAMobileAppRegistrationState = .unregistered
    private(set) var mobileAppPushNotificationState: HAMobileAppPushNotificationState = .unavailable
    private(set) var authState: HAAuthState = .signedOut
    private(set) var currentUserDisplayName: String?
    private(set) var currentUserEntityPicturePath: String?
    private(set) var currentUserIsAdmin = false
    private(set) var isNetworkAvailable = true
    private(set) var suppressesTransientConnectionHealth = false
    private(set) var serviceRegistry: HAServiceRegistry = .empty
    private(set) var serverConfiguration: HAServerConfigurationSnapshot?
    private(set) var serverEnvironment: HAServerEnvironmentSnapshot?
    private(set) var serverConfigurationStatus: HAServerConfigurationStatus = .unavailable
    private(set) var stateCacheMetadata: HAStateCacheMetadata?
    private(set) var activeRouteSummary: HAConnectionRouteSummary?
    private(set) var lastAuthenticationErrorMessage: String?
    private(set) var isSwitchingServer = false
    private(set) var serverOperationErrorMessage: String?

    var activityCacheUserIdentifier: String {
        currentUserID ?? currentUserDisplayName ?? "current-user"
    }

    @ObservationIgnored private let client: any HAWebSocketClientProtocol
    @ObservationIgnored private let httpClient: any HAHTTPClientProtocol
    @ObservationIgnored private let mobileAppClient: any HAMobileAppClientProtocol
    @ObservationIgnored private var mobileAppRegistrationStore: any HAMobileAppRegistrationStore
    @ObservationIgnored private let mobileAppDeviceIDStore: any HAMobileAppDeviceIDStore
    @ObservationIgnored private let pushRelayTokenStore: any PushRelayTokenStore
    @ObservationIgnored private let nativeNotificationService: NativeNotificationService
    @ObservationIgnored private var authManager: HAOAuthManager
    @ObservationIgnored private let authManagerProvider: (UUID) -> HAOAuthManager
    @ObservationIgnored private let mobileAppRegistrationStoreProvider: (UUID) -> any HAMobileAppRegistrationStore
    @ObservationIgnored private let oauthAuthorizer: any HAOAuthAuthorizing
    @ObservationIgnored private let currentWiFiNetworkProvider: any CurrentWiFiNetworkProviding
    @ObservationIgnored private let stateStore: HAStateStore
    @ObservationIgnored private let stateCache: HAStateCache
    @ObservationIgnored private let dashboardHistoryCache: DashboardHistoryCache
    @ObservationIgnored private let stateEventBatcher = HAStateEventBatcher()
    @ObservationIgnored private var activeConfiguration: HAConnectionConfiguration?
    @ObservationIgnored private var currentUserID: String?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var stateSyncTask: Task<Void, Never>?
    @ObservationIgnored private var stateEnrichmentTask: Task<Void, Never>?
    @ObservationIgnored private var registryRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var connectionHealthGraceTask: Task<Void, Never>?
    @ObservationIgnored private var pendingCommandTasksByID: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var weatherForecastSubscriptionIDsByEntityID: [String: [Int]] = [:]
    @ObservationIgnored private var weatherForecastSessionIDsByEntityID: [String: UUID] = [:]
    @ObservationIgnored private var weatherForecastConsumerIDsByEntityID: [String: Set<String>] = [:]
    @ObservationIgnored private var bufferedStateChangesByID: [String: HAStateChangedEventDTO] = [:]
    @ObservationIgnored private var isBufferingStateChanges = false
    @ObservationIgnored private var lastSuspendedAt: Date?
    @ObservationIgnored private var shouldReconnect = false
    @ObservationIgnored private var connectionGeneration: UInt = 0
    @ObservationIgnored private weak var currentConnectionSettings: HAConnectionSettings?
    @ObservationIgnored private var networkContext: HAConnectionNetworkContext
    @ObservationIgnored private var reachabilityMonitor: NWPathMonitor?
    @ObservationIgnored private let reachabilityQueue = DispatchQueue(label: "com.tyler.Homestead.homeAssistantReachability")
    @ObservationIgnored private let reconnectDelaySeconds = HAConnectionRecoveryPolicy.defaultReconnectDelaySeconds
    @ObservationIgnored private let pendingCommandTimeout: Duration = .seconds(3)
    @ObservationIgnored private let resumeRefreshInterval: TimeInterval = 5
    @ObservationIgnored private let foregroundConnectionHealthGrace: Duration = .seconds(2)
    @ObservationIgnored private let automaticallyRegistersMobileApp: Bool

    init(
        stateStore: HAStateStore,
        client: any HAWebSocketClientProtocol = HAWebSocketClient(),
        stateCache: HAStateCache = HAStateCache(),
        connectionStatus: HAConnectionStatus = .disconnected,
        dataFreshness: HADataFreshness = .empty,
        serviceFeedback: HAServiceFeedback? = nil,
        authState: HAAuthState = .signedOut,
        httpClient: (any HAHTTPClientProtocol)? = nil,
        mobileAppClient: (any HAMobileAppClientProtocol)? = nil,
        mobileAppRegistrationStore: (any HAMobileAppRegistrationStore)? = nil,
        mobileAppDeviceIDStore: (any HAMobileAppDeviceIDStore)? = nil,
        pushRelayTokenStore: (any PushRelayTokenStore)? = nil,
        nativeNotificationService: NativeNotificationService? = nil,
        authManager: HAOAuthManager? = nil,
        authManagerProvider: ((UUID) -> HAOAuthManager)? = nil,
        mobileAppRegistrationStoreProvider: ((UUID) -> any HAMobileAppRegistrationStore)? = nil,
        oauthAuthorizer: (any HAOAuthAuthorizing)? = nil,
        currentWiFiNetworkProvider: (any CurrentWiFiNetworkProviding)? = nil,
        dashboardHistoryCache: DashboardHistoryCache = DashboardHistoryCache(),
        networkContext: HAConnectionNetworkContext = .availableExternal,
        automaticallyRegistersMobileApp: Bool = true,
        currentUserIsAdmin: Bool = false
    ) {
        self.stateStore = stateStore
        self.client = client
        self.dataFreshness = dataFreshness
        self.serviceFeedback = serviceFeedback
        self.httpClient = httpClient ?? HAHTTPClient()
        self.mobileAppClient = mobileAppClient ?? HAMobileAppClient()
        self.mobileAppRegistrationStore = mobileAppRegistrationStore ?? KeychainHAMobileAppRegistrationStore()
        self.mobileAppDeviceIDStore = mobileAppDeviceIDStore ?? KeychainHAMobileAppDeviceIDStore()
        self.pushRelayTokenStore = pushRelayTokenStore ?? KeychainPushRelayTokenStore()
        self.nativeNotificationService = nativeNotificationService ?? NativeNotificationService()
        self.authManager = authManager ?? HAOAuthManager()
        self.authManagerProvider = authManagerProvider ?? { profileID in
            HAOAuthManager(tokenStore: KeychainHAOAuthTokenStore(profileID: profileID), profileID: profileID)
        }
        self.mobileAppRegistrationStoreProvider = mobileAppRegistrationStoreProvider ?? { profileID in
            KeychainHAMobileAppRegistrationStore(profileID: profileID)
        }
        self.oauthAuthorizer = oauthAuthorizer ?? HAWebAuthenticationSession()
        self.currentWiFiNetworkProvider = currentWiFiNetworkProvider ?? SystemCurrentWiFiNetworkProvider()
        self.dashboardHistoryCache = dashboardHistoryCache
        self.stateCache = stateCache
        self.networkContext = networkContext
        self.automaticallyRegistersMobileApp = automaticallyRegistersMobileApp
        self.currentUserIsAdmin = currentUserIsAdmin
        self.connectionStatus = connectionStatus == .disconnected && authState.isSignedIn
            ? .preparing
            : connectionStatus
        self.authState = authState
        self.hasKnownSession = authState.isSignedIn
        refreshMobileAppRegistrationState()
    }

    func connectIfPossible(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        guard settings.hasServerURL,
              authState.isSignedIn,
              connectionStatus != .connected,
              connectionStatus != .connecting,
              connectionStatus != .reconnecting else {
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

    func restoreCachedStatesSynchronouslyIfPossible(
        settings: HAConnectionSettings,
        tokenStore: any HAOAuthTokenStore,
        cacheDirectoryURL: URL? = nil
    ) {
        currentConnectionSettings = settings
        authState = HAOAuthManager.status(tokenStore: tokenStore)

        guard settings.hasServerURL,
              !stateStore.hasLoadedInitialSnapshot,
              let configuration = cachedConfiguration(settings: settings, tokenStore: tokenStore),
              let snapshot = HAStateCache.loadSynchronously(for: configuration, directoryURL: cacheDirectoryURL),
              !snapshot.entities.isEmpty else {
            return
        }

        applyCachedSnapshot(snapshot, configuration: configuration)
        hasCompletedInitialCacheLoad = true
    }

    func connect(baseURLString: String) async {
        await connect(routeSelection: HAConnectionRouteResolver.explicit(baseURLString: baseURLString))
    }

    func connect(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        await refreshCurrentWiFiSSIDIfNeeded(settings: settings)
        await connect(routeSelection: routeSelection(for: settings))
    }

    func refreshCurrentWiFiSSID() async -> String? {
        let ssid = await currentWiFiNetworkProvider.currentSSID()
        networkContext = networkContext.withCurrentWiFiSSID(ssid)
        return ssid
    }

    private func connect(routeSelection: HAConnectionRouteSelection) async {
        let generation = connectionGeneration
        reconnectTask?.cancel()
        reconnectTask = nil
        stateSyncTask?.cancel()
        stateSyncTask = nil
        stateEnrichmentTask?.cancel()
        stateEnrichmentTask = nil
        registryRefreshTask?.cancel()
        registryRefreshTask = nil
        discardBufferedStateChanges()
        await stateEventBatcher.discardPendingUpdates()
        let previousDataSourceID = activeConfiguration?.dataSourceID
        if activeConfiguration != nil {
            discardWeatherForecastSubscriptions()
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
            guard generation == connectionGeneration else { return }
        } catch {
            failConnection(with: error)
            return
        }

        if previousDataSourceID != baseConfiguration.dataSourceID {
            serviceRegistry = .empty
            serverConfiguration = nil
            serverEnvironment = nil
            serverConfigurationStatus = .unavailable
            await dashboardHistoryCache.removeAll()
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
                    configuration: routeConfiguration,
                    timeout: candidate.route == .internalURL ? .seconds(4) : nil
                )
                guard generation == connectionGeneration else {
                    await client.disconnect()
                    return
                }
                activeConfiguration = connectedConfiguration
                activeRouteSummary = HAConnectionRouteSummary(
                    route: candidate.route,
                    baseURLString: connectedConfiguration.baseURLString
                )
                refreshMobileAppRegistrationState(for: connectedConfiguration)
                lastErrorMessage = nil
                endConnectionHealthGrace()
                connectionStatus = .connected
                dataFreshness = .refreshing(lastUpdated: dataFreshness.lastKnownUpdateDate)
                startStateSync(configuration: connectedConfiguration)
                if automaticallyRegistersMobileApp {
                    await registerMobileAppIfNeeded(configuration: connectedConfiguration)
                    await startMobileAppPushNotificationChannel(configuration: connectedConfiguration)
                }
                return
            } catch {
                lastConnectionError = error
                guard HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: error) else {
                    break
                }
            }
        }

        if routeSelection.candidates.isEmpty {
            lastConnectionError = HAWebSocketError.invalidURL
        }

        if let error = lastConnectionError {
            handleConnectFailure(error, fallbackConfiguration: preferredConfiguration)
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
        connectionGeneration &+= 1
        shouldReconnect = false
        endConnectionHealthGrace()
        reconnectTask?.cancel()
        reconnectTask = nil
        stateSyncTask?.cancel()
        stateSyncTask = nil
        stateEnrichmentTask?.cancel()
        stateEnrichmentTask = nil
        registryRefreshTask?.cancel()
        registryRefreshTask = nil
        discardBufferedStateChanges()
        await stateEventBatcher.discardPendingUpdates()
        cancelPendingCommandTasks()
        discardWeatherForecastSubscriptions()
        await client.disconnect()
        await dashboardHistoryCache.removeAll()
        activeConfiguration = nil
        activeRouteSummary = nil
        mobileAppPushNotificationState = .unavailable
        currentUserID = nil
        currentUserDisplayName = nil
        currentUserEntityPicturePath = nil
        currentUserIsAdmin = false
        serviceRegistry = .empty
        serverConfiguration = nil
        serverEnvironment = nil
        serverConfigurationStatus = .unavailable
        stateCacheMetadata = nil
        dataFreshness = staleFreshness(nil)
        connectionStatus = .disconnected
    }

    func startWeatherForecastUpdates(
        for entityBox: HAEntityState,
        consumerID: String = "weather-detail"
    ) async {
        let entityID = entityBox.entityID
        weatherForecastConsumerIDsByEntityID[entityID, default: []].insert(consumerID)

        guard connectionStatus == .connected,
              let weather = entityBox.weatherEntity else {
            return
        }

        guard weatherForecastSessionIDsByEntityID[entityID] == nil else {
            return
        }

        weatherForecastSubscriptionIDsByEntityID[entityID] = []
        let sessionID = UUID()
        weatherForecastSessionIDsByEntityID[entityID] = sessionID
        var subscriptionIDs: [Int] = []

        // Reserve every supported forecast slot before the first subscription
        // can deliver data so the UI never observes a partially-started load.
        for type in weather.supportedForecastTypes {
            entityBox.beginLoadingWeatherForecast(type)
        }

        for type in weather.supportedForecastTypes {
            do {
                let subscriptionID = try await client.subscribeToWeatherForecast(
                    entityID: entityID,
                    forecastType: type
                ) { [weak self] event in
                    await self?.applyWeatherForecast(event, entityID: entityID, sessionID: sessionID)
                }
                guard weatherForecastSessionIDsByEntityID[entityID] == sessionID else {
                    try? await client.unsubscribe(subscriptionID: subscriptionID)
                    return
                }
                subscriptionIDs.append(subscriptionID)
                weatherForecastSubscriptionIDsByEntityID[entityID] = subscriptionIDs
            } catch {
                if weatherForecastSessionIDsByEntityID[entityID] == sessionID {
                    entityBox.failLoadingWeatherForecast(type, message: weatherForecastErrorMessage(error))
                }
            }
        }
    }

    func restartWeatherForecastUpdates(for entityBox: HAEntityState) async {
        await unsubscribeFromWeatherForecastUpdates(entityID: entityBox.entityID)
        guard weatherForecastConsumerIDsByEntityID[entityBox.entityID]?.isEmpty == false else { return }
        await startWeatherForecastUpdates(
            for: entityBox,
            consumerID: weatherForecastConsumerIDsByEntityID[entityBox.entityID]?.first ?? "weather-detail"
        )
    }

    func stopWeatherForecastUpdates(
        entityID: String,
        consumerID: String = "weather-detail"
    ) async {
        weatherForecastConsumerIDsByEntityID[entityID]?.remove(consumerID)
        guard weatherForecastConsumerIDsByEntityID[entityID]?.isEmpty != false else { return }
        weatherForecastConsumerIDsByEntityID.removeValue(forKey: entityID)
        await unsubscribeFromWeatherForecastUpdates(entityID: entityID)
    }

    private func unsubscribeFromWeatherForecastUpdates(entityID: String) async {
        let subscriptionIDs = weatherForecastSubscriptionIDsByEntityID.removeValue(forKey: entityID) ?? []
        weatherForecastSessionIDsByEntityID.removeValue(forKey: entityID)
        stateStore.entityBox(for: entityID)?.clearWeatherForecastLoadingState()

        for subscriptionID in subscriptionIDs {
            try? await client.unsubscribe(subscriptionID: subscriptionID)
        }
    }

    func refreshAuthState() async {
        let refreshedAuthState = await authManager.status()
        if refreshedAuthState.isSignedIn {
            hasKnownSession = true
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

    func authenticationState(for profileID: UUID) async -> HAAuthState {
        if currentConnectionSettings?.activeProfileID == profileID {
            return authState
        }
        return await authManagerProvider(profileID).status()
    }

    func signInWithHomeAssistant(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        await refreshCurrentWiFiSSIDIfNeeded(settings: settings)
        let routeSelection = routeSelection(for: settings)
        let baseURLString = routeSelection.preferredCandidate?.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines) ??
            routeSelection.authenticationBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
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
            settings.baseURL = baseURLString

            hasKnownSession = true
            authState = await authManager.status()
            lastErrorMessage = nil
            lastAuthenticationErrorMessage = nil
            await connect(settings: settings)
        } catch {
            let rawMessage = error.localizedDescription
            print("Home Assistant sign-in failed: \(rawMessage)")
            if isUserCancelledSignIn(error) {
                authState = .signedOut
                lastErrorMessage = nil
                lastAuthenticationErrorMessage = rawMessage
                return
            }

            let message = signInFailureMessage(for: error)
            authState = .refreshFailed(message)
            lastErrorMessage = message
            lastAuthenticationErrorMessage = rawMessage
        }
    }

    func signOut() async {
        do {
            try await authManager.signOut()
            try mobileAppRegistrationStore.deleteRegistration()
            await disconnect()
            hasKnownSession = false
            authState = .signedOut
            mobileAppRegistrationState = .unregistered
            lastErrorMessage = nil
            lastAuthenticationErrorMessage = nil
        } catch {
            authState = .refreshFailed(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func switchActiveProfile(
        to profileID: UUID,
        settings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration? = nil
    ) async -> Bool {
        guard profileID != settings.activeProfileID,
              settings.profileStore.profile(id: profileID)?.hasServerURL == true else {
            return profileID == settings.activeProfileID
        }

        isSwitchingServer = true
        serverOperationErrorMessage = nil
        defer { isSwitchingServer = false }

        await disconnect()
        guard settings.activateProfile(id: profileID) else { return false }
        dashboardConfiguration?.activateProfile(profileID)
        stateStore.replaceDataSourceIfNeeded("profile-\(profileID.uuidString.lowercased())")
        await CameraSnapshotStore.shared.removeAll()

        authManager = authManagerProvider(profileID)
        mobileAppRegistrationStore = mobileAppRegistrationStoreProvider(profileID)
        authState = await authManager.status()
        hasKnownSession = authState.isSignedIn
        refreshMobileAppRegistrationState()

        guard authState.isSignedIn else {
            connectionStatus = .disconnected
            dataFreshness = .empty
            return true
        }

        connectionStatus = .preparing
        await loadCachedStatesIfPossible(settings: settings)
        await connectIfPossible(settings: settings)
        return true
    }

    @discardableResult
    func addServer(
        baseURLString: String,
        settings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration? = nil
    ) async -> UUID? {
        let trimmedBaseURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else {
            serverOperationErrorMessage = HAWebSocketError.invalidURL.localizedDescription
            return nil
        }

        if let existing = settings.profileStore.profile(matchingBaseURL: trimmedBaseURL) {
            _ = await switchActiveProfile(
                to: existing.id,
                settings: settings,
                dashboardConfiguration: dashboardConfiguration
            )
            return existing.id
        }

        let profileID = UUID()
        let tokenStore = KeychainHAOAuthTokenStore(profileID: profileID)
        let pendingAuthManager = HAOAuthManager(tokenStore: tokenStore, profileID: profileID)
        let state = UUID().uuidString
        serverOperationErrorMessage = nil

        do {
            let authorizationURL = try await pendingAuthManager.authorizeURL(
                baseURLString: trimmedBaseURL,
                state: state
            )
            let callbackURL = try await oauthAuthorizer.authorize(
                authorizationURL: authorizationURL,
                callbackScheme: HAOAuthClientMetadata.callbackScheme
            )
            let authorizationCode = try authorizationCode(from: callbackURL, expectedState: state)
            _ = try await pendingAuthManager.signIn(
                baseURLString: trimmedBaseURL,
                authorizationCode: authorizationCode
            )

            settings.profileStore.addProfile(
                id: profileID,
                baseURL: trimmedBaseURL
            )
            _ = await switchActiveProfile(
                to: profileID,
                settings: settings,
                dashboardConfiguration: dashboardConfiguration
            )
            return profileID
        } catch {
            try? tokenStore.deleteCredential()
            if !isUserCancelledSignIn(error) {
                serverOperationErrorMessage = signInFailureMessage(for: error)
            }
            return nil
        }
    }

    @discardableResult
    func removeServer(
        profileID: UUID,
        removeFromDeviceAnyway: Bool = false,
        settings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration? = nil,
        appearanceSettings: HomesteadAppearanceSettings? = nil
    ) async -> Bool {
        guard settings.profileStore.profile(id: profileID) != nil else { return true }
        serverOperationErrorMessage = nil

        let manager = authManagerProvider(profileID)
        if !removeFromDeviceAnyway {
            do {
                try await manager.revokeAndSignOut()
            } catch {
                serverOperationErrorMessage = error.localizedDescription
                return false
            }
        } else {
            try? KeychainHAOAuthTokenStore(profileID: profileID).deleteCredential()
        }
        try? mobileAppRegistrationStoreProvider(profileID).deleteRegistration()
        if let profile = settings.profileStore.profile(id: profileID) {
            let cacheConfiguration = HAConnectionConfiguration(
                baseURLString: profile.baseURL,
                accessToken: "",
                profileID: profileID
            )
            await stateCache.remove(for: cacheConfiguration)
        }
        dashboardConfiguration?.removeProfileData(profileID)
        appearanceSettings?.removeProfileData(profileID)

        let wasActive = settings.activeProfileID == profileID
        if wasActive { await disconnect() }
        let fallbackID = settings.profileStore.removeProfile(id: profileID)

        guard wasActive, let fallbackID else { return true }
        guard settings.profileStore.profile(id: fallbackID)?.hasServerURL == true else {
            _ = settings.activateProfile(id: fallbackID)
            dashboardConfiguration?.activateProfile(fallbackID)
            authManager = authManagerProvider(fallbackID)
            mobileAppRegistrationStore = mobileAppRegistrationStoreProvider(fallbackID)
            authState = .signedOut
            hasKnownSession = false
            connectionStatus = .disconnected
            dataFreshness = .empty
            stateStore.replaceDataSourceIfNeeded("profile-\(fallbackID.uuidString.lowercased())")
            return true
        }

        let target = fallbackID
        _ = settings.activateProfile(id: target)
        dashboardConfiguration?.activateProfile(target)
        authManager = authManagerProvider(target)
        mobileAppRegistrationStore = mobileAppRegistrationStoreProvider(target)
        authState = await authManager.status()
        hasKnownSession = authState.isSignedIn
        stateStore.replaceDataSourceIfNeeded("profile-\(target.uuidString.lowercased())")
        await loadCachedStatesIfPossible(settings: settings)
        if authState.isSignedIn { await connectIfPossible(settings: settings) }
        return true
    }

    @discardableResult
    func reauthenticateServer(
        profileID: UUID,
        settings: HAConnectionSettings
    ) async -> Bool {
        guard let profile = settings.profileStore.profile(id: profileID) else { return false }
        let manager = authManagerProvider(profileID)
        let state = UUID().uuidString
        serverOperationErrorMessage = nil
        do {
            let authorizationURL = try await manager.authorizeURL(baseURLString: profile.baseURL, state: state)
            let callbackURL = try await oauthAuthorizer.authorize(
                authorizationURL: authorizationURL,
                callbackScheme: HAOAuthClientMetadata.callbackScheme
            )
            let code = try authorizationCode(from: callbackURL, expectedState: state)
            _ = try await manager.signIn(baseURLString: profile.baseURL, authorizationCode: code)
            if profileID == settings.activeProfileID {
                authManager = manager
                authState = await manager.status()
                hasKnownSession = authState.isSignedIn
                await connectIfPossible(settings: settings)
            }
            return true
        } catch {
            if !isUserCancelledSignIn(error) { serverOperationErrorMessage = signInFailureMessage(for: error) }
            return false
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
        case .pressButton:
            await pressButton(entityID: entityID)
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

    func installAvailableUpdates(_ updates: [HAUpdateEntity], backup: Bool? = nil) async {
        for update in updates where update.status == .available && update.supportsInstall {
            await installUpdate(
                entityID: update.entityID,
                backup: backup,
                version: update.supportsSpecificVersion ? update.latestVersion : nil
            )
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

    func fetchUpdateReleaseNotes(entityID: String) async throws -> String? {
        try await client.fetchUpdateReleaseNotes(entityID: entityID)
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

        return HAActivityRow.makeRows(
            from: entries,
            entityDisplayName: { [stateStore] entityID in
                stateStore.entity(for: entityID)?.displayName
            },
            entityDeviceClass: { [stateStore] entityID in
                let entityBox = stateStore.entityBox(for: entityID)
                return entityBox?.binarySensorEntity?.deviceClass ?? entityBox?.coverEntity?.deviceClass
            },
            contextUserDisplayName: { [weak self] userID in
                guard let self else {
                    return nil
                }

                if let personName = self.stateStore.personDisplayName(forUserID: userID) {
                    return personName
                }

                guard userID == self.currentUserID else {
                    return nil
                }

                return self.currentUserDisplayName
            },
            historicalStateDisplayValue: { [stateStore] entityID, state in
                if let date = HADateParser.date(from: state) {
                    return date.formatted(date: .abbreviated, time: .shortened)
                }

                guard let sensor = stateStore.entityBox(for: entityID)?.sensorEntity else {
                    return nil
                }

                return SensorEntity(
                    entityID: sensor.entityID,
                    displayName: sensor.displayName,
                    value: state,
                    unit: sensor.unit,
                    deviceClass: sensor.deviceClass,
                    stateClass: sensor.stateClass,
                    displayPrecision: sensor.displayPrecision,
                    lastUpdated: nil,
                    suggestedMinimumValue: sensor.suggestedMinimumValue,
                    suggestedMaximumValue: sensor.suggestedMaximumValue
                ).formattedValue
            }
        )
    }

    func fetchSupervisorApps(settings: HAConnectionSettings) async -> HASupervisorAppsFetchResult {
        currentConnectionSettings = settings
        guard settings.hasServerURL else {
            return .unavailable(.notConfigured)
        }

        guard connectionStatus == .connected else {
            return .unavailable(.connectionUnavailable)
        }

        do {
            let response = try await client.fetchSupervisorApps()
            return .available(HASupervisorApp.installedApps(from: response))
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .timedOut:
                return .unavailable(.connectionUnavailable)
            default:
                return .failed(urlError.localizedDescription)
            }
        } catch let webSocketError as HAWebSocketError {
            switch webSocketError {
            case .invalidURL:
                return .unavailable(.notConfigured)
            case .notConnected, .requestTimedOut, .transportFailure:
                return .unavailable(.connectionUnavailable)
            case .unexpectedMessage, .authenticationFailed, .requestFailed, .missingResult:
                if webSocketError.isSupervisorAppsUnsupported {
                    return .unavailable(.unsupported)
                }
                return .failed(webSocketError.localizedDescription)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func fetchSupervisorAppDetails(
        settings: HAConnectionSettings,
        slug: String
    ) async throws -> HASupervisorAppDetails {
        currentConnectionSettings = settings
        guard settings.hasServerURL else {
            throw HAWebSocketError.invalidURL
        }

        guard connectionStatus == .connected else {
            throw HAWebSocketError.notConnected
        }

        let normalizedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSlug.isEmpty else {
            throw HAWebSocketError.requestFailed("The Home Assistant app identifier is missing.")
        }

        return HASupervisorAppDetails(
            dto: try await client.fetchSupervisorAppInfo(slug: normalizedSlug)
        )
    }

    func performSupervisorAppLifecycleAction(
        settings: HAConnectionSettings,
        slug: String,
        action: HASupervisorAppLifecycleAction
    ) async throws -> HASupervisorAppDetails {
        currentConnectionSettings = settings
        guard settings.hasServerURL else {
            throw HAWebSocketError.invalidURL
        }

        guard connectionStatus == .connected else {
            throw HAWebSocketError.notConnected
        }

        guard currentUserIsAdmin else {
            throw HAWebSocketError.requestFailed("Administrator access is required to control apps.")
        }

        let normalizedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSlug.isEmpty else {
            throw HAWebSocketError.requestFailed("The Home Assistant app identifier is missing.")
        }

        try await client.performSupervisorAppLifecycleAction(
            slug: normalizedSlug,
            action: action
        )

        return HASupervisorAppDetails(
            dto: try await client.fetchSupervisorAppInfo(slug: normalizedSlug)
        )
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

        let entityBox = stateStore.entityBox(for: request.entityID)
        let entity = entityBox?.homeEntity ?? stateStore.entity(for: request.entityID)
        let binarySensor = entityBox?.binarySensorEntity
        let cover = entityBox?.coverEntity
        let domain = entity?.domain ?? EntityDomain(entityID: request.entityID)
        let profile = EntityCapabilityRegistry.profile(for: domain)
        guard profile.supports(.showActivity) else {
            throw HAWebSocketError.unexpectedMessage(
                "History is not supported for \(domain.rawValue)."
            )
        }

        let configuration = try await preferredConfiguration(for: settings)
        activeConfiguration = configuration
        let response = try await httpClient.fetchHistory(configuration: configuration, request: request)

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
                domain: .entity(domain),
                range: range
            )
        }
    }

    func fetchAutomationOverview(entityID: String) async throws -> HAAutomationOverview {
        let response = try await client.fetchAutomationConfiguration(entityID: entityID)
        return HAAutomationOverviewBuilder.make(
            config: response.config,
            entityName: { [stateStore] targetID in
                stateStore.entity(for: targetID)?.displayName ?? targetID
            },
            areaName: { [stateStore] registryID in
                stateStore.automationTargetName(for: registryID)
            },
            deviceName: { [stateStore] deviceID in
                stateStore.deviceName(forDeviceID: deviceID)
            }
        )
    }

    func fetchScriptOverview(entityID: String) async throws -> HAAutomationOverview {
        let response = try await client.fetchScriptConfiguration(entityID: entityID)
        return HAAutomationOverviewBuilder.makeScript(
            config: response.config,
            entityName: { [stateStore] targetID in
                stateStore.entity(for: targetID)?.displayName ?? targetID
            },
            areaName: { [stateStore] registryID in
                stateStore.automationTargetName(for: registryID)
            },
            deviceName: { [stateStore] deviceID in
                stateStore.deviceName(forDeviceID: deviceID)
            }
        )
    }

    func fetchAutomationTimeline(
        entityID: String,
        range: HAHistoryRangePreset
    ) async throws -> HAHistoryTimeline {
        let configuration = try await client.fetchAutomationConfiguration(entityID: entityID)
        let itemID = configuration.config["id"]?.stringValue
            ?? stateStore.rawEntity(for: entityID)?.attributes["id"]?.stringValue
            ?? String(entityID.dropFirst("automation.".count))
        let traces = try await client.fetchAutomationTraces(itemID: itemID)
        let interval = range.interval()
        let displayName = stateStore.entity(for: entityID)?.displayName ?? entityID

        return HAAutomationTraceTimeline.make(
            traces: traces,
            entityID: entityID,
            displayName: displayName,
            range: range,
            interval: DateInterval(start: interval.start, end: interval.end)
        )
    }

    func fetchDashboardHistory(
        settings: HAConnectionSettings,
        entityID: String,
        range: HAHistoryRangePreset = .sixHours,
        endingAt endDate: Date = Date()
    ) async throws -> HAHistoryChartSeries {
        currentConnectionSettings = settings
        guard settings.hasServerURL, !entityID.isEmpty else {
            throw HAWebSocketError.invalidURL
        }

        let configuration = try await preferredConfiguration(for: settings)
        activeConfiguration = configuration
        let sensor = stateStore.entityBox(for: entityID)?.sensorEntity
        let entity = stateStore.entity(for: entityID)
        let displayName = sensor?.displayName ?? entity?.displayName ?? entityID
        let unit = sensor?.unitText
        let key = DashboardHistoryCache.Key(
            dataSourceID: configuration.dataSourceID,
            entityID: entityID,
            range: range,
            endDateMinuteBucket: Int(endDate.timeIntervalSince1970 / 60)
        )
        let httpClient = httpClient

        return try await dashboardHistoryCache.series(for: key) {
            let interval = range.interval(endingAt: endDate)
            let request = HAHistoryRequest(
                startDate: interval.start,
                endDate: interval.end,
                entityID: entityID
            )
            let response = try await httpClient.fetchHistory(configuration: configuration, request: request)

            return HAHistoryChartSeries.make(
                response: response,
                request: request,
                displayName: displayName,
                unit: unit,
                range: range
            )
        }
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
            serverEnvironment = nil
            serverConfigurationStatus = .unavailable
            return
        }

        serverConfigurationStatus = .loading

        do {
            let config = try await client.fetchConfig()
            let environment = await serverEnvironmentSnapshot(for: config)
            let snapshot = HAServerConfigurationSnapshot(dto: config)
            serverConfiguration = snapshot
            serverEnvironment = environment
            currentConnectionSettings?.adoptServerRoutes(from: snapshot)
            currentConnectionSettings?.updateServerName(snapshot.locationName)
            serverConfigurationStatus = .loaded(snapshot.loadedAt)
        } catch {
            serverConfigurationStatus = .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func updateServerName(_ name: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            serverOperationErrorMessage = "Enter a server name."
            return false
        }
        guard connectionStatus == .connected else {
            serverOperationErrorMessage = "Connect to Home Assistant before changing its name."
            return false
        }

        serverOperationErrorMessage = nil
        do {
            try await client.updateLocationName(trimmedName)
            await refreshServerConfiguration()
            guard serverConfiguration?.locationName == trimmedName else {
                serverOperationErrorMessage = "Home Assistant did not return the updated name."
                return false
            }
            return true
        } catch {
            serverOperationErrorMessage = error.localizedDescription
            return false
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
        case .pressButton:
            return serviceActionAvailable(domain: "button", service: "press")
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

    func refreshMobileAppPushRegistrationIfNeeded(settings: HAConnectionSettings) async {
        currentConnectionSettings = settings
        guard settings.hasServerURL, authState.isSignedIn else {
            return
        }

        do {
            let configuration = try await preferredConfiguration(for: settings)
            await registerMobileAppIfNeeded(configuration: configuration, force: false)
        } catch {
            mobileAppRegistrationState = .failed(error.localizedDescription)
            authState = authFailureState(for: error)
        }
    }

    private func registerMobileAppIfNeeded(
        configuration: HAConnectionConfiguration,
        force: Bool = false
    ) async {
        let existingRegistration: HAMobileAppRegistrationInfo?
        do {
            existingRegistration = try mobileAppRegistrationStore.readRegistration()
        } catch {
            mobileAppRegistrationState = .failed(error.localizedDescription)
            return
        }

        if !force,
           let registration = existingRegistration,
           registration.hasCurrentRemotePushRegistration(for: configuration) {
            mobileAppRegistrationState = .registered(HAMobileAppRegistrationSummary(info: registration))
            return
        }

        mobileAppRegistrationState = .registering

        do {
            let deviceID = try mobileAppDeviceIDStore.readOrCreateDeviceID()
            let pushRelayToken = try pushRelayTokenStore.readOrCreateRelayToken()

            let registration: HAMobileAppRegistrationInfo
            if let existingRegistration,
               existingRegistration.serverIdentifier == configuration.dataSourceID {
                let update = HAMobileAppRegistrationRequestFactory.makeUpdate(
                    userDisplayName: currentUserDisplayName,
                    pushRelayToken: pushRelayToken
                )
                try await mobileAppClient.updateRegistration(
                    configuration: configuration,
                    registration: existingRegistration,
                    update: update
                )
                registration = HAMobileAppRegistrationInfo(
                    serverIdentifier: configuration.dataSourceID,
                    deviceID: existingRegistration.deviceID,
                    appID: existingRegistration.appID,
                    appName: existingRegistration.appName,
                    appVersion: update.appVersion,
                    deviceName: update.deviceName,
                    webhookID: existingRegistration.webhookID,
                    cloudhookURL: existingRegistration.cloudhookURL,
                    remoteUIURL: existingRegistration.remoteUIURL,
                    secret: existingRegistration.secret,
                    supportsWebSocketNotifications: update.appData?["push_websocket_channel"]?.boolValue == true,
                    supportsCloudPushNotifications: update.includesRemotePushAppData
                )
                #if DEBUG
                print("Home Assistant mobile-app registration updated: remotePush=\(update.includesRemotePushAppData), localPush=\(update.appData?["push_websocket_channel"]?.boolValue == true)")
                #endif
            } else {
                let request = HAMobileAppRegistrationRequestFactory.makeRequest(
                    deviceID: deviceID,
                    userDisplayName: currentUserDisplayName,
                    pushRelayToken: pushRelayToken
                )
                let response = try await mobileAppClient.register(
                    configuration: configuration,
                    request: request
                )
                registration = HAMobileAppRegistrationInfo(
                    serverIdentifier: configuration.dataSourceID,
                    request: request,
                    response: response
                )
                #if DEBUG
                print("Home Assistant mobile-app registration created: remotePush=\(request.includesRemotePushAppData), localPush=\(request.appData?["push_websocket_channel"]?.boolValue == true)")
                #endif
            }
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

            return try HomeAssistantImageRequestBuilder.request(
                configuration: configuration,
                pathOrURL: trimmedPathOrURL
            )
        } catch {
            return nil
        }
    }

    func homeAssistantFrontendDestination(
        settings: HAConnectionSettings,
        entityID: String
    ) async -> HomeAssistantFrontendEntityDestination? {
        currentConnectionSettings = settings
        await refreshCurrentWiFiSSIDIfNeeded(settings: settings)

        let selection = routeSelection(for: settings)
        let baseURLString = activeRouteSummary?.baseURLString
            ?? selection.preferredCandidate?.baseURLString
            ?? selection.authenticationBaseURLString
        let rawEntity = stateStore.rawEntity(for: entityID)
        let isPersonEditable = rawEntity?.attributes["editable"]?.boolValue
            ?? (rawEntity?.attributes["editable"]?.stringValue?.lowercased() != "false")

        return HomeAssistantFrontendEntityDestinationResolver.destination(
            baseURLString: baseURLString,
            entityID: entityID,
            configurationID: rawEntity?.attributes["id"]?.stringValue,
            registryUniqueID: stateStore.entityRegistryUniqueID(for: entityID),
            isPersonEditable: isPersonEditable
        )
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

    nonisolated static func numberServiceDomain(for entityID: String) -> String {
        entityID.hasPrefix("input_number.") ? "input_number" : "number"
    }

    nonisolated static func textServiceDomain(for entityID: String) -> String {
        entityID.hasPrefix("input_text.") ? "input_text" : "text"
    }

    func setNumberValue(entityID: String, value: Double) async {
        let serviceData = ["value": JSONValue.number(value)]
        let pendingCommand = setPendingCommand(
            entityID: entityID,
            expectedState: nil
        )

        let succeeded = await callService(
            domain: Self.numberServiceDomain(for: entityID),
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

    func setTextValue(entityID: String, value: String) async {
        let pendingCommand = setPendingCommand(entityID: entityID, expectedState: value)
        let succeeded = await callService(
            domain: Self.textServiceDomain(for: entityID),
            service: "set_value",
            entityID: entityID,
            serviceData: ["value": .string(value)]
        )
        if succeeded {
            schedulePendingResolution(for: pendingCommand)
        } else {
            clearPendingCommand(pendingCommand)
        }
    }

    func setTemporalValue(entityID: String, date: Date) async {
        guard let temporal = stateStore.entityBox(for: entityID)?.temporalEntity else { return }
        let pendingCommand = setPendingCommand(entityID: entityID, expectedState: nil)
        let succeeded = await callService(
            domain: temporal.serviceDomain,
            service: temporal.service,
            entityID: entityID,
            serviceData: temporal.serviceData(for: date)
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

        let clampedTemperature = ClimateSetpointAdjustment(climate: climate)
            .clampedSingleTemperature(temperature)
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

        let range = ClimateSetpointAdjustment(climate: climate)
            .clampedRange(lowTemperature: lowTemperature, highTemperature: highTemperature)
        let serviceData = [
            "target_temp_low": JSONValue.number(range.lowTemperature),
            "target_temp_high": JSONValue.number(range.highTemperature)
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
        currentUserIsAdmin = currentUser.isAdmin == true
        refreshCurrentUserEntityPicturePath()
    }

    private func applyCachedCurrentUser(_ currentUser: HAStateCacheCurrentUser?) {
        currentUserIsAdmin = false
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
                style: .failure,
                entityID: entityID
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
                style: .failure,
                entityID: entityID
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
                    style: .success,
                    entityID: entityID
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
                style: .failure,
                entityID: entityID
            )
            return false
        }
    }

    func actions(for entityID: String) async -> [HAEntityAction] {
        do {
            let identifiers = try await client.fetchServicesForTarget(entityID: entityID)
            return serviceRegistry.actions(with: identifiers)
        } catch {
            // Older servers and temporarily unavailable metadata still get the domain catalog fallback.
            return serviceRegistry.actions(for: entityID)
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
        guard !stateStore.hasLoadedInitialSnapshot else {
            return
        }

        #if DEBUG
        let startDate = Date()
        #endif
        applyCachedSnapshot(snapshot, configuration: configuration)
        #if DEBUG
        print(
            "Home Assistant cached snapshot applied: \(snapshot.entities.count) entities in \(String(format: "%.3f", Date().timeIntervalSince(startDate)))s"
        )
        #endif
    }

    private func applyCachedSnapshot(
        _ snapshot: HAStateCacheSnapshot,
        configuration: HAConnectionConfiguration
    ) {
        if stateStore.dataSourceID != configuration.dataSourceID {
            stateStore.replaceDataSourceIfNeeded(configuration.dataSourceID)
            stateCacheMetadata = nil
        }
        if let registryMetadata = snapshot.registryMetadata {
            stateStore.applyRegistryMetadata(registryMetadata)
        }
        stateStore.applySnapshot(snapshot.entities)
        applyCachedCurrentUser(snapshot.currentUser)
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

    private func cachedConfiguration(
        settings: HAConnectionSettings,
        tokenStore: any HAOAuthTokenStore
    ) -> HAConnectionConfiguration? {
        guard let credential = try? tokenStore.readCredential() else {
            return nil
        }

        let selection = routeSelection(for: settings)
        let authenticationConfiguration = HAConnectionConfiguration(
            baseURLString: credential.baseURLString,
            accessToken: credential.accessToken,
            profileID: settings.activeProfileID
        )
        let selectedAuthenticationConfiguration = HAConnectionConfiguration(
            baseURLString: selection.authenticationBaseURLString,
            accessToken: credential.accessToken,
            profileID: settings.activeProfileID
        )
        guard authenticationConfiguration.dataSourceID == selectedAuthenticationConfiguration.dataSourceID else {
            return nil
        }

        return authenticationConfiguration.routed(
            to: selection.preferredCandidate?.baseURLString ?? selection.authenticationBaseURLString
        )
    }

    private func staleFreshness(_ errorMessage: String?, lastUpdated: Date? = nil) -> HADataFreshness {
        guard stateStore.hasLoadedInitialSnapshot else {
            return .empty
        }

        return .stale(errorMessage, lastUpdated: lastUpdated ?? dataFreshness.lastKnownUpdateDate)
    }

    private func failConnection(with error: Error) {
        shouldReconnect = false
        endConnectionHealthGrace()
        let rawMessage = error.localizedDescription
        lastErrorMessage = rawMessage
        authState = authFailureState(for: error)
        dataFreshness = staleFreshness(rawMessage)
        connectionStatus = .failed(HAConnectionIssuePresentation.message(for: error))
    }

    private func handleConnectFailure(
        _ error: Error,
        fallbackConfiguration: HAConnectionConfiguration
    ) {
        guard shouldReconnect,
              HAConnectionRecoveryPolicy.shouldReconnectSocket(after: error) else {
            failConnection(with: error)
            return
        }

        let rawMessage = error.localizedDescription
        lastErrorMessage = rawMessage
        authState = authFailureState(for: error)
        dataFreshness = staleFreshness(rawMessage)
        scheduleReconnect(configuration: fallbackConfiguration)
    }

    private func handleNetworkPathUpdate(
        _ path: NWPath,
        settings: HAConnectionSettings
    ) async {
        currentConnectionSettings = settings
        let previousSelection = routeSelection(for: settings).preferredCandidate
        let previousNetworkAvailability = isNetworkAvailable
        var nextNetworkContext = HAConnectionNetworkContext(path: path)
        if settings.routingSnapshot.hasInternalNetworkSSIDs {
            let ssid = await currentWiFiNetworkProvider.currentSSID()
            nextNetworkContext = nextNetworkContext.withCurrentWiFiSSID(ssid)
        }
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
        configuration: HAConnectionConfiguration,
        timeout: Duration? = nil
    ) async throws -> HAConnectionConfiguration {
        guard let timeout else {
            return try await establishTransportConnectionWithAuthRecoveryWithoutTimeout(configuration: configuration)
        }

        return try await withThrowingTaskGroup(of: HAConnectionConfiguration.self) { group in
            group.addTask { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.establishTransportConnectionWithAuthRecoveryWithoutTimeout(configuration: configuration)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw HAWebSocketError.requestTimedOut
            }
            defer { group.cancelAll() }
            return try await group.next() ?? configuration
        }
    }

    private func establishTransportConnectionWithAuthRecoveryWithoutTimeout(
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
        await refreshCurrentWiFiSSIDIfNeeded(settings: settings)
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

    private func refreshCurrentWiFiSSIDIfNeeded(settings: HAConnectionSettings) async {
        guard settings.routingSnapshot.hasInternalNetworkSSIDs else {
            if networkContext.currentWiFiSSID != nil {
                networkContext = networkContext.withCurrentWiFiSSID(nil)
            }
            return
        }

        _ = await refreshCurrentWiFiSSID()
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

        if let oauthError = error as? HAOAuthError {
            switch oauthError {
            case .noRefreshTokenForServer, .invalidTokenResponse, .missingAuthorizationCode, .stateMismatch:
                return .refreshFailed(oauthError.localizedDescription)
            case .signInCancelled:
                return authState
            case .signedOut:
                return .signedOut
            }
        }

        if case .authenticationFailed = error as? HAWebSocketError {
            return .refreshFailed(error.localizedDescription)
        }

        return authState
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

    private func signInFailureMessage(for error: Error) -> String {
        if let oauthError = error as? HAOAuthError {
            switch oauthError {
            case .signInCancelled:
                return "Sign-in was canceled."
            case .missingAuthorizationCode, .stateMismatch:
                return oauthError.localizedDescription
            case .signedOut, .noRefreshTokenForServer, .invalidTokenResponse:
                return genericSignInFailureMessage
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Check your internet connection and try again."
            case .cannotFindHost, .cannotConnectToHost, .timedOut, .secureConnectionFailed:
                return "Couldn’t reach Home Assistant. Check the address and try again."
            default:
                return genericSignInFailureMessage
            }
        }

        if let webSocketError = error as? HAWebSocketError {
            switch webSocketError {
            case .invalidURL:
                return "Check the Home Assistant address and try again."
            case .requestTimedOut, .transportFailure, .notConnected:
                return "Couldn’t reach Home Assistant. Check the address and try again."
            case .authenticationFailed, .unexpectedMessage, .requestFailed, .missingResult:
                return genericSignInFailureMessage
            }
        }

        return genericSignInFailureMessage
    }

    private func isUserCancelledSignIn(_ error: Error) -> Bool {
        if error as? HAOAuthError == .signInCancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" &&
            nsError.code == 1
    }

    private var genericSignInFailureMessage: String {
        "Couldn’t complete sign-in with Home Assistant. Check that Home Assistant is reachable and try again."
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
            do {
                try await client.subscribeToRegistryChanges()
            } catch {
                #if DEBUG
                print("Home Assistant registry subscriptions failed: \(error.localizedDescription)")
                #endif
            }
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
        let previous = stateStore.registryMetadataSnapshot()
        async let entityRegistryResult = registryFetchResult {
            try await self.client.fetchEntityRegistryForDisplay()
        }
        async let deviceRegistryResult = registryFetchResult {
            try await self.client.fetchDeviceRegistry()
        }
        async let areaRegistryResult = registryFetchResult {
            try await self.client.fetchAreaRegistry()
        }
        async let floorRegistryResult = registryFetchResult {
            try await self.client.fetchFloorRegistry()
        }

        let (entityResult, deviceResult, areaResult, floorResult) = await (
            entityRegistryResult,
            deviceRegistryResult,
            areaRegistryResult,
            floorRegistryResult
        )
        let entities = registryValue(
            entityResult.map(\.entities),
            fallback: previous?.entities ?? [],
            section: "entity"
        )
        let devices = registryValue(
            deviceResult,
            fallback: previous?.devices ?? [],
            section: "device"
        )
        let areas = registryValue(
            areaResult,
            fallback: previous?.areas ?? [],
            section: "area"
        )
        let floors = registryValue(
            floorResult,
            fallback: previous?.floors ?? [],
            section: "floor"
        )

        async let organizationResult = try? client.fetchEntityOrganization()
        async let labelResult = try? client.fetchLabelRegistry()
        async let automationCategoriesResult = try? client.fetchCategoryRegistry(scope: .automation)
        async let sceneCategoriesResult = try? client.fetchCategoryRegistry(scope: .scene)
        async let scriptCategoriesResult = try? client.fetchCategoryRegistry(scope: .script)
        async let helperCategoriesResult = try? client.fetchCategoryRegistry(scope: .helper)

        let organization = await organizationResult ?? []
        let labels = await labelResult ?? []
        let categories = await [
            automationCategoriesResult,
            sceneCategoriesResult,
            scriptCategoriesResult,
            helperCategoriesResult
        ].compactMap { $0 }.flatMap { $0 }

        let metadata = HARegistryMetadataSnapshot(
            entities: entities,
            devices: devices,
            areas: areas,
            floors: floors,
            organization: organization,
            labels: labels,
            categories: categories
        )
        guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
            return nil
        }
        stateStore.applyRegistryMetadata(metadata)
        return metadata
    }

    private func registryFetchResult<Value: Sendable>(
        _ fetch: @escaping @Sendable () async throws -> Value
    ) async -> Result<Value, Error> {
        do {
            return .success(try await fetch())
        } catch {
            return .failure(error)
        }
    }

    private func registryValue<Value>(
        _ result: Result<Value, Error>,
        fallback: Value,
        section: String
    ) -> Value {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            #if DEBUG
            print("Home Assistant \(section) registry metadata failed: \(String(reflecting: error))")
            #endif
            return fallback
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

            let environment = await serverEnvironmentSnapshot(for: config)
            guard activeConfiguration?.dataSourceID == configuration.dataSourceID else {
                return
            }

            let snapshot = HAServerConfigurationSnapshot(dto: config)
            serverConfiguration = snapshot
            serverEnvironment = environment
            currentConnectionSettings?.adoptServerRoutes(from: snapshot)
            currentConnectionSettings?.updateServerName(snapshot.locationName)
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

    private func serverEnvironmentSnapshot(for config: HAConfigDTO) async -> HAServerEnvironmentSnapshot {
        async let supervisorInfo = optionalSupervisorInfo()
        async let operatingSystemInfo = optionalOperatingSystemInfo()

        return await HAServerEnvironmentSnapshot(
            config: config,
            supervisorInfo: supervisorInfo,
            operatingSystemInfo: operatingSystemInfo
        )
    }

    private func optionalSupervisorInfo() async -> HASupervisorInfoDTO? {
        do {
            return try await client.fetchSupervisorInfo()
        } catch {
            return nil
        }
    }

    private func optionalOperatingSystemInfo() async -> HAOperatingSystemInfoDTO? {
        do {
            return try await client.fetchOperatingSystemInfo()
        } catch {
            return nil
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
                mobileAppPushNotificationState = .unavailable
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
            try await nativeNotificationService.presentNotification(
                event.notificationRequest(profileID: currentConnectionSettings?.activeProfileID)
            )

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
        if event.isRegistryMetadataChanged {
            scheduleRegistryMetadataRefresh()
            return
        }

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

    private func scheduleRegistryMetadataRefresh() {
        guard let activeConfiguration else {
            return
        }

        registryRefreshTask?.cancel()
        registryRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            guard let self,
                  self.activeConfiguration?.dataSourceID == activeConfiguration.dataSourceID else {
                return
            }
            let metadata = await self.fetchRegistryMetadataIfAvailable(configuration: activeConfiguration)
            guard metadata != nil else {
                return
            }
            self.scheduleStateCacheSave(configuration: activeConfiguration)
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

    private func applyWeatherForecast(
        _ event: HAWeatherForecastEventDTO,
        entityID: String,
        sessionID: UUID
    ) {
        guard weatherForecastSessionIDsByEntityID[entityID] == sessionID,
              let entityBox = stateStore.entityBox(for: entityID) else {
            return
        }

        entityBox.applyWeatherForecast(EntityMapper.weatherForecastSnapshot(from: event))
    }

    private func discardWeatherForecastSubscriptions() {
        for entityID in weatherForecastSubscriptionIDsByEntityID.keys {
            stateStore.entityBox(for: entityID)?.clearWeatherForecastLoadingState()
        }
        weatherForecastSubscriptionIDsByEntityID.removeAll()
        weatherForecastSessionIDsByEntityID.removeAll()
    }

    private func weatherForecastErrorMessage(_ error: Error) -> String {
        if case HAWebSocketError.requestFailed(let message) = error,
           message?.localizedCaseInsensitiveContains("not support") == true {
            return "This forecast is not available from the weather provider."
        }

        return "Couldn’t update the forecast."
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
              HAConnectionRecoveryPolicy.shouldReconnectSocket(after: error) else {
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
        registryRefreshTask?.cancel()
        registryRefreshTask = nil
        discardBufferedStateChanges()
        Task {
            await stateEventBatcher.discardPendingUpdates()
        }
        beginConnectionHealthGraceIfCachedContentVisible()
        connectionStatus = .reconnecting
        reconnectTask = Task { [weak self] in
            await self?.runReconnectLoop(configuration: configuration)
        }
    }

    private func runReconnectLoop(configuration: HAConnectionConfiguration) async {
        var attempt = 0

        while shouldReconnect, !Task.isCancelled {
            let delay = HAConnectionRecoveryPolicy.reconnectDelaySeconds(
                forAttempt: attempt,
                delays: reconnectDelaySeconds
            )

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
                        guard HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: error) else {
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
                endConnectionHealthGrace()
                connectionStatus = .connected
                reconnectTask = nil
                dataFreshness = .refreshing(lastUpdated: dataFreshness.lastKnownUpdateDate)
                startStateSync(configuration: connectedConfiguration)
                return
            } catch is CancellationError {
                break
            } catch {
                let rawMessage = error.localizedDescription
                lastErrorMessage = rawMessage
                dataFreshness = staleFreshness(rawMessage)
                guard HAConnectionRecoveryPolicy.shouldReconnectSocket(after: error) else {
                    shouldReconnect = false
                    authState = authFailureState(for: error)
                    endConnectionHealthGrace()
                    connectionStatus = .failed(HAConnectionIssuePresentation.message(for: error))
                    break
                }
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

    private func beginConnectionHealthGraceIfCachedContentVisible() {
        guard dataFreshness.isUsable else {
            return
        }

        beginConnectionHealthGrace()
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

        await refreshCurrentWiFiSSIDIfNeeded(settings: settings)
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
        HAConnectionRecoveryPolicy.shouldRefreshAfterResume(
            lastSuspendedAt: lastSuspendedAt,
            interval: resumeRefreshInterval
        )
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
            style: .failure,
            entityID: pendingCommand.entityID
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
                return HAConnectionIssuePresentation.message(for: webSocketError)
            }
        }

        return HAConnectionIssuePresentation.message(for: error)
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

#if DEBUG
extension HomeAssistantService {
    func applySettingsPreviewState(
        currentUserDisplayName: String,
        isNetworkAvailable: Bool,
        mobileAppRegistrationState: HAMobileAppRegistrationState,
        serverConfiguration: HAServerConfigurationSnapshot,
        serverEnvironment: HAServerEnvironmentSnapshot,
        stateCacheMetadata: HAStateCacheMetadata,
        activeRouteSummary: HAConnectionRouteSummary
    ) {
        self.currentUserDisplayName = currentUserDisplayName
        self.isNetworkAvailable = isNetworkAvailable
        self.mobileAppRegistrationState = mobileAppRegistrationState
        self.serverConfiguration = serverConfiguration
        self.serverEnvironment = serverEnvironment
        self.serverConfigurationStatus = .loaded(serverConfiguration.loadedAt)
        self.stateCacheMetadata = stateCacheMetadata
        self.activeRouteSummary = activeRouteSummary
    }
}
#endif
