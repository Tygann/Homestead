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

    var formattedValue: String {
        switch value {
        case "unknown":
            return "Unknown"
        case "unavailable":
            return "Unavailable"
        default:
            break
        }

        let formattedValue = formattedNumber ?? value
        guard let unit = displayUnit, !unit.isEmpty else { return formattedValue }

        let separator = unitNeedsLeadingSpace(unit) ? " " : ""
        return "\(formattedValue)\(separator)\(unit)"
    }

    var formattedDeviceClass: String? {
        guard let deviceClass, !deviceClass.isEmpty else { return nil }
        return deviceClass.replacingOccurrences(of: "_", with: " ").capitalized
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
        case "energy":
            2
        default:
            1
        }
    }

    private func unitNeedsLeadingSpace(_ unit: String) -> Bool {
        !unit.hasPrefix("°") && unit != "%"
    }
}
