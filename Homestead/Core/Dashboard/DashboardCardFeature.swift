import Foundation

enum DashboardCardFeatureKey: String, Codable, Equatable, Sendable {
    case lightBrightness
    case fanSpeed
    case climateSetpoint
    case coverControls
    case coverPosition
    case lockControls
    case selectOptions
    case sensorGauge
}

enum DashboardCardFeatureVisibility: String, CaseIterable, Codable, Equatable, Sendable {
    case automatic
    case hidden

    var displayName: String {
        switch self {
        case .automatic:
            "Automatic"
        case .hidden:
            "Hidden"
        }
    }

    var systemImage: String {
        switch self {
        case .automatic:
            "sparkles"
        case .hidden:
            "eye.slash"
        }
    }
}

enum DashboardCardFeatureContent: Equatable, Sendable {
    case level(DashboardCardLevelFeature)
    case setpoint(DashboardCardSetpointFeature)
    case commandGroup(DashboardCardCommandGroupFeature)
    case options(DashboardCardOptionsFeature)
    case gauge(DashboardCardGaugeFeature)
}

struct DashboardCardFeature: Equatable, Identifiable, Sendable {
    let key: DashboardCardFeatureKey
    let title: String
    let content: DashboardCardFeatureContent

    var id: String { key.rawValue }
}

enum DashboardCardLevelAction: String, Equatable, Sendable {
    case setLightBrightness
    case setFanPercentage
    case setCoverPosition
}

struct DashboardCardLevelFeature: Equatable, Sendable {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueLabel: String
    let accessibilityLabel: String
    let action: DashboardCardLevelAction
}

enum DashboardCardSetpointAction: String, Equatable, Sendable {
    case setClimateTemperature
    case setClimateTemperatureRange
}

enum DashboardCardSetpointRole: String, Equatable, Sendable {
    case target
    case low
    case high
}

struct DashboardCardSetpointValue: Equatable, Identifiable, Sendable {
    let role: DashboardCardSetpointRole
    let value: Double
    let displayValue: String
    let formattedValue: String
    let minimumValue: Double
    let maximumValue: Double
    let step: Double
    let decrementAccessibilityLabel: String
    let incrementAccessibilityLabel: String
    let accessibilityLabel: String

    var id: String { role.rawValue }
}

struct DashboardCardSetpointFeature: Equatable, Sendable {
    let values: [DashboardCardSetpointValue]
    let action: DashboardCardSetpointAction
}

enum DashboardCardCommandAction: String, Equatable, Sendable {
    case openCover
    case stopCover
    case closeCover
    case lock
    case unlock
}

struct DashboardCardCommand: Equatable, Identifiable, Sendable {
    let action: DashboardCardCommandAction
    let title: String
    let systemImage: String
    let isDisabled: Bool

    var id: String { action.rawValue }
}

struct DashboardCardCommandGroupFeature: Equatable, Sendable {
    let commands: [DashboardCardCommand]
}

struct DashboardCardOption: Equatable, Identifiable, Sendable {
    let value: String
    let displayValue: String
    let isSelected: Bool

    var id: String { value }
}

struct DashboardCardOptionsFeature: Equatable, Sendable {
    let selectedValue: String
    let selectedDisplayValue: String
    let options: [DashboardCardOption]
}

struct DashboardCardGaugeFeature: Equatable, Sendable {
    let presentation: GaugePresentation
}

enum DashboardCardFeatureProvider {
    static func features(
        for entityBox: HAEntityState,
        presentation: DashboardEntityPresentation
    ) -> [DashboardCardFeature] {
        switch presentation.capability.domain {
        case .light:
            guard let light = entityBox.lightEntity, light.supportsBrightness else { return [] }
            return [lightBrightnessFeature(light, entityBox: entityBox)]
        case .fan:
            guard let fan = entityBox.fanEntity, fan.supportsPercentageControl else { return [] }
            return [fanSpeedFeature(fan, entityBox: entityBox)]
        case .climate:
            guard let climate = entityBox.climateEntity else { return [] }
            return climateSetpointFeatures(climate, entityBox: entityBox)
        case .cover:
            guard let cover = entityBox.coverEntity else { return [] }
            return coverFeatures(cover, entityBox: entityBox)
        case .lock:
            return lockFeatures(entityBox.homeEntity)
        case .select:
            guard let select = entityBox.selectEntity else { return [] }
            return selectOptionsFeatures(select, entityBox: entityBox)
        case .sensor:
            guard let sensor = entityBox.sensorEntity else { return [] }
            return sensorGaugeFeatures(sensor)
        default:
            return []
        }
    }

