import Foundation

enum EntityMapper {
    static func homeEntity(from dto: HAEntityDTO) -> HomeEntity {
        let domain = EntityDomain(entityID: dto.entityID)

        return HomeEntity(
            entityID: dto.entityID,
            domain: domain,
            displayName: displayName(for: dto),
            state: dto.state,
            iconName: iconName(for: domain, state: dto.state),
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
            iconName: dto.state == "on" ? "lightbulb.fill" : "lightbulb",
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
            mediaArtist: dto.attributes["media_artist"]?.stringValue
        )
    }

    static func coverEntity(from dto: HAEntityDTO) -> CoverEntity? {
        guard EntityDomain(entityID: dto.entityID) == .cover else { return nil }

        return CoverEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            position: dto.attributes["current_position"]?.intValue
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

    private static func iconName(for domain: EntityDomain, state: String) -> String {
        switch domain {
        case .light:
            state == "on" ? "lightbulb.fill" : "lightbulb"
        case .climate:
            "thermometer.medium"
        case .cover:
            "blinds.horizontal.closed"
        case .sensor:
            "gauge.medium"
        case .binarySensor:
            binarySensorIconName(deviceClass: nil, state: state)
        case .switch:
            state == "on" ? "switch.2" : "switch.2"
        case .fan:
            state == "on" ? "fan.fill" : "fan"
        case .lock:
            state == "locked" ? "lock.fill" : "lock.open"
        case .mediaPlayer:
            mediaPlayerIconName(state: state)
        case .camera:
            "camera.fill"
        case .vacuum:
            state == "cleaning" ? "washer.fill" : "washer"
        case .scene:
            "sparkles"
        case .script:
            "play.circle"
        case .other:
            "circle.hexagongrid"
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
            return isActive ? "lock.open" : "lock"
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
        case .connectivity:
            return isActive ? "wifi" : "wifi.slash"
        case .plug:
            return isActive ? "powerplug.fill" : "powerplug"
        case .power:
            return isActive ? "power.circle.fill" : "power.circle"
        case .light:
            return isActive ? "lightbulb.fill" : "lightbulb"
        case .generic:
            return isActive ? "sensor.tag.radiowaves.forward.fill" : "sensor.tag.radiowaves.forward"
        }
    }

    private static func mediaPlayerIconName(state: String) -> String {
        switch state {
        case "playing":
            "play.tv.fill"
        case "paused", "idle", "standby", "off":
            "play.tv"
        default:
            "play.tv"
        }
    }

    private static func sensorIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "temperature":
            "thermometer.medium"
        case "humidity":
            "humidity"
        case "battery":
            "battery.75percent"
        case "energy":
            "bolt.circle.fill"
        case "power":
            "bolt.fill"
        case "illuminance":
            "sun.max.fill"
        case "pressure":
            "gauge.with.dots.needle.50percent"
        case "signal_strength":
            "wifi"
        case "voltage", "current":
            "waveform.path.ecg"
        case "water":
            "drop.fill"
        case "gas":
            "flame.fill"
        case "problem":
            "exclamationmark.triangle.fill"
        default:
            "gauge.medium"
        }
    }
}
