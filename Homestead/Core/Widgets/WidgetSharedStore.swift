import Foundation

enum WidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    nonisolated static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let lightSnapshotsKey = "widgetLightSnapshots"

    static func saveBaseURL(_ baseURL: String) {
        sharedDefaults?.set(baseURL, forKey: baseURLKey)
    }

    static func saveLightSnapshots(_ lights: [LightEntity]) {
        let snapshots = lights
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { light in
                WidgetLightSnapshot(
                    entityID: light.entityID,
                    displayName: light.displayName,
                    isOn: light.isOn
                )
            }

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: lightSnapshotsKey)
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

struct WidgetLightSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
}
