import Foundation

struct HAEntityDTO: Decodable, Equatable, Identifiable, Sendable {
    let entityID: String
    let state: String
    let attributes: [String: JSONValue]
    let lastChanged: Date?
    let lastUpdated: Date?

    var id: String { entityID }

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
    }

    init(
        entityID: String,
        state: String,
        attributes: [String: JSONValue] = [:],
        lastChanged: Date? = nil,
        lastUpdated: Date? = nil
    ) {
        self.entityID = entityID
        self.state = state
        self.attributes = attributes
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityID = try container.decode(String.self, forKey: .entityID)
        state = try container.decode(String.self, forKey: .state)
        attributes = try container.decodeIfPresent([String: JSONValue].self, forKey: .attributes) ?? [:]
        lastChanged = HADateParser.date(from: try container.decodeIfPresent(String.self, forKey: .lastChanged))
        lastUpdated = HADateParser.date(from: try container.decodeIfPresent(String.self, forKey: .lastUpdated))
    }
}
