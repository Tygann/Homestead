import Foundation

nonisolated enum HomeAssistantImageRequestBuilder {
    static func request(
        configuration: HAConnectionConfiguration,
        pathOrURL: String
    ) throws -> URLRequest? {
        let trimmedPathOrURL = pathOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPathOrURL.isEmpty else {
            return nil
        }

        let url = try HomeAssistantEndpointBuilder.httpURL(
            from: configuration.baseURLString,
            pathOrURL: trimmedPathOrURL
        )
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil, components.user == nil, components.password == nil,
              !trimmedPathOrURL.hasPrefix("//") else {
            throw HAWebSocketError.invalidURL
        }
        var request = URLRequest(url: url)
        let configuredOrigins = [configuration.baseURLString, configuration.dataSourceBaseURLString,
                                 configuration.tokenRefreshBaseURLString]
        if configuredOrigins.contains(where: { baseURL in
            guard let base = try? HomeAssistantEndpointBuilder.httpURL(from: baseURL, pathOrURL: "") else { return false }
            return sameOrigin(url, base)
        }) {
            request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        func port(_ url: URL) -> Int { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
        return lhs.scheme?.lowercased() == rhs.scheme?.lowercased() &&
            lhs.host?.lowercased() == rhs.host?.lowercased() && port(lhs) == port(rhs)
    }
}
