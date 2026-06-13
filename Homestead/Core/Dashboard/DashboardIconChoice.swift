import Foundation

nonisolated enum DashboardIconCategory: String, CaseIterable, Identifiable, Sendable {
    case home = "Home"
    case lighting = "Lighting & Power"
    case climate = "Climate & Air"
    case security = "Security & Access"
    case media = "Media & Devices"
    case sensors = "Sensors & Status"
    case outdoors = "Outdoors & Weather"
    case actions = "Scenes & Actions"

    var id: Self { self }
}

nonisolated enum DashboardIconRecommendation: Equatable, Sendable {
    case domain(EntityDomain)
    case summary(DashboardSummaryKind)
}

nonisolated struct DashboardIconChoice: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemName: String
    let category: DashboardIconCategory
    let searchTerms: [String]

    static let choices: [DashboardIconChoice] = [
        // Home
        choice("Home", "house.fill", .home, "building residence"),
        choice("Home Outline", "house", .home, "building residence"),
        choice("House and Flag", "house.and.flag.fill", .home, "home location"),
        choice("Building", "building.2.fill", .home, "apartment office"),
        choice("Kitchen", "frying.pan.fill", .home, "cooking stove"),
        choice("Bed", "bed.double.fill", .home, "bedroom sleep"),
        choice("Sofa", "sofa.fill", .home, "living room couch"),
        choice("Chair", "chair.lounge.fill", .home, "furniture room"),
        choice("Table", "table.furniture.fill", .home, "dining desk"),
        choice("Shower", "shower.fill", .home, "bathroom water"),
        choice("Bathtub", "bathtub.fill", .home, "bathroom water"),
        choice("Washer", "washer.fill", .home, "laundry appliance"),
        choice("Dryer", "dryer.fill", .home, "laundry appliance"),
        choice("Dishwasher", "dishwasher.fill", .home, "kitchen appliance"),
        choice("Refrigerator", "refrigerator.fill", .home, "kitchen appliance fridge"),
        choice("Oven", "oven.fill", .home, "kitchen appliance"),
        choice("Microwave", "microwave.fill", .home, "kitchen appliance"),
        choice("Stairs", "stairs", .home, "floor steps"),
        choice("Garage", "door.garage.closed", .home, "car entry cover"),
        choice("Car", "car.fill", .home, "garage vehicle"),
        choice("Grid", "square.grid.2x2.fill", .home, "dashboard overview"),
        choice("Status", "circle.fill", .home, "generic dot"),

        // Lighting and power
        choice("Light", "lightbulb.fill", .lighting, "bulb lamp lighting"),
        choice("Ceiling Light", "light.recessed.3.fill", .lighting, "lamp lighting"),
        choice("Table Lamp", "lamp.table.fill", .lighting, "light desk"),
        choice("Floor Lamp", "lamp.floor.fill", .lighting, "light standing"),
        choice("Desk Lamp", "lamp.desk.fill", .lighting, "light office"),
        choice("Chandelier", "chandelier.fill", .lighting, "light ceiling"),
        choice("Lantern", "light.beacon.max.fill", .lighting, "light beacon"),
        choice("Flashlight", "flashlight.on.fill", .lighting, "light torch"),
        choice("Switch", "lightswitch.on.fill", .lighting, "wall toggle"),
        choice("Dimmer", "slider.horizontal.3", .lighting, "brightness control"),
        choice("Outlet", "poweroutlet.type.b.fill", .lighting, "plug socket power"),
        choice("Plug", "powerplug.fill", .lighting, "outlet electricity"),
        choice("Power", "power", .lighting, "on off switch"),
        choice("Bolt", "bolt.fill", .lighting, "energy electricity power"),
        choice("Energy", "bolt.circle.fill", .lighting, "electricity power"),
        choice("Battery", "battery.75percent", .lighting, "energy charge"),
        choice("Full Battery", "battery.100percent", .lighting, "energy charge"),
        choice("Low Battery", "battery.25percent", .lighting, "energy charge"),
        choice("Solar", "sun.max.circle.fill", .lighting, "panel energy daylight"),
        choice("Meter", "gauge.with.dots.needle.67percent", .lighting, "power energy usage"),

        // Climate and air
        choice("Temperature", "thermometer.medium", .climate, "climate heat cold"),
        choice("Warm", "thermometer.sun.fill", .climate, "temperature heat"),
        choice("Cold", "thermometer.snowflake", .climate, "temperature cooling"),
        choice("Fan", "fan.fill", .climate, "air ventilation"),
        choice("Ceiling Fan", "fan.ceiling.fill", .climate, "air ventilation"),
        choice("Air Conditioner", "air.conditioner.horizontal.fill", .climate, "ac cooling hvac"),
        choice("Heater", "heater.vertical.fill", .climate, "heat hvac"),
        choice("Humidity", "humidity.fill", .climate, "moisture water"),
        choice("Dehumidifier", "dehumidifier.fill", .climate, "humidity air"),
        choice("Humidifier", "humidifier.fill", .climate, "humidity air"),
        choice("Air Purifier", "air.purifier.fill", .climate, "clean filter"),
        choice("Wind", "wind", .climate, "air breeze"),
        choice("Vent", "vent.heat.waves.upward", .climate, "air duct"),
        choice("Heat Waves", "heat.waves", .climate, "temperature warm"),
        choice("Snowflake", "snowflake", .climate, "cold cooling freeze"),
        choice("Flame", "flame.fill", .climate, "fire heat furnace"),
        choice("Fireplace", "fireplace.fill", .climate, "fire heat"),
        choice("Water Heater", "water.waves", .climate, "boiler hot"),

        // Security and access
        choice("Lock", "lock.fill", .security, "secure closed"),
        choice("Unlocked", "lock.open.fill", .security, "access open"),
        choice("Shield", "shield.fill", .security, "secure protection"),
        choice("Alarm", "bell.and.waves.left.and.right.fill", .security, "siren alert"),
        choice("Siren", "light.beacon.min.fill", .security, "alarm emergency"),
        choice("Camera", "camera.fill", .security, "security photo"),
        choice("Video Camera", "video.fill", .security, "security recording"),
        choice("Doorbell", "video.doorbell.fill", .security, "entry chime"),
        choice("Key", "key.fill", .security, "access lock"),
        choice("Keypad", "rectangle.and.hand.point.up.left.fill", .security, "access code"),
        choice("Door", "door.left.hand.closed", .security, "entry access"),
        choice("Open Door", "door.left.hand.open", .security, "entry access"),
        choice("Window", "window.vertical.closed", .security, "cover access"),
        choice("Open Window", "window.vertical.open", .security, "cover access"),
        choice("Blinds", "blinds.horizontal.closed", .security, "cover shade"),
        choice("Open Blinds", "blinds.horizontal.open", .security, "cover shade"),
        choice("Gate", "door.garage.open", .security, "entry access garage"),
        choice("Valve", "drop.circle.fill", .security, "water gas control"),
        choice("Vertical Cover", "rectangle.compress.vertical", .security, "shade blind close"),
        choice("Person", "person.fill", .security, "presence user"),
        choice("People", "person.2.fill", .security, "presence family"),
        choice("Location", "location.fill", .security, "presence position"),

        // Media and devices
        choice("Television", "tv.fill", .media, "screen media"),
        choice("Play TV", "play.tv.fill", .media, "screen media"),
        choice("Speaker", "hifispeaker.fill", .media, "audio music"),
        choice("Speakers", "hifispeaker.2.fill", .media, "audio music"),
        choice("HomePod", "homepod.fill", .media, "speaker audio"),
        choice("Music", "music.note", .media, "audio"),
        choice("Radio", "radio.fill", .media, "audio broadcast"),
        choice("Headphones", "headphones", .media, "audio"),
        choice("Play", "play.fill", .media, "start media"),
        choice("Pause", "pause.fill", .media, "stop media"),
        choice("Remote", "av.remote.fill", .media, "control television"),
        choice("Game Controller", "gamecontroller.fill", .media, "console play"),
        choice("Computer", "desktopcomputer", .media, "device monitor"),
        choice("Laptop", "laptopcomputer", .media, "device computer"),
        choice("Phone", "iphone.gen3", .media, "device mobile"),
        choice("Tablet", "ipad.gen2", .media, "device"),
        choice("Router", "wifi.router.fill", .media, "network internet"),
        choice("Wi-Fi", "wifi", .media, "network internet signal"),
        choice("Printer", "printer.fill", .media, "device office"),
        choice("Display", "display", .media, "screen monitor"),
        choice("Photo", "photo.fill", .media, "image picture"),
        choice("Photo Stack", "photo.on.rectangle.angled.fill", .media, "image gallery"),
        choice("Viewfinder", "viewfinder", .media, "camera image focus"),

        // Sensors and status
        choice("Gauge", "gauge.medium", .sensors, "sensor meter"),
        choice("Dial", "gauge.open.with.lines.needle.33percent", .sensors, "sensor meter"),
        choice("Chart", "chart.xyaxis.line", .sensors, "history graph trend"),
        choice("Activity", "waveform.path.ecg", .sensors, "health status sensor"),
        choice("Motion", "figure.walk.motion", .sensors, "presence movement"),
        choice("Eye", "eye.fill", .sensors, "visibility monitor"),
        choice("Wave", "wave.3.right", .sensors, "signal sensor"),
        choice("Signal", "antenna.radiowaves.left.and.right", .sensors, "radio sensor"),
        choice("Bluetooth", "dot.radiowaves.left.and.right", .sensors, "signal connection"),
        choice("Water", "drop.fill", .sensors, "leak moisture"),
        choice("Smoke", "smoke.fill", .sensors, "detector air"),
        choice("Carbon Dioxide", "carbon.dioxide.cloud.fill", .sensors, "air quality gas co2"),
        choice("Air Quality", "aqi.medium", .sensors, "pollution sensor"),
        choice("Leaf", "leaf.fill", .sensors, "eco air quality"),
        choice("Speed", "speedometer", .sensors, "meter velocity"),
        choice("Clock", "clock.fill", .sensors, "time timer"),
        choice("Calendar", "calendar", .sensors, "date schedule"),
        choice("Calendar and Clock", "calendar.badge.clock", .sensors, "date time schedule"),
        choice("Alarm Clock", "alarm.fill", .sensors, "time reminder"),
        choice("Hourglass", "hourglass", .sensors, "time duration"),
        choice("Number", "number", .sensors, "value count"),
        choice("List", "list.bullet", .sensors, "options items"),
        choice("Checklist", "checklist", .sensors, "tasks todo"),
        choice("Text", "textformat", .sensors, "label type"),
        choice("Text Cursor", "character.cursor.ibeam", .sensors, "input type"),
        choice("Document", "doc.text.fill", .sensors, "text file"),
        choice("Quote", "quote.bubble.fill", .sensors, "text message"),
        choice("Edit Text", "rectangle.and.pencil.and.ellipsis", .sensors, "input write"),
        choice("Info", "info.circle.fill", .sensors, "status details"),
        choice("Warning", "exclamationmark.triangle.fill", .sensors, "alert problem"),
        choice("Checkmark", "checkmark.circle.fill", .sensors, "ok success status"),
        choice("Unavailable", "questionmark.circle.fill", .sensors, "unknown status"),
        choice("Update", "arrow.triangle.2.circlepath.circle.fill", .sensors, "upgrade refresh"),

        // Outdoors and weather
        choice("Sunny", "sun.max.fill", .outdoors, "weather clear"),
        choice("Cloudy", "cloud.fill", .outdoors, "weather overcast"),
        choice("Partly Cloudy", "cloud.sun.fill", .outdoors, "weather"),
        choice("Rain", "cloud.rain.fill", .outdoors, "weather water"),
        choice("Storm", "cloud.bolt.rain.fill", .outdoors, "weather lightning"),
        choice("Snow", "cloud.snow.fill", .outdoors, "weather cold"),
        choice("Moon", "moon.fill", .outdoors, "night weather"),
        choice("Umbrella", "umbrella.fill", .outdoors, "rain weather"),
        choice("Tree", "tree.fill", .outdoors, "garden yard"),
        choice("Flower", "camera.macro", .outdoors, "garden plant"),
        choice("Sprinkler", "sprinkler.and.droplets.fill", .outdoors, "garden water irrigation"),
        choice("Pool", "figure.pool.swim", .outdoors, "water swimming"),
        choice("Patio", "sun.horizon.fill", .outdoors, "outdoor sunset"),
        choice("Lawn", "leaf.circle.fill", .outdoors, "mower garden grass"),
        choice("Trash", "trash.fill", .outdoors, "waste bin"),
        choice("Package", "shippingbox.fill", .outdoors, "delivery parcel"),

        // Scenes and actions
        choice("Scene", "sparkles", .actions, "mood favorite"),
        choice("Magic", "wand.and.stars", .actions, "scene automation"),
        choice("Automation", "gearshape.2.fill", .actions, "settings routine"),
        choice("Script", "play.rectangle.fill", .actions, "run action"),
        choice("Button", "button.programmable", .actions, "press action"),
        choice("Power Button", "power.circle.fill", .actions, "on off action"),
        choice("Dial", "dial.medium.fill", .actions, "slider control adjust"),
        choice("Timer", "timer", .actions, "countdown schedule"),
        choice("Stopwatch", "stopwatch.fill", .actions, "time action"),
        choice("Repeat", "repeat", .actions, "cycle automation"),
        choice("Refresh", "arrow.clockwise", .actions, "reload update"),
        choice("Play Circle", "play.circle.fill", .actions, "run start"),
        choice("Stop", "stop.fill", .actions, "end action"),
        choice("Favorite", "star.fill", .actions, "scene bookmark"),
        choice("Heart", "heart.fill", .actions, "favorite"),
        choice("Vacuum", "robotic.vacuum.fill", .actions, "clean appliance"),
        choice("Clean", "bubbles.and.sparkles.fill", .actions, "wash vacuum"),
        choice("Notification", "bell.fill", .actions, "alert reminder"),
        choice("Microphone", "mic.fill", .actions, "voice assistant"),
        choice("Hand", "hand.tap.fill", .actions, "touch press action"),
        choice("Tools", "wrench.and.screwdriver.fill", .actions, "maintenance repair"),
        choice("Download", "arrow.down.circle.fill", .actions, "update install"),
        choice("Terminal", "terminal.fill", .actions, "script command"),
        choice("Plus or Minus", "plus.forwardslash.minus", .actions, "number adjust"),
        choice("Edit", "square.and.pencil", .actions, "write change"),
        choice("Pipe", "pipe.and.drop.fill", .actions, "water plumbing")
    ]

    static func matching(_ query: String) -> [DashboardIconChoice] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return choices }

        let tokens = normalizedQuery.split(whereSeparator: \Character.isWhitespace).map(String.init)
        return choices.filter { choice in
            let searchableText = ([choice.title, choice.systemName] + choice.searchTerms)
                .joined(separator: " ")
                .lowercased()
            return tokens.allSatisfy(searchableText.contains)
        }
    }

    static func recommended(for recommendation: DashboardIconRecommendation) -> [DashboardIconChoice] {
        let systemNames: [String]
        switch recommendation {
        case .summary(let kind):
            systemNames = summaryRecommendations[kind] ?? []
        case .domain(let domain):
            systemNames = domainRecommendations[domain] ?? fallbackRecommendations
        }

        let choicesByName = Dictionary(uniqueKeysWithValues: choices.map { ($0.systemName, $0) })
        return systemNames.compactMap { choicesByName[$0] }
    }

    private static let fallbackRecommendations = [
        "house.fill", "square.grid.2x2.fill", "circle.fill", "star.fill", "info.circle.fill"
    ]

    private static let summaryRecommendations: [DashboardSummaryKind: [String]] = [
        .lights: ["lightbulb.fill", "lamp.table.fill", "light.recessed.3.fill", "bolt.fill", "sun.max.fill"],
        .security: ["lock.fill", "shield.fill", "camera.fill", "video.doorbell.fill", "key.fill"],
        .climate: ["fan.fill", "thermometer.medium", "air.conditioner.horizontal.fill", "humidity.fill", "flame.fill"],
        .maintenance: ["wrench.and.screwdriver.fill", "battery.25percent", "exclamationmark.triangle.fill", "arrow.triangle.2.circlepath.circle.fill", "gearshape.2.fill"],
        .media: ["play.tv.fill", "hifispeaker.fill", "music.note", "radio.fill", "av.remote.fill"]
    ]

    private static let domainRecommendations: [EntityDomain: [String]] = [
        .light: ["lightbulb.fill", "light.recessed.3.fill", "lamp.table.fill", "lamp.floor.fill", "chandelier.fill"],
        .climate: ["thermometer.medium", "fan.fill", "air.conditioner.horizontal.fill", "heater.vertical.fill", "snowflake"],
        .cover: ["blinds.horizontal.closed", "window.vertical.closed", "door.garage.closed", "door.left.hand.closed", "rectangle.compress.vertical"],
        .sensor: ["gauge.medium", "chart.xyaxis.line", "thermometer.medium", "humidity.fill", "waveform.path.ecg"],
        .binarySensor: ["circle.fill", "checkmark.circle.fill", "figure.walk.motion", "door.left.hand.closed", "drop.fill"],
        .switch: ["lightswitch.on.fill", "power", "powerplug.fill", "bolt.fill", "button.programmable"],
        .fan: ["fan.fill", "fan.ceiling.fill", "wind", "vent.heat.waves.upward", "air.purifier.fill"],
        .lock: ["lock.fill", "lock.open.fill", "key.fill", "shield.fill", "door.left.hand.closed"],
        .mediaPlayer: ["play.tv.fill", "hifispeaker.fill", "homepod.fill", "music.note", "radio.fill"],
        .camera: ["camera.fill", "video.fill", "eye.fill", "video.doorbell.fill", "shield.fill"],
        .vacuum: ["robotic.vacuum.fill", "bubbles.and.sparkles.fill", "sparkles", "house.fill", "timer"],
        .remote: ["av.remote.fill", "tv.fill", "play.fill", "power", "wifi"],
        .button: ["button.programmable", "hand.tap.fill", "play.circle.fill", "power.circle.fill", "bell.fill"],
        .select: ["list.bullet", "slider.horizontal.3", "checkmark.circle.fill", "dial.medium.fill", "square.grid.2x2.fill"],
        .number: ["number", "gauge.medium", "slider.horizontal.3", "plus.forwardslash.minus", "dial.medium.fill"],
        .text: ["textformat", "character.cursor.ibeam", "doc.text.fill", "rectangle.and.pencil.and.ellipsis", "quote.bubble.fill"],
        .date: ["calendar", "calendar.badge.clock", "clock.fill", "sun.max.fill", "moon.fill"],
        .time: ["clock.fill", "timer", "stopwatch.fill", "alarm.fill", "hourglass"],
        .datetime: ["calendar.badge.clock", "calendar", "clock.fill", "timer", "alarm.fill"],
        .deviceTracker: ["location.fill", "iphone.gen3", "car.fill", "wifi", "antenna.radiowaves.left.and.right"],
        .person: ["person.fill", "person.2.fill", "location.fill", "house.fill", "figure.walk.motion"],
        .update: ["arrow.triangle.2.circlepath.circle.fill", "arrow.down.circle.fill", "gearshape.2.fill", "checkmark.circle.fill", "exclamationmark.triangle.fill"],
        .alarmControlPanel: ["shield.fill", "lock.fill", "bell.and.waves.left.and.right.fill", "key.fill", "rectangle.and.hand.point.up.left.fill"],
        .humidifier: ["humidifier.fill", "humidity.fill", "drop.fill", "wind", "water.waves"],
        .waterHeater: ["water.waves", "thermometer.sun.fill", "flame.fill", "drop.fill", "heater.vertical.fill"],
        .lawnMower: ["leaf.circle.fill", "leaf.fill", "tree.fill", "house.fill", "timer"],
        .valve: ["drop.circle.fill", "drop.fill", "water.waves", "pipe.and.drop.fill", "gauge.medium"],
        .siren: ["bell.and.waves.left.and.right.fill", "bell.fill", "light.beacon.min.fill", "exclamationmark.triangle.fill", "shield.fill"],
        .weather: ["sun.max.fill", "cloud.sun.fill", "cloud.rain.fill", "cloud.bolt.rain.fill", "snowflake"],
        .calendar: ["calendar", "calendar.badge.clock", "clock.fill", "bell.fill", "list.bullet"],
        .todo: ["checklist", "checkmark.circle.fill", "list.bullet", "calendar", "square.and.pencil"],
        .event: ["bell.fill", "calendar", "wave.3.right", "bolt.fill", "info.circle.fill"],
        .image: ["photo.fill", "camera.fill", "photo.on.rectangle.angled.fill", "eye.fill", "sparkles"],
        .imageProcessing: ["viewfinder", "camera.fill", "eye.fill", "waveform.path.ecg", "gearshape.2.fill"],
        .airQuality: ["aqi.medium", "leaf.fill", "wind", "carbon.dioxide.cloud.fill", "air.purifier.fill"],
        .scene: ["sparkles", "wand.and.stars", "star.fill", "house.fill", "play.circle.fill"],
        .script: ["play.rectangle.fill", "play.circle.fill", "terminal.fill", "gearshape.2.fill", "wand.and.stars"],
        .automation: ["gearshape.2.fill", "repeat", "bolt.fill", "timer", "wand.and.stars"],
        .other: fallbackRecommendations
    ]

    private init(
        title: String,
        systemName: String,
        category: DashboardIconCategory,
        searchTerms: [String]
    ) {
        self.id = systemName
        self.title = title
        self.systemName = systemName
        self.category = category
        self.searchTerms = searchTerms
    }

    private static func choice(
        _ title: String,
        _ systemName: String,
        _ category: DashboardIconCategory,
        _ searchTerms: String = ""
    ) -> DashboardIconChoice {
        DashboardIconChoice(
            title: title,
            systemName: systemName,
            category: category,
            searchTerms: searchTerms.split(separator: " ").map(String.init)
        )
    }
}
