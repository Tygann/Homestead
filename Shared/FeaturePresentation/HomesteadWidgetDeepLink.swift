import Foundation

/// Stable app-owned destinations used by widgets and the main app.
///
enum HomesteadWidgetDeepLink {
    private static let scheme = "homestead"
    private static let entityHost = "entity"
    private static let plusHost = "plus"

    static func entityURL(entityID: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = entityHost
        components.path = "/\(entityID)"
        return components.url ?? URL(string: "\(scheme)://\(entityHost)/\(entityID)")!
    }

    static var plusURL: URL {
        URL(string: "\(scheme)://\(plusHost)")!
    }

    static func isPlusURL(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == plusHost
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

    static func entityReference(from url: URL) -> HomesteadEntityReference? {
        guard let encoded = entityID(from: url) else { return nil }
        return HomesteadEntityReference(encodedID: encoded)
    }
}
