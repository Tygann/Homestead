import Foundation

nonisolated enum GaugePresentationStatus: String, Equatable, Sendable {
    case nominal
    case low
    case high
    case warning
    case critical
}

nonisolated enum GaugeRangeSource: String, Equatable, Sendable {
    case homeAssistant
    case deviceClass
    case percentageUnit
}

struct GaugePresentation: Equatable, Sendable {
    let value: Double
    let range: ClosedRange<Double>
    let valueText: String
    let unitText: String?
    let status: GaugePresentationStatus
    let rangeSource: GaugeRangeSource
    let isDashboardFeatureEligible: Bool
    let accessibilityLabel: String
    let accessibilityValue: String

    var normalizedValue: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return min(max(normalized, 0), 1)
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
        case .homeAssistant, .percentageUnit:
            return true
        case .deviceClass:
            switch sensor.displayKind {
            case .battery, .humidity, .moisture, .airQuality, .carbonDioxide, .particulateMatter, .signal, .volatileOrganicCompounds:
                return true
            case .water:
                return sensor.unitText == "%" || sensor.displayName.localizedCaseInsensitiveContains("level")
            case .temperature, .area, .carbonMonoxide, .conductivity, .data, .date, .distance, .duration, .enum, .energy, .energyDistance, .energyStorage, .frequency, .gas, .generic, .illuminance, .irradiance, .monetary, .pH, .power, .powerFactor, .precipitation, .pressure, .problem, .reactiveEnergy, .reactivePower, .soundPressure, .speed, .temperatureDelta, .uptime, .voltage, .current, .volume, .volumeFlowRate, .weight, .windDirection:
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
            return nil
        }
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
            if value < 25 || value > 70 { return .warning }
            if value < 30 { return .low }
            if value > 60 { return .high }
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
