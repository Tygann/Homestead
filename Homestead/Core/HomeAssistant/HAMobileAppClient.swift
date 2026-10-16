import Foundation
import Sodium

nonisolated protocol HAMobileAppClientProtocol {
    func register(configuration: HAConnectionConfiguration, request: HAMobileAppRegistrationRequestDTO) async throws -> HAMobileAppRegistrationResponseDTO
    func requestCameraStream(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo, entityID: String) async throws -> HACameraStreamResponseDTO
    func updateRegistration(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo, update: HAMobileAppRegistrationUpdateDTO) async throws
    func enableEncryption(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo) async throws -> String?
}

extension HAMobileAppClientProtocol {
    func enableEncryption(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo) async throws -> String? { nil }
}

nonisolated enum HAMobileAppClientError: LocalizedError, Equatable {
    case httpStatus(Int)
    case webhookError(String)
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .httpStatus(410): "This Home Assistant app registration was deleted."
        case .httpStatus(let status): "Home Assistant app request failed with status \(status)."
        case .webhookError(let code): "Home Assistant app request failed (\(code))."
        case .encryptionFailed: "Home Assistant app encryption failed. Register this device again."
        }
    }
}

actor HAMobileAppClient: HAMobileAppClientProtocol {
    // MARK: - Properties

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) { self.session = session }

    // MARK: - Public API

    func register(configuration: HAConnectionConfiguration, request: HAMobileAppRegistrationRequestDTO) async throws -> HAMobileAppRegistrationResponseDTO {
        let url = try HomeAssistantEndpointBuilder.mobileAppRegistrationURL(from: configuration.baseURLString)
        var urlRequest = makeRequest(url: url, body: try encoder.encode(request))
        urlRequest.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response)
        return try decoder.decode(HAMobileAppRegistrationResponseDTO.self, from: data)
    }

    func requestCameraStream(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo, entityID: String) async throws -> HACameraStreamResponseDTO {
        let payload = HACameraStreamRequestDTO(cameraEntityID: entityID)
        let data = try await sendWebhook(configuration: configuration, registration: registration,
                                         type: HAMobileAppWebhookType.streamCamera, payload: payload)
        return try decoder.decode(HACameraStreamResponseDTO.self, from: data)
    }

    func updateRegistration(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo, update: HAMobileAppRegistrationUpdateDTO) async throws {
        _ = try await sendWebhook(configuration: configuration, registration: registration,
                                  type: HAMobileAppWebhookType.updateRegistration, payload: update)
    }

    func enableEncryption(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo) async throws -> String? {
        if let secret = registration.secret, !secret.isEmpty { return secret }
        do {
            // The server creates an unrecoverable secret. A lost response must not be replayed.
            let data = try await sendWebhook(configuration: configuration, registration: registration,
                                             type: "enable_encryption", payload: [String: String](), allowFailover: false)
            struct Response: Decodable { let secret: String }
            let secret = try decoder.decode(Response.self, from: data).secret
            _ = try HAMobileAppWebhookEncryption.key(secret: secret)
            return secret
        } catch HAMobileAppClientError.webhookError("encryption_not_available") {
            return nil
        }
    }

    // MARK: - Private Helpers

    private func sendWebhook<Payload: Encodable & Sendable>(
        configuration: HAConnectionConfiguration,
        registration: HAMobileAppRegistrationInfo,
        type: String,
        payload: Payload,
        allowFailover: Bool = true
    ) async throws -> Data {
        guard registration.serverIdentifier == configuration.dataSourceID else {
            throw HAWebSocketError.requestFailed("Homestead is not registered with this Home Assistant server.")
        }
        let body: Data
        if let secret = registration.secret, !secret.isEmpty {
            body = try HAMobileAppWebhookEncryption.encode(type: type, data: encoder.encode(payload), secret: secret)
        } else {
            body = try encoder.encode(HAMobileAppWebhookRequestDTO(type: type, data: payload))
        }
        let urls = try webhookURLs(configuration: configuration, registration: registration)
        for (index, url) in urls.enumerated() {
            do {
                let (data, response) = try await session.data(for: makeRequest(url: url, body: body))
                if let response = response as? HTTPURLResponse, response.statusCode == 400,
                   let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = object["error"] as? [String: Any], let code = error["code"] as? String {
                    throw HAMobileAppClientError.webhookError(code)
                }
                try validate(response: response)
                return try HAMobileAppWebhookEncryption.decode(data: data, secret: registration.secret)
            } catch {
                try Task.checkCancellation()
                guard allowFailover, index + 1 < urls.count, shouldFailover(error) else { throw error }
            }
        }
        throw HAWebSocketError.invalidURL
    }

    private func shouldFailover(_ error: Error) -> Bool {
        if case HAMobileAppClientError.httpStatus(let status) = error {
            return status == 404 || status == 408 || status == 429 || (500...599).contains(status)
        }
        guard let error = error as? URLError else { return false }
        return [.timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
                .dnsLookupFailed, .notConnectedToInternet, .secureConnectionFailed].contains(error.code)
    }

    private func makeRequest(url: URL, body: Data) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid response.")
        }
        guard (200..<300).contains(response.statusCode) else {
            throw HAMobileAppClientError.httpStatus(response.statusCode)
        }
    }

    private func webhookURLs(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo) throws -> [URL] {
        var candidates: [URL] = []
        if let cloudhook = registration.cloudhookURL, let url = URL(string: cloudhook) { candidates.append(url) }
        for base in [registration.remoteUIURL, configuration.baseURLString].compactMap({ $0 }) {
            candidates.append(try HomeAssistantEndpointBuilder.mobileAppWebhookURL(from: base, webhookID: registration.webhookID))
        }
        var result: [URL] = []
        for url in candidates {
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
                  url.user == nil, url.password == nil else { continue }
            if !result.contains(url) { result.append(url) }
        }
        guard !result.isEmpty else { throw HAWebSocketError.invalidURL }
        return result
    }
}

nonisolated enum HAMobileAppWebhookEncryption {
    static func key(secret: String) throws -> [UInt8] {
        let characters = Array(secret)
        guard characters.count == 64 else { throw HAMobileAppClientError.encryptionFailed }
        var bytes: [UInt8] = []
        for index in stride(from: 0, to: characters.count, by: 2) {
            guard let byte = UInt8(String(characters[index...index + 1]), radix: 16) else {
                throw HAMobileAppClientError.encryptionFailed
            }
            bytes.append(byte)
        }
        return bytes
    }

    static func encode(type: String, data: Data, secret: String) throws -> Data {
        let secretKey = try key(secret: secret)
        guard let sealed: [UInt8] = Sodium().secretBox.seal(message: Array(data), secretKey: secretKey) else {
            throw HAMobileAppClientError.encryptionFailed
        }
        // HA encrypts only `data`; the command stays in `type` for webhook routing.
        return try JSONSerialization.data(withJSONObject: ["type": type, "encrypted": true,
                                                           "encrypted_data": Data(sealed).base64EncodedString()])
    }

    static func decode(data: Data, secret: String?) throws -> Data {
        guard let secret, !secret.isEmpty else { return data }
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope["encrypted"] as? Bool == true,
              let encoded = envelope["encrypted_data"] as? String,
              let ciphertext = Data(base64Encoded: encoded),
              let plaintext = Sodium().secretBox.open(nonceAndAuthenticatedCipherText: Array(ciphertext), secretKey: try key(secret: secret)) else {
            throw HAMobileAppClientError.encryptionFailed
        }
        return Data(plaintext)
    }
}
