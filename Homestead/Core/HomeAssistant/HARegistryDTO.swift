import Foundation

struct HAEntityRegistryDisplayResponseDTO: Decodable, Equatable, Sendable {
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

struct HAEntityRegistryDisplayDTO: Decodable, Equatable, Identifiable, Sendable {
    let entityID: String
    let deviceID: String?
    let originalName: String?
    let name: String?
    let hiddenBy: Bool?

    var id: String { entityID }

    enum CodingKeys: String, CodingKey {
        case entityID = "ei"
        case deviceID = "di"
        case originalName = "en"
        case name = "n"
        case hiddenBy = "hb"
    }

    nonisolated init(
        entityID: String,
        deviceID: String?,
        originalName: String?,
        name: String? = nil,
        hiddenBy: Bool? = nil
    ) {
        self.entityID = entityID
        self.deviceID = deviceID
        self.originalName = originalName
        self.name = name
        self.hiddenBy = hiddenBy
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        entityID = try container.decode(String.self, forKey: .entityID)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        hiddenBy = try container.decodeLossyBoolIfPresent(forKey: .hiddenBy)
    }
}

struct HADeviceRegistryDTO: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String?
    let nameByUser: String?
    let manufacturer: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameByUser = "name_by_user"
        case manufacturer
        case model
    }

    nonisolated init(
        id: String,
        name: String?,
        nameByUser: String? = nil,
        manufacturer: String? = nil,
        model: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameByUser = nameByUser
        self.manufacturer = manufacturer
        self.model = model
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        nameByUser = try container.decodeIfPresent(String.self, forKey: .nameByUser)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        model = try container.decodeIfPresent(String.self, forKey: .model)
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
