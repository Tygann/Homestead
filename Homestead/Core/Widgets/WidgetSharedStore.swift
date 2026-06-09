import Foundation

enum WidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    nonisolated static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let lightSnapshotsKey = "widgetLightSnapshots"
    private static let switchSnapshotsKey = "widgetSwitchSnapshots"
    private static let sensorSnapshotsKey = "widgetSensorSnapshots"
    private static let presenceSnapshotsKey = "widgetPresenceSnapshots"
    private static let actionSnapshotsKey = "widgetActionSnapshots"

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

    static func saveSensorSnapshots(_ sensors: [SensorEntity]) {
        let snapshots = sensorSnapshots(from: sensors)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: sensorSnapshotsKey)
    }

    static func savePresenceSnapshots(_ entities: [HomeEntity]) {
        let snapshots = presenceSnapshots(from: entities)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: presenceSnapshotsKey)
    }

    static func saveActionSnapshots(_ entities: [HomeEntity]) {
        let snapshots = actionSnapshots(from: entities)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: actionSnapshotsKey)
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
                    isOn: light.isOn,
                    brightnessPercentage: light.brightnessPercentage
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

    static func sensorSnapshots(from sensors: [SensorEntity]) -> [WidgetSensorSnapshot] {
        sensors
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { sensor in
                WidgetSensorSnapshot(
                    entityID: sensor.entityID,
                    displayName: sensor.displayName,
                    valueText: sensor.formattedValue,
                    subtitle: sensor.displaySubtitle,
                    systemImage: sensor.iconName,
                    unit: sensor.unitText,
                    isNumeric: sensor.numericValue != nil,
                    isAlerting: sensor.isAlerting,
                    isAvailable: sensor.isAvailable
                )
            }
    }

    static func presenceSnapshots(from entities: [HomeEntity]) -> [WidgetPresenceSnapshot] {
        entities
            .filter { $0.domain == .person }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { entity in
                WidgetPresenceSnapshot(
                    entityID: entity.entityID,
                    displayName: entity.displayName,
                    statusText: presenceStatusText(for: entity.state),
                    isHome: entity.state == "home",
                    systemImage: entity.iconName,
                    isAvailable: entity.isAvailable
                )
            }
    }

    static func actionSnapshots(from entities: [HomeEntity]) -> [WidgetActionSnapshot] {
        entities
            .filter { $0.domain == .scene || $0.domain == .script }
            .sorted { lhs, rhs in
                let domainComparison = lhs.domain.rawValue.localizedCaseInsensitiveCompare(rhs.domain.rawValue)
                guard domainComparison == .orderedSame else {
                    return domainComparison == .orderedAscending
                }

                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { entity in
                WidgetActionSnapshot(
                    entityID: entity.entityID,
                    displayName: entity.displayName,
                    domain: entity.domain.rawValue,
                    systemImage: entity.iconName
                )
            }
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static func presenceStatusText(for state: String) -> String {
        switch state {
        case "home":
            "Home"
        case "not_home":
            "Away"
        case "unknown":
            "Unknown"
        case "unavailable":
            "Unavailable"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct WidgetLightSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let brightnessPercentage: Int?
}

struct WidgetSwitchSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let systemImage: String
}

struct WidgetSensorSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let unit: String?
    let isNumeric: Bool
    let isAlerting: Bool
    let isAvailable: Bool
}

struct WidgetPresenceSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let statusText: String
    let isHome: Bool
    let systemImage: String
    let isAvailable: Bool
}

struct WidgetActionSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let domain: String
    let systemImage: String
}
