import Foundation

/// Stable app-owned destinations used by widgets and the main app.
///
enum HomesteadWidgetDeepLink {
    private static let scheme = "homestead"
    private static let entityHost = "entity"

    static func entityURL(entityID: String) -> URL {
        let referenceID: String
        if HomesteadEntityReference(encodedID: entityID) != nil {
            referenceID = entityID
        } else if let profileID = legacyWidgetProfileID {
            referenceID = HomesteadEntityReference(profileID: profileID, entityID: entityID).encodedID
        } else {
            referenceID = entityID
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = entityHost
        components.path = "/\(referenceID)"
        return components.url ?? URL(string: "\(scheme)://\(entityHost)/\(referenceID)")!
    }

    static func entityID(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == entityHost else {
            return nil
        }

        let entityID = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .removingPercentEncoding ?? ""

        return entityID.isEmpty ? nil : entityID
    }

    static func entityReference(from url: URL, fallbackProfileID: UUID) -> HomesteadEntityReference? {
        guard let encoded = entityID(from: url) else { return nil }
        return HomesteadEntityReference(encodedID: encoded)
            ?? HomesteadEntityReference(profileID: fallbackProfileID, entityID: encoded)
    }

    private static var legacyWidgetProfileID: UUID? {
        UserDefaults(suiteName: "group.com.tyler.Homestead")?
            .string(forKey: "homeAssistantLegacyWidgetProfileID")
            .flatMap(UUID.init(uuidString:))
    }
}
