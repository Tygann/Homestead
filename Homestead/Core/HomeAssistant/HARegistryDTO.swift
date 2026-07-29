import Foundation

nonisolated enum HAOrganizationScope: String, CaseIterable, Codable, Sendable {
    case automation
    case scene
    case script
    case helper
}

nonisolated struct HAEntityOrganizationDTO: Codable, Equatable, Identifiable, Sendable {
    let entityID: String
    let uniqueID: String?
    let labels: [String]
    let categories: [String: String]

    var id: String { entityID }

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case uniqueID = "unique_id"
        case labels
        case categories
    }

    nonisolated init(
        entityID: String,
        uniqueID: String? = nil,
        labels: [String] = [],
        categories: [String: String] = [:]
    ) {
        self.entityID = entityID
        self.uniqueID = uniqueID
        self.labels = labels
        self.categories = categories
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityID = try container.decode(String.self, forKey: .entityID)
        uniqueID = try container.decodeIfPresent(String.self, forKey: .uniqueID)
        labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
        categories = try container.decodeIfPresent([String: String].self, forKey: .categories) ?? [:]
    }
}

nonisolated struct HALabelRegistryDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case id = "label_id"
        case name
        case icon
        case color
    }
}

nonisolated struct HACategoryRegistryDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let scope: HAOrganizationScope

    enum CodingKeys: String, CodingKey {
        case id = "category_id"
        case name
        case icon
        case scope
    }

    nonisolated init(id: String, name: String, icon: String? = nil, scope: HAOrganizationScope) {
        self.id = id
        self.name = name
        self.icon = icon
        self.scope = scope
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        scope = try container.decodeIfPresent(HAOrganizationScope.self, forKey: .scope) ?? .automation
    }

    nonisolated func withScope(_ scope: HAOrganizationScope) -> HACategoryRegistryDTO {
        HACategoryRegistryDTO(id: id, name: name, icon: icon, scope: scope)
    }
}

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
    let icon: String?
    let platform: String?
    let translationKey: String?
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
        case icon = "ic"
        case platform = "pl"
        case translationKey = "tk"
        case hiddenBy = "hb"
        case entityCategoryIndex = "ec"
        case entityCategory = "entity_category"
    }

    enum FullCodingKeys: String, CodingKey {
        case areaID = "area_id"
        case icon
        case platform
        case translationKey = "translation_key"
        case entityCategory = "entity_category"
    }

    nonisolated init(
        entityID: String,
        deviceID: String?,
        areaID: String? = nil,
        originalName: String?,
        name: String? = nil,
        icon: String? = nil,
        platform: String? = nil,
        translationKey: String? = nil,
        hiddenBy: Bool? = nil,
        entityCategory: String? = nil,
        entityCategoryIndex: Int? = nil
    ) {
        self.entityID = entityID
        self.deviceID = deviceID
        self.areaID = areaID
        self.originalName = originalName
        self.name = name
        self.icon = icon
        self.platform = platform
        self.translationKey = translationKey
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
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ??
            fullContainer?.decodeIfPresent(String.self, forKey: .icon)
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ??
            fullContainer?.decodeIfPresent(String.self, forKey: .platform)
        translationKey = try container.decodeIfPresent(String.self, forKey: .translationKey) ??
            fullContainer?.decodeIfPresent(String.self, forKey: .translationKey)
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
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(platform, forKey: .platform)
        try container.encodeIfPresent(translationKey, forKey: .translationKey)
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
            icon: icon,
            platform: platform,
            translationKey: translationKey,
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
    let labels: [String]
    let identifiers: [[String]]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameByUser = "name_by_user"
        case areaID = "area_id"
        case manufacturer
        case model
        case labels
        case identifiers
    }

    nonisolated init(
        id: String,
        name: String?,
        nameByUser: String? = nil,
        areaID: String? = nil,
        manufacturer: String? = nil,
        model: String? = nil,
        labels: [String] = [],
        identifiers: [[String]] = []
    ) {
        self.id = id
        self.name = name
        self.nameByUser = nameByUser
        self.areaID = areaID
        self.manufacturer = manufacturer
        self.model = model
        self.labels = labels
        self.identifiers = identifiers
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        nameByUser = try container.decodeIfPresent(String.self, forKey: .nameByUser)
        areaID = try container.decodeIfPresent(String.self, forKey: .areaID)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
        identifiers = try container.decodeIfPresent([[String]].self, forKey: .identifiers) ?? []
    }
}

nonisolated struct HAAreaRegistryDTO: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let floorID: String?
    let temperatureEntityID: String?
    let humidityEntityID: String?

    enum CodingKeys: String, CodingKey {
        case id = "area_id"
        case name
        case icon
        case floorID = "floor_id"
        case temperatureEntityID = "temperature_entity_id"
        case humidityEntityID = "humidity_entity_id"
    }

    nonisolated init(
        id: String,
        name: String,
        icon: String? = nil,
        floorID: String? = nil,
        temperatureEntityID: String? = nil,
        humidityEntityID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
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
