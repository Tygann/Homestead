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
            targetTemperature: dto.attributes["temperature"]?.doubleValue
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
        case .scene:
            "sparkles"
        case .script:
            "play.circle"
        case .other:
            "circle.hexagongrid"
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
