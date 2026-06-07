import Foundation

nonisolated enum HAOAuthClientMetadata {
    static let clientID = "https://homestead.keegan.pro"
    static let redirectURI = "homestead://auth"
    static let callbackScheme = "homestead"
    static let refreshLeeway: TimeInterval = 60
}

nonisolated struct HAOAuthCredential: Codable, Equatable, Sendable {
    let baseURLString: String
    let clientID: String
    let refreshToken: String
    let accessToken: String
    let accessTokenExpiresAt: Date
    let tokenType: String
    let updatedAt: Date

    var hasExpiredAccessToken: Bool {
        accessTokenExpiresAt <= Date()
    }

    func accessTokenExpiresSoon(
        now: Date = Date(),
        leeway: TimeInterval = HAOAuthClientMetadata.refreshLeeway
    ) -> Bool {
        accessTokenExpiresAt.timeIntervalSince(now) <= leeway
    }

    func replacingAccessToken(
        _ accessToken: String,
        expiresIn: TimeInterval,
        tokenType: String,
        now: Date
    ) -> HAOAuthCredential {
        HAOAuthCredential(
            baseURLString: baseURLString,
            clientID: clientID,
            refreshToken: refreshToken,
            accessToken: accessToken,
            accessTokenExpiresAt: now.addingTimeInterval(expiresIn),
            tokenType: tokenType,
            updatedAt: now
        )
    }
}

nonisolated struct HAAuthSessionSummary: Equatable, Sendable {
    let baseURLString: String
    let accessTokenExpiresAt: Date

    init(credential: HAOAuthCredential) {
        baseURLString = credential.baseURLString
        accessTokenExpiresAt = credential.accessTokenExpiresAt
    }
}

nonisolated enum HAAuthState: Equatable, Sendable {
    case signedOut
    case signingIn
    case refreshing(HAAuthSessionSummary?)
    case signedIn(HAAuthSessionSummary)
    case accessTokenExpired(HAAuthSessionSummary)
    case refreshFailed(String)

    var isSignedIn: Bool {
        switch self {
        case .signedIn, .accessTokenExpired, .refreshing:
            true
        case .signedOut, .signingIn, .refreshFailed:
            false
        }
    }

    var title: String {
        switch self {
        case .signedOut:
            "Signed Out"
        case .signingIn:
            "Signing In"
        case .refreshing:
            "Refreshing Sign-In"
        case .signedIn:
            "Signed In"
        case .accessTokenExpired:
            "Token Expired"
        case .refreshFailed:
            "Refresh Failed"
        }
    }
}

nonisolated enum HAOAuthError: LocalizedError, Equatable, Sendable {
    case missingAuthorizationCode
    case stateMismatch
    case signedOut
    case noRefreshTokenForServer
    case invalidTokenResponse

    var errorDescription: String? {
        switch self {
        case .missingAuthorizationCode:
            "Home Assistant did not return an authorization code."
        case .stateMismatch:
            "Home Assistant sign-in returned an unexpected state value."
        case .signedOut:
            "Sign in with Home Assistant before connecting."
        case .noRefreshTokenForServer:
            "Sign in again for this Home Assistant server."
        case .invalidTokenResponse:
            "Home Assistant returned an invalid token response."
        }
    }
}

