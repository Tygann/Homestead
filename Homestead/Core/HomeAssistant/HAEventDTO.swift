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

    nonisolated var stateChanged: HAStateChangedEventDTO? {
        guard eventType == "state_changed",
              case .object(let eventData) = data,
              case .string(let entityID)? = eventData["entity_id"] else {
            return nil
        }

        let oldState = eventData["old_state"].flatMap(Self.entityDTO)
        let newState = eventData["new_state"].flatMap(Self.entityDTO)

        return HAStateChangedEventDTO(
            entityID: entityID,
            oldState: oldState,
            newState: newState
        )
    }

    nonisolated var stateChangedNewState: HAEntityDTO? {
        stateChanged?.newState
    }

    nonisolated var isRegistryMetadataChanged: Bool {
        Self.registryMetadataEventTypes.contains(eventType)
    }

    private nonisolated static let registryMetadataEventTypes: Set<String> = [
        "entity_registry_updated",
        "device_registry_updated",
        "area_registry_updated",
        "floor_registry_updated"
    ]

    private nonisolated static func entityDTO(from value: JSONValue) -> HAEntityDTO? {
        guard case .object(let stateObject) = value,
              case .string(let entityID)? = stateObject["entity_id"],
              case .string(let state)? = stateObject["state"] else {
            return nil
        }

        return HAEntityDTO(
            entityID: entityID,
            state: state,
            attributes: stateObject["attributes"]?.objectValue ?? [:],
            lastChanged: HADateParser.date(from: stateObject["last_changed"]?.stringValue),
            lastUpdated: HADateParser.date(from: stateObject["last_updated"]?.stringValue)
        )
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
