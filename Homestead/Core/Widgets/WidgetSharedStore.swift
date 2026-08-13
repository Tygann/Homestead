import Foundation

enum WidgetSharedStore {
    static let appGroupID = WidgetStorageContract.appGroupID
    nonisolated static let keychainAccessGroup = WidgetStorageContract.keychainAccessGroup

    static func saveServerProfiles(_ profiles: [HAConnectionProfile]) {
        let widgetProfiles = profiles.filter(\.hasServerURL).map {
            WidgetServerProfile(id: $0.id, displayName: $0.resolvedDisplayName, baseURLString: $0.baseURL)
        }
        guard let data = try? JSONEncoder().encode(widgetProfiles) else { return }
        sharedDefaults?.set(data, forKey: WidgetStorageContract.Key.serverProfiles)
    }

    static func serverDisplayName(profileID: UUID) -> String {
        guard let data = sharedDefaults?.data(forKey: WidgetStorageContract.Key.serverProfiles),
              let profiles = try? JSONDecoder().decode([WidgetServerProfile].self, from: data) else {
            return "Home Assistant"
        }
        return profiles.first(where: { $0.id == profileID })?.displayName ?? "Home Assistant"
    }

    nonisolated static func lightSnapshots(
        from lights: [LightEntity],
        contextForEntityID: (String) -> WidgetEntityContext = { _ in .empty },
        iconForEntityID: (String) -> ResolvedIcon? = { _ in nil },
        isAvailableForEntityID: (String) -> Bool = { _ in true }
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
                    icon: icon,
                    isAvailable: isAvailableForEntityID(light.entityID)
                )
            }
    }

    nonisolated static func switchSnapshots(
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
                    icon: entity.resolvedIcon,
                    isAvailable: entity.isAvailable
                )
            }
    }

    nonisolated static func coverSnapshots(
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

    nonisolated static func fanSnapshots(
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

    nonisolated static func lockSnapshots(
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

    nonisolated static func sensorSnapshots(
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
                    gauge: sensor.gaugePresentation.flatMap(Self.widgetGaugePresentation),
                    historyChartInterpolationStyle: sensor.historyChartInterpolationStyle,
                    chartAccentColor: widgetChartAccentColor(for: sensor)
                )
            }
    }

    nonisolated private static func widgetChartAccentColor(for sensor: SensorEntity) -> WidgetGaugeColor {
        guard sensor.isAvailable else { return .gray }
        guard !sensor.isAlerting else { return .red }

        switch sensor.displayKind {
        case .temperature, .temperatureDelta, .gas, .carbonMonoxide:
            return .orange
        case .humidity, .water, .moisture:
            return .cyan
        case .battery:
            return .green
        case .energy, .energyDistance, .energyStorage, .power, .powerFactor, .reactiveEnergy, .reactivePower, .voltage, .current, .illuminance, .irradiance:
            return .yellow
        case .pressure:
            return .purple
        case .signal, .data, .speed, .frequency, .soundPressure:
            return .blue
        case .airQuality, .carbonDioxide, .particulateMatter, .volatileOrganicCompounds, .conductivity, .pH, .precipitation:
            return .mint
        case .problem:
            return .red
        case .area, .date, .distance, .duration, .enum, .monetary, .volume, .volumeFlowRate, .weight, .windDirection, .uptime, .generic:
            return .accent
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
                    color: section.color
                        ?? GaugeZoneColor.widgetStandard(for: widgetGaugeStatus(from: section.status))
                )
            },
            accessibilityLabel: gauge.accessibilityLabel,
            accessibilityValue: gauge.accessibilityValue
        )
    }

    nonisolated static func presenceSnapshots(
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

    nonisolated static func actionSnapshots(
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
                    icon: entity.resolvedIcon,
                    isAvailable: entity.isAvailable
                )
            }
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    nonisolated private static func presenceStatusText(for state: String) -> String {
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

    nonisolated private static func fanStatusText(for fan: FanEntity) -> String {
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

    nonisolated private static func lockStatusText(for state: String) -> String {
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
