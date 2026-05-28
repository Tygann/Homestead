import Foundation

enum HomeAssistantEndpointBuilder {
    nonisolated static func authAuthorizeURL(
        from baseURLString: String,
        clientID: String,
        redirectURI: String,
        state: String? = nil
    ) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "auth", "authorize"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        if let state {
            components.queryItems?.append(URLQueryItem(name: "state", value: state))
        }
        components.fragment = nil

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }

    nonisolated static func authTokenURL(from baseURLString: String) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "auth", "token"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }

    nonisolated static func webSocketURL(from baseURLString: String) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try webSocketScheme(from: components.scheme)

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

    nonisolated static func cameraSnapshotURL(
        from baseURLString: String,
        entityID: String,
        cacheBuster: String? = nil
    ) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "camera_proxy", entityID].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        if let cacheBuster {
            components.queryItems = [URLQueryItem(name: "t", value: cacheBuster)]
        } else {
            components.query = nil
        }
        components.fragment = nil

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }

    nonisolated static func mobileAppRegistrationURL(from baseURLString: String) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "mobile_app", "registrations"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }

    nonisolated static func mobileAppWebhookURL(
        from baseURLString: String,
        webhookID: String
    ) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "webhook", webhookID].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }

    nonisolated static func httpURL(from baseURLString: String, pathOrURL: String) throws -> URL {
        if let absoluteURL = URL(string: pathOrURL),
           absoluteURL.scheme != nil,
           absoluteURL.host != nil {
            return absoluteURL
        }

        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        guard let pathComponents = URLComponents(string: pathOrURL) else {
            throw HAWebSocketError.invalidURL
        }

        if pathComponents.path.hasPrefix("/") {
            components.path = pathComponents.path
        } else {
            let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let path = pathComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let pathParts = [basePath, path].filter { !$0.isEmpty }
            components.path = "/" + pathParts.joined(separator: "/")
        }
        components.query = pathComponents.query
        components.fragment = pathComponents.fragment

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }

    private nonisolated static func baseComponents(from baseURLString: String) throws -> URLComponents {
        let normalizedString = baseURLString.contains("://") ? baseURLString : "http://\(baseURLString)"

        guard let components = URLComponents(string: normalizedString),
              components.scheme != nil,
              components.host != nil else {
            throw HAWebSocketError.invalidURL
        }

        return components
    }

    private nonisolated static func webSocketScheme(from scheme: String?) throws -> String {
        switch scheme?.lowercased() {
        case "http", "ws":
            return "ws"
        case "https", "wss":
            return "wss"
        default:
            throw HAWebSocketError.invalidURL
        }
    }

    private nonisolated static func httpScheme(from scheme: String?) throws -> String {
        switch scheme?.lowercased() {
        case "http", "ws":
            return "http"
        case "https", "wss":
            return "https"
        default:
            throw HAWebSocketError.invalidURL
        }
    }
}
