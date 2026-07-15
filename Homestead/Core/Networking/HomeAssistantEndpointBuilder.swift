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
            URLQueryItem(name: "response_type", value: "code"),
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

    nonisolated static func authRevokeURL(from baseURLString: String) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "auth", "revoke"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else { throw HAWebSocketError.invalidURL }
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

    nonisolated static func logbookURL(
        from baseURLString: String,
        startDate: Date,
        endDate: Date?,
        entityID: String? = nil
    ) throws -> URL {
        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "logbook", logbookTimestamp(from: startDate)].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")

        var queryItems: [URLQueryItem] = []
        if let endDate {
            queryItems.append(URLQueryItem(name: "end_time", value: logbookTimestamp(from: endDate)))
        }
        if let entityID = entityID?.trimmingCharacters(in: .whitespacesAndNewlines), !entityID.isEmpty {
            queryItems.append(URLQueryItem(name: "entity", value: entityID))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        components.fragment = nil

        guard let url = components.url else {
            throw HAWebSocketError.invalidURL
        }

        return url
    }

    nonisolated static func historyURL(
        from baseURLString: String,
        request: HAHistoryRequest
    ) throws -> URL {
        guard !request.entityID.isEmpty else {
            throw HAWebSocketError.invalidURL
        }

        var components = try baseComponents(from: baseURLString)
        components.scheme = try httpScheme(from: components.scheme)

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "history", "period", historyTimestamp(from: request.startDate)].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")

        var queryItems = [
            URLQueryItem(name: "filter_entity_id", value: request.entityID),
            URLQueryItem(name: "end_time", value: historyTimestamp(from: request.endDate))
        ]
        if request.minimalResponse {
            queryItems.append(URLQueryItem(name: "minimal_response", value: nil))
        }
        if request.noAttributes {
            queryItems.append(URLQueryItem(name: "no_attributes", value: nil))
        }
        if request.significantChangesOnly {
            queryItems.append(URLQueryItem(name: "significant_changes_only", value: nil))
        }
        components.queryItems = queryItems
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
        let trimmedString = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedString = trimmedString.contains("://") ? trimmedString : "\(defaultScheme(forHostOnlyBaseURL: trimmedString))://\(trimmedString)"

        guard var components = URLComponents(string: normalizedString),
              components.scheme != nil,
              let host = components.host?.lowercased() else {
            throw HAWebSocketError.invalidURL
        }

        if !isLocalHost(host) {
            switch components.scheme?.lowercased() {
            case "http":
                components.scheme = "https"
            case "ws":
                components.scheme = "wss"
            default:
                break
            }
        }

        return components
    }

    private nonisolated static func defaultScheme(forHostOnlyBaseURL baseURLString: String) -> String {
        guard let host = URLComponents(string: "https://\(baseURLString)")?.host?.lowercased() else {
            return "https"
        }

        return isLocalHost(host) ? "http" : "https"
    }

    private nonisolated static func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") || host == "::1" {
            return true
        }

        if host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") {
            return true
        }

        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else {
            return false
        }

        switch parts[0] {
        case 10, 127:
            return true
        case 172:
            return (16...31).contains(parts[1])
        case 192:
            return parts[1] == 168
        case 169:
            return parts[1] == 254
        default:
            return false
        }
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

    private nonisolated static func logbookTimestamp(from date: Date) -> String {
        timestamp(from: date)
    }

    private nonisolated static func historyTimestamp(from date: Date) -> String {
        timestamp(from: date)
    }

    private nonisolated static func timestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
