import SwiftUI

enum EntitySemanticAccentColor {
    static func sensor(_ sensor: SensorEntity) -> Color {
        guard sensor.isAvailable else { return .secondary }
        guard !sensor.isAlerting else { return .red }

        switch sensor.displayKind {
        case .temperature, .temperatureDelta:
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
        case .gas, .carbonMonoxide:
            return .orange
        case .airQuality, .carbonDioxide, .particulateMatter, .volatileOrganicCompounds, .conductivity, .pH, .precipitation:
            return .mint
        case .problem:
            return .red
        case .area, .date, .distance, .duration, .enum, .monetary, .volume, .volumeFlowRate, .weight, .windDirection, .uptime, .generic:
            return .accentColor
        }
    }

    static func climate(_ climate: ClimateEntity) -> Color {
        switch climate.state {
        case "heat":
            return .orange
        case "cool":
            return .cyan
        case "off":
            return .secondary
        default:
            return .accentColor
        }
    }

    static func weather(_ weather: WeatherEntity) -> Color {
        guard weather.isAvailable else { return .secondary }

        switch weather.condition {
        case .sunny, .clearNight:
            return .orange
        case .rainy, .pouring, .lightning, .lightningRainy, .hail:
            return .blue
        case .snowy, .snowyRainy, .fog:
            return .cyan
        case .windy, .windyVariant:
            return .mint
        case .exceptional:
            return .red
        case .cloudy, .partlyCloudy, .other:
            return .accentColor
        case .unavailable, .unknown:
            return .secondary
        }
    }
}
