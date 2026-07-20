import Foundation

nonisolated enum NumberEntityDisplayMode: String, Equatable, Sendable {
    case automatic = "auto"
    case box
    case slider

    init(homeAssistantValue: String?) {
        self = homeAssistantValue.flatMap(Self.init(rawValue:)) ?? .automatic
    }
}

nonisolated struct NumberEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let value: Double?
    let minimumValue: Double?
    let maximumValue: Double?
    let step: Double
    let unit: String?
    let displayMode: NumberEntityDisplayMode

    var id: String { entityID }

    var valueRange: ClosedRange<Double> {
        let fallbackValue = value ?? 0
        let minimum = minimumValue ?? min(0, fallbackValue)
        let maximum = maximumValue ?? max(100, fallbackValue)
        return minimum...max(minimum, maximum)
    }
}
