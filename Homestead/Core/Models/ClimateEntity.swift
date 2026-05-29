import Foundation

struct ClimateEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let currentTemperature: Double?
    let targetTemperature: Double?
    let hvacModes: [String]
    let minTemperature: Double?
    let maxTemperature: Double?
    let targetTemperatureStep: Double?
    let temperatureUnit: String?
    let fanMode: String?
    let fanModes: [String]
    let presetMode: String?
    let presetModes: [String]

    var id: String { entityID }

    var isActive: Bool {
        !["off", "unavailable", "unknown"].contains(state)
    }

    var displayState: String {
        switch state {
        case "heat_cool":
            "Auto"
        case "heat":
            "Heat"
        case "cool":
            "Cool"
        case "dry":
            "Dry"
        case "fan_only":
            "Fan"
        case "off":
            "Off"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var displaySubtitle: String {
        if let targetTemperature {
            "\(displayState), set to \(formatTemperature(targetTemperature))"
        } else if let currentTemperature {
            "\(displayState), \(formatTemperature(currentTemperature)) now"
        } else {
            displayState
        }
    }

    var targetTemperatureText: String? {
        targetTemperature.map(formatTemperature)
    }

    var currentTemperatureText: String? {
        currentTemperature.map(formatTemperature)
    }

    var resolvedMinimumTemperature: Double {
        minTemperature ?? 50
    }

    var resolvedMaximumTemperature: Double {
        maxTemperature ?? 90
    }

    var resolvedTemperatureStep: Double {
        let step = targetTemperatureStep ?? 1
        return step > 0 ? step : 1
    }

    func displayName(forHVACMode mode: String) -> String {
        switch mode {
        case "heat_cool":
            "Auto"
        case "fan_only":
            "Fan"
        default:
            mode.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    func displayName(forFanMode mode: String) -> String {
        mode.replacingOccurrences(of: "_", with: " ").capitalized
    }

    func displayName(forPresetMode mode: String) -> String {
        switch mode {
        case "none":
            "None"
        case "eco":
            "Eco"
        case "away":
            "Away"
        case "home":
            "Home"
        case "sleep":
            "Sleep"
        default:
            mode.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    func iconName(forHVACMode mode: String) -> String {
        switch mode {
        case "heat":
            "flame.fill"
        case "cool":
            "snowflake"
        case "heat_cool":
            "arrow.triangle.2.circlepath"
        case "dry":
            "drop"
        case "fan_only":
            "fan"
        case "off":
            "power"
        default:
            "thermometer.medium"
        }
    }

    func formatTemperature(_ value: Double) -> String {
        let formatted = Self.temperatureFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted)\(temperatureUnit ?? "°")"
    }

    private static let temperatureFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
