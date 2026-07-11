import Foundation

nonisolated enum GaugePresentationStatus: String, CaseIterable, Codable, Equatable, Sendable {
    case nominal
    case low
    case high
    case warning
    case critical
}

nonisolated enum GaugeRangeSource: String, Equatable, Sendable {
    case userConfigured
    case homeAssistant
    case deviceClass
    case percentageUnit
    case valueSuggested
}

struct GaugePresentationSection: Equatable, Sendable {
    let range: ClosedRange<Double>
    let status: GaugePresentationStatus
}

nonisolated struct GaugeZoneConfiguration: Codable, Equatable, Sendable {
    static let maximumZoneCount = 5

    var lowerBound: Double
    var upperBound: Double
    var boundaries: [Double]
    var statuses: [GaugePresentationStatus]

    var isValid: Bool {
        guard lowerBound < upperBound,
              statuses.count == boundaries.count + 1 else { return false }
        let values = [lowerBound] + boundaries + [upperBound]
        return zip(values, values.dropFirst()).allSatisfy { $0.0 < $0.1 }
    }

    func sections() -> [GaugePresentationSection]? {
        guard isValid else { return nil }
        let upperBounds = boundaries + [upperBound]
        var lower = lowerBound
        return zip(upperBounds, statuses).map { upper, status in
            defer { lower = upper }
            return GaugePresentationSection(range: lower...upper, status: status)
        }
    }

    func range(forZoneAt index: Int) -> ClosedRange<Double>? {
        guard statuses.indices.contains(index) else { return nil }
        let lower = index == 0 ? lowerBound : boundaries[index - 1]
        let upper = index == boundaries.count ? upperBound : boundaries[index]
        guard lower < upper else { return nil }
        return lower...upper
    }

    mutating func addZone() {
        guard isValid, statuses.count < Self.maximumZoneCount else { return }
        let widestIndex = statuses.indices.max { lhs, rhs in
            let lhsRange = range(forZoneAt: lhs)
            let rhsRange = range(forZoneAt: rhs)
            return (lhsRange?.upperBound ?? 0) - (lhsRange?.lowerBound ?? 0)
                < (rhsRange?.upperBound ?? 0) - (rhsRange?.lowerBound ?? 0)
        }
        guard let widestIndex, let range = range(forZoneAt: widestIndex) else { return }
        boundaries.insert((range.lowerBound + range.upperBound) / 2, at: widestIndex)
        statuses.insert(statuses[widestIndex], at: widestIndex + 1)
    }

    mutating func removeZone(at index: Int) {
        guard statuses.count > 1, statuses.indices.contains(index) else { return }
        if index == 0 {
            boundaries.removeFirst()
            statuses.removeFirst()
        } else {
            boundaries.remove(at: index - 1)
            statuses.remove(at: index)
        }
    }

    static func defaults(for presentation: GaugePresentation) -> Self {
        GaugeZoneConfiguration(
            lowerBound: presentation.range.lowerBound,
            upperBound: presentation.range.upperBound,
            boundaries: presentation.sections.dropLast().map(\.range.upperBound),
            statuses: presentation.sections.map(\.status)
        )
    }
}

struct GaugePresentation: Equatable, Sendable {
    let value: Double
    let range: ClosedRange<Double>
    let valueText: String
    let unitText: String?
    let status: GaugePresentationStatus
    let statusDisplayText: String
    let rangeSource: GaugeRangeSource
    let isDashboardFeatureEligible: Bool
    let sections: [GaugePresentationSection]
    let accessibilityLabel: String
    let accessibilityValue: String

