import Foundation

nonisolated enum IconResolver {
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
        case "motion", "occupancy", "presence": return isActive ? "figure.motion" : "figure.stand"
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

    private static let mdiToSFSymbol: [String: String] = [
        "mdi:air-conditioner": "air.conditioner.horizontal.fill",
        "mdi:alarm-light": "light.beacon.max.fill",
        "mdi:bathtub": "bathtub.fill",
        "mdi:bed": "bed.double",
        "mdi:bed-double": "bed.double",
        "mdi:bed-king": "bed.double",
        "mdi:bell": "bell.fill",
        "mdi:camera": "camera.fill",
        "mdi:ceiling-fan": "fan.ceiling.fill",
        "mdi:controller": "gamecontroller",
        "mdi:desk": "desktopcomputer",
        "mdi:desktop-tower-monitor": "desktopcomputer",
        "mdi:door": "door.left.hand.closed",
        "mdi:fan": "fan.fill",
        "mdi:food-fork-drink": "fork.knife",
        "mdi:fridge": "refrigerator",
        "mdi:gamepad-variant": "gamecontroller",
        "mdi:garage": "door.garage.closed",
        "mdi:garage-variant": "door.garage.closed",
        "mdi:hanger": "hanger",
        "mdi:home": "house.fill",
        "mdi:lightbulb": "lightbulb.fill",
        "mdi:lock": "lock.fill",
        "mdi:lock-open": "lock.open.fill",
        "mdi:monitor": "desktopcomputer",
        "mdi:movie": "play.tv",
        "mdi:pine-tree": "tree",
        "mdi:power-socket-us": "poweroutlet.type.b.fill",
        "mdi:robot-vacuum": "robotic.vacuum.fill",
        "mdi:shower": "shower",
        "mdi:silverware-fork-knife": "fork.knife",
        "mdi:sofa": "sofa",
        "mdi:television": "tv",
        "mdi:thermometer": "thermometer.medium",
        "mdi:toilet": "toilet",
        "mdi:tree": "tree",
        "mdi:washing-machine": "washer",
        "mdi:weather-cloudy": "cloud.fill",
        "mdi:weather-night": "moon.stars.fill",
        "mdi:weather-partly-cloudy": "cloud.sun.fill",
        "mdi:weather-pouring": "cloud.heavyrain.fill",
        "mdi:weather-rainy": "cloud.rain.fill",
        "mdi:weather-snowy": "cloud.snow.fill",
        "mdi:weather-sunny": "sun.max.fill",
        "mdi:window-closed": "window.vertical.closed",
        "mdi:window-open": "window.vertical.open"
    ]
}
