import Foundation

enum WidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    nonisolated static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let serverProfilesKey = "homeAssistantServerProfiles"
    private static let activeProfileIDKey = "homeAssistantActiveProfileID"
    private static let legacyWidgetProfileIDKey = "homeAssistantLegacyWidgetProfileID"
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

    static func saveActiveProfileID(_ profileID: UUID) {
        sharedDefaults?.set(profileID.uuidString, forKey: activeProfileIDKey)
    }

    static func saveServerProfiles(_ profiles: [HAConnectionProfile], activeProfileID: UUID) {
        let widgetProfiles = profiles.filter(\.hasServerURL).map {
            WidgetServerProfile(id: $0.id, displayName: $0.resolvedDisplayName, baseURLString: $0.baseURL)
        }
        guard let data = try? JSONEncoder().encode(widgetProfiles) else { return }
        sharedDefaults?.set(data, forKey: serverProfilesKey)
        if sharedDefaults?.string(forKey: legacyWidgetProfileIDKey) == nil {
            sharedDefaults?.set(activeProfileID.uuidString, forKey: legacyWidgetProfileIDKey)
        }
        saveActiveProfileID(activeProfileID)
    }

    static var legacyWidgetProfileID: UUID? {
        sharedDefaults?.string(forKey: legacyWidgetProfileIDKey).flatMap(UUID.init(uuidString:))
    }

    static func saveLightSnapshots(
        _ lights: [LightEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) {
        let snapshots = lightSnapshots(
            from: lights,
            contextForEntityID: contextForEntityID,
            iconForEntityID: iconForEntityID
        )

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: lightSnapshotsKey)
    }

    static func saveLightSnapshotPayload(_ snapshots: [WidgetLightSnapshot]) {
        save(snapshots, forKey: lightSnapshotsKey)
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

    static func saveSwitchSnapshotPayload(_ snapshots: [WidgetSwitchSnapshot]) {
        save(snapshots, forKey: switchSnapshotsKey)
    }

    static func saveCoverSnapshots(
        _ covers: [CoverEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) {
        let snapshots = coverSnapshots(
            from: covers,
            contextForEntityID: contextForEntityID,
            iconForEntityID: iconForEntityID
        )

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: coverSnapshotsKey)
    }

    static func saveCoverSnapshotPayload(_ snapshots: [WidgetCoverSnapshot]) {
        save(snapshots, forKey: coverSnapshotsKey)
    }

    static func saveFanSnapshots(
        _ fans: [FanEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) {
        let snapshots = fanSnapshots(
            from: fans,
            contextForEntityID: contextForEntityID,
            iconForEntityID: iconForEntityID
        )

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: fanSnapshotsKey)
    }

    static func saveFanSnapshotPayload(_ snapshots: [WidgetFanSnapshot]) {
        save(snapshots, forKey: fanSnapshotsKey)
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

    static func saveLockSnapshotPayload(_ snapshots: [WidgetLockSnapshot]) {
        save(snapshots, forKey: lockSnapshotsKey)
    }

    static func saveSensorSnapshots(
        _ sensors: [SensorEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) {
        let snapshots = sensorSnapshots(
            from: sensors,
            contextForEntityID: contextForEntityID,
            iconForEntityID: iconForEntityID
        )

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: sensorSnapshotsKey)
    }

    static func saveSensorSnapshotPayload(_ snapshots: [WidgetSensorSnapshot]) {
        save(snapshots, forKey: sensorSnapshotsKey)
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

    static func savePresenceSnapshotPayload(_ snapshots: [WidgetPresenceSnapshot]) {
        save(snapshots, forKey: presenceSnapshotsKey)
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

    static func saveActionSnapshotPayload(_ snapshots: [WidgetActionSnapshot]) {
        save(snapshots, forKey: actionSnapshotsKey)
    }

    static func lightSnapshots(
        from lights: [LightEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) -> [WidgetLightSnapshot] {
        lights
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { light in
                let context = contextForEntityID(light.entityID)
                let icon = iconForEntityID(light.entityID) ?? IconResolver.resolveEntity(
                    EntityIconResolutionInput(domain: "light", state: light.isOn ? "on" : "off")
                )
                return WidgetLightSnapshot(
                    entityID: light.entityID,
                    displayName: light.displayName,
                    isOn: light.isOn,
                    brightnessPercentage: light.brightnessPercentage,
                    areaName: context.areaName,
                    deviceName: context.deviceName,
                    icon: icon
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
                    deviceName: context.deviceName,
                    icon: entity.resolvedIcon
                )
            }
    }

    static func coverSnapshots(
        from covers: [CoverEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) -> [WidgetCoverSnapshot] {
        covers
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { cover in
                let context = contextForEntityID(cover.entityID)
                let icon = iconForEntityID(cover.entityID) ?? IconResolver.resolveEntity(
                    EntityIconResolutionInput(
                        domain: "cover",
                        deviceClass: cover.deviceClass,
                        state: cover.state
                    )
                )
                return WidgetCoverSnapshot(
                    entityID: cover.entityID,
                    displayName: cover.displayName,
                    state: cover.state,
                    statusText: cover.displaySubtitle,
                    systemImage: icon.sfSymbolName,
                    isOpen: cover.isOpen,
                    isClosed: cover.isClosed,
                    isMoving: cover.isMoving,
                    isAvailable: !["unknown", "unavailable"].contains(cover.state),
                    areaName: context.areaName,
                    deviceName: context.deviceName,
                    icon: icon
                )
            }
    }

    static func fanSnapshots(
        from fans: [FanEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) -> [WidgetFanSnapshot] {
        fans
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { fan in
                let context = contextForEntityID(fan.entityID)
                let icon = iconForEntityID(fan.entityID) ?? IconResolver.resolveEntity(
                    EntityIconResolutionInput(domain: "fan", state: fan.state)
                )
                return WidgetFanSnapshot(
                    entityID: fan.entityID,
                    displayName: fan.displayName,
                    isOn: fan.isOn,
                    statusText: fanStatusText(for: fan),
                    isAvailable: fan.isAvailable,
                    areaName: context.areaName,
                    deviceName: context.deviceName,
                    icon: icon
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
                    systemImage: entity.iconName,
                    isLocked: entity.state == "locked",
                    isAvailable: entity.isAvailable,
                    areaName: context.areaName,
                    deviceName: context.deviceName,
                    icon: entity.resolvedIcon
                )
            }
    }

    static func sensorSnapshots(
        from sensors: [SensorEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil }
    ) -> [WidgetSensorSnapshot] {
        sensors
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map { sensor in
                let context = contextForEntityID(sensor.entityID)
                let icon = iconForEntityID(sensor.entityID) ?? IconResolver.resolveEntity(
                    EntityIconResolutionInput(
                        domain: "sensor",
                        deviceClass: sensor.deviceClass,
                        state: sensor.value
                    )
                )
                return WidgetSensorSnapshot(
                    entityID: sensor.entityID,
                    displayName: sensor.displayName,
                    valueText: sensor.formattedValue,
                    subtitle: sensor.displaySubtitle,
                    systemImage: icon.sfSymbolName,
                    unit: sensor.unitText,
                    isNumeric: sensor.numericValue != nil,
                    isAlerting: sensor.isAlerting,
                    isAvailable: sensor.isAvailable,
                    areaName: context.areaName,
                    deviceName: context.deviceName,
                    icon: icon,
                    gauge: sensor.gaugePresentation.flatMap(Self.widgetGaugePresentation)
                )
            }
    }

    nonisolated private static func widgetGaugePresentation(from gauge: GaugePresentation) -> WidgetGaugePresentation? {
        guard gauge.isDashboardFeatureEligible else {
            return nil
        }

        return WidgetGaugePresentation(
            value: gauge.value,
            lowerBound: gauge.range.lowerBound,
            upperBound: gauge.range.upperBound,
            valueText: gauge.valueText,
            unitText: gauge.unitText,
            status: widgetGaugeStatus(from: gauge.status),
            statusDisplayText: gauge.statusDisplayText,
            sections: gauge.sections.map { section in
                WidgetGaugeSection(
                    lowerBound: section.range.lowerBound,
                    upperBound: section.range.upperBound,
                    color: WidgetGaugeColor.standard(for: widgetGaugeStatus(from: section.status))
                )
            },
            accessibilityLabel: gauge.accessibilityLabel,
            accessibilityValue: gauge.accessibilityValue
        )
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
                    deviceName: context.deviceName,
                    icon: entity.resolvedIcon
                )
            }
    }

    static func actionSnapshots(
        from entities: [HomeEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty }
    ) -> [WidgetActionSnapshot] {
        entities
            .filter { $0.domain == .scene || $0.domain == .script || $0.domain == .button }
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
                    deviceName: context.deviceName,
                    icon: entity.resolvedIcon
                )
            }
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        sharedDefaults?.set(data, forKey: key)
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

    nonisolated private static func widgetGaugeStatus(from status: GaugePresentationStatus) -> WidgetGaugeStatus {
        switch status {
        case .nominal:
            .nominal
        case .low:
            .low
        case .high:
            .high
        case .warning:
            .warning
        case .critical:
            .critical
        }
    }

}
