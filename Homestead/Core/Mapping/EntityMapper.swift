import Foundation

enum EntityMapper {
    // MARK: - Public API

    static func homeEntity(
        from dto: HAEntityDTO,
        resolvedIcon: ResolvedIcon? = nil
    ) -> HomeEntity {
        let domain = EntityDomain(entityID: dto.entityID)
        let icon = resolvedIcon ?? IconResolver.resolveEntity(
            EntityIconResolutionInput(
                domain: domain.rawValue,
                deviceClass: dto.attributes["device_class"]?.stringValue,
                state: dto.state,
                explicitIcon: dto.attributes["icon"]?.stringValue
            )
        )

        return HomeEntity(
            entityID: dto.entityID,
            domain: domain,
            displayName: displayName(for: dto),
            state: dto.state,
            resolvedIcon: icon,
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
            deviceClass: dto.attributes["device_class"]?.stringValue
        )
    }

    static func coverEntity(from dto: HAEntityDTO) -> CoverEntity? {
        guard EntityDomain(entityID: dto.entityID) == .cover else { return nil }

        return CoverEntity(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            state: dto.state,
            position: dto.attributes["current_position"]?.intValue,
            deviceClass: dto.attributes["device_class"]?.stringValue
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

    // MARK: - Helpers

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

}
