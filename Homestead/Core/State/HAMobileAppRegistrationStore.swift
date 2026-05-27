import Foundation
import Security

nonisolated protocol HAMobileAppRegistrationStore {
    func readRegistration() throws -> HAMobileAppRegistrationInfo?
    func saveRegistration(_ registration: HAMobileAppRegistrationInfo) throws
    func deleteRegistration() throws
}

enum HAMobileAppRegistrationStoreError: LocalizedError {
    case unreadableRegistration
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unreadableRegistration:
            "Unable to read the saved Home Assistant app registration."
        case .keychainFailure(let status):
            "Keychain operation failed with status \(status)."
        }
    }
}

nonisolated struct KeychainHAMobileAppRegistrationStore: HAMobileAppRegistrationStore {
    private let service: String
    private let account: String
    private let accessGroup: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        service: String = "com.tyler.Homestead.homeAssistant",
        account: String = "mobileAppRegistration",
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

    func readRegistration() throws -> HAMobileAppRegistrationInfo? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw HAMobileAppRegistrationStoreError.keychainFailure(status)
        }

        guard let data = result as? Data,
              let registration = try? decoder.decode(HAMobileAppRegistrationInfo.self, from: data) else {
            throw HAMobileAppRegistrationStoreError.unreadableRegistration
        }

        return registration
    }

    func saveRegistration(_ registration: HAMobileAppRegistrationInfo) throws {
        let data = try encoder.encode(registration)
        var query = baseQuery
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw HAMobileAppRegistrationStoreError.keychainFailure(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw HAMobileAppRegistrationStoreError.keychainFailure(addStatus)
        }
    }

    func deleteRegistration() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HAMobileAppRegistrationStoreError.keychainFailure(status)
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

nonisolated final class InMemoryHAMobileAppRegistrationStore: HAMobileAppRegistrationStore {
    private var registration: HAMobileAppRegistrationInfo?

    init(registration: HAMobileAppRegistrationInfo? = nil) {
        self.registration = registration
    }

    func readRegistration() throws -> HAMobileAppRegistrationInfo? {
        registration
    }

    func saveRegistration(_ registration: HAMobileAppRegistrationInfo) throws {
        self.registration = registration
    }

    func deleteRegistration() throws {
        registration = nil
    }
}
