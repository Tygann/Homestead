import Foundation

enum HomeAssistantEndpointBuilder {
    nonisolated static func webSocketURL(from baseURLString: String) throws -> URL {
        let normalizedString = baseURLString.contains("://") ? baseURLString : "http://\(baseURLString)"

        guard var components = URLComponents(string: normalizedString),
              let scheme = components.scheme,
              components.host != nil else {
            throw HAWebSocketError.invalidURL
        }

        switch scheme.lowercased() {
        case "http", "ws":
            components.scheme = "ws"
        case "https", "wss":
            components.scheme = "wss"
        default:
            throw HAWebSocketError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "websocket"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }
}
