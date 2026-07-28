import Foundation

nonisolated enum WidgetHistoryRequest {
    static func url(
        baseURLString: String,
        entityIDs: [String],
        startDate: Date,
        endDate: Date
    ) -> URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.contains("://")
            ? trimmed
            : "\(defaultScheme(forHostOnlyBaseURL: trimmed))://\(trimmed)"

        guard var components = URLComponents(string: normalized),
              let scheme = components.scheme,
              let host = components.host?.lowercased(),
              !entityIDs.isEmpty else {
            return nil
        }

        switch normalizedScheme(scheme, host: host) {
        case "http", "ws": components.scheme = "http"
        case "https", "wss": components.scheme = "https"
        default: return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [
            basePath,
            "api",
            "history",
            "period",
            timestamp(from: startDate)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "/")
        components.queryItems = [
            URLQueryItem(name: "filter_entity_id", value: entityIDs.joined(separator: ",")),
            URLQueryItem(name: "end_time", value: timestamp(from: endDate)),
            URLQueryItem(name: "minimal_response", value: nil),
            URLQueryItem(name: "no_attributes", value: nil)
        ]
        components.fragment = nil
        return components.url
    }

    private static func timestamp(from date: Date) -> String {
        date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
    }

    private static func normalizedScheme(_ scheme: String, host: String) -> String {
        let lowercased = scheme.lowercased()
        guard !isLocalHost(host) else { return lowercased }
        switch lowercased {
        case "http": return "https"
        case "ws": return "wss"
        default: return lowercased
        }
    }

    private static func defaultScheme(forHostOnlyBaseURL baseURLString: String) -> String {
        guard let host = URLComponents(string: "https://\(baseURLString)")?.host?.lowercased() else {
            return "https"
        }
        return isLocalHost(host) ? "http" : "https"
    }

    private static func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") || host == "::1" {
            return true
        }
        if host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") {
            return true
        }

        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        switch parts[0] {
        case 10, 127: return true
        case 172: return (16...31).contains(parts[1])
        case 192: return parts[1] == 168
        case 169: return parts[1] == 254
        default: return false
        }
    }
}
