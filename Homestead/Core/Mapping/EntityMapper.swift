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
            lastUpdated: dto.lastUpdated,
            suggestedMinimumValue: numericAttribute(
                from: dto,
                keys: ["min", "minimum", "min_value", "native_min_value"]
            ),
            suggestedMaximumValue: numericAttribute(
                from: dto,
                keys: ["max", "maximum", "max_value", "native_max_value"]
            )
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

    static func weatherEntity(from dto: HAEntityDTO) -> WeatherEntity? {
        guard EntityDomain(entityID: dto.entityID) == .weather else { return nil }

        return WeatherEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            condition: WeatherCondition(state: dto.state),
            temperature: dto.attributes["temperature"]?.doubleValue,
            temperatureUnit: dto.attributes["temperature_unit"]?.stringValue,
            humidity: dto.attributes["humidity"]?.doubleValue,
            windSpeed: dto.attributes["wind_speed"]?.doubleValue,
            windSpeedUnit: dto.attributes["wind_speed_unit"]?.stringValue,
            windBearing: dto.attributes["wind_bearing"]?.doubleValue,
            forecastCount: dto.attributes["forecast"]?.arrayValue?.count,
            attribution: dto.attributes["attribution"]?.stringValue ?? dto.attributes["_attr_attribution"]?.stringValue,
            lastUpdated: dto.lastUpdated
        )
    }

    static func selectEntity(from dto: HAEntityDTO) -> SelectEntity? {
        guard EntityDomain(entityID: dto.entityID) == .select else { return nil }

        return SelectEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            options: dto.attributes["options"]?.arrayValue?.compactMap(\.stringValue) ?? []
        )
    }

    static func displayName(for dto: HAEntityDTO) -> String {
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

    private static func numericAttribute(
        from dto: HAEntityDTO,
        keys: [String]
    ) -> Double? {
        for key in keys {
            if let doubleValue = dto.attributes[key]?.doubleValue {
                return doubleValue
            }
        }

        return nil
    }

    private static func iconName(for dto: HAEntityDTO) -> String {
        let domain = EntityDomain(entityID: dto.entityID)

        switch domain {
        case .cover:
            return coverIconName(for: dto)
        case .switch:
            return switchIconName(for: dto)
        case .sensor, .number:
            return sensorIconName(for: dto)
        case .binarySensor:
            return binarySensorIconName(for: dto)
        case .mediaPlayer:
            return mediaPlayerIconName(for: dto)
        case .button:
            return buttonIconName(for: dto)
        case .humidifier:
            return humidifierIconName(for: dto)
        case .valve:
            return valveIconName(for: dto)
        case .update:
            return updateIconName(for: dto)
        case .event:
            return eventIconName(for: dto)
        case .imageProcessing:
            return imageProcessingIconName(for: dto)
        case .light, .climate, .fan, .lock, .camera, .vacuum, .remote, .select, .text, .date, .time, .datetime, .deviceTracker, .person, .alarmControlPanel, .waterHeater, .lawnMower, .siren, .weather, .calendar, .todo, .image, .airQuality, .scene, .script, .automation, .other:
            return iconName(for: domain, state: dto.state)
        }
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
            state == "home" ? "location.fill" : "location"
        case .person:
            state == "home" ? "person.fill" : "person"
        case .update:
            state == "on" ? "arrow.trianglehead.2.clockwise" : "checkmark.circle"
        case .alarmControlPanel:
            alarmControlPanelIconName(state: state)
        case .humidifier:
            "humidifier.fill"
        case .waterHeater:
            "water.waves"
        case .lawnMower:
            lawnMowerIconName(state: state)
        case .valve:
            state == "open" || state == "opening" ? "pipe.and.drop.fill" : "pipe.and.drop"
        case .siren:
            state == "on" ? "megaphone.fill" : "megaphone"
        case .weather:
            weatherIconName(state: state)
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

    private static func buttonIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "identify":
            "dot.radiowaves.left.and.right"
        case "restart":
            "arrow.trianglehead.2.clockwise"
        case "update":
            "square.and.arrow.down.fill"
        default:
            "button.programmable"
        }
    }

    private static func humidifierIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "dehumidifier":
            "dehumidifier.fill"
        case "humidifier":
            "humidifier.fill"
        default:
            "humidifier.fill"
        }
    }

    private static func valveIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "gas":
            return "flame.fill"
        case "water":
            return "drop.fill"
        default:
            return dto.state == "open" || dto.state == "opening" ? "pipe.and.drop.fill" : "pipe.and.drop"
        }
    }

    private static func updateIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "firmware":
            return dto.state == "on" ? "memorychip.fill" : "checkmark.circle"
        default:
            return dto.state == "on" ? "arrow.trianglehead.2.clockwise" : "checkmark.circle"
        }
    }

    private static func eventIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "doorbell":
            "bell.and.waves.left.and.right.fill"
        case "button":
            "button.programmable"
        case "motion":
            "figure.motion"
        default:
            "sensor.tag.radiowaves.forward.fill"
        }
    }

    private static func imageProcessingIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "alpr":
            "licenseplate.fill"
        case "face":
            "face.smiling"
        case "ocr":
            "text.viewfinder"
        default:
            "viewfinder"
        }
    }

    private static func alarmControlPanelIconName(state: String) -> String {
        switch state {
        case "disarmed":
            "shield"
        case "triggered":
            "exclamationmark.shield.fill"
        default:
            "shield.lefthalf.filled"
        }
    }

    private static func lawnMowerIconName(state: String) -> String {
        switch state {
        case "mowing":
            "leaf.fill"
        case "docked":
            "parkingsign.circle.fill"
        case "error":
            "exclamationmark.triangle.fill"
        default:
            "leaf"
        }
    }

    private static func weatherIconName(state: String) -> String {
        WeatherCondition(state: state).systemImage
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
        case "projector":
            return "videoprojector.fill"
        default:
            return "play.tv.fill"
        }
    }

    private static func sensorIconName(for dto: HAEntityDTO) -> String {
        switch dto.attributes["device_class"]?.stringValue {
        case "aqi":
            "aqi.medium"
        case "absolute_humidity":
            "humidity.fill"
        case "apparent_power", "reactive_power":
            "bolt.fill"
        case "area":
            "square.dashed"
        case "atmospheric_pressure":
            "barometer"
        case "temperature":
            "thermometer.medium"
        case "temperature_delta":
            "thermometer.variable"
        case "humidity":
            "humidity"
        case "battery":
            "battery.75percent"
        case "blood_glucose_concentration":
            "drop.degreesign.fill"
        case "carbon_dioxide":
            "carbon.dioxide.cloud.fill"
        case "carbon_monoxide":
            "carbon.monoxide.cloud.fill"
        case "conductivity":
            "waveform.path.ecg"
        case "data_size", "volume_storage":
            "externaldrive.fill"
        case "data_rate":
            "speedometer"
        case "date", "timestamp", "uptime":
            "calendar"
        case "distance":
            "ruler.fill"
        case "duration":
            "timer"
        case "enum":
            "list.bullet.rectangle.fill"
        case "energy":
            "bolt.circle.fill"
        case "energy_distance", "energy_storage", "reactive_energy":
            "bolt.batteryblock.fill"
        case "frequency":
            "waveform.path"
        case "monetary":
            "dollarsign.circle.fill"
        case "power":
            "bolt.fill"
        case "power_factor":
            "bolt.badge.clock.fill"
        case "illuminance":
            "sun.max.fill"
        case "irradiance":
            "sun.max.trianglebadge.exclamationmark.fill"
        case "moisture":
            "drop.fill"
        case "nitrogen_dioxide", "nitrogen_monoxide", "nitrous_oxide", "ozone", "pm1", "pm10", "pm25", "pm4", "sulphur_dioxide":
            "aqi.medium"
        case "ph":
            "testtube.2"
        case "precipitation", "precipitation_intensity":
            "cloud.rain.fill"
        case "pressure":
            "gauge.with.dots.needle.50percent"
        case "signal_strength":
            "wifi"
        case "sound_pressure":
            "speaker.wave.3.fill"
        case "speed", "wind_speed":
            "speedometer"
        case "voltage", "current":
            "waveform.path.ecg"
        case "volatile_organic_compounds", "volatile_organic_compounds_parts":
            "aqi.medium"
        case "volume", "volume_flow_rate":
            "cube.fill"
        case "water":
            "drop.fill"
        case "weight":
            "scalemass.fill"
        case "wind_direction":
            "location.north.line.fill"
        case "gas":
            "flame.fill"
        case "problem":
            "exclamationmark.triangle.fill"
        default:
            "gauge.medium"
        }
    }
}
