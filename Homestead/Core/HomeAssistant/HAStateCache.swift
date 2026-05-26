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
            print("Home Assistant state cache hit: \(snapshot.entities.count) entities from \(url.path)")
            #endif
            return snapshot
        } catch {
            #if DEBUG
            print("Home Assistant state cache load failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    func save(_ entities: [HAEntityDTO], for configuration: HAConnectionConfiguration) async {
        do {
            let url = try cacheURL(for: configuration)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let snapshot = HAStateCacheSnapshot(savedAt: Date(), entities: entities)
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            #if DEBUG
            print("Home Assistant state cache saved: \(entities.count) entities to \(url.path)")
            #endif
        } catch {
            #if DEBUG
            print("Home Assistant state cache save failed: \(error.localizedDescription)")
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

    static func cacheFileName(for configuration: HAConnectionConfiguration) -> String {
        let normalizedBaseURL = normalizedBaseURLString(configuration.baseURLString)
        let digest = SHA256.hash(data: Data(normalizedBaseURL.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return "\(digest).json"
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

struct HAStateCacheSnapshot: Codable, Equatable, Sendable {
    let savedAt: Date
    let entities: [HAEntityDTO]
}
