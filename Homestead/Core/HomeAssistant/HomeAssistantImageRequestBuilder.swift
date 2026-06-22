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
        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}
