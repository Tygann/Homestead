import Foundation

nonisolated struct WidgetServerProfile: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let baseURLString: String
}

typealias HomesteadEntityReference = EntityPresentationReference
