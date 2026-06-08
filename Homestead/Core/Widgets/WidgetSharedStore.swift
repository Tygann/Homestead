import Foundation

enum WidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    nonisolated static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let lightSnapshotsKey = "widgetLightSnapshots"
    private static let switchSnapshotsKey = "widgetSwitchSnapshots"

    static func saveBaseURL(_ baseURL: String) {
        sharedDefaults?.set(baseURL, forKey: baseURLKey)
    }

    static func saveLightSnapshots(_ lights: [LightEntity]) {
        let snapshots = lightSnapshots(from: lights)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: lightSnapshotsKey)
    }

    static func saveSwitchSnapshots(_ entities: [HomeEntity]) {
        let snapshots = switchSnapshots(from: entities)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: switchSnapshotsKey)
    }

    static func lightSnapshots(from lights: [LightEntity]) -> [WidgetLightSnapshot] {
        lights
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
    }

    static func switchSnapshots(from entities: [HomeEntity]) -> [WidgetSwitchSnapshot] {
        entities
            .filter { $0.domain == .switch }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { entity in
                WidgetSwitchSnapshot(
                    entityID: entity.entityID,
                    displayName: entity.displayName,
                    isOn: entity.state == "on",
                    systemImage: entity.iconName
                )
            }
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

struct WidgetSwitchSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let systemImage: String
}