    private init(
        value: Double,
        range: ClosedRange<Double>,
        valueText: String,
        unitText: String?,
        status: GaugePresentationStatus,
        statusDisplayText: String,
        rangeSource: GaugeRangeSource,
        isDashboardFeatureEligible: Bool,
        sections: [GaugePresentationSection],
        accessibilityLabel: String,
        accessibilityValue: String
    ) {
        self.value = value
        self.range = range
        self.valueText = valueText
        self.unitText = unitText
        self.status = status
        self.statusDisplayText = statusDisplayText
        self.rangeSource = rangeSource
        self.isDashboardFeatureEligible = isDashboardFeatureEligible
        self.sections = sections
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    var normalizedValue: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return min(max(normalized, 0), 1)
    }

    func applying(zoneConfiguration: GaugeZoneConfiguration?) -> Self {
        guard let zoneConfiguration,
              let resolvedSections = zoneConfiguration.sections() else { return self }
        let resolvedStatus = resolvedSections.first(where: { $0.range.contains(value) })?.status
            ?? (value < zoneConfiguration.lowerBound ? resolvedSections[0].status : resolvedSections[resolvedSections.count - 1].status)

        return GaugePresentation(
            value: value,
            range: zoneConfiguration.lowerBound...zoneConfiguration.upperBound,
            valueText: valueText,
            unitText: unitText,
            status: resolvedStatus,
            statusDisplayText: Self.genericStatusDisplayText(for: resolvedStatus),
            rangeSource: .userConfigured,
            isDashboardFeatureEligible: isDashboardFeatureEligible,
            sections: resolvedSections,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: Self.accessibilityValue(valueText: valueText, status: resolvedStatus)
        )
    }

    init?(sensor: SensorEntity) {
        guard sensor.isAvailable,
              let numericValue = sensor.numericValue,
              let rangeResolution = GaugePresentation.resolvedRange(for: sensor) else {
            return nil
        }

        value = numericValue
        range = rangeResolution.range
        valueText = sensor.valueText
        unitText = sensor.unitText
        rangeSource = rangeResolution.source
        status = GaugePresentation.status(
            for: numericValue,
            sensor: sensor,
            range: rangeResolution.range
        )
        statusDisplayText = GaugePresentation.statusDisplayText(for: status, sensor: sensor)
        sections = GaugePresentation.sections(
            for: sensor,
            range: rangeResolution.range
        )
        isDashboardFeatureEligible = GaugePresentation.isDashboardFeatureEligible(
            sensor: sensor,
            rangeSource: rangeResolution.source
        )
        accessibilityLabel = "\(sensor.displayName) gauge"
        accessibilityValue = GaugePresentation.accessibilityValue(
            valueText: sensor.formattedValue,
            status: status
        )
    }

}

private struct GaugeRangeResolution: Equatable, Sendable {
    let range: ClosedRange<Double>
    let source: GaugeRangeSource
}

private extension GaugePresentation {
    static func isDashboardFeatureEligible(
        sensor: SensorEntity,
        rangeSource: GaugeRangeSource
    ) -> Bool {
        switch rangeSource {
        case .userConfigured, .homeAssistant, .percentageUnit, .valueSuggested:
            return true
        case .deviceClass:
            switch sensor.displayKind {
            case .battery, .humidity, .moisture, .airQuality, .carbonDioxide, .particulateMatter, .signal, .volatileOrganicCompounds:
                return true
            case .water:
                return sensor.unitText == "%" || sensor.displayName.localizedCaseInsensitiveContains("level")
            case .temperature:
                return true
            case .area, .carbonMonoxide, .conductivity, .data, .date, .distance, .duration, .enum, .energy, .energyDistance, .energyStorage, .frequency, .gas, .generic, .illuminance, .irradiance, .monetary, .pH, .power, .powerFactor, .precipitation, .pressure, .problem, .reactiveEnergy, .reactivePower, .soundPressure, .speed, .temperatureDelta, .uptime, .voltage, .current, .volume, .volumeFlowRate, .weight, .windDirection:
                return false
            }
        }
    }

