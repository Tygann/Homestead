import Foundation

enum EntityDomain: String, Hashable, Sendable {
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

    var displayName: String {
        switch self {
        case .light:
            "Lights"
        case .climate:
            "Climate"
        case .cover:
            "Covers"
        case .sensor:
            "Sensors"
        case .scene:
            "Scenes"
        case .script:
            "Scripts"
        case .other:
            "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .light:
            "lightbulb"
        case .climate:
            "thermometer.medium"
        case .cover:
            "blinds.horizontal.closed"
        case .sensor:
            "sensor"
        case .scene:
            "sparkles"
        case .script:
            "play.rectangle"
        case .other:
            "square.grid.2x2"
        }
    }

    var dashboardPriority: Int {
        switch self {
        case .light:
            0
        case .climate:
            1
        case .cover:
            2
        case .sensor:
            3
        case .scene:
            4
        case .script:
            5
        case .other:
            6
        }
    }
}
