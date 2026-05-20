import Foundation

enum EntityDomain: String, Equatable, Sendable {
    case light
    case climate
    case cover
    case sensor
    case scene
    case script
    case other

    init(entityID: String) {
        guard let domain = entityID.split(separator: ".").first else {
            self = .other
            return
        }

        self = EntityDomain(rawValue: String(domain)) ?? .other
    }
}
