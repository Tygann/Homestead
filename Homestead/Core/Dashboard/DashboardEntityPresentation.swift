import SwiftUI

enum DashboardEntityPrimaryAction: Equatable, Sendable {
    case toggleLight
    case toggleCover
    case toggleSwitch
    case toggleFan
    case toggleLock
    case activateScene
    case runScript
}

enum DashboardEntityDetailKind: String, Equatable, Sendable {
    case light
    case cover
    case climate
    case toggle
    case lock
    case action
    case entity
}

struct DashboardEntityPresentation {
    let title: String
    let subtitle: String
    let headline: String?
    let iconName: String
    let isActive: Bool
    let isAvailable: Bool
    let accentColor: Color
    let isPending: Bool
    let primaryAction: DashboardEntityPrimaryAction?
    let detailKind: DashboardEntityDetailKind
    let supportsFavorite: Bool

    init(entityBox: HAEntityState) {
        let pendingCommand = entityBox.pendingCommand
        isPending = pendingCommand != nil
        primaryAction = Self.primaryAction(for: entityBox)
        detailKind = Self.detailKind(for: entityBox)
        supportsFavorite = entityBox.domain != .other

        if let light = entityBox.lightEntity {
            let effectiveIsOn = pendingCommand?.expectedState.map { $0 == "on" } ?? light.isOn
            let brightnessPercentage = Self.pendingBrightnessPercentage(from: pendingCommand) ?? light.brightnessPercentage

            title = light.displayName
            subtitle = Self.lightSubtitle(
                isOn: effectiveIsOn,
                brightnessPercentage: brightnessPercentage,
                pendingCommand: pendingCommand
            )
            headline = effectiveIsOn ? brightnessPercentage.map { "\($0)%" } : nil
            iconName = light.iconName
            isActive = effectiveIsOn
            isAvailable = true
            accentColor = .accentColor
        } else if let sensor = entityBox.sensorEntity {
            title = sensor.displayName
            subtitle = sensor.displaySubtitle
            headline = sensor.formattedValue
            iconName = sensor.iconName
            isActive = sensor.isAlerting
            isAvailable = sensor.isAvailable
            accentColor = Self.sensorAccentColor(for: sensor)
        } else if let cover = entityBox.coverEntity {
            title = cover.displayName
            subtitle = Self.coverSubtitle(cover, pendingCommand: pendingCommand)
            headline = cover.positionPercentage.map { "\($0)%" }
            iconName = entityBox.homeEntity.iconName
            isActive = cover.isOpen
            isAvailable = entityBox.homeEntity.isAvailable
            accentColor = .accentColor
        } else if let climate = entityBox.climateEntity {
            title = climate.displayName
            subtitle = Self.climateSubtitle(climate, pendingCommand: pendingCommand)
            headline = climate.targetTemperatureText ?? climate.currentTemperatureText
            iconName = entityBox.homeEntity.iconName
            isActive = climate.isActive
            isAvailable = entityBox.homeEntity.isAvailable
            accentColor = Self.climateAccentColor(for: climate)
        } else {
            let entity = entityBox.homeEntity
            let effectiveEntity = pendingCommand.map {
                HomeEntity(
                    entityID: entity.entityID,
                    domain: entity.domain,
                    displayName: entity.displayName,
                    state: $0.expectedState ?? entity.state,
                    iconName: entity.iconName,
                    isAvailable: entity.isAvailable,
                    lastUpdated: entity.lastUpdated
                )
            } ?? entity
            title = entity.displayName
            subtitle = pendingCommand == nil ? Self.subtitle(for: effectiveEntity) : Self.pendingSubtitle(for: effectiveEntity)
            headline = Self.headline(for: effectiveEntity)
            iconName = effectiveEntity.iconName
            isActive = Self.isActive(effectiveEntity)
            isAvailable = entity.isAvailable
            accentColor = Self.accentColor(for: effectiveEntity)
        }
    }

