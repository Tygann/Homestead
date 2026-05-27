import Foundation

actor HAHTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCameraSnapshot(configuration: HAConnectionConfiguration, entityID: String) async throws -> Data {
        let url = try HomeAssistantEndpointBuilder.cameraSnapshotURL(
            from: configuration.baseURLString,
            entityID: entityID,
            cacheBuster: String(Int(Date().timeIntervalSince1970))
        )
        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid camera response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HAWebSocketError.requestFailed("Home Assistant camera snapshot failed with status \(httpResponse.statusCode).")
        }

        guard !data.isEmpty else {
            throw HAWebSocketError.missingResult
        }

        return data
    }
}
