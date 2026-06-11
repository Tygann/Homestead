import Foundation

struct SelectEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let options: [String]

    var id: String { entityID }
}
