import Foundation

nonisolated struct LightEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let brightness: Int?
    let supportsBrightness: Bool
    let lastUpdated: Date?

    var id: String { entityID }

    var brightnessPercentage: Int? {
        guard let brightness else { return nil }
        let percentage = Int((Double(brightness) / 255.0) * 100.0)
        return min(max(percentage, 1), 100)
    }
}
