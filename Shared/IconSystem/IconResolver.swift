import Foundation

nonisolated enum IconResolver {
    // MARK: - Public API

    static func resolveEntity(_ input: EntityIconResolutionInput) -> ResolvedIcon {
        let semanticFallback = semanticSFSymbol(
            domain: input.domain,
            deviceClass: input.deviceClass,
            state: input.semanticState
        )

        if let presentationOverride = input.presentationOverride {
            return resolveLocalOverride(
                presentationOverride,
                fallback: semanticFallback,
                provenance: .dashboardOverride
            )
        }

        if let appOverride = input.appOverride {
            return resolveLocalOverride(
                appOverride,
                fallback: semanticFallback,
                provenance: .appOverride
            )
        }

        if let registryIcon = input.registryIcon {
            return resolveHomeAssistantIdentifier(
                registryIcon,
                fallback: semanticFallback,
                provenance: .haRegistryIcon
            )
        }

        if let explicitIcon = input.explicitIcon {
            return resolveHomeAssistantIdentifier(
                explicitIcon,
                fallback: semanticFallback,
                provenance: .haExplicitIcon
            )
        }

        return .sfSymbol(
            semanticFallback,
            provenance: .haSemanticMapping,
            sourceIdentifier: semanticFallback
        )
    }

    static func resolveArea(_ input: AreaIconResolutionInput) -> ResolvedIcon {
        let inferred = inferredAreaSFSymbol(for: input.name)
        let fallback = inferred ?? "house"

        if let presentationOverride = input.presentationOverride {
            return resolveLocalOverride(
                presentationOverride,
                fallback: fallback,
                provenance: .dashboardOverride
            )
        }

        if let appOverride = input.appOverride {
            return resolveLocalOverride(
                appOverride,
                fallback: fallback,
                provenance: .appOverride
            )
        }

        if let registryIcon = input.registryIcon {
            return resolveHomeAssistantIdentifier(
                registryIcon,
                fallback: fallback,
                provenance: .haRegistryIcon
            )
        }

        if let inferred {
            return .sfSymbol(
                inferred,
                provenance: .homesteadSemanticMapping,
                sourceIdentifier: inferred
            )
        }

        return .sfSymbol("house", provenance: .fallback)
    }

    static func resolveRegistryIcon(_ identifier: String?, fallback: String) -> ResolvedIcon {
        guard let identifier = normalized(identifier) else {
            return .sfSymbol(fallback, provenance: .fallback)
        }

        return resolveHomeAssistantIdentifier(
            identifier,
            fallback: fallback,
            provenance: .haRegistryIcon
        )
    }

    static func applyingDashboardOverride(
        _ identifier: String?,
        to icon: ResolvedIcon
    ) -> ResolvedIcon {
        guard let identifier = normalized(identifier) else {
            return icon
        }

        return resolveLocalOverride(
            identifier,
            fallback: icon.fallbackSFSymbol,
            provenance: .dashboardOverride
        )
    }

    static func historicalEntityIcon(
        domain: String,
        deviceClass: String?,
        state: String,
        fallback: String = "list.bullet.clipboard"
    ) -> ResolvedIcon {
        let input = EntityIconResolutionInput(
            domain: domain,
            deviceClass: deviceClass,
            state: state
        )
        let resolved = resolveEntity(input)
        guard resolved.provenance != .fallback else {
            return .sfSymbol(fallback, provenance: .fallback)
        }
        return resolved
    }

    static func iconSemanticState(
        domain: String,
        deviceClass: String?,
        state: String
    ) -> String? {
        switch domain {
        case "automation", "binary_sensor", "cover", "device_tracker", "person", "lock", "switch",
             "update", "alarm_control_panel", "lawn_mower", "valve", "siren", "weather":
            state.lowercased()
        case "sensor" where ["battery", "battery_charging"].contains(deviceClass):
            nil
        default:
            nil
        }
    }

    // MARK: - Home Assistant Identifier Resolution

    private static func resolveLocalOverride(
        _ identifier: String,
        fallback: String,
        provenance: IconProvenance
    ) -> ResolvedIcon {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("mdi:") {
            return resolveHomeAssistantIdentifier(trimmed, fallback: fallback, provenance: provenance)
        }

        return ResolvedIcon(
            asset: .sfSymbol(trimmed),
            fallbackSFSymbol: fallback,
            provenance: provenance,
            sourceIdentifier: trimmed
        )
    }

    private static func resolveHomeAssistantIdentifier(
        _ identifier: String,
        fallback: String,
        provenance: IconProvenance
    ) -> ResolvedIcon {
        let sourceIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIdentifier = normalizedHomeAssistantIdentifier(sourceIdentifier)

        guard normalizedIdentifier.hasPrefix("mdi:") else {
            return ResolvedIcon(
                asset: .unsupportedHomeAssistant(sourceIdentifier),
                fallbackSFSymbol: fallback,
                provenance: provenance,
                sourceIdentifier: sourceIdentifier
            )
        }

        // Keep the Home Assistant bridge curated: obvious MDI icons can become
        // native SF Symbols, while ambiguous or missing icons keep MDI rendering.
        if let mapped = mdiToSFSymbol[normalizedIdentifier] {
            return ResolvedIcon(
                asset: .sfSymbol(mapped),
                fallbackSFSymbol: mapped,
                provenance: provenance,
                sourceIdentifier: sourceIdentifier
            )
        }

        let mdiName = String(normalizedIdentifier.dropFirst(4))
        if MaterialDesignIconCatalog.codepoint(for: mdiName) != nil {
            return ResolvedIcon(
                asset: .materialDesign(mdiName),
                fallbackSFSymbol: fallback,
                provenance: provenance,
                sourceIdentifier: sourceIdentifier
            )
        }

        return ResolvedIcon(
            asset: .unsupportedHomeAssistant(sourceIdentifier),
            fallbackSFSymbol: fallback,
            provenance: provenance,
            sourceIdentifier: sourceIdentifier
        )
    }

    private static func normalizedHomeAssistantIdentifier(_ identifier: String) -> String {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains(":") {
            return normalized
        }
        return "mdi:\(normalized)"
    }

    private static func normalized(_ identifier: String?) -> String? {
        let trimmed = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Entity Semantic Mapping

    private static func semanticSFSymbol(
        domain: String,
        deviceClass: String?,
        state: String?
    ) -> String {
        switch domain {
        case "light":
            return "lightbulb.fill"
        case "climate":
            return "thermometer.medium"
        case "cover":
            return coverSFSymbol(deviceClass: deviceClass, state: state)
        case "sensor", "number":
            return sensorSFSymbol(deviceClass: deviceClass)
        case "binary_sensor":
            return binarySensorSFSymbol(deviceClass: deviceClass, state: state)
        case "switch":
            return switchSFSymbol(deviceClass: deviceClass, state: state)
        case "fan":
            return "fan.fill"
        case "lock":
            switch state {
            case "locked", "locking": return "lock.fill"
            case "jammed": return "exclamationmark.triangle.fill"
            default: return "lock.open.fill"
            }
        case "media_player":
            return mediaPlayerSFSymbol(deviceClass: deviceClass)
        case "camera":
            return "camera.fill"
        case "vacuum":
            return "robotic.vacuum.fill"
        case "remote":
            return "appletvremote.gen4.fill"
        case "button":
            return buttonSFSymbol(deviceClass: deviceClass)
        case "select", "input_select":
            return "filemenu.and.selection"
        case "text":
            return "text.cursor"
        case "date":
            return "calendar"
        case "time":
            return "clock"
        case "datetime":
            return "calendar.badge.clock"
        case "device_tracker":
            switch state {
            case "home": return "location.fill"
            case "not_home", "off", "unknown", "unavailable", nil: return "location"
            default: return "mappin.and.ellipse"
            }
        case "person":
            switch state {
            case "home": return "person.fill"
            case "not_home", "off", "unknown", "unavailable", nil: return "person"
            default: return "mappin.and.ellipse"
            }
        case "update":
            if deviceClass == "firmware" {
                return state == "off" ? "checkmark.circle" : "memorychip.fill"
            }
            return state == "off" ? "checkmark.circle" : "arrow.trianglehead.2.clockwise"
        case "alarm_control_panel":
            switch state {
            case "disarmed": return "shield"
            case "triggered": return "exclamationmark.shield.fill"
            default: return "shield.lefthalf.filled"
            }
        case "humidifier":
            return deviceClass == "dehumidifier" ? "dehumidifier.fill" : "humidifier.fill"
        case "water_heater":
            return "water.waves"
        case "lawn_mower":
            switch state {
            case "mowing": return "leaf.fill"
            case "docked": return "parkingsign.circle.fill"
            case "error": return "exclamationmark.triangle.fill"
            default: return "leaf"
            }
        case "valve":
            switch deviceClass {
            case "gas": return "flame.fill"
            case "water": return "drop.fill"
            default: return state == "open" || state == "opening" ? "pipe.and.drop.fill" : "pipe.and.drop"
            }
        case "siren":
            return state == "on" ? "megaphone.fill" : "megaphone"
        case "weather":
            return weatherSFSymbol(state: state)
        case "calendar":
            return "calendar"
        case "todo":
            return "checklist"
        case "event":
            return eventSFSymbol(deviceClass: deviceClass)
        case "image":
            return "photo.fill"
        case "image_processing":
            return imageProcessingSFSymbol(deviceClass: deviceClass)
        case "air_quality":
            return "aqi.medium"
        case "scene":
            return "sparkles"
        case "script":
            return "play.circle"
        case "automation":
            return state == "off" ? "calendar" : "calendar.badge.clock"
        default:
            return "circle.hexagongrid"
        }
    }

    private static func switchSFSymbol(deviceClass: String?, state: String?) -> String {
        if deviceClass == "outlet" {
            return "poweroutlet.type.b.fill"
        }
        return state == "on" ? "lightswitch.on.fill" : "lightswitch.off.fill"
    }

    private static func coverSFSymbol(deviceClass: String?, state: String?) -> String {
        let isOpen = state == "open" || state == "opening"
        switch deviceClass {
        case "garage": return isOpen ? "door.garage.open" : "door.garage.closed"
        case "gate": return isOpen ? "pedestrian.gate.open" : "pedestrian.gate.closed"
        case "door": return isOpen ? "door.left.hand.open" : "door.left.hand.closed"
        case "window": return isOpen ? "window.vertical.open" : "window.vertical.closed"
        case "curtain": return isOpen ? "curtains.open" : "curtains.closed"
        case "awning": return isOpen ? "window.awning" : "window.awning.closed"
        case "blind": return isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        case "shade": return isOpen ? "window.shade.open" : "window.shade.closed"
        case "shutter": return isOpen ? "blinds.vertical.open" : "blinds.vertical.closed"
        case "damper": return isOpen ? "rectangle.portrait.tophalf.inset.filled" : "rectangle.portrait.bottomhalf.inset.filled"
        default: return isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        }
    }

    private static func binarySensorSFSymbol(deviceClass: String?, state: String?) -> String {
        let isActive = state == "on"
        switch deviceClass {
        case "door": return isActive ? "door.left.hand.open" : "door.left.hand.closed"
        case "window": return isActive ? "window.vertical.open" : "window.vertical.closed"
        case "garage_door": return isActive ? "door.garage.open" : "door.garage.closed"
        case "opening": return isActive ? "rectangle.portrait.and.arrow.right" : "rectangle.portrait"
        case "lock": return isActive ? "lock.open.fill" : "lock.fill"
        case "motion", "occupancy", "presence": return isActive ? "figure.walk" : "figure.stand"
        case "tamper", "safety", "problem": return isActive ? "exclamationmark.triangle.fill" : "checkmark.shield"
        case "smoke": return isActive ? "smoke.fill" : "smoke"
        case "gas": return isActive ? "flame.fill" : "flame"
        case "moisture": return isActive ? "drop.fill" : "drop"
        case "battery": return isActive ? "battery.25percent" : "battery.100percent"
        case "battery_charging": return isActive ? "battery.100percent.bolt" : "battery.100percent"
        case "cold": return "snowflake"
        case "carbon_monoxide": return isActive ? "carbon.monoxide.cloud.fill" : "carbon.monoxide.cloud"
        case "heat": return "heat.waves"
        case "moving": return isActive ? "figure.walk.motion" : "figure.stand"
        case "running": return isActive ? "figure.run" : "figure.stand"
        case "sound": return isActive ? "speaker.wave.2.fill" : "speaker"
        case "update": return isActive ? "arrow.trianglehead.2.clockwise" : "checkmark.circle"
        case "vibration": return isActive ? "waveform.path" : "waveform"
        case "connectivity": return isActive ? "wifi" : "wifi.slash"
        case "plug": return "powerplug.fill"
        case "power": return "power.circle.fill"
        case "light": return "lightbulb.fill"
        default: return "sensor.tag.radiowaves.forward.fill"
        }
    }

    private static func mediaPlayerSFSymbol(deviceClass: String?) -> String {
        switch deviceClass {
        case "tv": return "tv.fill"
        case "speaker": return "speaker.wave.2.fill"
        case "receiver": return "hifispeaker.2.fill"
        case "projector": return "videoprojector.fill"
        default: return "play.tv.fill"
        }
    }

    private static func buttonSFSymbol(deviceClass: String?) -> String {
        switch deviceClass {
        case "identify": return "dot.radiowaves.left.and.right"
        case "restart": return "arrow.trianglehead.2.clockwise"
        case "update": return "square.and.arrow.down.fill"
        default: return "button.programmable"
        }
    }

    private static func eventSFSymbol(deviceClass: String?) -> String {
        switch deviceClass {
        case "doorbell": return "bell.and.waves.left.and.right.fill"
        case "button": return "button.programmable"
        case "motion": return "figure.motion"
        default: return "sensor.tag.radiowaves.forward.fill"
        }
    }

    private static func imageProcessingSFSymbol(deviceClass: String?) -> String {
        switch deviceClass {
        case "alpr": return "licenseplate.fill"
        case "face": return "face.smiling"
        case "ocr": return "text.viewfinder"
        default: return "viewfinder"
        }
    }

    private static func sensorSFSymbol(deviceClass: String?) -> String {
        switch deviceClass {
        case "aqi": return "aqi.medium"
        case "absolute_humidity": return "humidity.fill"
        case "apparent_power", "reactive_power": return "bolt.fill"
        case "area": return "square.dashed"
        case "atmospheric_pressure": return "barometer"
        case "temperature": return "thermometer.medium"
        case "temperature_delta": return "thermometer.variable"
        case "humidity": return "humidity"
        case "battery": return "battery.75percent"
        case "blood_glucose_concentration": return "drop.degreesign.fill"
        case "carbon_dioxide": return "carbon.dioxide.cloud.fill"
        case "carbon_monoxide": return "carbon.monoxide.cloud.fill"
        case "conductivity": return "waveform.path.ecg"
        case "data_size", "volume_storage": return "externaldrive.fill"
        case "data_rate": return "speedometer"
        case "date", "timestamp", "uptime": return "calendar"
        case "distance": return "ruler.fill"
        case "duration": return "timer"
        case "enum": return "list.bullet.rectangle.fill"
        case "energy": return "bolt.circle.fill"
        case "energy_distance", "energy_storage", "reactive_energy": return "bolt.batteryblock.fill"
        case "frequency": return "waveform.path"
        case "monetary": return "dollarsign.circle.fill"
        case "power": return "bolt.fill"
        case "power_factor": return "bolt.badge.clock.fill"
        case "illuminance": return "sun.max.fill"
        case "irradiance": return "sun.max.trianglebadge.exclamationmark.fill"
        case "moisture": return "drop.fill"
        case "nitrogen_dioxide", "nitrogen_monoxide", "nitrous_oxide", "ozone", "pm1", "pm10", "pm25", "pm4", "sulphur_dioxide": return "aqi.medium"
        case "ph": return "testtube.2"
        case "precipitation", "precipitation_intensity": return "cloud.rain.fill"
        case "pressure": return "gauge.with.dots.needle.50percent"
        case "signal_strength": return "wifi"
        case "sound_pressure": return "speaker.wave.3.fill"
        case "speed", "wind_speed": return "speedometer"
        case "voltage", "current": return "waveform.path.ecg"
        case "volatile_organic_compounds", "volatile_organic_compounds_parts": return "aqi.medium"
        case "volume", "volume_flow_rate": return "cube.fill"
        case "water": return "drop.fill"
        case "weight": return "scalemass.fill"
        case "wind_direction": return "location.north.line.fill"
        case "gas": return "flame.fill"
        case "problem": return "exclamationmark.triangle.fill"
        default: return "gauge.medium"
        }
    }

    private static func weatherSFSymbol(state: String?) -> String {
        switch state {
        case "sunny": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "cloudy": return "cloud.fill"
        case "partlycloudy": return "cloud.sun.fill"
        case "rainy": return "cloud.rain.fill"
        case "pouring": return "cloud.heavyrain.fill"
        case "snowy", "snowy-rainy": return "cloud.snow.fill"
        case "lightning", "lightning-rainy": return "cloud.bolt.rain.fill"
        case "windy", "windy-variant": return "wind"
        case "fog": return "cloud.fog.fill"
        case "hail": return "cloud.hail.fill"
        case "exceptional": return "exclamationmark.triangle.fill"
        default: return "cloud.sun.fill"
        }
    }

    // MARK: - Area Semantic Mapping

    private static func inferredAreaSFSymbol(for name: String) -> String? {
        let separators = CharacterSet.alphanumerics.inverted
        let words = name.lowercased().components(separatedBy: separators).filter { !$0.isEmpty }
        let normalizedName = " \(words.joined(separator: " ")) "
        return areaNameRules.first { rule in
            rule.phrases.contains { normalizedName.contains(" \($0) ") }
        }?.systemName
    }

    private static let areaNameRules: [(phrases: [String], systemName: String)] = [
        (["garage"], "door.garage.closed"),
        (["kitchen", "pantry", "dining room", "dining"], "fork.knife"),
        (["bedroom", "primary bedroom", "guest bedroom", "bed"], "bed.double"),
        (["nursery"], "teddybear.fill"),
        (["office", "study"], "desktopcomputer"),
        (["entryway", "entry", "foyer", "mudroom"], "door.left.hand.closed"),
        (["living room", "family room", "den", "lounge"], "sofa"),
        (["bathroom", "bath", "powder room", "restroom"], "shower"),
        (["laundry", "utility room"], "washer"),
        (["hallway", "hall", "corridor"], "door.left.hand.open"),
        (["patio", "porch", "backyard", "front yard", "yard", "outside", "outdoor", "garden", "deck"], "tree"),
        (["game room", "games room"], "gamecontroller"),
        (["media room", "theater", "theatre", "cinema"], "play.tv"),
        (["closet", "wardrobe"], "hanger")
    ]

    // MARK: - Curated MDI Mapping

    private static let mdiToSFSymbol: [String: String] = [
        "mdi:air-conditioner": "air.conditioner.horizontal.fill",
        "mdi:air-humidifier": "humidifier.fill",
        "mdi:air-humidifier-off": "humidifier.fill",
        "mdi:air-purifier": "air.purifier.fill",
        "mdi:air-purifier-off": "air.purifier.fill",
        "mdi:alarm-light": "light.beacon.max.fill",
        "mdi:bathtub": "bathtub.fill",
        "mdi:bathtub-outline": "bathtub.fill",
        "mdi:bed": "bed.double.fill",
        "mdi:bed-double": "bed.double.fill",
        "mdi:bed-double-outline": "bed.double.fill",
        "mdi:bed-king": "bed.double.fill",
        "mdi:bed-king-outline": "bed.double.fill",
        "mdi:bed-queen": "bed.double.fill",
        "mdi:bed-queen-outline": "bed.double.fill",
        "mdi:bed-single": "bed.double.fill",
        "mdi:bed-single-outline": "bed.double.fill",
        "mdi:bell": "bell.fill",
        "mdi:blinds": "blinds.horizontal.closed",
        "mdi:blinds-closed": "blinds.horizontal.closed",
        "mdi:blinds-horizontal": "blinds.horizontal.open",
        "mdi:blinds-horizontal-closed": "blinds.horizontal.closed",
        "mdi:blinds-open": "blinds.horizontal.open",
        "mdi:blinds-vertical": "blinds.vertical.open",
        "mdi:blinds-vertical-closed": "blinds.vertical.closed",
        "mdi:camera": "camera.fill",
        "mdi:ceiling-fan": "fan.ceiling.fill",
        "mdi:ceiling-fan-light": "fan.ceiling.fill",
        "mdi:ceiling-fan-on": "fan.ceiling.fill",
        "mdi:ceiling-lamp": "light.recessed.3.fill",
        "mdi:ceiling-lamp-multiple": "light.recessed.3.fill",
        "mdi:ceiling-lamp-multiple-outline": "light.recessed.3.fill",
        "mdi:ceiling-light": "light.recessed.3.fill",
        "mdi:ceiling-light-flat": "light.recessed.fill",
        "mdi:ceiling-light-multiple": "light.recessed.3.fill",
        "mdi:ceiling-light-multiple-outline": "light.recessed.3.fill",
        "mdi:ceiling-light-outline": "light.recessed.fill",
        "mdi:chair": "chair.lounge.fill",
        "mdi:chair-outline": "chair.lounge.fill",
        "mdi:chandelier": "chandelier.fill",
        "mdi:coffee": "cup.and.saucer.fill",
        "mdi:coffee-maker": "cup.and.saucer.fill",
        "mdi:coffee-maker-outline": "cup.and.saucer.fill",
        "mdi:coffee-machine": "cup.and.saucer.fill",
        "mdi:controller": "gamecontroller",
        "mdi:curtains": "curtains.open",
        "mdi:curtains-closed": "curtains.closed",
        "mdi:desk-lamp": "lamp.desk.fill",
        "mdi:desk-lamp-off": "lamp.desk.fill",
        "mdi:desk-lamp-on": "lamp.desk.fill",
        "mdi:desk": "desktopcomputer",
        "mdi:desktop-tower-monitor": "desktopcomputer",
        "mdi:dishwasher": "dishwasher.fill",
        "mdi:dishwasher-alert": "dishwasher.fill",
        "mdi:dishwasher-off": "dishwasher.fill",
        "mdi:door": "door.left.hand.closed",
        "mdi:door-closed": "door.left.hand.closed",
        "mdi:door-open": "door.left.hand.open",
        "mdi:doorbell": "bell.and.waves.left.and.right.fill",
        "mdi:doorbell-video": "video.doorbell.fill",
        "mdi:downlight": "light.recessed.fill",
        "mdi:fan": "fan.fill",
        "mdi:floor-lamp": "lamp.floor.fill",
        "mdi:floor-lamp-dual": "lamp.floor.fill",
        "mdi:floor-lamp-dual-outline": "lamp.floor.fill",
        "mdi:floor-lamp-outline": "lamp.floor.fill",
        "mdi:floor-lamp-torchiere": "lamp.floor.fill",
        "mdi:floor-lamp-torchiere-outline": "lamp.floor.fill",
        "mdi:floor-lamp-torchiere-variant": "lamp.floor.fill",
        "mdi:floor-lamp-torchiere-variant-outline": "lamp.floor.fill",
        "mdi:floor-light": "lamp.floor.fill",
        "mdi:floor-light-dual": "lamp.floor.fill",
        "mdi:floor-light-dual-outline": "lamp.floor.fill",
        "mdi:floor-light-outline": "lamp.floor.fill",
        "mdi:floor-light-torchiere": "lamp.floor.fill",
        "mdi:floor-light-torchiere-variant": "lamp.floor.fill",
        "mdi:floor-light-torchiere-variant-outline": "lamp.floor.fill",
        "mdi:food-fork-drink": "fork.knife",
        "mdi:fridge": "refrigerator.fill",
        "mdi:fridge-alert": "refrigerator.fill",
        "mdi:fridge-bottom": "refrigerator.fill",
        "mdi:fridge-filled": "refrigerator.fill",
        "mdi:fridge-filled-bottom": "refrigerator.fill",
        "mdi:fridge-filled-top": "refrigerator.fill",
        "mdi:fridge-off": "refrigerator.fill",
        "mdi:fridge-outline": "refrigerator.fill",
        "mdi:fridge-top": "refrigerator.fill",
        "mdi:fridge-variant": "refrigerator.fill",
        "mdi:fridge-variant-off": "refrigerator.fill",
        "mdi:gamepad-variant": "gamecontroller",
        "mdi:garage": "door.garage.closed",
        "mdi:garage-open": "door.garage.open",
        "mdi:garage-open-variant": "door.garage.open",
        "mdi:garage-variant": "door.garage.closed",
        "mdi:gate": "pedestrian.gate.closed",
        "mdi:gate-open": "pedestrian.gate.open",
        "mdi:hanger": "hanger",
        "mdi:home": "house.fill",
        "mdi:humidity": "humidity.fill",
        "mdi:kettle": "cup.and.saucer.fill",
        "mdi:kettle-outline": "cup.and.saucer.fill",
        "mdi:lamp": "lamp.table.fill",
        "mdi:lamp-outline": "lamp.table",
        "mdi:lamps": "lamp.table.fill",
        "mdi:lamps-outline": "lamp.table",
        "mdi:light-recessed": "light.recessed.fill",
        "mdi:lightbulb-group": "lightbulb.fill",
        "mdi:lightbulb-group-outline": "lightbulb.fill",
        "mdi:lightbulb": "lightbulb.fill",
        "mdi:lightbulb-multiple": "lightbulb.fill",
        "mdi:lightbulb-multiple-outline": "lightbulb.fill",
        "mdi:lightbulb-on": "lightbulb.fill",
        "mdi:lightbulb-on-outline": "lightbulb.fill",
        "mdi:lightbulb-outline": "lightbulb",
        "mdi:lock": "lock.fill",
        "mdi:lock-open": "lock.open.fill",
        "mdi:microwave": "microwave.fill",
        "mdi:microwave-off": "microwave.fill",
        "mdi:microwave-oven": "microwave.fill",
        "mdi:motion-sensor": "figure.motion",
        "mdi:motion-sensor-off": "figure.stand",
        "mdi:monitor": "desktopcomputer",
        "mdi:movie": "play.tv",
        "mdi:nas": "externaldrive.fill",
        "mdi:oven": "oven.fill",
        "mdi:pine-tree": "tree",
        "mdi:power-plug": "powerplug.fill",
        "mdi:power-plug-off": "powerplug.fill",
        "mdi:power-plug-outline": "powerplug.fill",
        "mdi:power-socket": "poweroutlet.type.b.fill",
        "mdi:power-socket-type-b": "poweroutlet.type.b.fill",
        "mdi:power-socket-united-states": "poweroutlet.type.b.fill",
        "mdi:power-socket-us": "poweroutlet.type.b.fill",
        "mdi:printer": "printer.fill",
        "mdi:printer-3d": "printer.fill",
        "mdi:printer-alert": "printer.fill",
        "mdi:printer-check": "printer.fill",
        "mdi:printer-off": "printer.fill",
        "mdi:projector": "videoprojector.fill",
        "mdi:router": "wifi.router.fill",
        "mdi:router-network": "wifi.router.fill",
        "mdi:router-network-wireless": "wifi.router.fill",
        "mdi:router-wireless": "wifi.router.fill",
        "mdi:router-wireless-off": "wifi.router.fill",
        "mdi:router-wireless-settings": "wifi.router.fill",
        "mdi:security-camera": "camera.fill",
        "mdi:server": "server.rack",
        "mdi:server-network": "server.rack",
        "mdi:server-network-outline": "server.rack",
        "mdi:server-off": "server.rack",
        "mdi:robot-vacuum": "robotic.vacuum.fill",
        "mdi:robot-vacuum-alert": "robotic.vacuum.fill",
        "mdi:robot-vacuum-error": "robotic.vacuum.fill",
        "mdi:robot-vacuum-off": "robotic.vacuum.fill",
        "mdi:robot-vacuum-variant": "robotic.vacuum.fill",
        "mdi:shower": "shower",
        "mdi:shower-head": "shower",
        "mdi:silverware-fork-knife": "fork.knife",
        "mdi:smoke": "smoke.fill",
        "mdi:smoke-detector": "smoke.fill",
        "mdi:smoke-detector-alert": "smoke.fill",
        "mdi:smoke-detector-outline": "smoke",
        "mdi:sofa": "sofa",
        "mdi:sofa-outline": "sofa",
        "mdi:sofa-single": "sofa",
        "mdi:sofa-single-outline": "sofa",
        "mdi:speaker": "speaker.wave.2.fill",
        "mdi:speaker-multiple": "hifispeaker.2.fill",
        "mdi:speaker-off": "speaker.slash.fill",
        "mdi:speaker-wireless": "hifispeaker.fill",
        "mdi:stairs": "stairs",
        "mdi:stove": "frying.pan.fill",
        "mdi:stove-burner": "frying.pan.fill",
        "mdi:television": "tv",
        "mdi:television-box": "tv.fill",
        "mdi:television-classic": "tv.fill",
        "mdi:television-off": "tv",
        "mdi:thermometer": "thermometer.medium",
        "mdi:thermometer-alert": "thermometer.medium",
        "mdi:thermometer-high": "thermometer.sun.fill",
        "mdi:thermometer-low": "thermometer.snowflake",
        "mdi:thermometer-water": "thermometer.medium",
        "mdi:toilet": "toilet",
        "mdi:toaster": "frying.pan.fill",
        "mdi:toaster-oven": "oven.fill",
        "mdi:tree": "tree",
        "mdi:tumble-dryer": "dryer.fill",
        "mdi:tumble-dryer-alert": "dryer.fill",
        "mdi:tumble-dryer-off": "dryer.fill",
        "mdi:water-alert": "drop.fill",
        "mdi:water-percent": "humidity.fill",
        "mdi:water-thermometer": "thermometer.medium",
        "mdi:washing-machine": "washer.fill",
        "mdi:washing-machine-alert": "washer.fill",
        "mdi:washing-machine-off": "washer.fill",
        "mdi:weather-cloudy": "cloud.fill",
        "mdi:weather-night": "moon.stars.fill",
        "mdi:weather-partly-cloudy": "cloud.sun.fill",
        "mdi:weather-pouring": "cloud.heavyrain.fill",
        "mdi:weather-rainy": "cloud.rain.fill",
        "mdi:weather-snowy": "cloud.snow.fill",
        "mdi:weather-sunny": "sun.max.fill",
        "mdi:window-closed": "window.vertical.closed",
        "mdi:window-closed-variant": "window.vertical.closed",
        "mdi:window-open": "window.vertical.open",
        "mdi:window-open-variant": "window.vertical.open",
        "mdi:wireless-router": "wifi.router.fill"
    ]
}