    static func resolvedRange(for sensor: SensorEntity) -> GaugeRangeResolution? {
        if let metadataRange = metadataRange(for: sensor) {
            return GaugeRangeResolution(range: metadataRange, source: .homeAssistant)
        }

        switch sensor.displayKind {
        case .battery, .humidity, .moisture:
            return GaugeRangeResolution(range: 0...100, source: .deviceClass)
        case .temperature:
            return temperatureRange(for: sensor).map {
                GaugeRangeResolution(range: $0, source: .deviceClass)
            }
        case .airQuality:
            return GaugeRangeResolution(range: 0...500, source: .deviceClass)
        case .carbonDioxide:
            return GaugeRangeResolution(range: 400...2000, source: .deviceClass)
        case .particulateMatter, .volatileOrganicCompounds:
            return GaugeRangeResolution(range: 0...250, source: .deviceClass)
        case .signal:
            return signalRange(for: sensor)
        case .water:
            if sensor.unitText == "%" || sensor.displayName.localizedCaseInsensitiveContains("level") {
                return GaugeRangeResolution(range: 0...100, source: .deviceClass)
            }
            return nil
        case .area, .carbonMonoxide, .conductivity, .data, .date, .distance, .duration, .enum, .energy, .energyDistance, .energyStorage, .frequency, .gas, .generic, .illuminance, .irradiance, .monetary, .pH, .power, .powerFactor, .precipitation, .pressure, .problem, .reactiveEnergy, .reactivePower, .soundPressure, .speed, .temperatureDelta, .uptime, .voltage, .current, .volume, .volumeFlowRate, .weight, .windDirection:
            if sensor.unitText == "%" {
                return GaugeRangeResolution(range: 0...100, source: .percentageUnit)
            }
            guard sensor.stateClass != .total, sensor.stateClass != .totalIncreasing else { return nil }
            return suggestedRange(around: sensor.numericValue).map {
                GaugeRangeResolution(range: $0, source: .valueSuggested)
            }
        }
    }

    static func suggestedRange(around value: Double?) -> ClosedRange<Double>? {
        guard let value, value.isFinite else { return nil }
        if value == 0 { return 0...100 }

        let magnitude = pow(10, floor(log10(abs(value))))
        let padding = max(magnitude, abs(value) * 0.2)
        let lower = value >= 0 ? 0 : floor((value - padding) / magnitude) * magnitude
        let upper = ceil((value + padding) / magnitude) * magnitude
        guard lower < upper else { return nil }
        return lower...upper
    }

    static func metadataRange(for sensor: SensorEntity) -> ClosedRange<Double>? {
        guard let minimumValue = sensor.suggestedMinimumValue,
              let maximumValue = sensor.suggestedMaximumValue,
              minimumValue < maximumValue else {
            return nil
        }

        return minimumValue...maximumValue
    }

    static func temperatureRange(for sensor: SensorEntity) -> ClosedRange<Double>? {
        switch sensor.unitText {
        case "°F":
            return 0...120
        case "°C":
            return -20...50
        default:
            return sensor.deviceClass == "temperature" ? -20...50 : nil
        }
    }

    static func signalRange(for sensor: SensorEntity) -> GaugeRangeResolution {
        if sensor.unitText == "%" {
            return GaugeRangeResolution(range: 0...100, source: .deviceClass)
        }

        return GaugeRangeResolution(range: -100 ... -30, source: .deviceClass)
    }

