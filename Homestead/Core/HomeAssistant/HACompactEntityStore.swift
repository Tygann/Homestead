import Foundation

/// Reconstructs HA's subscribe_entities deltas before they enter the UI state plane.
/// The first event replaces the transport snapshot, including an empty `a` object.
nonisolated struct HACompactEntityStore: Sendable {
    private(set) var entitiesByID: [String: HAEntityDTO] = [:]
    private(set) var hasInitialSnapshot = false

    mutating func apply(_ payload: JSONValue) throws -> [HAStateChangedEventDTO] {
        guard let object = payload.objectValue,
              object["a"] != nil || object["c"] != nil || object["r"] != nil else {
            throw HAWebSocketError.unexpectedMessage("Invalid entity subscription update")
        }
        let isInitial = !hasInitialSnapshot
        if isInitial, object["a"]?.objectValue == nil {
            throw HAWebSocketError.unexpectedMessage("Missing entity subscription snapshot")
        }
        var changes: [HAStateChangedEventDTO] = []
        for (id, value) in object["a"]?.objectValue ?? [:] {
            guard let fields = value.objectValue,
                  let state = fields["s"]?.stringValue,
                  let changed = fields["lc"]?.doubleValue,
                  let attributes = fields["a"]?.objectValue else {
                throw HAWebSocketError.unexpectedMessage("Invalid compressed entity")
            }
            let entity = HAEntityDTO(entityID: id, state: state, attributes: attributes,
                                     lastChanged: Date(timeIntervalSince1970: changed),
                                     lastUpdated: Date(timeIntervalSince1970: fields["lu"]?.doubleValue ?? changed))
            let previous = entitiesByID.updateValue(entity, forKey: id)
            if !isInitial { changes.append(.init(entityID: id, oldState: previous, newState: entity)) }
        }
        for (id, value) in object["c"]?.objectValue ?? [:] {
            guard let previous = entitiesByID[id], let delta = value.objectValue else {
                throw HAWebSocketError.unexpectedMessage("Entity delta has no base state")
            }
            let additions = delta["+"]?.objectValue ?? [:]
            var attributes = previous.attributes
            for (key, value) in additions["a"]?.objectValue ?? [:] { attributes[key] = value }
            for key in delta["-"]?.objectValue?["a"]?.arrayValue?.compactMap(\.stringValue) ?? [] {
                attributes.removeValue(forKey: key)
            }
            let changed = additions["lc"]?.doubleValue.map(Date.init(timeIntervalSince1970:))
            let updated = changed ?? additions["lu"]?.doubleValue.map(Date.init(timeIntervalSince1970:))
            let entity = HAEntityDTO(entityID: id, state: additions["s"]?.stringValue ?? previous.state,
                                     attributes: attributes, lastChanged: changed ?? previous.lastChanged,
                                     lastUpdated: updated ?? previous.lastUpdated)
            entitiesByID[id] = entity
            changes.append(.init(entityID: id, oldState: previous, newState: entity))
        }
        for id in object["r"]?.arrayValue?.compactMap(\.stringValue) ?? [] {
            let previous = entitiesByID.removeValue(forKey: id)
            changes.append(.init(entityID: id, oldState: previous, newState: nil))
        }
        hasInitialSnapshot = true
        return changes
    }
}

nonisolated enum HAWebSocketFrame {
    static func decode(_ data: Data) throws -> [HAWebSocketIncomingMessage] {
        let decoder = JSONDecoder()
        if data.first(where: { ![9, 10, 13, 32].contains($0) }) == 91 {
            return try decoder.decode([HAWebSocketIncomingMessage].self, from: data)
        }
        return [try decoder.decode(HAWebSocketIncomingMessage.self, from: data)]
    }
}

nonisolated enum HAWebSocketVersion {
    static func supports(_ version: String?, year: Int, month: Int) -> Bool {
        guard let version else { return false }
        let parts = version.split(separator: ".").prefix(2).compactMap { Int($0) }
        guard parts.count == 2 else { return false }
        return parts[0] > year || (parts[0] == year && parts[1] >= month)
    }
}
