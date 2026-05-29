import Foundation

struct HAServiceRegistry: Decodable, Equatable, Sendable {
    static let empty = HAServiceRegistry(domains: [:], hasLoaded: false)

    let domains: [String: [String: HAServiceDescription]]
    let hasLoaded: Bool

    init(domains: [String: [String: HAServiceDescription]], hasLoaded: Bool = true) {
        self.domains = domains
        self.hasLoaded = hasLoaded
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        domains = try container.decode([String: [String: HAServiceDescription]].self)
        hasLoaded = true
    }

    func hasService(domain: String, service: String) -> Bool {
        domains[domain]?[service] != nil
    }
}

struct HAServiceDescription: Decodable, Equatable, Sendable {
    let name: String?
    let description: String?
    let fields: [String: JSONValue]
    let target: JSONValue?
    let response: JSONValue?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case fields
        case target
        case response
    }

    nonisolated init(
        name: String? = nil,
        description: String? = nil,
        fields: [String: JSONValue] = [:],
        target: JSONValue? = nil,
        response: JSONValue? = nil
    ) {
        self.name = name
        self.description = description
        self.fields = fields
        self.target = target
        self.response = response
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        fields = try container.decodeIfPresent([String: JSONValue].self, forKey: .fields) ?? [:]
        target = try container.decodeIfPresent(JSONValue.self, forKey: .target)
        response = try container.decodeIfPresent(JSONValue.self, forKey: .response)
    }
}
