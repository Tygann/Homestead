import Foundation

struct SensorEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let value: String
    let unit: String?
    let iconName: String
    let lastUpdated: Date?

    var id: String { entityID }

    var formattedValue: String {
        guard let unit, !unit.isEmpty else { return value }
        return "\(value) \(unit)"
    }
}
