import Foundation

nonisolated struct HAEntityRegistryDisplayResponseDTO: Decodable, Equatable, Sendable {
    let entities: [HAEntityRegistryDisplayDTO]

    enum CodingKeys: String, CodingKey {
        case entities
        case entityCategories = "entity_categories"
    }

    nonisolated init(entities: [HAEntityRegistryDisplayDTO]) {
        self.entities = entities
    }

    nonisolated init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           var entities = try? container.decode([HAEntityRegistryDisplayDTO].self, forKey: .entities) {
            let categories = try container.decodeIfPresent([String: String].self, forKey: .entityCategories) ?? [:]
            if !categories.isEmpty {
                entities = entities.map { entity in
                    guard entity.entityCategory == nil,
                          let categoryIndex = entity.entityCategoryIndex,
                          let category = categories[String(categoryIndex)] else {
                        return entity
                    }

                    return entity.withEntityCategory(category)
                }
            }
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
    let entityCategory: String?
    let entityCategoryIndex: Int?

    var id: String { entityID }

    enum CodingKeys: String, CodingKey {
        case entityID = "ei"
        case deviceID = "di"
        case areaID = "ai"
        case originalName = "en"
        case name = "n"
        case hiddenBy = "hb"
        case entityCategoryIndex = "ec"
        case entityCategory = "entity_category"
    }

    enum FullCodingKeys: String, CodingKey {
        case areaID = "area_id"
        case entityCategory = "entity_category"
    }

    nonisolated init(
        entityID: String,
        deviceID: String?,
        areaID: String? = nil,
        originalName: String?,
        name: String? = nil,
        hiddenBy: Bool? = nil,
        entityCategory: String? = nil,
        entityCategoryIndex: Int? = nil
    ) {
        self.entityID = entityID
        self.deviceID = deviceID
        self.areaID = areaID
        self.originalName = originalName
        self.name = name
        self.hiddenBy = hiddenBy
        self.entityCategory = entityCategory
        self.entityCategoryIndex = entityCategoryIndex
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
        entityCategoryIndex = try container.decodeIfPresent(Int.self, forKey: .entityCategoryIndex)
        entityCategory = try container.decodeIfPresent(String.self, forKey: .entityCategory) ??
            fullContainer?.decodeIfPresent(String.self, forKey: .entityCategory)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(entityID, forKey: .entityID)
        try container.encodeIfPresent(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(areaID, forKey: .areaID)
        try container.encodeIfPresent(originalName, forKey: .originalName)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(hiddenBy, forKey: .hiddenBy)
        try container.encodeIfPresent(entityCategory, forKey: .entityCategory)
        try container.encodeIfPresent(entityCategoryIndex, forKey: .entityCategoryIndex)
    }

    nonisolated func withEntityCategory(_ category: String?) -> HAEntityRegistryDisplayDTO {
        HAEntityRegistryDisplayDTO(
            entityID: entityID,
            deviceID: deviceID,
            areaID: areaID,
            originalName: originalName,
            name: name,
            hiddenBy: hiddenBy,
            entityCategory: category,
            entityCategoryIndex: entityCategoryIndex
        )
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
    let floorID: String?
    let temperatureEntityID: String?
    let humidityEntityID: String?

    enum CodingKeys: String, CodingKey {
        case id = "area_id"
        case name
        case floorID = "floor_id"
        case temperatureEntityID = "temperature_entity_id"
        case humidityEntityID = "humidity_entity_id"
    }

    nonisolated init(
        id: String,
        name: String,
        floorID: String? = nil,
        temperatureEntityID: String? = nil,
        humidityEntityID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.floorID = floorID
        self.temperatureEntityID = temperatureEntityID
        self.humidityEntityID = humidityEntityID
    }
}

nonisolated struct HAFloorRegistryDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let level: Int?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case id = "floor_id"
        case name
        case level
        case icon
    }

    nonisolated init(
        id: String,
        name: String,
        level: Int? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.icon = icon
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
