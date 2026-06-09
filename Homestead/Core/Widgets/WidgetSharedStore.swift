import Foundation

enum WidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    nonisolated static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let lightSnapshotsKey = "widgetLightSnapshots"
    private static let switchSnapshotsKey = "widgetSwitchSnapshots"
    private static let coverSnapshotsKey = "widgetCoverSnapshots"
    private static let fanSnapshotsKey = "widgetFanSnapshots"
    private static let lockSnapshotsKey = "widgetLockSnapshots"
    private static let sensorSnapshotsKey = "widgetSensorSnapshots"
    private static let presenceSnapshotsKey = "widgetPresenceSnapshots"
    private static let actionSnapshotsKey = "widgetActionSnapshots"

    static func saveBaseURL(_ baseURL: String) {
        sharedDefaults?.set(baseURL, forKey: baseURLKey)
    }

    static func saveLightSnapshots(
        _ lights: [LightEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = lightSnapshots(from: lights, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: lightSnapshotsKey)
    }

    static func saveSwitchSnapshots(
        _ entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = switchSnapshots(from: entities, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: switchSnapshotsKey)
    }

    static func saveCoverSnapshots(
        _ covers: [CoverEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = coverSnapshots(from: covers, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: coverSnapshotsKey)
    }

    static func saveFanSnapshots(
        _ fans: [FanEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = fanSnapshots(from: fans, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: fanSnapshotsKey)
    }

    static func saveLockSnapshots(
        _ entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = lockSnapshots(from: entities, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: lockSnapshotsKey)
    }

    static func saveSensorSnapshots(
        _ sensors: [SensorEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = sensorSnapshots(from: sensors, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: sensorSnapshotsKey)
    }

    static func savePresenceSnapshots(
        _ entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = presenceSnapshots(from: entities, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: presenceSnapshotsKey)
    }

    static func saveActionSnapshots(
        _ entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) {
        let snapshots = actionSnapshots(from: entities, contextForEntityID: contextForEntityID)

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: actionSnapshotsKey)
    }

    static func lightSnapshots(
        from lights: [LightEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetLightSnapshot] {
        lights
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { light in
                let context = contextForEntityID(light.entityID)
                return WidgetLightSnapshot(
                    entityID: light.entityID,
                    displayName: light.displayName,
                    isOn: light.isOn,
                    brightnessPercentage: light.brightnessPercentage,
                    areaName: context.areaName,
                    deviceName: context.deviceName
                )
            }
    }

    static func switchSnapshots(
        from entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetSwitchSnapshot] {
        entities
            .filter { $0.domain == .switch }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { entity in
                let context = contextForEntityID(entity.entityID)
                return WidgetSwitchSnapshot(
                    entityID: entity.entityID,
                    displayName: entity.displayName,
                    isOn: entity.state == "on",
                    systemImage: entity.iconName,
                    areaName: context.areaName,
                    deviceName: context.deviceName
                )
            }
    }

    static func coverSnapshots(
        from covers: [CoverEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetCoverSnapshot] {
        covers
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { cover in
                let context = contextForEntityID(cover.entityID)
                return WidgetCoverSnapshot(
                    entityID: cover.entityID,
                    displayName: cover.displayName,
                    state: cover.state,
                    statusText: cover.displaySubtitle,
                    systemImage: cover.iconName,
                    isOpen: cover.isOpen,
                    isClosed: cover.isClosed,
                    isMoving: cover.isMoving,
                    isAvailable: !["unknown", "unavailable"].contains(cover.state),
                    areaName: context.areaName,
                    deviceName: context.deviceName
                )
            }
    }

    static func fanSnapshots(
        from fans: [FanEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetFanSnapshot] {
        fans
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { fan in
                let context = contextForEntityID(fan.entityID)
                return WidgetFanSnapshot(
                    entityID: fan.entityID,
                    displayName: fan.displayName,
                    isOn: fan.isOn,
                    statusText: fanStatusText(for: fan),
                    isAvailable: fan.isAvailable,
                    areaName: context.areaName,
                    deviceName: context.deviceName
                )
            }
    }

    static func lockSnapshots(
        from entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetLockSnapshot] {
        entities
            .filter { $0.domain == .lock }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { entity in
                let context = contextForEntityID(entity.entityID)
                return WidgetLockSnapshot(
                    entityID: entity.entityID,
                    displayName: entity.displayName,
                    state: entity.state,
                    statusText: lockStatusText(for: entity.state),
                    systemImage: lockSystemImage(for: entity.state),
                    isLocked: entity.state == "locked",
                    isAvailable: entity.isAvailable,
                    areaName: context.areaName,
                    deviceName: context.deviceName
                )
            }
    }

    static func sensorSnapshots(
        from sensors: [SensorEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetSensorSnapshot] {
        sensors
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { sensor in
                let context = contextForEntityID(sensor.entityID)
                return WidgetSensorSnapshot(
                    entityID: sensor.entityID,
                    displayName: sensor.displayName,
                    valueText: sensor.formattedValue,
                    subtitle: sensor.displaySubtitle,
                    systemImage: sensor.iconName,
                    unit: sensor.unitText,
                    isNumeric: sensor.numericValue != nil,
                    isAlerting: sensor.isAlerting,
                    isAvailable: sensor.isAvailable,
                    areaName: context.areaName,
                    deviceName: context.deviceName
                )
            }
    }

    static func presenceSnapshots(
        from entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetPresenceSnapshot] {
        entities
            .filter { $0.domain == .person }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { entity in
                let context = contextForEntityID(entity.entityID)
                return WidgetPresenceSnapshot(
                    entityID: entity.entityID,
                    displayName: entity.displayName,
                    statusText: presenceStatusText(for: entity.state),
                    isHome: entity.state == "home",
                    systemImage: entity.iconName,
                    isAvailable: entity.isAvailable,
                    areaName: context.areaName,
                    deviceName: context.deviceName
                )
            }
    }

    static func actionSnapshots(
        from entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetActionSnapshot] {
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
                let context = contextForEntityID(entity.entityID)
                return WidgetActionSnapshot(
                    entityID: entity.entityID,
                    displayName: entity.displayName,
                    domain: entity.domain.rawValue,
                    systemImage: entity.iconName,
                    areaName: context.areaName,
                    deviceName: context.deviceName
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

    private static func fanStatusText(for fan: FanEntity) -> String {
        guard fan.isAvailable else {
            return "Unavailable"
        }

        guard fan.isOn else {
            return fan.displayState
        }

        if let percentage = fan.percentage {
            return "On • \(percentage)%"
        }

        if let presetMode = fan.presetMode, !presetMode.isEmpty {
            return "On • \(fan.displayName(forPresetMode: presetMode))"
        }

        return fan.displayState
    }

    private static func lockStatusText(for state: String) -> String {
        switch state {
        case "locked":
            "Locked"
        case "unlocked":
            "Unlocked"
        case "locking":
            "Locking"
        case "unlocking":
            "Unlocking"
        case "jammed":
            "Jammed"
        case "unknown":
            "Unknown"
        case "unavailable":
            "Unavailable"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func lockSystemImage(for state: String) -> String {
        switch state {
        case "locked", "locking":
            "lock.fill"
        case "jammed":
            "exclamationmark.lock.fill"
        default:
            "lock.open.fill"
        }
    }
}

struct WidgetLightSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let brightnessPercentage: Int?
    let areaName: String?
    let deviceName: String?
}

struct WidgetSwitchSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let systemImage: String
    let areaName: String?
    let deviceName: String?
}

struct WidgetCoverSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String
    let isOpen: Bool
    let isClosed: Bool
    let isMoving: Bool
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
}

struct WidgetFanSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let statusText: String
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
}

struct WidgetLockSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String
    let isLocked: Bool
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
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
    let areaName: String?
    let deviceName: String?
}

struct WidgetPresenceSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let statusText: String
    let isHome: Bool
    let systemImage: String
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
}

struct WidgetActionSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let domain: String
    let systemImage: String
    let areaName: String?
    let deviceName: String?
}

struct WidgetEntityContext: Codable, Equatable, Sendable {
    let areaName: String?
    let deviceName: String?

    static let empty = WidgetEntityContext(areaName: nil, deviceName: nil)
}
