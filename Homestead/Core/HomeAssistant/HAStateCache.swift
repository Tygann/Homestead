import CryptoKit
import Foundation

actor HAStateCache {
    private let directoryURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(for configuration: HAConnectionConfiguration) async -> HAStateCacheSnapshot? {
        do {
            let url = try cacheURL(for: configuration)
            guard FileManager.default.fileExists(atPath: url.path) else {
                #if DEBUG
                print("Home Assistant state cache miss: \(Self.cacheFileName(for: configuration)) at \(url.path)")
                #endif
                return nil
            }

            let data = try Data(contentsOf: url)
            let snapshot = try decoder.decode(HAStateCacheSnapshot.self, from: data)
            #if DEBUG
            let registryCount = snapshot.registryMetadata?.entities.count ?? 0
            print("Home Assistant state cache hit: \(snapshot.entities.count) entities, \(registryCount) registry entries from \(url.path)")
            #endif
            return snapshot
        } catch {
            #if DEBUG
            print("Home Assistant state cache load failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    nonisolated static func loadSynchronously(
        for configuration: HAConnectionConfiguration,
        directoryURL: URL? = nil
    ) -> HAStateCacheSnapshot? {
        do {
            let url = try cacheURL(for: configuration, directoryURL: directoryURL)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }

            let data = try Data(contentsOf: url)
            return try makeDecoder().decode(HAStateCacheSnapshot.self, from: data)
        } catch {
            #if DEBUG
            print("Home Assistant state cache synchronous load failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    func metadata(for configuration: HAConnectionConfiguration) async -> HAStateCacheMetadata? {
        do {
            let url = try cacheURL(for: configuration)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }

            let data = try Data(contentsOf: url)
            let snapshot = try decoder.decode(HAStateCacheSnapshot.self, from: data)
            return HAStateCacheMetadata(
                scopeIdentifier: Self.cacheScopeIdentifier(for: configuration),
                savedAt: snapshot.savedAt,
                entityCount: snapshot.entities.count,
                entityRegistryCount: snapshot.registryMetadata?.entities.count,
                deviceRegistryCount: snapshot.registryMetadata?.devices.count,
                areaRegistryCount: snapshot.registryMetadata?.areas.count,
                floorRegistryCount: snapshot.registryMetadata?.floors.count
            )
        } catch {
            return nil
        }
    }

    func save(
        _ entities: [HAEntityDTO],
        registryMetadata: HARegistryMetadataSnapshot? = nil,
        currentUser: HAStateCacheCurrentUser? = nil,
        for configuration: HAConnectionConfiguration
    ) async {
        do {
            let url = try cacheURL(for: configuration)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let snapshot = HAStateCacheSnapshot(
                savedAt: Date(),
                entities: entities,
                registryMetadata: registryMetadata,
                currentUser: currentUser
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            #if DEBUG
            let registryCount = registryMetadata?.entities.count ?? 0
            print("Home Assistant state cache saved: \(entities.count) entities, \(registryCount) registry entries to \(url.path)")
            #endif
        } catch {
            #if DEBUG
            print("Home Assistant state cache save failed: \(error.localizedDescription)")
            #endif
        }
    }

    func remove(for configuration: HAConnectionConfiguration) async {
        do {
            let url = try cacheURL(for: configuration)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("Home Assistant state cache removal failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func cacheURL(for configuration: HAConnectionConfiguration) throws -> URL {
        try cacheDirectoryURL()
            .appendingPathComponent(Self.cacheFileName(for: configuration), isDirectory: false)
    }

    private func cacheDirectoryURL() throws -> URL {
        if let directoryURL {
            return directoryURL
        }

        return try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Homestead", isDirectory: true)
        .appendingPathComponent("HomeAssistantStateCache", isDirectory: true)
    }

    private nonisolated static func cacheURL(
        for configuration: HAConnectionConfiguration,
        directoryURL: URL?
    ) throws -> URL {
        try cacheDirectoryURL(directoryURL: directoryURL)
            .appendingPathComponent(cacheFileName(for: configuration), isDirectory: false)
    }

    private nonisolated static func cacheDirectoryURL(directoryURL: URL?) throws -> URL {
        if let directoryURL {
            return directoryURL
        }

        return try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Homestead", isDirectory: true)
        .appendingPathComponent("HomeAssistantStateCache", isDirectory: true)
    }

    private nonisolated static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func cacheFileName(for configuration: HAConnectionConfiguration) -> String {
        "\(cacheScopeIdentifier(for: configuration)).json"
    }

    static func cacheScopeIdentifier(for configuration: HAConnectionConfiguration) -> String {
        if let profileID = configuration.profileID {
            return "profile-\(profileID.uuidString.lowercased())"
        }
        let normalizedBaseURL = normalizedBaseURLString(configuration.dataSourceBaseURLString)
        return SHA256.hash(data: Data(normalizedBaseURL.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func normalizedBaseURLString(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let webSocketURL = try? HomeAssistantEndpointBuilder.webSocketURL(from: trimmedValue),
           var components = URLComponents(url: webSocketURL, resolvingAgainstBaseURL: false) {
            switch components.scheme?.lowercased() {
            case "ws":
                components.scheme = "http"
            case "wss":
                components.scheme = "https"
            default:
                break
            }

            let webSocketSuffix = "/api/websocket"
            while components.path.hasSuffix(webSocketSuffix) {
                components.path.removeLast(webSocketSuffix.count)
            }

            var normalizedValue = components.url?.absoluteString ?? trimmedValue
            while normalizedValue.hasSuffix("/") {
                normalizedValue.removeLast()
            }

            return normalizedValue.lowercased()
        }

        var normalizedValue = trimmedValue.lowercased()

        while normalizedValue.hasSuffix("/") {
            normalizedValue.removeLast()
        }

        return normalizedValue
    }
}

nonisolated struct HAStateCacheMetadata: Equatable, Sendable {
    let scopeIdentifier: String
    let savedAt: Date
    let entityCount: Int
    let entityRegistryCount: Int?
    let deviceRegistryCount: Int?
    let areaRegistryCount: Int?
    let floorRegistryCount: Int?

    var shortScopeIdentifier: String {
        String(scopeIdentifier.prefix(8))
    }
}

nonisolated struct HARegistryMetadataSnapshot: Codable, Equatable, Sendable {
    let entities: [HAEntityRegistryDisplayDTO]
    let devices: [HADeviceRegistryDTO]
    let areas: [HAAreaRegistryDTO]
    let floors: [HAFloorRegistryDTO]
    let organization: [HAEntityOrganizationDTO]
    let labels: [HALabelRegistryDTO]
    let categories: [HACategoryRegistryDTO]

    enum CodingKeys: String, CodingKey {
        case entities
        case devices
        case areas
        case floors
        case organization
        case labels
        case categories
    }

    nonisolated init(
        entities: [HAEntityRegistryDisplayDTO],
        devices: [HADeviceRegistryDTO],
        areas: [HAAreaRegistryDTO],
        floors: [HAFloorRegistryDTO] = [],
        organization: [HAEntityOrganizationDTO] = [],
        labels: [HALabelRegistryDTO] = [],
        categories: [HACategoryRegistryDTO] = []
    ) {
        self.entities = entities
        self.devices = devices
        self.areas = areas
        self.floors = floors
        self.organization = organization
        self.labels = labels
        self.categories = categories
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entities = try container.decode([HAEntityRegistryDisplayDTO].self, forKey: .entities)
        devices = try container.decode([HADeviceRegistryDTO].self, forKey: .devices)
        areas = try container.decode([HAAreaRegistryDTO].self, forKey: .areas)
        floors = try container.decodeIfPresent([HAFloorRegistryDTO].self, forKey: .floors) ?? []
        organization = try container.decodeIfPresent([HAEntityOrganizationDTO].self, forKey: .organization) ?? []
        labels = try container.decodeIfPresent([HALabelRegistryDTO].self, forKey: .labels) ?? []
        categories = try container.decodeIfPresent([HACategoryRegistryDTO].self, forKey: .categories) ?? []
    }
}

nonisolated struct HAStateCacheSnapshot: Codable, Equatable, Sendable {
    let savedAt: Date
    let entities: [HAEntityDTO]
    let registryMetadata: HARegistryMetadataSnapshot?
    let currentUser: HAStateCacheCurrentUser?

    nonisolated init(
        savedAt: Date,
        entities: [HAEntityDTO],
        registryMetadata: HARegistryMetadataSnapshot? = nil,
        currentUser: HAStateCacheCurrentUser? = nil
    ) {
        self.savedAt = savedAt
        self.entities = entities
        self.registryMetadata = registryMetadata
        self.currentUser = currentUser
    }
}

nonisolated struct HAStateCacheCurrentUser: Codable, Equatable, Sendable {
    let id: String
    let name: String?

    nonisolated init(id: String, name: String?) {
        self.id = id
        self.name = name
    }
}
