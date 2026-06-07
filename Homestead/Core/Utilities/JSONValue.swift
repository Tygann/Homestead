import Foundation

nonisolated enum JSONValue: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    nonisolated var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    nonisolated var doubleValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    nonisolated var intValue: Int? {
        guard let doubleValue else { return nil }
        return Int(doubleValue)
    }

    nonisolated var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    nonisolated var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    nonisolated var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    nonisolated func decoded<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }
}