    var accessibilityValue: String {
        subtitle
    }

    var subtitleColor: Color {
        guard isAvailable else { return .red }
        return .secondary
    }

    var headlineColor: Color {
        guard isAvailable else { return .secondary }
        return accentColor
    }

    private static func primaryAction(for entityBox: HAEntityState) -> DashboardEntityPrimaryAction? {
        guard entityBox.homeEntity.isAvailable else { return nil }

        switch entityBox.domain {
        case .light:
            return .toggleLight
        case .cover:
            return .toggleCover
        case .switch:
            return .toggleSwitch
        case .fan:
            return .toggleFan
        case .lock:
            return .toggleLock
        case .scene:
            return .activateScene
        case .script:
            return .runScript
        case .climate, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .other:
            return nil
        }
    }

    private static func detailKind(for entityBox: HAEntityState) -> DashboardEntityDetailKind {
        if entityBox.lightEntity != nil {
            return .light
        }

        if entityBox.coverEntity != nil {
            return .cover
        }

        if entityBox.climateEntity != nil {
            return .climate
        }

        switch entityBox.domain {
        case .switch, .fan:
            return .toggle
        case .lock:
            return .lock
        case .scene, .script:
            return .action
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .other:
            break
        }

        return .entity
    }

    private static func lightSubtitle(
        isOn: Bool,
        brightnessPercentage: Int?,
        pendingCommand: HAEntityPendingCommand?
    ) -> String {
        if let pendingCommand {
            if let brightnessPercentage {
                return "Setting \(brightnessPercentage)%..."
            }

            switch pendingCommand.expectedState {
            case "on":
                return "Turning On..."
            case "off":
                return "Turning Off..."
            default:
                return "Updating..."
            }
        }

        guard isOn else { return "Off" }
        guard let brightnessPercentage else { return "On" }

        return "\(brightnessPercentage)%"
    }

    private static func pendingBrightnessPercentage(from pendingCommand: HAEntityPendingCommand?) -> Int? {
        guard let brightness = pendingCommand?.expectedAttributes["brightness"]?.doubleValue else {
            return nil
        }

        let percentage = Int((brightness / 255.0) * 100.0)
        return min(max(percentage, 1), 100)
    }

    private static func coverSubtitle(
        _ cover: CoverEntity,
        pendingCommand: HAEntityPendingCommand?
    ) -> String {
        if let pendingCommand {
            if let position = pendingCommand.expectedAttributes["current_position"]?.doubleValue {
                return "Moving to \(Int(position.rounded()))%..."
            }

            switch pendingCommand.expectedState {
            case "open":
                return "Opening..."
            case "closed":
                return "Closing..."
            default:
                return "Updating..."
            }
        }

        return cover.displaySubtitle
    }

    private static func climateSubtitle(
        _ climate: ClimateEntity,
        pendingCommand: HAEntityPendingCommand?
    ) -> String {
        if let pendingCommand {
            if let temperature = pendingCommand.expectedAttributes["temperature"]?.doubleValue {
                return "Setting \(climate.formatTemperature(temperature))..."
            }

            if let expectedState = pendingCommand.expectedState {
                return "Switching to \(climate.displayName(forHVACMode: expectedState))..."
            }

            return "Updating..."
        }

        return climate.displaySubtitle
    }

