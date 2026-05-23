import Foundation
import Observation

@MainActor
@Observable
final class HomeAssistantService {
    private(set) var connectionStatus: HAConnectionStatus = .disconnected
    private(set) var lastErrorMessage: String?
    private(set) var smokeTestState: HAConnectionSmokeTestState = .idle
    private(set) var serviceFeedback: HAServiceFeedback?

    @ObservationIgnored private let client: HAWebSocketClient
    @ObservationIgnored private let stateStore: HAStateStore
    @ObservationIgnored private let stateEventBatcher = HAStateEventBatcher()
    @ObservationIgnored private var activeConfiguration: HAConnectionConfiguration?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var pendingCommandTasksByID: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var bufferedStateChangesByID: [String: HAStateChangedEventDTO] = [:]
    @ObservationIgnored private var isBufferingStateChanges = false
    @ObservationIgnored private var lastSuspendedAt: Date?
    @ObservationIgnored private var shouldReconnect = false
    @ObservationIgnored private let reconnectDelaySeconds = [1, 2, 5, 10, 30]
    @ObservationIgnored private let pendingCommandTimeout: Duration = .seconds(3)
    @ObservationIgnored private let resumeRefreshInterval: TimeInterval = 5

    init(
        stateStore: HAStateStore,
        client: HAWebSocketClient = HAWebSocketClient(),
        connectionStatus: HAConnectionStatus = .disconnected
    ) {
        self.stateStore = stateStore
        self.client = client
        self.connectionStatus = connectionStatus
    }

    func connectIfPossible(settings: HAConnectionSettings) async {
        guard settings.hasCredentials,
              connectionStatus != .connected,
              connectionStatus != .connecting,
              connectionStatus != .reconnecting else {
            return
        }

        await connect(baseURLString: settings.baseURL, accessToken: settings.accessToken)
    }

    func connect(baseURLString: String, accessToken: String) async {
        let configuration = HAConnectionConfiguration(
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        reconnectTask?.cancel()
        reconnectTask = nil
        shouldReconnect = true
        connectionStatus = .connecting

        do {
            try await establishConnection(configuration: configuration)
            activeConfiguration = configuration
            lastErrorMessage = nil
            connectionStatus = .connected
        } catch {
            shouldReconnect = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = .failed(error.localizedDescription)
        }
    }

    func testConnection(baseURLString: String, accessToken: String) async {
        let configuration = HAConnectionConfiguration(
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let smokeClient = HAWebSocketClient()

        smokeTestState = .testing

        do {
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
        reconnectTask?.cancel()
        reconnectTask = nil
        cancelPendingCommandTasks()
        await client.disconnect()
        activeConfiguration = nil
        connectionStatus = .disconnected
    }

    func applicationDidEnterBackground() {
        lastSuspendedAt = Date()
    }

    func resume(settings: HAConnectionSettings) async {
        guard !RuntimeEnvironment.isRunningForPreviews else {
            return
        }

        switch connectionStatus {
        case .disconnected, .failed:
            await connectIfPossible(settings: settings)
        case .reconnecting:
            guard settings.hasCredentials else { return }
            reconnectTask?.cancel()
            reconnectTask = nil
            await connect(baseURLString: settings.baseURL, accessToken: settings.accessToken)
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

    func activateScene(entityID: String) async {
        await callService(
            domain: "scene",
            service: "turn_on",
            entityID: entityID,
            successTitle: "Scene activated"
        )
    }

    func runScript(entityID: String) async {
        await callService(
            domain: "script",
            service: "turn_on",
            entityID: entityID,
            successTitle: "Script started"
        )
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
        await callService(
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
    func callService(
        domain: String,
        service: String,
        entityID: String?,
        serviceData: [String: JSONValue] = [:],
        successTitle: String? = nil
    ) async -> Bool {
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
            await recoverConnectionIfNeeded(after: error)
            serviceFeedback = HAServiceFeedback(
                title: "Action failed",
                message: serviceFailureMessage(
                    domain: domain,
                    service: service,
                    entityID: entityID,
                    error: error
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

    private func establishConnection(configuration: HAConnectionConfiguration) async throws {
        await configureClientCallbacks()
        try await client.connect(configuration: configuration)

        beginBufferingStateChanges()
        do {
            try await client.subscribeToStateChanges()
            let states = try await client.fetchStates()
            stateStore.applySnapshot(states)
            applyBufferedStateChanges()
        } catch {
            bufferedStateChangesByID.removeAll()
            isBufferingStateChanges = false
            throw error
        }
        await fetchRegistryMetadataIfAvailable()
    }

    func refreshStates() async {
        guard connectionStatus == .connected else {
            return
        }

        beginBufferingStateChanges()

        do {
            let states = try await client.fetchStates()
            stateStore.applySnapshot(states)
            applyBufferedStateChanges()
            lastErrorMessage = nil
        } catch {
            applyBufferedStateChanges()
            lastErrorMessage = error.localizedDescription
            await recoverConnectionIfNeeded(after: error)
        }
    }

    private func fetchRegistryMetadataIfAvailable() async {
        do {
            async let entityRegistry = client.fetchEntityRegistryForDisplay()
            async let deviceRegistry = client.fetchDeviceRegistry()

            let registryMetadata = try await (entityRegistry, deviceRegistry)
            stateStore.applyRegistryMetadata(
                entities: registryMetadata.0.entities,
                devices: registryMetadata.1
            )
        } catch {
            // Registry metadata improves organization, but live state should still work without it.
            #if DEBUG
            print("Home Assistant registry metadata failed: \(error.localizedDescription)")
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

        await client.setDisconnectHandler { [weak self] error in
            self?.handleUnexpectedDisconnect(error)
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

    private func handleUnexpectedDisconnect(_ error: Error) {
        guard shouldReconnect, let activeConfiguration else {
            return
        }

        lastErrorMessage = error.localizedDescription
        scheduleReconnect(configuration: activeConfiguration)
    }

    private func recoverConnectionIfNeeded(after error: Error) async {
        guard shouldReconnect,
              reconnectTask == nil,
              let activeConfiguration,
              error.shouldReconnectHomeAssistantSocket else {
            return
        }

        await client.disconnect()
        scheduleReconnect(configuration: activeConfiguration)
    }

    private func scheduleReconnect(configuration: HAConnectionConfiguration) {
        guard reconnectTask == nil else {
            return
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
                try await establishConnection(configuration: configuration)

                activeConfiguration = configuration
                lastErrorMessage = nil
                connectionStatus = .connected
                reconnectTask = nil
                return
            } catch is CancellationError {
                break
            } catch {
                lastErrorMessage = error.localizedDescription
                connectionStatus = .reconnecting
                attempt += 1
            }
        }

        reconnectTask = nil
        if connectionStatus == .reconnecting {
            connectionStatus = .disconnected
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
        error: Error
    ) -> String {
        let target = entityDisplayName(for: entityID) ?? "\(domain).\(service)"
        return "\(target): \(error.localizedDescription)"
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
