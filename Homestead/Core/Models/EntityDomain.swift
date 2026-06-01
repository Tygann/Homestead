import Foundation

enum EntityDomain: String, CaseIterable, Hashable, Sendable {
    case light
    case climate
    case cover
    case sensor
    case binarySensor = "binary_sensor"
    case `switch`
    case fan
    case lock
    case mediaPlayer = "media_player"
    case camera
    case vacuum
    case scene
    case script
    case automation
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
        case .binarySensor:
            "Binary Sensors"
        case .switch:
            "Switches"
        case .fan:
            "Fans"
        case .lock:
            "Locks"
        case .mediaPlayer:
            "Media Players"
        case .camera:
            "Cameras"
        case .vacuum:
            "Vacuums"
        case .scene:
            "Scenes"
        case .script:
            "Scripts"
        case .automation:
            "Automations"
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
        case .binarySensor:
            "sensor.tag.radiowaves.forward"
        case .switch:
            "switch.2"
        case .fan:
            "fan"
        case .lock:
            "lock"
        case .mediaPlayer:
            "play.tv"
        case .camera:
            "camera"
        case .vacuum:
            "washer"
        case .scene:
            "sparkles"
        case .script:
            "play.rectangle"
        case .automation:
            "calendar.badge.clock"
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
        case .binarySensor:
            4
        case .switch:
            5
        case .fan:
            6
        case .lock:
            7
        case .mediaPlayer:
            8
        case .camera:
            9
        case .vacuum:
            10
        case .scene:
            11
        case .script:
            12
        case .automation:
            13
        case .other:
            14
        }
    }
}
