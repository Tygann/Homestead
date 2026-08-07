import Foundation
import Security
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum HomesteadPushRelayEndpoint {
    static let baseURLString = "https://api.homesteadcontrol.com"
    static let pushURLString = "\(baseURLString)/mobile-app/push"

    static var registerPushTokenURL: URL {
        URL(string: "\(baseURLString)/mobile-app/register-push-token")!
    }
}

nonisolated enum HomesteadPushEnvironment: String, Encodable, Equatable, Sendable {
    case sandbox
    case production

    #if DEBUG
    static let current: HomesteadPushEnvironment = .sandbox
    #else
    static let current: HomesteadPushEnvironment = .production
    #endif
}

nonisolated struct HomesteadPushTokenRegistrationRequest: Encodable, Equatable, Sendable {
    let pushRelayToken: String
    let apnsToken: String
    let environment: HomesteadPushEnvironment
}

nonisolated protocol HomesteadPushTokenRegistrationClient {
    func register(_ request: HomesteadPushTokenRegistrationRequest) async throws
}

struct URLSessionHomesteadPushTokenRegistrationClient: HomesteadPushTokenRegistrationClient {
    private let session: URLSession
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        encoder = JSONEncoder()
    }

    func register(_ request: HomesteadPushTokenRegistrationRequest) async throws {
        var urlRequest = URLRequest(url: HomesteadPushRelayEndpoint.registerPushTokenURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (_, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HomesteadPushRegistrationError.invalidBackendResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HomesteadPushRegistrationError.backendRejected(statusCode: httpResponse.statusCode)
        }
    }
}

nonisolated protocol PushRelayTokenStore {
    func readOrCreateRelayToken() throws -> String
}

enum PushRelayTokenStoreError: LocalizedError {
    case keychainFailure(OSStatus)
    case randomGenerationFailed(OSStatus)
    case unreadableToken

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status):
            "Keychain operation failed with status \(status)."
        case .randomGenerationFailed:
            "Unable to create a notification token. Try again."
        case .unreadableToken:
            "Unable to read the saved notification token."
        }
    }
}

nonisolated struct KeychainPushRelayTokenStore: PushRelayTokenStore {
    private let service: String
    private let account: String
    private let accessGroup: String?

    init(
        service: String = "com.tyler.Homestead.notifications",
        account: String = "pushRelayToken",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    func readOrCreateRelayToken() throws -> String {
        if let token = try readRelayToken() {
            return token
        }

        let token = try PushRelayTokenGenerator.makeToken()
        try saveRelayToken(token)
        return token
    }

    private func readRelayToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw PushRelayTokenStoreError.keychainFailure(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            throw PushRelayTokenStoreError.unreadableToken
        }

        return token
    }

    private func saveRelayToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw PushRelayTokenStoreError.keychainFailure(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw PushRelayTokenStoreError.keychainFailure(addStatus)
        }
    }

    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

nonisolated final class InMemoryPushRelayTokenStore: PushRelayTokenStore {
    private let token: String

    init(token: String = "preview-push-relay-token") {
        self.token = token
    }

    func readOrCreateRelayToken() throws -> String {
        token
    }
}

enum PushRelayTokenGenerator {
    nonisolated static func makeToken(byteCount: Int = 32) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw PushRelayTokenStoreError.randomGenerationFailed(status)
        }

        return Data(bytes).lowercaseHexString
    }
}

@MainActor
protocol NativeRemoteNotificationRegistrationClient {
    func registerForRemoteNotifications() async
}

struct UIApplicationRemoteNotificationRegistrationClient: NativeRemoteNotificationRegistrationClient {
    func registerForRemoteNotifications() async {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }
}

enum HomesteadPushRegistrationError: LocalizedError, Equatable {
    case invalidBackendResponse
    case backendRejected(statusCode: Int)
    case remoteRegistrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackendResponse:
            "Notification setup could not be completed. Try again later."
        case .backendRejected:
            "Notification setup was rejected. Try again later."
        case .remoteRegistrationFailed(let message):
            message.isEmpty ? "Notification setup could not be completed." : message
        }
    }
}

extension Data {
    nonisolated var lowercaseHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
