import Foundation
import Security

enum HomesteadWidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let lightSnapshotsKey = "widgetLightSnapshots"
    private static let optimisticLightStatesKey = "widgetOptimisticLightStates"
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

    static func lightSnapshot(entityID: String) -> WidgetLightSnapshot? {
        lightSnapshots.first { $0.entityID == entityID }
    }

    static func optimisticLightState(entityID: String) -> Bool? {
        guard let optimisticState = optimisticLightStates[entityID],
              Date().timeIntervalSince(optimisticState.updatedAt) < 10 else {
            return nil
        }

        return optimisticState.isOn
    }

    static func updateLightSnapshot(entityID: String, isOn: Bool) {
        let updatedSnapshots = lightSnapshots.map { snapshot in
            guard snapshot.entityID == entityID else {
                return snapshot
            }

            return WidgetLightSnapshot(
                entityID: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: isOn
            )
        }

        saveLightSnapshots(updatedSnapshots)

        var optimisticStates = optimisticLightStates
        optimisticStates[entityID] = OptimisticLightState(isOn: isOn, updatedAt: Date())
        saveOptimisticLightStates(optimisticStates)
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static var optimisticLightStates: [String: OptimisticLightState] {
        guard let data = sharedDefaults?.data(forKey: optimisticLightStatesKey),
              let states = try? JSONDecoder().decode([String: OptimisticLightState].self, from: data) else {
            return [:]
        }

        return states
    }

    private static func saveLightSnapshots(_ snapshots: [WidgetLightSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: lightSnapshotsKey)
    }

    private static func saveOptimisticLightStates(_ states: [String: OptimisticLightState]) {
        guard let data = try? JSONEncoder().encode(states) else {
            return
        }

        sharedDefaults?.set(data, forKey: optimisticLightStatesKey)
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

private struct OptimisticLightState: Codable, Equatable {
    let isOn: Bool
    let updatedAt: Date
}
