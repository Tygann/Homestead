import Foundation
import Security

nonisolated protocol HAOAuthTokenStore {
    func readCredential() throws -> HAOAuthCredential?
    func saveCredential(_ credential: HAOAuthCredential) throws
    func deleteCredential() throws
}

enum HAOAuthTokenStoreError: LocalizedError {
    case unreadableCredential
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unreadableCredential:
            "Unable to read the saved Home Assistant sign-in."
        case .keychainFailure(let status):
            "Keychain operation failed with status \(status)."
        }
    }
}

nonisolated struct KeychainHAOAuthTokenStore: HAOAuthTokenStore {
    private let service: String
    private let account: String
    private let accessGroup: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        service: String = "com.tyler.Homestead.homeAssistant",
        account: String = "oauthCredential",
        accessGroup: String? = WidgetSharedStore.keychainAccessGroup
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func readCredential() throws -> HAOAuthCredential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw HAOAuthTokenStoreError.keychainFailure(status)
        }

        guard let data = result as? Data,
              let credential = try? decoder.decode(HAOAuthCredential.self, from: data) else {
            throw HAOAuthTokenStoreError.unreadableCredential
        }

        return credential
    }

    func saveCredential(_ credential: HAOAuthCredential) throws {
        let data = try encoder.encode(credential)
        var query = baseQuery
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw HAOAuthTokenStoreError.keychainFailure(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw HAOAuthTokenStoreError.keychainFailure(addStatus)
        }
    }

    func deleteCredential() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HAOAuthTokenStoreError.keychainFailure(status)
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

nonisolated final class InMemoryHAOAuthTokenStore: HAOAuthTokenStore {
    private var credential: HAOAuthCredential?

    init(credential: HAOAuthCredential? = nil) {
        self.credential = credential
    }

    func readCredential() throws -> HAOAuthCredential? {
        credential
    }

    func saveCredential(_ credential: HAOAuthCredential) throws {
        self.credential = credential
    }

    func deleteCredential() throws {
        credential = nil
    }
}
