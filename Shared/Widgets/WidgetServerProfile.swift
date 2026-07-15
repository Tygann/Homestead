import Foundation

nonisolated struct WidgetServerProfile: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let baseURLString: String
}

nonisolated struct HomesteadEntityReference: Codable, Equatable, Hashable, Sendable {
    static let separator = "|"

    let profileID: UUID
    let entityID: String

    var encodedID: String {
        "\(profileID.uuidString.lowercased())\(Self.separator)\(entityID)"
    }

    init(profileID: UUID, entityID: String) {
        self.profileID = profileID
        self.entityID = entityID
    }

    init?(encodedID: String, fallbackProfileID: UUID? = nil) {
        let components = encodedID.split(separator: Character(Self.separator), maxSplits: 1).map(String.init)
        if components.count == 2,
           let profileID = UUID(uuidString: components[0]),
           !components[1].isEmpty {
            self.init(profileID: profileID, entityID: components[1])
            return
        }

        guard let fallbackProfileID, !encodedID.isEmpty else { return nil }
        self.init(profileID: fallbackProfileID, entityID: encodedID)
    }
}