    static func status(
        for value: Double,
        sensor: SensorEntity,
        range: ClosedRange<Double>
    ) -> GaugePresentationStatus {
        switch sensor.displayKind {
        case .battery:
            return lowIsBadStatus(value, warning: 20, critical: 10)
        case .humidity, .moisture:
            if value < 20 || value > 70 { return .critical }
            if value < 30 || value > 60 { return .warning }
            return .nominal
        case .temperature:
            return temperatureStatus(value, unitText: sensor.unitText)
        case .airQuality:
            return highIsBadStatus(value, elevated: 50, warning: 100, critical: 150)
        case .carbonDioxide:
            return highIsBadStatus(value, elevated: 800, warning: 1000, critical: 1500)
        case .particulateMatter, .volatileOrganicCompounds:
            return highIsBadStatus(value, elevated: 50, warning: 100, critical: 150)
        case .signal:
            if sensor.unitText == "%" {
                return lowIsBadStatus(value, warning: 35, critical: 20)
            }
            return lowIsBadStatus(value, warning: -80, critical: -90)
        case .water:
            return sensor.unitText == "%" ? lowIsBadStatus(value, warning: 25, critical: 10) : .nominal
        case .area, .carbonMonoxide, .conductivity, .data, .date, .distance, .duration, .enum, .energy, .energyDistance, .energyStorage, .frequency, .gas, .generic, .illuminance, .irradiance, .monetary, .pH, .power, .powerFactor, .precipitation, .pressure, .problem, .reactiveEnergy, .reactivePower, .soundPressure, .speed, .temperatureDelta, .uptime, .voltage, .current, .volume, .volumeFlowRate, .weight, .windDirection:
            return value < range.lowerBound || value > range.upperBound ? .warning : .nominal
        }
    }

    static func sections(
        for sensor: SensorEntity,
        range: ClosedRange<Double>
    ) -> [GaugePresentationSection] {
        switch sensor.displayKind {
        case .battery:
            return clampedSections(
                [
                    GaugePresentationSection(range: range.lowerBound...10, status: .critical),
                    GaugePresentationSection(range: 10...20, status: .warning),
                    GaugePresentationSection(range: 20...range.upperBound, status: .nominal)
                ],
                to: range
            )
        case .humidity, .moisture:
            return clampedSections(
                [
                    GaugePresentationSection(range: range.lowerBound...20, status: .critical),
                    GaugePresentationSection(range: 20...30, status: .warning),
                    GaugePresentationSection(range: 30...60, status: .nominal),
                    GaugePresentationSection(range: 60...70, status: .warning),
                    GaugePresentationSection(range: 70...range.upperBound, status: .critical)
                ],
                to: range
            )
        case .temperature:
            return temperatureSections(unitText: sensor.unitText, range: range)
        case .airQuality:
            return highBadSections(range: range, elevated: 50, warning: 100, critical: 150)
        case .carbonDioxide:
            return highBadSections(range: range, elevated: 800, warning: 1000, critical: 1500)
        case .particulateMatter, .volatileOrganicCompounds:
            return highBadSections(range: range, elevated: 50, warning: 100, critical: 150)
        case .signal:
            if sensor.unitText == "%" {
                return lowBadSections(range: range, warning: 35, critical: 20)
            }
            return lowBadSections(range: range, warning: -80, critical: -90)
        case .water:
            if sensor.unitText == "%" {
                return lowBadSections(range: range, warning: 25, critical: 10)
            }
            return [GaugePresentationSection(range: range, status: .nominal)]
        case .area, .carbonMonoxide, .conductivity, .data, .date, .distance, .duration, .enum, .energy, .energyDistance, .energyStorage, .frequency, .gas, .generic, .illuminance, .irradiance, .monetary, .pH, .power, .powerFactor, .precipitation, .pressure, .problem, .reactiveEnergy, .reactivePower, .soundPressure, .speed, .temperatureDelta, .uptime, .voltage, .current, .volume, .volumeFlowRate, .weight, .windDirection:
            return [GaugePresentationSection(range: range, status: .nominal)]
        }
    }

    static func statusDisplayText(
        for status: GaugePresentationStatus,
        sensor: SensorEntity
    ) -> String {
        switch (sensor.displayKind, status) {
        case (.humidity, .nominal), (.moisture, .nominal), (.temperature, .nominal):
            return "Comfortable"
        case (_, .nominal):
            return "Normal"
        case (_, .low):
            return "Low"
        case (_, .high):
            return "High"
        case (_, .warning):
            return "Warning"
        case (_, .critical):
            return "Critical"
        }
    }

