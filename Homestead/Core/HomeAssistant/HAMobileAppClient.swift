import Foundation

nonisolated protocol HAMobileAppClientProtocol {
    func register(
        configuration: HAConnectionConfiguration,
        request: HAMobileAppRegistrationRequestDTO
    ) async throws -> HAMobileAppRegistrationResponseDTO

    func requestCameraStream(
        configuration: HAConnectionConfiguration,
        registration: HAMobileAppRegistrationInfo,
        entityID: String
    ) async throws -> HACameraStreamResponseDTO
}

actor HAMobileAppClient: HAMobileAppClientProtocol {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func register(
        configuration: HAConnectionConfiguration,
        request: HAMobileAppRegistrationRequestDTO
    ) async throws -> HAMobileAppRegistrationResponseDTO {
        let url = try HomeAssistantEndpointBuilder.mobileAppRegistrationURL(
            from: configuration.baseURLString
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, failurePrefix: "Home Assistant app registration failed")

        guard !data.isEmpty else {
            throw HAWebSocketError.missingResult
        }

        return try decoder.decode(HAMobileAppRegistrationResponseDTO.self, from: data)
    }

    func requestCameraStream(
        configuration: HAConnectionConfiguration,
        registration: HAMobileAppRegistrationInfo,
        entityID: String
    ) async throws -> HACameraStreamResponseDTO {
        guard registration.serverIdentifier == configuration.dataSourceID else {
            throw HAWebSocketError.requestFailed("Homestead is not registered with this Home Assistant server.")
        }

        guard !registration.hasEncryptedWebhookSecret else {
            throw HAWebSocketError.requestFailed("Encrypted Home Assistant mobile-app webhooks are not supported yet.")
        }

        let url = try webhookURL(configuration: configuration, registration: registration)
        let payload = HAMobileAppWebhookRequestDTO(
            type: HAMobileAppWebhookType.streamCamera,
            data: HACameraStreamRequestDTO(cameraEntityID: entityID)
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, failurePrefix: "Home Assistant camera stream handoff failed")

        guard !data.isEmpty else {
            throw HAWebSocketError.missingResult
        }

        return try decoder.decode(HACameraStreamResponseDTO.self, from: data)
    }

    private func validate(response: URLResponse, failurePrefix: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HAWebSocketError.requestFailed("\(failurePrefix) with status \(httpResponse.statusCode).")
        }
    }

    private func webhookURL(
        configuration: HAConnectionConfiguration,
        registration: HAMobileAppRegistrationInfo
    ) throws -> URL {
        if let cloudhookURL = registration.cloudhookURL,
           let url = URL(string: cloudhookURL) {
            return url
        }

        return try HomeAssistantEndpointBuilder.mobileAppWebhookURL(
            from: registration.remoteUIURL ?? configuration.baseURLString,
            webhookID: registration.webhookID
        )
    }
}
