import Foundation

// MARK: - Migration Result

nonisolated enum DashboardDocumentMigrationResult {
    case loaded(
        document: DashboardConfigurationDocument,
        originalSchemaVersion: Int,
        didMigrate: Bool
    )
    case newerSchema(version: Int)
    case unsupportedSchema(version: Int?)
    case invalid
}

// MARK: - Migrator

nonisolated enum DashboardConfigurationMigrator {
    static let oldestSupportedSchemaVersion = 5

    static func migrate(_ data: Data) -> DashboardDocumentMigrationResult {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .object(var object) = root else {
            return .invalid
        }

        let sourceVersion = object["schemaVersion"]?.intValue
        guard let sourceVersion else {
            return .unsupportedSchema(version: nil)
        }
        guard sourceVersion <= DashboardConfigurationDocument.currentSchemaVersion else {
            return .newerSchema(version: sourceVersion)
        }
        guard sourceVersion >= oldestSupportedSchemaVersion else {
            return .unsupportedSchema(version: sourceVersion)
        }

        var workingVersion = sourceVersion
        while workingVersion < DashboardConfigurationDocument.currentSchemaVersion {
            switch workingVersion {
            case 5:
                object = migrateV5ToV6(object)
                workingVersion = 6
            default:
                return .unsupportedSchema(version: workingVersion)
            }
        }

        object["schemaVersion"] = .number(Double(DashboardConfigurationDocument.currentSchemaVersion))
        guard let migratedData = try? JSONEncoder().encode(JSONValue.object(object)),
              let document = try? JSONDecoder().decode(DashboardConfigurationDocument.self, from: migratedData) else {
            return .invalid
        }

        return .loaded(
            document: document,
            originalSchemaVersion: sourceVersion,
            didMigrate: sourceVersion != DashboardConfigurationDocument.currentSchemaVersion
        )
    }

    private static func migrateV5ToV6(_ object: [String: JSONValue]) -> [String: JSONValue] {
        guard case .array(let dashboards) = object["dashboards"] else {
            var updated = object
            updated["schemaVersion"] = .number(6)
            return updated
        }

        var updated = object
        updated["schemaVersion"] = .number(6)
        updated["dashboards"] = .array(dashboards.map { replacingObjectKey(in: $0, from: "graph", to: "chart") })
        return updated
    }

    private static func replacingObjectKey(
        in value: JSONValue,
        from oldKey: String,
        to newKey: String
    ) -> JSONValue {
        switch value {
        case .object(let object):
            var updated: [String: JSONValue] = [:]
            for (key, child) in object {
                updated[key == oldKey ? newKey : key] = replacingObjectKey(
                    in: child,
                    from: oldKey,
                    to: newKey
                )
            }
            return .object(updated)
        case .array(let values):
            return .array(values.map { replacingObjectKey(in: $0, from: oldKey, to: newKey) })
        case .string, .number, .bool, .null:
            return value
        }
    }
}

// MARK: - Lossy Collections

nonisolated struct LossyDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []

        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                decoded.append(element)
            } else {
                _ = try? container.decode(JSONValue.self)
            }
        }

        elements = decoded
    }
}
