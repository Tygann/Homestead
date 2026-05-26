import SwiftUI

enum DashboardEntityPrimaryAction: Equatable, Sendable {
    case toggleLight
    case toggleCover
    case activateScene
    case runScript
}

enum DashboardEntityDetailKind: String, Equatable, Sendable {
    case light
    case cover
    case climate
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
            title = entity.displayName
            subtitle = Self.subtitle(for: entity)
            headline = Self.headline(for: entity)
            iconName = entity.iconName
            isActive = Self.isActive(entity)
            isAvailable = entity.isAvailable
            accentColor = Self.accentColor(for: entity)
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
        case .scene:
            return .activateScene
        case .script:
            return .runScript
        case .climate, .sensor, .other:
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
        case .light, .climate, .cover, .sensor, .other:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func headline(for entity: HomeEntity) -> String? {
        switch entity.domain {
        case .scene, .script:
            entity.isAvailable ? "Run" : nil
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
        case .light, .climate, .cover, .sensor, .other:
            entity.state == "on" || entity.state == "open"
        }
    }

    private static func accentColor(for entity: HomeEntity) -> Color {
        switch entity.domain {
        case .scene:
            .purple
        case .script:
            .accentColor
        case .light, .climate, .cover, .sensor, .other:
            .accentColor
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
