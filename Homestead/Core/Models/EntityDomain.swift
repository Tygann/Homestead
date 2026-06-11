import Foundation

nonisolated enum EntityDomain: String, CaseIterable, Hashable, Sendable {
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
    case remote
    case button
    case select
    case number
    case text
    case date
    case time
    case datetime
    case deviceTracker = "device_tracker"
    case person
    case update
    case alarmControlPanel = "alarm_control_panel"
    case humidifier
    case waterHeater = "water_heater"
    case lawnMower = "lawn_mower"
    case valve
    case siren
    case weather
    case calendar
    case todo
    case event
    case image
    case imageProcessing = "image_processing"
    case airQuality = "air_quality"
    case scene
    case script
    case automation
    case other

    init(entityID: String) {
        guard let domain = entityID.split(separator: ".").first else {
            self = .other
            return
        }

        if domain == "input_select" {
            self = .select
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
        case .remote:
            "Remotes"
        case .button:
            "Buttons"
        case .select:
            "Selects"
        case .number:
            "Numbers"
        case .text:
            "Text"
        case .date:
            "Dates"
        case .time:
            "Times"
        case .datetime:
            "Date & Time"
        case .deviceTracker:
            "Device Trackers"
        case .person:
            "People"
        case .update:
            "Updates"
        case .alarmControlPanel:
            "Alarm Panels"
        case .humidifier:
            "Humidifiers"
        case .waterHeater:
            "Water Heaters"
        case .lawnMower:
            "Lawn Mowers"
        case .valve:
            "Valves"
        case .siren:
            "Sirens"
        case .weather:
            "Weather"
        case .calendar:
            "Calendars"
        case .todo:
            "To-do Lists"
        case .event:
            "Events"
        case .image:
            "Images"
        case .imageProcessing:
            "Image Processing"
        case .airQuality:
            "Air Quality"
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
            "lightbulb.fill"
        case .climate:
            "thermometer.medium"
        case .cover:
            "blinds.horizontal.closed"
        case .sensor:
            "sensor"
        case .binarySensor:
            "sensor.tag.radiowaves.forward.fill"
        case .switch:
            "lightswitch.on.fill"
        case .fan:
            "fan.fill"
        case .lock:
            "lock.fill"
        case .mediaPlayer:
            "play.tv.fill"
        case .camera:
            "camera.fill"
        case .vacuum:
            "washer.fill"
        case .remote:
            "appletvremote.gen4.fill"
        case .button:
            "button.programmable"
        case .select:
            "filemenu.and.selection"
        case .number:
            "number"
        case .text:
            "text.cursor"
        case .date:
            "calendar"
        case .time:
            "clock"
        case .datetime:
            "calendar.badge.clock"
        case .deviceTracker:
            "location.fill"
        case .person:
            "person.fill"
        case .update:
            "arrow.trianglehead.2.clockwise"
        case .alarmControlPanel:
            "shield.lefthalf.filled"
        case .humidifier:
            "humidifier.fill"
        case .waterHeater:
            "water.waves"
        case .lawnMower:
            "leaf.fill"
        case .valve:
            "pipe.and.drop.fill"
        case .siren:
            "megaphone.fill"
        case .weather:
            "cloud.sun.fill"
        case .calendar:
            "calendar"
        case .todo:
            "checklist"
        case .event:
            "sensor.tag.radiowaves.forward.fill"
        case .image:
            "photo.fill"
        case .imageProcessing:
            "viewfinder"
        case .airQuality:
            "aqi.medium"
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
        case .remote:
            14
        case .button:
            15
        case .select:
            16
        case .number:
            17
        case .text:
            18
        case .date:
            19
        case .time:
            20
        case .datetime:
            21
        case .deviceTracker:
            22
        case .person:
            23
        case .update:
            24
        case .alarmControlPanel:
            25
        case .humidifier:
            26
        case .waterHeater:
            27
        case .lawnMower:
            28
        case .valve:
            29
        case .siren:
            30
        case .weather:
            31
        case .calendar:
            32
        case .todo:
            33
        case .event:
            34
        case .image:
            35
        case .imageProcessing:
            36
        case .airQuality:
            37
        case .other:
            38
        }
    }
}