    private static func lightBrightnessFeature(
        _ light: LightEntity,
        entityBox: HAEntityState
    ) -> DashboardCardFeature {
        let brightnessPercentage = effectiveBrightnessPercentage(for: light, entityBox: entityBox)

        return DashboardCardFeature(
            key: .lightBrightness,
            title: "Brightness",
            content: .level(
                DashboardCardLevelFeature(
                    value: brightnessPercentage,
                    range: 0...100,
                    step: 5,
                    valueLabel: "\(Int(brightnessPercentage.rounded()))%",
                    accessibilityLabel: "Brightness",
                    action: .setLightBrightness
                )
            )
        )
    }

    private static func fanSpeedFeature(
        _ fan: FanEntity,
        entityBox: HAEntityState
    ) -> DashboardCardFeature {
        let percentage = effectiveFanPercentage(for: fan, entityBox: entityBox)

        return DashboardCardFeature(
            key: .fanSpeed,
            title: "Speed",
            content: .level(
                DashboardCardLevelFeature(
                    value: percentage,
                    range: 0...100,
                    step: fan.resolvedPercentageStep,
                    valueLabel: "\(Int(percentage.rounded()))%",
                    accessibilityLabel: "Fan speed",
                    action: .setFanPercentage
                )
            )
        )
    }

    private static func climateSetpointFeatures(
        _ climate: ClimateEntity,
        entityBox: HAEntityState
    ) -> [DashboardCardFeature] {
        if climate.usesTemperatureRange {
            let lowTemperature = effectiveTargetLowTemperature(for: climate, entityBox: entityBox)
            let highTemperature = effectiveTargetHighTemperature(
                for: climate,
                entityBox: entityBox,
                lowTemperature: lowTemperature
            )

            return [
                DashboardCardFeature(
                    key: .climateSetpoint,
                    title: "Setpoint",
                    content: .setpoint(
                        DashboardCardSetpointFeature(
                            values: [
                                DashboardCardSetpointValue(
                                    role: .low,
                                    value: lowTemperature,
                                    displayValue: climateSetpointText(lowTemperature),
                                    formattedValue: climate.formatTemperature(lowTemperature),
                                    minimumValue: climate.resolvedMinimumTemperature,
                                    maximumValue: highTemperature,
                                    step: climate.resolvedTemperatureStep,
                                    decrementAccessibilityLabel: "Decrease heat setpoint",
                                    incrementAccessibilityLabel: "Increase heat setpoint",
                                    accessibilityLabel: "Heat setpoint"
                                ),
                                DashboardCardSetpointValue(
                                    role: .high,
                                    value: highTemperature,
                                    displayValue: climateSetpointText(highTemperature),
                                    formattedValue: climate.formatTemperature(highTemperature),
                                    minimumValue: lowTemperature,
                                    maximumValue: climate.resolvedMaximumTemperature,
                                    step: climate.resolvedTemperatureStep,
                                    decrementAccessibilityLabel: "Decrease cool setpoint",
                                    incrementAccessibilityLabel: "Increase cool setpoint",
                                    accessibilityLabel: "Cool setpoint"
                                )
                            ],
                            action: .setClimateTemperatureRange
                        )
                    )
                )
            ]
        }

        guard climate.targetTemperature != nil else {
            return []
        }

        let targetTemperature = effectiveTargetTemperature(for: climate, entityBox: entityBox)

        return [
            DashboardCardFeature(
                key: .climateSetpoint,
                title: "Setpoint",
                content: .setpoint(
                    DashboardCardSetpointFeature(
                        values: [
                            DashboardCardSetpointValue(
                                role: .target,
                                value: targetTemperature,
                                displayValue: climateSetpointText(targetTemperature),
                                formattedValue: climate.formatTemperature(targetTemperature),
                                minimumValue: climate.resolvedMinimumTemperature,
                                maximumValue: climate.resolvedMaximumTemperature,
                                step: climate.resolvedTemperatureStep,
                                decrementAccessibilityLabel: "Decrease temperature",
                                incrementAccessibilityLabel: "Increase temperature",
                                accessibilityLabel: "Target temperature"
                            )
                        ],
                        action: .setClimateTemperature
                    )
                )
            )
        ]
    }

