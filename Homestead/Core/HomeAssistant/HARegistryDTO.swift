import Foundation

nonisolated struct HAEntityRegistryDisplayResponseDTO: Decodable, Equatable, Sendable {
    let entities: [HAEntityRegistryDisplayDTO]

    enum CodingKeys: String, CodingKey {
        case entities
    }

    nonisolated init(entities: [HAEntityRegistryDisplayDTO]) {
        self.entities = entities
    }

    nonisolated init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let entities = try? container.decode([HAEntityRegistryDisplayDTO].self, forKey: .entities) {
            self.entities = entities
            return
        }

        entities = try [HAEntityRegistryDisplayDTO](from: decoder)
    }
}

nonisolated struct HAEntityRegistryDisplayDTO: Codable, Equatable, Identifiable, Sendable {
    let entityID: String
    let deviceID: String?
    let areaID: String?
    let originalName: String?
    let name: String?
    let hiddenBy: Bool?

    var id: String { entityID }

    enum CodingKeys: String, CodingKey {
        case entityID = "ei"
        case deviceID = "di"
        case areaID = "ai"
        case originalName = "en"
        case name = "n"
        case hiddenBy = "hb"
    }

    enum FullCodingKeys: String, CodingKey {
        case areaID = "area_id"
    }

    nonisolated init(
        entityID: String,
        deviceID: String?,
        areaID: String? = nil,
        originalName: String?,
        name: String? = nil,
        hiddenBy: Bool? = nil
    ) {
        self.entityID = entityID
        self.deviceID = deviceID
        self.areaID = areaID
        self.originalName = originalName
        self.name = name
        self.hiddenBy = hiddenBy
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        entityID = try container.decode(String.self, forKey: .entityID)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
        let fullContainer = try? decoder.container(keyedBy: FullCodingKeys.self)
        areaID = try container.decodeIfPresent(String.self, forKey: .areaID) ??
            fullContainer?.decodeIfPresent(String.self, forKey: .areaID)
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        hiddenBy = try container.decodeLossyBoolIfPresent(forKey: .hiddenBy)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(entityID, forKey: .entityID)
        try container.encodeIfPresent(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(areaID, forKey: .areaID)
        try container.encodeIfPresent(originalName, forKey: .originalName)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(hiddenBy, forKey: .hiddenBy)
    }
}

nonisolated struct HADeviceRegistryDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String?
    let nameByUser: String?
    let areaID: String?
    let manufacturer: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameByUser = "name_by_user"
        case areaID = "area_id"
        case manufacturer
        case model
    }

    nonisolated init(
        id: String,
        name: String?,
        nameByUser: String? = nil,
        areaID: String? = nil,
        manufacturer: String? = nil,
        model: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameByUser = nameByUser
        self.areaID = areaID
        self.manufacturer = manufacturer
        self.model = model
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        nameByUser = try container.decodeIfPresent(String.self, forKey: .nameByUser)
        areaID = try container.decodeIfPresent(String.self, forKey: .areaID)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        model = try container.decodeIfPresent(String.self, forKey: .model)
    }
}

nonisolated struct HAAreaRegistryDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "area_id"
        case name
    }

    nonisolated init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

private extension KeyedDecodingContainer {
    nonisolated func decodeLossyBoolIfPresent(forKey key: Key) throws -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }

        guard let value = try decodeIfPresent(String.self, forKey: key) else {
            return nil
        }

        switch value.lowercased() {
        case "true", "1", "yes":
            return true
        case "false", "0", "no":
            return false
        default:
            return nil
        }
    }
}
