import Foundation

struct HAServiceRegistry: Decodable, Equatable, Sendable {
    nonisolated static let empty = HAServiceRegistry(domains: [:], hasLoaded: false)

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

    func actions(for entityID: String) -> [HAEntityAction] {
        guard let rawDomain = entityID.split(separator: ".").first.map(String.init),
              let services = domains[rawDomain] else { return [] }

        return services.map { service, description in
            HAEntityAction(domain: rawDomain, service: service, description: description)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func actions(with identifiers: [String]) -> [HAEntityAction] {
        identifiers.compactMap { identifier in
            let components = identifier.split(separator: ".", maxSplits: 1).map(String.init)
            guard components.count == 2,
                  let description = domains[components[0]]?[components[1]] else { return nil }
            return HAEntityAction(domain: components[0], service: components[1], description: description)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

struct HAEntityAction: Identifiable, Equatable, Sendable {
    let domain: String
    let service: String
    let description: HAServiceDescription

    var id: String { "\(domain).\(service)" }
    var displayName: String {
        if let value = description.name?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return value
        }
        return service.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var requiresFields: Bool {
        fields.contains(where: \.isRequired)
    }

    var fields: [HAEntityActionField] {
        description.fields.map { key, value in
            HAEntityActionField(key: key, metadata: value.objectValue ?? [:])
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

struct HAEntityActionField: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case boolean
        case number
        case select([String])
        case text
    }

    let key: String
    let displayName: String
    let helpText: String?
    let isRequired: Bool
    let kind: Kind

    var id: String { key }

    init(key: String, metadata: [String: JSONValue]) {
        self.key = key
        displayName = metadata["name"]?.stringValue
            ?? key.replacingOccurrences(of: "_", with: " ").capitalized
        helpText = metadata["description"]?.stringValue
        isRequired = metadata["required"]?.boolValue == true

        let selector = metadata["selector"]?.objectValue ?? [:]
        if selector["boolean"] != nil {
            kind = .boolean
        } else if selector["number"] != nil {
            kind = .number
        } else if let select = selector["select"]?.objectValue,
                  let options = select["options"]?.arrayValue {
            kind = .select(options.compactMap { option in
                option.stringValue ?? option.objectValue?["value"]?.stringValue
            })
        } else {
            kind = .text
        }
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
