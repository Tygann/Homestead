import Foundation
import Observation

@MainActor
@Observable
final class HomeAssistantService {
    private(set) var connectionStatus: HAConnectionStatus = .disconnected
    private(set) var lastErrorMessage: String?
    private(set) var smokeTestState: HAConnectionSmokeTestState = .idle

    @ObservationIgnored private let client: HAWebSocketClient
    @ObservationIgnored private let stateStore: HAStateStore
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
        await callService(domain: "light", service: "turn_on", entityID: entityID)
    }

    func turnOffLight(entityID: String) async {
        await callService(domain: "light", service: "turn_off", entityID: entityID)
    }

    func setLightBrightness(entityID: String, brightnessPercentage: Double) async {
        let clampedPercentage = min(max(brightnessPercentage, 1), 100)
        let brightness = Int((clampedPercentage / 100) * 255)

        await callService(
            domain: "light",
            service: "turn_on",
            entityID: entityID,
            serviceData: ["brightness": .number(Double(max(1, brightness)))]
        )
    }

    func callService(
        domain: String,
        service: String,
        entityID: String?,
        serviceData: [String: JSONValue] = [:]
    ) async {
        do {
            try await client.callService(
                domain: domain,
                service: service,
                entityID: entityID,
                serviceData: serviceData
            )
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func establishConnection(configuration: HAConnectionConfiguration) async throws {
        await configureClientCallbacks()
        try await client.connect(configuration: configuration)

        let states = try await client.fetchStates()
        stateStore.applyInitialStates(states)
        try await client.subscribeToStateChanges()
    }

    private func configureClientCallbacks() async {
        await client.setEventHandler { [weak stateStore] event in
            stateStore?.apply(event: event)
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
}
