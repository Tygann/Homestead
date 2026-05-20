import Foundation

actor HAWebSocketClient {
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var nextID = 1
    private var pendingResults: [Int: CheckedContinuation<HAWebSocketIncomingMessage, Error>] = [:]
    private var eventHandler: (@MainActor @Sendable (HAEventDTO) -> Void)?
    private var disconnectHandler: (@MainActor @Sendable (Error) -> Void)?
    private var isDisconnecting = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setEventHandler(_ handler: (@MainActor @Sendable (HAEventDTO) -> Void)?) {
        eventHandler = handler
    }

    func setDisconnectHandler(_ handler: (@MainActor @Sendable (Error) -> Void)?) {
        disconnectHandler = handler
    }

    func connect(configuration: HAConnectionConfiguration) async throws {
        isDisconnecting = true
        closeCurrentConnection()
        isDisconnecting = false

        let url = try HomeAssistantEndpointBuilder.webSocketURL(from: configuration.baseURLString)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        let authRequired = try await receiveIncomingMessage()
        guard authRequired.type == HAWebSocketMessageType.authRequired else {
            throw HAWebSocketError.unexpectedMessage(authRequired.type)
        }

        try await send(.auth(accessToken: configuration.accessToken))

        let authResponse = try await receiveIncomingMessage()
        switch authResponse.type {
        case HAWebSocketMessageType.authOK:
            startReceiveLoop()
        case HAWebSocketMessageType.authInvalid:
            throw HAWebSocketError.authenticationFailed(authResponse.message)
        default:
            throw HAWebSocketError.unexpectedMessage(authResponse.type)
        }
    }

    func disconnect() {
        isDisconnecting = true
        closeCurrentConnection()
    }

    private func closeCurrentConnection() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        resumeAllPending(throwing: HAWebSocketError.notConnected)
    }

    func fetchStates() async throws -> [HAEntityDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(.getStates(id: id), id: id)

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded([HAEntityDTO].self)
    }

    func subscribeToStateChanges() async throws {
        let id = makeRequestID()
        _ = try await sendRequest(
            .subscribeEvents(id: id, eventType: "state_changed"),
            id: id
        )
    }

    func callService(
        domain: String,
        service: String,
        entityID: String?,
        serviceData: [String: JSONValue] = [:]
    ) async throws {
        let id = makeRequestID()
        let target = entityID.map { ["entity_id": JSONValue.string($0)] }
        _ = try await sendRequest(
            .callService(
                id: id,
                domain: domain,
                service: service,
                target: target,
                serviceData: serviceData.isEmpty ? nil : serviceData
            ),
            id: id
        )
    }

    private func makeRequestID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func sendRequest(_ request: HAWebSocketRequest, id: Int) async throws -> HAWebSocketIncomingMessage {
        try await withCheckedThrowingContinuation { continuation in
            pendingResults[id] = continuation

            Task {
                do {
                    try await self.send(request)
                } catch {
                    self.resumePendingResult(id: id, throwing: error)
                }
            }
        }
    }

    private func send(_ request: HAWebSocketRequest) async throws {
        guard let webSocketTask else {
            throw HAWebSocketError.notConnected
        }

        let data = try JSONEncoder().encode(request)
        try await webSocketTask.send(.data(data))
    }

    private func receiveIncomingMessage() async throws -> HAWebSocketIncomingMessage {
        guard let webSocketTask else {
            throw HAWebSocketError.notConnected
        }

        let message = try await webSocketTask.receive()
        let data: Data

        switch message {
        case .data(let payload):
            data = payload
        case .string(let payload):
            data = Data(payload.utf8)
        @unknown default:
            throw HAWebSocketError.unexpectedMessage("unknown payload")
        }

        return try JSONDecoder().decode(HAWebSocketIncomingMessage.self, from: data)
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        do {
            while !Task.isCancelled {
                let message = try await receiveIncomingMessage()
                await handle(message)
            }
        } catch {
            resumeAllPending(throwing: error)

            guard !Task.isCancelled, !isDisconnecting else {
                return
            }

            await disconnectHandler?(error)
        }
    }

    private func handle(_ message: HAWebSocketIncomingMessage) async {
        switch message.type {
        case HAWebSocketMessageType.result:
            handleResult(message)
        case HAWebSocketMessageType.event:
            if let event = message.event {
                await eventHandler?(event)
            }
        default:
            break
        }
    }

    private func handleResult(_ message: HAWebSocketIncomingMessage) {
        guard let id = message.id, let continuation = pendingResults.removeValue(forKey: id) else {
            return
        }

        if message.success == false {
            continuation.resume(throwing: HAWebSocketError.requestFailed(message.message ?? message.error?.message))
        } else {
            continuation.resume(returning: message)
        }
    }

    private func resumePendingResult(id: Int, throwing error: Error) {
        guard let continuation = pendingResults.removeValue(forKey: id) else {
            return
        }

        continuation.resume(throwing: error)
    }

    private func resumeAllPending(throwing error: Error) {
        let continuations = pendingResults.values
        pendingResults.removeAll()

        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}