    private static func coverFeatures(
        _ cover: CoverEntity,
        entityBox: HAEntityState
    ) -> [DashboardCardFeature] {
        var features: [DashboardCardFeature] = [
            DashboardCardFeature(
                key: .coverControls,
                title: "Cover",
                content: .commandGroup(
                    DashboardCardCommandGroupFeature(
                        commands: [
                            DashboardCardCommand(
                                action: .openCover,
                                title: "Open",
                                systemImage: "arrow.up",
                                isDisabled: cover.state == "open"
                            ),
                            DashboardCardCommand(
                                action: .stopCover,
                                title: "Stop",
                                systemImage: "stop.fill",
                                isDisabled: false
                            ),
                            DashboardCardCommand(
                                action: .closeCover,
                                title: "Close",
                                systemImage: "arrow.down",
                                isDisabled: cover.state == "closed"
                            )
                        ]
                    )
                )
            )
        ]

        if let positionPercentage = effectiveCoverPositionPercentage(for: cover, entityBox: entityBox) {
            features.append(
                DashboardCardFeature(
                    key: .coverPosition,
                    title: "Position",
                    content: .level(
                        DashboardCardLevelFeature(
                            value: positionPercentage,
                            range: 0...100,
                            step: 1,
                            valueLabel: "\(Int(positionPercentage.rounded()))%",
                            accessibilityLabel: "Cover position",
                            action: .setCoverPosition
                        )
                    )
                )
            )
        }

        return features
    }

    private static func lockFeatures(_ entity: HomeEntity) -> [DashboardCardFeature] {
        let isLocked = entity.state == "locked"
        let isLocking = entity.state == "locking"
        let isUnlocked = entity.state == "unlocked"
        let isUnlocking = entity.state == "unlocking"

        return [
            DashboardCardFeature(
                key: .lockControls,
                title: "Lock",
                content: .commandGroup(
                    DashboardCardCommandGroupFeature(
                        commands: [
                            DashboardCardCommand(
                                action: .lock,
                                title: "Lock",
                                systemImage: "lock.fill",
                                isDisabled: !entity.isAvailable || isLocked || isLocking
                            ),
                            DashboardCardCommand(
                                action: .unlock,
                                title: "Unlock",
                                systemImage: "lock.open.fill",
                                isDisabled: !entity.isAvailable || isUnlocked || isUnlocking
                            )
                        ]
                    )
                )
            )
        ]
    }

    private static func selectOptionsFeatures(
        _ select: SelectEntity,
        entityBox: HAEntityState
    ) -> [DashboardCardFeature] {
        guard !select.options.isEmpty else { return [] }

        let selectedValue = entityBox.pendingCommand?.expectedState ?? select.state
        return [
            DashboardCardFeature(
                key: .selectOptions,
                title: "Options",
                content: .options(
                    DashboardCardOptionsFeature(
                        selectedValue: selectedValue,
                        selectedDisplayValue: selectedValue.displayStateText,
                        options: select.options.map { option in
                            DashboardCardOption(
                                value: option,
                                displayValue: option.displayStateText,
                                isSelected: option == selectedValue
                            )
                        }
                    )
                )
            )
        ]
    }

    private static func sensorGaugeFeatures(_ sensor: SensorEntity) -> [DashboardCardFeature] {
        guard let gauge = sensor.gaugePresentation,
              gauge.isDashboardFeatureEligible else {
            return []
        }

        return [
            DashboardCardFeature(
                key: .sensorGauge,
                title: "Gauge",
                content: .gauge(DashboardCardGaugeFeature(presentation: gauge))
            )
        ]
    }

    private static func effectiveBrightnessPercentage(
        for light: LightEntity,
        entityBox: HAEntityState
    ) -> Double {
        if let pendingBrightness = entityBox.pendingCommand?.expectedAttributes["brightness"]?.doubleValue {
            return min(max((pendingBrightness / 255.0) * 100.0, 0), 100)
        }

        guard light.isOn else { return 0 }
        return Double(light.brightnessPercentage ?? 100)
    }

    private static func effectiveFanPercentage(
        for fan: FanEntity,
        entityBox: HAEntityState
    ) -> Double {
        if let pendingPercentage = entityBox.pendingCommand?.expectedAttributes["percentage"]?.doubleValue {
            return min(max(pendingPercentage, 0), 100)
        }

        guard fan.isOn else { return 0 }
        return Double(fan.percentage ?? 100)
    }

