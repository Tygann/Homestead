import Foundation

struct HAEventDTO: Decodable, Equatable, Sendable {
    let eventType: String
    let data: JSONValue
    let origin: String?
    let timeFired: Date?
    let context: HAContextDTO?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case data
        case origin
        case timeFired = "time_fired"
        case context
    }

    init(
        eventType: String,
        data: JSONValue,
        origin: String? = nil,
        timeFired: Date? = nil,
        context: HAContextDTO? = nil
    ) {
        self.eventType = eventType
        self.data = data
        self.origin = origin
        self.timeFired = timeFired
        self.context = context
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(String.self, forKey: .eventType)
        data = try container.decodeIfPresent(JSONValue.self, forKey: .data) ?? .object([:])
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        timeFired = HADateParser.date(from: try container.decodeIfPresent(String.self, forKey: .timeFired))
        context = try container.decodeIfPresent(HAContextDTO.self, forKey: .context)
    }
}

struct HAStateChangedEventDTO: Decodable, Equatable, Sendable {
    let entityID: String
    let oldState: HAEntityDTO?
    let newState: HAEntityDTO?

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case oldState = "old_state"
        case newState = "new_state"
    }
}

struct HAContextDTO: Decodable, Equatable, Sendable {
    let id: String?
    let parentID: String?
    let userID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case parentID = "parent_id"
        case userID = "user_id"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
    }
}
