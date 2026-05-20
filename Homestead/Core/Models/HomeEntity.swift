import Foundation

struct HomeEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let domain: EntityDomain
    let displayName: String
    let state: String
    let iconName: String
    let isAvailable: Bool
    let lastUpdated: Date?

    var id: String { entityID }
}
