import Foundation

struct SensorEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let value: String
    let unit: String?
    let deviceClass: String?
    let iconName: String
    let lastUpdated: Date?

    var id: String { entityID }

    var isAvailable: Bool {
        !["unknown", "unavailable"].contains(value)
    }

    var formattedValue: String {
        guard let unitText, !unitText.isEmpty else { return valueText }

        let separator = unitNeedsLeadingSpace(unitText) ? " " : ""
        return "\(valueText)\(separator)\(unitText)"
    }

    var valueText: String {
        switch value {
        case "unknown":
            return "Unknown"
        case "unavailable":
            return "Unavailable"
        default:
            break
        }

        return formattedNumber ?? value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var unitText: String? {
        guard isAvailable else { return nil }
        return displayUnit
    }

    var formattedDeviceClass: String? {
        guard let deviceClass, !deviceClass.isEmpty else { return nil }
        return deviceClass.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var displayKind: SensorDisplayKind {
        SensorDisplayKind(deviceClass: deviceClass)
    }

    var displaySubtitle: String {
        guard isAvailable else { return "Sensor unavailable" }
        return formattedDeviceClass ?? "Sensor"
    }

    private var formattedNumber: String? {
        guard let number = Double(value) else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0

        return formatter.string(from: NSNumber(value: number))
    }

    private var displayUnit: String? {
        switch (deviceClass, unit) {
        case ("temperature", "F"):
            "°F"
        case ("temperature", "C"):
            "°C"
        default:
            unit
        }
    }

    private var maximumFractionDigits: Int {
        switch deviceClass {
        case "humidity", "battery":
            0
        case "temperature":
            1
        case "energy", "power":
            2
        case "illuminance", "signal_strength":
            0
        default:
            1
        }
    }

    private func unitNeedsLeadingSpace(_ unit: String) -> Bool {
        !unit.hasPrefix("°") && unit != "%"
    }
}

nonisolated enum SensorDisplayKind: Equatable, Sendable {
    case temperature
    case humidity
    case battery
    case energy
    case power
    case illuminance
    case pressure
    case signal
    case voltage
    case current
    case water
    case gas
    case problem
    case generic

    init(deviceClass: String?) {
        switch deviceClass {
        case "temperature":
            self = .temperature
        case "humidity":
            self = .humidity
        case "battery":
            self = .battery
        case "energy":
            self = .energy
        case "power":
            self = .power
        case "illuminance":
            self = .illuminance
        case "pressure":
            self = .pressure
        case "signal_strength":
            self = .signal
        case "voltage":
            self = .voltage
        case "current":
            self = .current
        case "water":
            self = .water
        case "gas":
            self = .gas
        case "problem":
            self = .problem
        default:
            self = .generic
        }
    }
}
