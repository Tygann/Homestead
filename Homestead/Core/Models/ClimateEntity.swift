import Foundation

struct ClimateEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let currentTemperature: Double?
    let targetTemperature: Double?

    var id: String { entityID }
}
