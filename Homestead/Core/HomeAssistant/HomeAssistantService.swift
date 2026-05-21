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
    @ObservationIgnored private var shouldReconnect = false
    @ObservationIgnored private let reconnectDelaySeconds = [1, 2, 5, 10, 30]

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
        await client.disconnect()
        activeConfiguration = nil
        connectionStatus = .disconnected
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
        let succeeded = await callService(
            domain: "light",
            service: "turn_on",
            entityID: entityID
        )
        if succeeded {
            stateStore.applyOptimisticLightState(entityID: entityID, isOn: true)
        }
    }

    func turnOffLight(entityID: String) async {
        let succeeded = await callService(
            domain: "light",
            service: "turn_off",
            entityID: entityID
        )
        if succeeded {
            stateStore.applyOptimisticLightState(entityID: entityID, isOn: false)
        }
    }

    func setLightBrightness(entityID: String, brightnessPercentage: Double) async {
        let clampedPercentage = min(max(brightnessPercentage, 1), 100)
        let brightness = Int((clampedPercentage / 100) * 255)

        let succeeded = await callService(
            domain: "light",
            service: "turn_on",
            entityID: entityID,
            serviceData: ["brightness": .number(Double(max(1, brightness)))]
        )
        if succeeded {
            stateStore.applyOptimisticLightBrightness(
                entityID: entityID,
                brightnessPercentage: clampedPercentage
            )
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

        let states = try await client.fetchStates()
        stateStore.applyInitialStates(states)
        await fetchRegistryMetadataIfAvailable()
        try await client.subscribeToStateChanges()
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
            stateStore?.applyLiveStateUpdates(updates)
        }

        await client.setEventHandler { [stateEventBatcher] event in
            guard let newState = event.stateChangedNewState else {
                return
            }

            await stateEventBatcher.enqueue(newState)
        }

        await client.setDisconnectHandler { [weak self] error in
            self?.handleUnexpectedDisconnect(error)
        }
    }

    private func handleUnexpectedDisconnect(_ error: Error) {
        guard shouldReconnect, let activeConfiguration else {
            return
        }

        lastErrorMessage = error.localizedDescription
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
    private var pendingUpdatesByID: [String: HAEntityDTO] = [:]
    private var flushTask: Task<Void, Never>?
    private var flushHandler: (@MainActor @Sendable ([HAEntityDTO]) -> Void)?

    init(flushInterval: Duration = .milliseconds(200)) {
        self.flushInterval = flushInterval
    }

    func setFlushHandler(_ handler: (@MainActor @Sendable ([HAEntityDTO]) -> Void)?) {
        flushHandler = handler
    }

    func enqueue(_ update: HAEntityDTO) {
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
