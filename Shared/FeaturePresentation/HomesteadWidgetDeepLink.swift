import Foundation

/// Stable app-owned destinations used by widgets and the main app.
///
/// The URL carries only an entity identifier. Widget configuration and
/// dashboard configuration remain owned by their respective surfaces.
enum HomesteadWidgetDeepLink {
    private static let scheme = "homestead"
    private static let entityHost = "entity"

    static func entityURL(entityID: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = entityHost
        components.path = "/\(entityID)"
        return components.url ?? URL(string: "\(scheme)://\(entityHost)/\(entityID)")!
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
}