    private static func effectiveTargetTemperature(
        for climate: ClimateEntity,
        entityBox: HAEntityState
    ) -> Double {
        entityBox.pendingCommand?.expectedAttributes["temperature"]?.doubleValue
            ?? climate.targetTemperature
            ?? climate.currentTemperature
            ?? 70
    }

    private static func effectiveTargetLowTemperature(
        for climate: ClimateEntity,
        entityBox: HAEntityState
    ) -> Double {
        entityBox.pendingCommand?.expectedAttributes["target_temp_low"]?.doubleValue
            ?? climate.targetTemperatureLow
            ?? climate.targetTemperature
            ?? climate.currentTemperature
            ?? 68
    }

    private static func effectiveTargetHighTemperature(
        for climate: ClimateEntity,
        entityBox: HAEntityState,
        lowTemperature: Double
    ) -> Double {
        max(
            lowTemperature,
            entityBox.pendingCommand?.expectedAttributes["target_temp_high"]?.doubleValue
                ?? climate.targetTemperatureHigh
                ?? climate.targetTemperature
                ?? climate.currentTemperature
                ?? 76
        )
    }

    private static func effectiveCoverPositionPercentage(
        for cover: CoverEntity,
        entityBox: HAEntityState
    ) -> Double? {
        if let pendingPosition = entityBox.pendingCommand?.expectedAttributes["current_position"]?.doubleValue {
            return min(max(pendingPosition, 0), 100)
        }

        return cover.positionPercentage.map(Double.init)
    }

    private static func climateSetpointText(_ temperature: Double) -> String {
        climateSetpointFormatter.string(from: NSNumber(value: temperature)) ?? "\(temperature)"
    }

    private static let climateSetpointFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

enum DashboardCardFeatureLayout: Equatable, Sendable {
    case hidden
    case trailing
    case stacked
}

extension DashboardCardSize {
    var featureLayout: DashboardCardFeatureLayout {
        switch self {
        case .mini, .compact:
            .hidden
        case .row:
            .trailing
        case .square, .wide, .large:
            .stacked
        }
    }

    var maximumVisibleFeatureCount: Int {
        switch self {
        case .mini, .compact:
            0
        case .row, .square, .wide:
            1
        case .large:
            3
        }
    }

    func visibleFeatures(from features: [DashboardCardFeature]) -> [DashboardCardFeature] {
        guard featureLayout != .hidden else { return [] }
        return Array(features.prefix(maximumVisibleFeatureCount))
    }

    func visibleFeatures(
        from features: [DashboardCardFeature],
        visibility: DashboardCardFeatureVisibility
    ) -> [DashboardCardFeature] {
        guard visibility != .hidden else { return [] }
        return visibleFeatures(from: features)
    }

    static func defaultGeneratedSize(entityBox: HAEntityState) -> DashboardCardSize {
        guard entityBox.domain != .camera else {
            return .square
        }

        if defaultsToDashboardHistory(entityBox) {
            return .square
        }

        if defaultsToVisibleCardFeature(entityBox) {
            return .square
        }

        return .compact
    }

    static func defaultGeneratedFeatureVisibility(
        entityBox: HAEntityState,
        size: DashboardCardSize
    ) -> DashboardCardFeatureVisibility {
        guard DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: size),
              hasVisibleReadOnlySensorGauge(entityBox: entityBox, size: size) else {
            return .automatic
        }

        return .hidden
    }

    private static func defaultsToDashboardHistory(_ entityBox: HAEntityState) -> Bool {
        guard DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: .square),
              entityBox.sensorEntity?.deviceClass != "battery" else {
            return false
        }

        return true
    }

    private static func defaultsToVisibleCardFeature(_ entityBox: HAEntityState) -> Bool {
        switch entityBox.domain {
        case .light, .fan, .climate, .cover, .lock:
            break
        default:
            return false
        }

        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let features = DashboardCardFeatureProvider.features(
            for: entityBox,
            presentation: presentation
        )
        return !DashboardCardSize.square.visibleFeatures(from: features).isEmpty
    }

    private static func hasVisibleReadOnlySensorGauge(
        entityBox: HAEntityState,
        size: DashboardCardSize
    ) -> Bool {
        guard entityBox.domain == .sensor else {
            return false
        }

        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let features = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation)
        return size.visibleFeatures(from: features).contains { $0.key == .sensorGauge }
    }
}
