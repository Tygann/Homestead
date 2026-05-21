import Foundation
import Security

protocol HACredentialStore {
    func readAccessToken() throws -> String?
    func saveAccessToken(_ token: String) throws
    func deleteAccessToken() throws
}

enum HACredentialStoreError: LocalizedError {
    case unreadableToken
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unreadableToken:
            "Unable to read the saved Home Assistant token."
        case .keychainFailure(let status):
            "Keychain operation failed with status \(status)."
        }
    }
}

struct KeychainHACredentialStore: HACredentialStore {
    private let service: String
    private let account: String
    private let accessGroup: String?

    init(
        service: String = "com.tyler.Homestead.homeAssistant",
        account: String = "longLivedAccessToken",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    func readAccessToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw HACredentialStoreError.keychainFailure(status)
        }

        guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            throw HACredentialStoreError.unreadableToken
        }

        return token
    }

    func saveAccessToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw HACredentialStoreError.keychainFailure(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw HACredentialStoreError.keychainFailure(addStatus)
        }
    }

    func deleteAccessToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HACredentialStoreError.keychainFailure(status)
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

struct MigratingHACredentialStore: HACredentialStore {
    private let primary: HACredentialStore
    private let legacy: HACredentialStore

    init(
        primary: HACredentialStore = KeychainHACredentialStore(accessGroup: WidgetSharedStore.keychainAccessGroup),
        legacy: HACredentialStore = KeychainHACredentialStore()
    ) {
        self.primary = primary
        self.legacy = legacy
    }

    func readAccessToken() throws -> String? {
        if let token = try primary.readAccessToken() {
            return token
        }

        guard let legacyToken = try legacy.readAccessToken() else {
            return nil
        }

        try primary.saveAccessToken(legacyToken)
        return legacyToken
    }

    func saveAccessToken(_ token: String) throws {
        try primary.saveAccessToken(token)
    }

    func deleteAccessToken() throws {
        try primary.deleteAccessToken()
        try legacy.deleteAccessToken()
    }
}

final class InMemoryHACredentialStore: HACredentialStore {
    private var accessToken: String?

    init(accessToken: String? = nil) {
        self.accessToken = accessToken
    }

    func readAccessToken() throws -> String? {
        accessToken
    }

    func saveAccessToken(_ token: String) throws {
        accessToken = token
    }

    func deleteAccessToken() throws {
        accessToken = nil
    }
}