    static func genericStatusDisplayText(for status: GaugePresentationStatus) -> String {
        switch status {
        case .nominal: "Normal"
        case .low: "Low"
        case .high: "High"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }

    static func lowBadSections(
        range: ClosedRange<Double>,
        warning: Double,
        critical: Double
    ) -> [GaugePresentationSection] {
        clampedSections(
            [
                GaugePresentationSection(range: range.lowerBound...critical, status: .critical),
                GaugePresentationSection(range: critical...warning, status: .warning),
                GaugePresentationSection(range: warning...range.upperBound, status: .nominal)
            ],
            to: range
        )
    }

    static func highBadSections(
        range: ClosedRange<Double>,
        elevated: Double,
        warning: Double,
        critical: Double
    ) -> [GaugePresentationSection] {
        clampedSections(
            [
                GaugePresentationSection(range: range.lowerBound...elevated, status: .nominal),
                GaugePresentationSection(range: elevated...warning, status: .high),
                GaugePresentationSection(range: warning...critical, status: .warning),
                GaugePresentationSection(range: critical...range.upperBound, status: .critical)
            ],
            to: range
        )
    }

    static func temperatureSections(
        unitText: String?,
        range: ClosedRange<Double>
    ) -> [GaugePresentationSection] {
        if unitText == "°C" {
            return clampedSections(
                [
                    GaugePresentationSection(range: range.lowerBound...4.5, status: .warning),
                    GaugePresentationSection(range: 4.5...15.5, status: .low),
                    GaugePresentationSection(range: 15.5...26.5, status: .nominal),
                    GaugePresentationSection(range: 26.5...37.5, status: .high),
                    GaugePresentationSection(range: 37.5...range.upperBound, status: .warning)
                ],
                to: range
            )
        }

        return clampedSections(
            [
                GaugePresentationSection(range: range.lowerBound...40, status: .warning),
                GaugePresentationSection(range: 40...60, status: .low),
                GaugePresentationSection(range: 60...80, status: .nominal),
                GaugePresentationSection(range: 80...100, status: .high),
                GaugePresentationSection(range: 100...range.upperBound, status: .warning)
            ],
            to: range
        )
    }

    static func clampedSections(
        _ sections: [GaugePresentationSection],
        to range: ClosedRange<Double>
    ) -> [GaugePresentationSection] {
        sections.compactMap { section in
            let lowerBound = max(section.range.lowerBound, range.lowerBound)
            let upperBound = min(section.range.upperBound, range.upperBound)
            guard lowerBound < upperBound else { return nil }
            return GaugePresentationSection(range: lowerBound...upperBound, status: section.status)
        }
    }

    static func lowIsBadStatus(
        _ value: Double,
        warning: Double,
        critical: Double
    ) -> GaugePresentationStatus {
        if value <= critical { return .critical }
        if value <= warning { return .warning }
        return .nominal
    }

    static func highIsBadStatus(
        _ value: Double,
        elevated: Double,
        warning: Double,
        critical: Double
    ) -> GaugePresentationStatus {
        if value >= critical { return .critical }
        if value >= warning { return .warning }
        if value >= elevated { return .high }
        return .nominal
    }

    static func temperatureStatus(
        _ value: Double,
        unitText: String?
    ) -> GaugePresentationStatus {
        let fahrenheitValue: Double
        if unitText == "°C" {
            fahrenheitValue = (value * 9 / 5) + 32
        } else {
            fahrenheitValue = value
        }

        if fahrenheitValue <= 40 || fahrenheitValue >= 100 { return .warning }
        if fahrenheitValue < 60 { return .low }
        if fahrenheitValue > 80 { return .high }
        return .nominal
    }

    static func accessibilityValue(
        valueText: String,
        status: GaugePresentationStatus
    ) -> String {
        switch status {
        case .nominal:
            valueText
        case .low:
            "\(valueText), low"
        case .high:
            "\(valueText), high"
        case .warning:
            "\(valueText), warning"
        case .critical:
            "\(valueText), critical"
        }
    }
}
