import Foundation

enum EntityMapper {
    static func homeEntity(from dto: HAEntityDTO) -> HomeEntity {
        let domain = EntityDomain(entityID: dto.entityID)

        return HomeEntity(
            entityID: dto.entityID,
            domain: domain,
            displayName: displayName(for: dto),
            state: dto.state,
            iconName: iconName(for: dto),
            isAvailable: !["unavailable", "unknown"].contains(dto.state),
            lastUpdated: dto.lastUpdated
        )
    }

    static func lightEntity(from dto: HAEntityDTO) -> LightEntity? {
        guard EntityDomain(entityID: dto.entityID) == .light else { return nil }

        return LightEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            isOn: dto.state == "on",
            brightness: dto.attributes["brightness"]?.intValue,
            supportsBrightness: supportsLightBrightness(dto),
            iconName: "lightbulb.fill",
            lastUpdated: dto.lastUpdated
        )
    }

    static func climateEntity(from dto: HAEntityDTO) -> ClimateEntity? {
        guard EntityDomain(entityID: dto.entityID) == .climate else { return nil }

        return ClimateEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            currentTemperature: dto.attributes["current_temperature"]?.doubleValue,
            targetTemperature: dto.attributes["temperature"]?.doubleValue,
            targetTemperatureLow: dto.attributes["target_temp_low"]?.doubleValue,
            targetTemperatureHigh: dto.attributes["target_temp_high"]?.doubleValue,
            hvacModes: dto.attributes["hvac_modes"]?.arrayValue?.compactMap(\.stringValue) ?? [],
            minTemperature: dto.attributes["min_temp"]?.doubleValue,
            maxTemperature: dto.attributes["max_temp"]?.doubleValue,
            targetTemperatureStep: dto.attributes["target_temp_step"]?.doubleValue,
            temperatureUnit: dto.attributes["temperature_unit"]?.stringValue,
            fanMode: dto.attributes["fan_mode"]?.stringValue,
            fanModes: dto.attributes["fan_modes"]?.arrayValue?.compactMap(\.stringValue) ?? [],
            presetMode: dto.attributes["preset_mode"]?.stringValue,
            presetModes: dto.attributes["preset_modes"]?.arrayValue?.compactMap(\.stringValue) ?? []
        )
    }

    static func fanEntity(from dto: HAEntityDTO) -> FanEntity? {
        guard EntityDomain(entityID: dto.entityID) == .fan else { return nil }

        return FanEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            percentage: dto.attributes["percentage"]?.intValue,
            percentageStep: dto.attributes["percentage_step"]?.intValue,
            presetMode: dto.attributes["preset_mode"]?.stringValue,
            presetModes: dto.attributes["preset_modes"]?.arrayValue?.compactMap(\.stringValue) ?? []
        )
    }

    static func mediaPlayerEntity(from dto: HAEntityDTO) -> MediaPlayerEntity? {
        guard EntityDomain(entityID: dto.entityID) == .mediaPlayer else { return nil }

        return MediaPlayerEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            volumeLevel: dto.attributes["volume_level"]?.doubleValue,
            source: dto.attributes["source"]?.stringValue,
            sourceList: dto.attributes["source_list"]?.arrayValue?.compactMap(\.stringValue) ?? [],
            mediaTitle: dto.attributes["media_title"]?.stringValue,
            mediaArtist: dto.attributes["media_artist"]?.stringValue,
            deviceClass: dto.attributes["device_class"]?.stringValue,
            iconName: mediaPlayerIconName(for: dto)
        )
    }

    static func coverEntity(from dto: HAEntityDTO) -> CoverEntity? {
        guard EntityDomain(entityID: dto.entityID) == .cover else { return nil }

        return CoverEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            position: dto.attributes["current_position"]?.intValue,
            deviceClass: dto.attributes["device_class"]?.stringValue,
            iconName: coverIconName(for: dto)
        )
    }

    static func sensorEntity(from dto: HAEntityDTO) -> SensorEntity? {
        guard EntityDomain(entityID: dto.entityID) == .sensor else { return nil }

        return SensorEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            value: dto.state,
            unit: dto.attributes["unit_of_measurement"]?.stringValue,
            deviceClass: dto.attributes["device_class"]?.stringValue,
            iconName: sensorIconName(for: dto),
            lastUpdated: dto.lastUpdated
        )
    }

    static func binarySensorEntity(from dto: HAEntityDTO) -> BinarySensorEntity? {
        guard EntityDomain(entityID: dto.entityID) == .binarySensor else { return nil }

        return BinarySensorEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            deviceClass: dto.attributes["device_class"]?.stringValue,
            iconName: binarySensorIconName(for: dto),
            lastUpdated: dto.lastUpdated
        )
    }

    private static func displayName(for dto: HAEntityDTO) -> String {
        if let friendlyName = dto.attributes["friendly_name"]?.stringValue, !friendlyName.isEmpty {
            return friendlyName
        }

        let name = dto.entityID
            .split(separator: ".")
            .dropFirst()
            .joined(separator: " ")
            .replacingOccurrences(of: "_", with: " ")

        return name.capitalized.isEmpty ? dto.entityID : name.capitalized
    }

    private static func supportsLightBrightness(_ dto: HAEntityDTO) -> Bool {
        if dto.attributes["brightness"]?.intValue != nil {
            return true
        }

        let brightnessModes: Set<String> = [
            "brightness",
            "color_temp",
            "hs",
            "rgb",
            "rgbw",
            "rgbww",
            "white",
            "xy"
        ]
        let supportedModes = dto.attributes["supported_color_modes"]?.arrayValue?.compactMap(\.stringValue) ?? []
        return supportedModes.contains { brightnessModes.contains($0) }
    }

    private static func iconName(for dto: HAEntityDTO) -> String {
        let domain = EntityDomain(entityID: dto.entityID)

        if domain == .cover {
            return coverIconName(for: dto)
        }

        if domain == .switch {
            return switchIconName(for: dto)
        }

        if domain == .sensor {
            return sensorIconName(for: dto)
        }

        if domain == .binarySensor {
            return binarySensorIconName(for: dto)
        }

        if domain == .mediaPlayer {
            return mediaPlayerIconName(for: dto)
        }

        return iconName(for: domain, state: dto.state)
    }

    private static func iconName(for domain: EntityDomain, state: String) -> String {
        switch domain {
        case .light:
            "lightbulb.fill"
        case .climate:
            "thermometer.medium"
        case .cover:
            "blinds.horizontal.closed"
        case .sensor:
            "gauge.medium"
        case .binarySensor:
            binarySensorIconName(deviceClass: nil, state: state)
        case .switch:
            switchIconName(deviceClass: nil, state: state)
        case .fan:
            "fan.fill"
        case .lock:
            state == "locked" ? "lock.fill" : "lock.open.fill"
        case .mediaPlayer:
            mediaPlayerIconName(state: state)
        case .camera:
            "camera.fill"
        case .vacuum:
            "washer.fill"
        case .scene:
            "sparkles"
        case .script:
            "play.circle"
        case .automation:
            "calendar.badge.clock"
        case .other:
            "circle.hexagongrid"
        }
    }

    private static func coverIconName(for dto: HAEntityDTO) -> String {
        coverIconName(
            deviceClass: dto.attributes["device_class"]?.stringValue,
            state: dto.state
        )
    }

    private static func switchIconName(for dto: HAEntityDTO) -> String {
        switchIconName(
            deviceClass: dto.attributes["device_class"]?.stringValue,
            state: dto.state
        )
    }

    private static func switchIconName(deviceClass: String?, state: String) -> String {
        switch deviceClass {
        case "outlet":
            return "poweroutlet.type.b.fill"
        case "switch", nil:
            return state == "on" ? "lightswitch.on.fill" : "lightswitch.off.fill"
        default:
            return state == "on" ? "lightswitch.on.fill" : "lightswitch.off.fill"
        }
    }

    private static func coverIconName(deviceClass: String?, state: String) -> String {
        let isOpen = state == "open" || state == "opening"

        switch deviceClass {
        case "garage":
            return isOpen ? "door.garage.open" : "door.garage.closed"
        case "gate":
            return isOpen ? "pedestrian.gate.open" : "pedestrian.gate.closed"
        case "door":
            return isOpen ? "door.left.hand.open" : "door.left.hand.closed"
        case "window":
            return isOpen ? "window.vertical.open" : "window.vertical.closed"
        case "curtain":
            return isOpen ? "curtains.open" : "curtains.closed"
        case "awning":
            return isOpen ? "window.awning" : "window.awning.closed"
        case "blind":
            return isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        case "shade":
            return isOpen ? "window.shade.open" : "window.shade.closed"
        case "shutter":
            return isOpen ? "blinds.vertical.open" : "blinds.vertical.closed"
        case "damper":
            return isOpen ? "rectangle.portrait.tophalf.inset.filled" : "rectangle.portrait.bottomhalf.inset.filled"
        default:
            return isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        }
    }

    private static func binarySensorIconName(for dto: HAEntityDTO) -> String {
        binarySensorIconName(
            deviceClass: dto.attributes["device_class"]?.stringValue,
            state: dto.state
        )
    }

    private static func binarySensorIconName(deviceClass: String?, state: String) -> String {
        let isActive = state == "on"

        switch BinarySensorDisplayKind(deviceClass: deviceClass) {
        case .door:
            return isActive ? "door.left.hand.open" : "door.left.hand.closed"
        case .window:
            return isActive ? "window.vertical.open" : "window.vertical.closed"
        case .garageDoor:
            return isActive ? "door.garage.open" : "door.garage.closed"
        case .opening:
            return isActive ? "rectangle.portrait.and.arrow.right" : "rectangle.portrait"
        case .lock:
            return isActive ? "lock.open.fill" : "lock.fill"
        case .motion, .occupancy, .presence:
            return isActive ? "figure.motion" : "figure.stand"
        case .tamper, .safety, .problem:
            return isActive ? "exclamationmark.triangle.fill" : "checkmark.shield"
        case .smoke:
            return isActive ? "smoke.fill" : "smoke"
        case .gas:
            return isActive ? "flame.fill" : "flame"
        case .moisture:
            return isActive ? "drop.fill" : "drop"
        case .battery:
            return isActive ? "battery.25percent" : "battery.100percent"
        case .batteryCharging:
            return isActive ? "battery.100percent.bolt" : "battery.100percent"
        case .cold:
            return "snowflake"
        case .carbonMonoxide:
            return isActive ? "carbon.monoxide.cloud.fill" : "carbon.monoxide.cloud"
        case .heat:
            return "heat.waves"
        case .moving:
            return isActive ? "figure.walk.motion" : "figure.stand"
        case .running:
            return isActive ? "figure.run" : "figure.stand"
        case .sound:
            return isActive ? "speaker.wave.2.fill" : "speaker"
        case .update:
            return isActive ? "arrow.trianglehead.2.clockwise" : "checkmark.circle"
        case .vibration:
            return isActive ? "waveform.path" : "waveform"
        case .connectivity:
            return isActive ? "wifi" : "wifi.slash"
        case .plug:
            return "powerplug.fill"
        case .power:
            return "power.circle.fill"
        case .light:
            return "lightbulb.fill"
        case .generic:
            return "sensor.tag.radiowaves.forward.fill"
        }
    }

    private static func mediaPlayerIconName(for dto: HAEntityDTO) -> String {
        mediaPlayerIconName(
            deviceClass: dto.attributes["device_class"]?.stringValue,
            state: dto.state
        )
    }

    private static func mediaPlayerIconName(deviceClass: String? = nil, state _: String) -> String {
        switch deviceClass {
        case "tv":
            return "tv.fill"
        case "speaker":
            return "speaker.wave.2.fill"
        case "receiver":
            return "hifispeaker.2.fill"
        default:
            return "play.tv.fill"
        }
    }

    private static func sensorIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "aqi":
            "aqi.medium"
        case "temperature":
            "thermometer.medium"
        case "humidity":
            "humidity"
        case "battery":
            "battery.75percent"
        case "carbon_dioxide":
            "carbon.dioxide.cloud.fill"
        case "carbon_monoxide":
            "carbon.monoxide.cloud.fill"
        case "data_size", "volume_storage":
            "externaldrive.fill"
        case "data_rate":
            "speedometer"
        case "date", "timestamp":
            "calendar"
        case "distance":
            "ruler.fill"
        case "duration":
            "timer"
        case "enum":
            "list.bullet.rectangle.fill"
        case "energy":
            "bolt.circle.fill"
        case "frequency":
            "waveform.path"
        case "monetary":
            "dollarsign.circle.fill"
        case "power":
            "bolt.fill"
        case "illuminance":
            "sun.max.fill"
        case "irradiance":
            "sun.max.trianglebadge.exclamationmark.fill"
        case "moisture":
            "drop.fill"
        case "pm1", "pm10", "pm25":
            "aqi.medium"
        case "pressure":
            "gauge.with.dots.needle.50percent"
        case "signal_strength":
            "wifi"
        case "speed":
            "speedometer"
        case "voltage", "current":
            "waveform.path.ecg"
        case "volatile_organic_compounds", "volatile_organic_compounds_parts":
            "aqi.medium"
        case "volume":
            "cube.fill"
        case "water":
            "drop.fill"
        case "weight":
            "scalemass.fill"
        case "gas":
            "flame.fill"
        case "problem":
            "exclamationmark.triangle.fill"
        default:
            "gauge.medium"
        }
    }
}
