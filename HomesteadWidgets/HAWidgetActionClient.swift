import Foundation

enum HAWidgetActionError: LocalizedError {
    case missingCredentials
    case invalidURL
    case authenticationFailed
    case unexpectedResponse
    case serviceCallFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Home Assistant credentials are not available to the widget."
        case .invalidURL:
            "The Home Assistant URL is invalid."
        case .authenticationFailed:
            "Home Assistant authentication failed."
        case .unexpectedResponse:
            "Home Assistant returned an unexpected WebSocket response."
        case .serviceCallFailed:
            "The Home Assistant service call failed."
        }
    }
}

struct HAWidgetLightState: Sendable {
    let entityID: String
    let state: String
    let displayName: String

    var isOn: Bool { state == "on" }
}

struct HAWidgetSwitchState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let systemImage: String

    var isOn: Bool { state == "on" }
}

final class HAWidgetActionClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLightState(entityID: String) async throws -> HAWidgetLightState {
        try await withConnectedSocket { task in
            try await sendJSON(["id": 1, "type": "get_states"], over: task)

            let message = try await receiveJSONObject(from: task)
            guard let success = message["success"] as? Bool, success,
                  let states = message["result"] as? [[String: Any]],
                  let state = states.first(where: { $0["entity_id"] as? String == entityID }),
                  let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID

            return HAWidgetLightState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName
            )
        }
    }

    func setLight(entityID: String, isOn: Bool) async throws {
        try await callService(
            domain: "light",
            service: isOn ? "turn_on" : "turn_off",
            entityID: entityID
        )
    }

    func fetchSwitchState(entityID: String) async throws -> HAWidgetSwitchState {
        try await withConnectedSocket { task in
            try await sendJSON(["id": 1, "type": "get_states"], over: task)

            let message = try await receiveJSONObject(from: task)
            guard let success = message["success"] as? Bool, success,
                  let states = message["result"] as? [[String: Any]],
                  let state = states.first(where: { $0["entity_id"] as? String == entityID }),
                  let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID
            let deviceClass = attributes?["device_class"] as? String

            return HAWidgetSwitchState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                systemImage: switchSystemImage(deviceClass: deviceClass, isOn: stateValue == "on")
            )
        }
    }

    func setSwitch(entityID: String, isOn: Bool) async throws {
        try await callService(
            domain: "switch",
            service: isOn ? "turn_on" : "turn_off",
            entityID: entityID
        )
    }

    private func callService(domain: String, service: String, entityID: String) async throws {
        try await withConnectedSocket { task in
            try await sendJSON([
                "id": 1,
                "type": "call_service",
                "domain": domain,
                "service": service,
                "target": ["entity_id": entityID]
            ], over: task)

            let message = try await receiveJSONObject(from: task)
            guard let success = message["success"] as? Bool, success else {
                throw HAWidgetActionError.serviceCallFailed
            }
        }
    }

    private func withConnectedSocket<T>(
        _ operation: (URLSessionWebSocketTask) async throws -> T
    ) async throws -> T {
        guard let baseURL = HomesteadWidgetSharedStore.baseURL else {
            throw HAWidgetActionError.missingCredentials
        }
        let token = try await HomesteadWidgetSharedStore.validAccessToken()

        let url = try webSocketURL(from: baseURL)
        let task = session.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }

        let authRequired = try await receiveJSONObject(from: task)
        guard authRequired["type"] as? String == "auth_required" else {
            throw HAWidgetActionError.unexpectedResponse
        }

        try await sendJSON(["type": "auth", "access_token": token], over: task)

        let authResponse = try await receiveJSONObject(from: task)
        guard authResponse["type"] as? String == "auth_ok" else {
            throw HAWidgetActionError.authenticationFailed
        }

        return try await operation(task)
    }

    private func sendJSON(_ object: [String: Any], over task: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HAWidgetActionError.unexpectedResponse
        }

        try await task.send(.string(string))
    }

    private func receiveJSONObject(from task: URLSessionWebSocketTask) async throws -> [String: Any] {
        let message = try await task.receive()
        let data: Data

        switch message {
        case .string(let string):
            data = Data(string.utf8)
        case .data(let receivedData):
            data = receivedData
        @unknown default:
            throw HAWidgetActionError.unexpectedResponse
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HAWidgetActionError.unexpectedResponse
        }

        return object
    }

    private func webSocketURL(from baseURLString: String) throws -> URL {
        let normalizedString = baseURLString.contains("://") ? baseURLString : "http://\(baseURLString)"

        guard var components = URLComponents(string: normalizedString),
              let scheme = components.scheme,
              components.host != nil else {
            throw HAWidgetActionError.invalidURL
        }

        switch scheme.lowercased() {
        case "http", "ws":
            components.scheme = "ws"
        case "https", "wss":
            components.scheme = "wss"
        default:
            throw HAWidgetActionError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "websocket"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw HAWidgetActionError.invalidURL
        }

        return url
    }

    private func switchSystemImage(deviceClass: String?, isOn: Bool) -> String {
        switch deviceClass {
        case "outlet":
            "poweroutlet.type.b.fill"
        default:
            isOn ? "lightswitch.on.fill" : "lightswitch.off.fill"
        }
    }
}
