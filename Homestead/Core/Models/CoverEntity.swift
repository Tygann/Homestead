import Foundation

struct CoverEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let position: Int?

    var id: String { entityID }
}
