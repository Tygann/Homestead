import Foundation
import Security

enum HomesteadWidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let lightSnapshotsKey = "widgetLightSnapshots"
    private static let tokenService = "com.tyler.Homestead.homeAssistant"
    private static let tokenAccount = "longLivedAccessToken"

    static var baseURL: String? {
        sharedDefaults?.string(forKey: baseURLKey)
    }

    static var accessToken: String? {
        var query = baseTokenQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }

        return token
    }

    static var lightSnapshots: [WidgetLightSnapshot] {
        guard let data = sharedDefaults?.data(forKey: lightSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetLightSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static var baseTokenQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
            kSecAttrAccessGroup as String: keychainAccessGroup
        ]
    }
}

struct WidgetLightSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
}
