import Foundation

struct LightEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let brightness: Int?
    let iconName: String
    let lastUpdated: Date?

    var id: String { entityID }
}