    private static func subtitle(for entity: HomeEntity) -> String {
        switch entity.domain {
        case .scene:
            entity.isAvailable ? "Scene" : "Scene unavailable"
        case .script:
            if !entity.isAvailable {
                "Script unavailable"
            } else if entity.state == "on" {
                "Running"
            } else {
                "Script"
            }
        case .binarySensor:
            entity.isAvailable ? binarySensorSubtitle(for: entity) : "Sensor unavailable"
        case .switch:
            entity.isAvailable ? onOffSubtitle(for: entity, onTitle: "On", offTitle: "Off") : "Switch unavailable"
        case .fan:
            entity.isAvailable ? onOffSubtitle(for: entity, onTitle: "On", offTitle: "Off") : "Fan unavailable"
        case .lock:
            entity.isAvailable ? lockSubtitle(for: entity) : "Lock unavailable"
        case .mediaPlayer:
            entity.isAvailable ? mediaPlayerSubtitle(for: entity) : "Media player unavailable"
        case .camera:
            entity.isAvailable ? "Camera" : "Camera unavailable"
        case .vacuum:
            entity.isAvailable ? entity.state.replacingOccurrences(of: "_", with: " ").capitalized : "Vacuum unavailable"
        case .light, .climate, .cover, .sensor, .other:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func pendingSubtitle(for entity: HomeEntity) -> String {
        switch entity.domain {
        case .switch, .fan, .lock:
            "Updating..."
        case .scene, .script, .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .other:
            subtitle(for: entity)
        }
    }

    private static func headline(for entity: HomeEntity) -> String? {
        switch entity.domain {
        case .scene, .script:
            entity.isAvailable ? "Run" : nil
        case .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .binarySensor:
            nil
        case .light, .climate, .cover, .sensor, .other:
            nil
        }
    }

    private static func isActive(_ entity: HomeEntity) -> Bool {
        switch entity.domain {
        case .script:
            entity.state == "on"
        case .scene:
            false
        case .lock:
            entity.state == "unlocked" || entity.state == "unlocking"
        case .mediaPlayer:
            entity.state == "playing"
        case .vacuum:
            entity.state == "cleaning"
        case .camera:
            false
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .other:
            entity.state == "on" || entity.state == "open"
        }
    }

    private static func accentColor(for entity: HomeEntity) -> Color {
        switch entity.domain {
        case .scene:
            .purple
        case .script:
            .accentColor
        case .lock:
            entity.state == "unlocked" ? .orange : .accentColor
        case .mediaPlayer:
            entity.state == "playing" ? .green : .accentColor
        case .camera:
            .blue
        case .vacuum:
            entity.state == "cleaning" ? .green : .accentColor
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .other:
            .accentColor
        }
    }

    private static func onOffSubtitle(for entity: HomeEntity, onTitle: String, offTitle: String) -> String {
        switch entity.state {
        case "on":
            onTitle
        case "off":
            offTitle
        default:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func lockSubtitle(for entity: HomeEntity) -> String {
        switch entity.state {
        case "locked":
            "Locked"
        case "unlocked":
            "Unlocked"
        case "locking":
            "Locking"
        case "unlocking":
            "Unlocking"
        default:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func mediaPlayerSubtitle(for entity: HomeEntity) -> String {
        switch entity.state {
        case "playing":
            "Playing"
        case "paused":
            "Paused"
        case "idle":
            "Idle"
        case "standby":
            "Standby"
        case "off":
            "Off"
        default:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func binarySensorSubtitle(for entity: HomeEntity) -> String {
        switch entity.state {
        case "on":
            "Detected"
        case "off":
            "Clear"
        default:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func sensorAccentColor(for sensor: SensorEntity) -> Color {
        guard sensor.isAvailable else { return .secondary }
        guard !sensor.isAlerting else { return .red }

        switch sensor.displayKind {
        case .temperature:
            return .orange
        case .humidity, .water:
            return .cyan
        case .battery:
            return .green
        case .energy, .power, .voltage, .current, .illuminance:
            return .yellow
        case .pressure:
            return .purple
        case .signal:
            return .blue
        case .gas:
            return .orange
        case .problem:
            return .red
        case .generic:
            return .accentColor
        }
    }

    private static func climateAccentColor(for climate: ClimateEntity) -> Color {
        switch climate.state {
        case "heat":
            return .orange
        case "cool":
            return .cyan
        case "off":
            return .secondary
        default:
            return .accentColor
        }
    }
}