nonisolated struct HAOAuthTokenRequest: Equatable, Sendable {
    enum Grant: Equatable, Sendable {
        case authorizationCode(String)
        case refreshToken(String)
    }

    let grant: Grant
    let clientID: String

    var formItems: [(String, String)] {
        switch grant {
        case .authorizationCode(let code):
            [
                ("grant_type", "authorization_code"),
                ("code", code),
                ("client_id", clientID)
            ]
        case .refreshToken(let refreshToken):
            [
                ("grant_type", "refresh_token"),
                ("refresh_token", refreshToken),
                ("client_id", clientID)
            ]
        }
    }

    func formEncodedBody() -> Data {
        let body = formItems
            .map { key, value in
                "\(Self.formEncode(key))=\(Self.formEncode(value))"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private static func formEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._*")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

nonisolated struct HAOAuthTokenResponseDTO: Decodable, Equatable, Sendable {
    let accessToken: String
    let expiresIn: TimeInterval
    let refreshToken: String?
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

nonisolated protocol HAOAuthClientProtocol {
    func exchangeAuthorizationCode(
        baseURLString: String,
        code: String,
        clientID: String
    ) async throws -> HAOAuthTokenResponseDTO

    func refreshAccessToken(
        baseURLString: String,
        refreshToken: String,
        clientID: String
    ) async throws -> HAOAuthTokenResponseDTO
}

actor HAOAuthClient: HAOAuthClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
    }

    func exchangeAuthorizationCode(
        baseURLString: String,
        code: String,
        clientID: String
    ) async throws -> HAOAuthTokenResponseDTO {
        try await sendTokenRequest(
            baseURLString: baseURLString,
            request: HAOAuthTokenRequest(grant: .authorizationCode(code), clientID: clientID)
        )
    }

    func refreshAccessToken(
        baseURLString: String,
        refreshToken: String,
        clientID: String
    ) async throws -> HAOAuthTokenResponseDTO {
        try await sendTokenRequest(
            baseURLString: baseURLString,
            request: HAOAuthTokenRequest(grant: .refreshToken(refreshToken), clientID: clientID)
        )
    }

    private func sendTokenRequest(
        baseURLString: String,
        request tokenRequest: HAOAuthTokenRequest
    ) async throws -> HAOAuthTokenResponseDTO {
        let url = try HomeAssistantEndpointBuilder.authTokenURL(from: baseURLString)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = tokenRequest.formEncodedBody()

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid token response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HAWebSocketError.authenticationFailed("Home Assistant token request failed with status \(httpResponse.statusCode).")
        }

        guard !data.isEmpty else {
            throw HAOAuthError.invalidTokenResponse
        }

        return try decoder.decode(HAOAuthTokenResponseDTO.self, from: data)
    }
}

actor HAOAuthManager {
    private let client: any HAOAuthClientProtocol
    private let tokenStore: any HAOAuthTokenStore
    private let clientID: String
    private let redirectURI: String
    private let now: @Sendable () -> Date

    init(
        client: (any HAOAuthClientProtocol)? = nil,
        tokenStore: (any HAOAuthTokenStore)? = nil,
        clientID: String = HAOAuthClientMetadata.clientID,
        redirectURI: String = HAOAuthClientMetadata.redirectURI,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.client = client ?? HAOAuthClient()
        self.tokenStore = tokenStore ?? KeychainHAOAuthTokenStore()
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.now = now
    }

    func authorizeURL(baseURLString: String, state: String) throws -> URL {
        try HomeAssistantEndpointBuilder.authAuthorizeURL(
            from: baseURLString,
            clientID: clientID,
            redirectURI: redirectURI,
            state: state
        )
    }

    func status() -> HAAuthState {
        do {
            guard let credential = try tokenStore.readCredential() else {
                return .signedOut
            }

            let summary = HAAuthSessionSummary(credential: credential)
            return credential.accessTokenExpiresSoon(now: now(), leeway: 0)
                ? .accessTokenExpired(summary)
                : .signedIn(summary)
        } catch {
            return .refreshFailed(error.localizedDescription)
        }
    }

    func storedConfiguration(baseURLString: String? = nil) throws -> HAConnectionConfiguration? {
        guard let credential = try tokenStore.readCredential() else {
            return nil
        }

        if let baseURLString, !baseURLMatches(credential: credential, baseURLString: baseURLString) {
            return nil
        }

        return HAConnectionConfiguration(
            baseURLString: credential.baseURLString,
            accessToken: credential.accessToken
        )
    }

    func signIn(baseURLString: String, authorizationCode: String) async throws -> HAConnectionConfiguration {
        let trimmedBaseURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await client.exchangeAuthorizationCode(
            baseURLString: trimmedBaseURL,
            code: authorizationCode,
            clientID: clientID
        )

        guard let refreshToken = response.refreshToken, !refreshToken.isEmpty else {
            throw HAOAuthError.invalidTokenResponse
        }

        let credential = HAOAuthCredential(
            baseURLString: trimmedBaseURL,
            clientID: clientID,
            refreshToken: refreshToken,
            accessToken: response.accessToken,
            accessTokenExpiresAt: now().addingTimeInterval(response.expiresIn),
            tokenType: response.tokenType,
            updatedAt: now()
        )
        try tokenStore.saveCredential(credential)

        return HAConnectionConfiguration(
            baseURLString: credential.baseURLString,
            accessToken: credential.accessToken
        )
    }

    func validConfiguration(baseURLString: String) async throws -> HAConnectionConfiguration {
        let credential = try credentialForServer(baseURLString: baseURLString)

        if credential.accessTokenExpiresSoon(now: now()) {
            return try await refreshConfiguration(baseURLString: baseURLString)
        }

        return HAConnectionConfiguration(
            baseURLString: credential.baseURLString,
            accessToken: credential.accessToken
        )
    }

    func refreshConfiguration(baseURLString: String) async throws -> HAConnectionConfiguration {
        let credential = try credentialForServer(baseURLString: baseURLString)
        let response = try await client.refreshAccessToken(
            baseURLString: credential.baseURLString,
            refreshToken: credential.refreshToken,
            clientID: credential.clientID
        )

        let refreshedCredential = credential.replacingAccessToken(
            response.accessToken,
            expiresIn: response.expiresIn,
            tokenType: response.tokenType,
            now: now()
        )
        try tokenStore.saveCredential(refreshedCredential)

        return HAConnectionConfiguration(
            baseURLString: refreshedCredential.baseURLString,
            accessToken: refreshedCredential.accessToken
        )
    }

    func signOut() throws {
        try tokenStore.deleteCredential()
    }

    private func credentialForServer(baseURLString: String) throws -> HAOAuthCredential {
        guard let credential = try tokenStore.readCredential() else {
            throw HAOAuthError.signedOut
        }

        guard baseURLMatches(credential: credential, baseURLString: baseURLString) else {
            throw HAOAuthError.noRefreshTokenForServer
        }

        return credential
    }

    private func baseURLMatches(credential: HAOAuthCredential, baseURLString: String) -> Bool {
        HAConnectionConfiguration(
            baseURLString: credential.baseURLString,
            accessToken: credential.accessToken
        ).dataSourceID == HAConnectionConfiguration(
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: credential.accessToken
        ).dataSourceID
    }
}
