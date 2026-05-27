import SwiftUI

enum DashboardEntityCardStyle: String, Equatable, Sendable {
    case control
    case value
    case action
    case media
    case camera
    case status
    case generic
}

enum DashboardEntityPrimaryAction: Equatable, Sendable {
    case toggleLight
    case toggleCover
    case toggleSwitch
    case toggleFan
    case toggleLock
    case activateScene
    case runScript

    var serviceIntent: DashboardEntityServiceIntent {
        switch self {
        case .toggleLight:
            .stateToggle(domain: "light", onService: "turn_on", offService: "turn_off")
        case .toggleCover:
            .coverToggle
        case .toggleSwitch:
            .stateToggle(domain: "switch", onService: "turn_on", offService: "turn_off")
        case .toggleFan:
            .stateToggle(domain: "fan", onService: "turn_on", offService: "turn_off")
        case .toggleLock:
            .lockToggle
        case .activateScene:
            .call(domain: "scene", service: "turn_on")
        case .runScript:
            .call(domain: "script", service: "turn_on")
        }
    }
}

enum DashboardEntityDetailKind: String, Equatable, Sendable {
    case light
    case cover
    case climate
    case toggle
    case action
    case sensor
    case mediaPlayer
    case camera
    case vacuum
    case entity
}

enum DashboardEntitySecondaryAction: String, Equatable, Sendable {
    case setBrightness
    case openCover
    case closeCover
    case stopCover
    case setCoverPosition
    case setClimateTemperature
    case setClimateHVACMode
    case playPause
    case returnToBase
    case startCleaning
    case stopCleaning
}

enum DashboardEntityServiceIntent: Equatable, Sendable {
    case stateToggle(domain: String, onService: String, offService: String)
    case coverToggle
    case lockToggle
    case call(domain: String, service: String)
}

enum DashboardEntityStatusFormatter: Equatable, Sendable {
    case light
    case cover
    case climate
    case sensor
    case binarySensor
    case onOff(unavailableTitle: String)
    case lock
    case mediaPlayer
    case camera
    case vacuum
    case action(kind: String, unavailableTitle: String)
    case rawState
}

enum DashboardEntityIconAccentBehavior: Equatable, Sendable {
    case activeAccent
    case sensorKind
    case climateMode
    case lockState
    case mediaState
    case camera
    case vacuumState
    case actionAccent
    case defaultAccent
}

struct DashboardEntityDomainCapability: Equatable, Sendable {
    let domain: EntityDomain
    let cardStyle: DashboardEntityCardStyle
    let primaryAction: DashboardEntityPrimaryAction?
    let detailKind: DashboardEntityDetailKind
    let statusFormatter: DashboardEntityStatusFormatter
    let iconAccentBehavior: DashboardEntityIconAccentBehavior
    let secondaryActions: [DashboardEntitySecondaryAction]

    var primaryServiceIntent: DashboardEntityServiceIntent? {
        primaryAction?.serviceIntent
    }
}

enum DashboardEntityDomainRegistry {
    static func capability(for domain: EntityDomain) -> DashboardEntityDomainCapability {
        switch domain {
        case .light:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .control,
                primaryAction: .toggleLight,
                detailKind: .light,
                statusFormatter: .light,
                iconAccentBehavior: .activeAccent,
                secondaryActions: [.setBrightness]
            )
        case .switch:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .control,
                primaryAction: .toggleSwitch,
                detailKind: .toggle,
                statusFormatter: .onOff(unavailableTitle: "Switch unavailable"),
                iconAccentBehavior: .activeAccent,
                secondaryActions: []
            )
        case .fan:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .control,
                primaryAction: .toggleFan,
                detailKind: .toggle,
                statusFormatter: .onOff(unavailableTitle: "Fan unavailable"),
                iconAccentBehavior: .activeAccent,
                secondaryActions: []
            )
        case .lock:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .control,
                primaryAction: .toggleLock,
                detailKind: .toggle,
                statusFormatter: .lock,
                iconAccentBehavior: .lockState,
                secondaryActions: []
            )
        case .cover:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .control,
                primaryAction: .toggleCover,
                detailKind: .cover,
                statusFormatter: .cover,
                iconAccentBehavior: .activeAccent,
                secondaryActions: [.openCover, .closeCover, .stopCover, .setCoverPosition]
            )
        case .climate:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .status,
                primaryAction: nil,
                detailKind: .climate,
                statusFormatter: .climate,
                iconAccentBehavior: .climateMode,
                secondaryActions: [.setClimateTemperature, .setClimateHVACMode]
            )
        case .sensor:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .value,
                primaryAction: nil,
                detailKind: .sensor,
                statusFormatter: .sensor,
                iconAccentBehavior: .sensorKind,
                secondaryActions: []
            )
        case .binarySensor:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .status,
                primaryAction: nil,
                detailKind: .sensor,
                statusFormatter: .binarySensor,
                iconAccentBehavior: .activeAccent,
                secondaryActions: []
            )
        case .mediaPlayer:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .media,
                primaryAction: nil,
                detailKind: .mediaPlayer,
                statusFormatter: .mediaPlayer,
                iconAccentBehavior: .mediaState,
                secondaryActions: [.playPause]
            )
        case .camera:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .camera,
                primaryAction: nil,
                detailKind: .camera,
                statusFormatter: .camera,
                iconAccentBehavior: .camera,
                secondaryActions: []
            )
        case .scene:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .action,
                primaryAction: .activateScene,
                detailKind: .action,
                statusFormatter: .action(kind: "Scene", unavailableTitle: "Scene unavailable"),
                iconAccentBehavior: .actionAccent,
                secondaryActions: []
            )
        case .script:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .action,
                primaryAction: .runScript,
                detailKind: .action,
                statusFormatter: .action(kind: "Script", unavailableTitle: "Script unavailable"),
                iconAccentBehavior: .actionAccent,
                secondaryActions: []
            )
        case .vacuum:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .status,
                primaryAction: nil,
                detailKind: .vacuum,
                statusFormatter: .vacuum,
                iconAccentBehavior: .vacuumState,
                secondaryActions: [.startCleaning, .stopCleaning, .returnToBase]
            )
        case .other:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .generic,
                primaryAction: nil,
                detailKind: .entity,
                statusFormatter: .rawState,
                iconAccentBehavior: .defaultAccent,
                secondaryActions: []
            )
        }
    }
}

struct DashboardEntityPresentation {
    let capability: DashboardEntityDomainCapability
    let cardStyle: DashboardEntityCardStyle
    let title: String
    let subtitle: String
    let headline: String?
    let iconName: String
    let isActive: Bool
    let isAvailable: Bool
    let accentColor: Color
    let isPending: Bool
    let primaryAction: DashboardEntityPrimaryAction?
    let primaryServiceIntent: DashboardEntityServiceIntent?
    let detailKind: DashboardEntityDetailKind
    let secondaryActions: [DashboardEntitySecondaryAction]
    let supportsFavorite: Bool

    init(entityBox: HAEntityState) {
        let pendingCommand = entityBox.pendingCommand
        let capability = DashboardEntityDomainRegistry.capability(for: entityBox.domain)
        self.capability = capability
        cardStyle = capability.cardStyle
        isPending = pendingCommand != nil
        primaryAction = entityBox.homeEntity.isAvailable ? capability.primaryAction : nil
        primaryServiceIntent = entityBox.homeEntity.isAvailable ? capability.primaryServiceIntent : nil
        detailKind = capability.detailKind
        secondaryActions = capability.secondaryActions
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
            accentColor = Self.accentColor(for: effectiveIsOn, behavior: capability.iconAccentBehavior)
        } else if let sensor = entityBox.sensorEntity {
            title = sensor.displayName
            subtitle = sensor.displaySubtitle
            headline = sensor.formattedValue
            iconName = sensor.iconName
            isActive = sensor.isAlerting
            isAvailable = sensor.isAvailable
            accentColor = Self.sensorAccentColor(for: sensor, behavior: capability.iconAccentBehavior)
        } else if let cover = entityBox.coverEntity {
            title = cover.displayName
            subtitle = Self.coverSubtitle(cover, pendingCommand: pendingCommand)
            headline = cover.positionPercentage.map { "\($0)%" }
            iconName = entityBox.homeEntity.iconName
            isActive = cover.isOpen
            isAvailable = entityBox.homeEntity.isAvailable
            accentColor = Self.accentColor(for: cover.isOpen, behavior: capability.iconAccentBehavior)
        } else if let climate = entityBox.climateEntity {
            title = climate.displayName
            subtitle = Self.climateSubtitle(climate, pendingCommand: pendingCommand)
            headline = climate.targetTemperatureText ?? climate.currentTemperatureText
            iconName = entityBox.homeEntity.iconName
            isActive = climate.isActive
            isAvailable = entityBox.homeEntity.isAvailable
            accentColor = Self.climateAccentColor(for: climate, behavior: capability.iconAccentBehavior)
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
            subtitle = pendingCommand == nil ? Self.subtitle(for: effectiveEntity, capability: capability) : Self.pendingSubtitle(for: effectiveEntity, capability: capability)
            headline = Self.headline(for: effectiveEntity, capability: capability)
            iconName = effectiveEntity.iconName
            isActive = Self.isActive(effectiveEntity, capability: capability)
            isAvailable = entity.isAvailable
            accentColor = Self.accentColor(for: effectiveEntity, capability: capability)
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

    private static func subtitle(
        for entity: HomeEntity,
        capability: DashboardEntityDomainCapability
    ) -> String {
        switch capability.statusFormatter {
        case .action(let kind, let unavailableTitle):
            if !entity.isAvailable {
                unavailableTitle
            } else if entity.domain == .script, entity.state == "on" {
                "Running"
            } else {
                kind
            }
        case .binarySensor:
            entity.isAvailable ? binarySensorSubtitle(for: entity) : "Sensor unavailable"
        case .onOff(let unavailableTitle):
            entity.isAvailable ? onOffSubtitle(for: entity, onTitle: "On", offTitle: "Off") : unavailableTitle
        case .lock:
            entity.isAvailable ? lockSubtitle(for: entity) : "Lock unavailable"
        case .mediaPlayer:
            entity.isAvailable ? mediaPlayerSubtitle(for: entity) : "Media player unavailable"
        case .camera:
            entity.isAvailable ? "Camera" : "Camera unavailable"
        case .vacuum:
            entity.isAvailable ? entity.state.replacingOccurrences(of: "_", with: " ").capitalized : "Vacuum unavailable"
        case .light, .cover, .climate, .sensor, .rawState:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func pendingSubtitle(
        for entity: HomeEntity,
        capability: DashboardEntityDomainCapability
    ) -> String {
        switch capability.primaryAction {
        case .toggleSwitch, .toggleFan, .toggleLock:
            "Updating..."
        case .toggleLight, .toggleCover, .activateScene, .runScript, nil:
            subtitle(for: entity, capability: capability)
        }
    }

    private static func headline(
        for entity: HomeEntity,
        capability: DashboardEntityDomainCapability
    ) -> String? {
        switch capability.cardStyle {
        case .action:
            entity.isAvailable ? "Run" : nil
        case .control, .value, .media, .camera, .status, .generic:
            nil
        }
    }

    private static func isActive(
        _ entity: HomeEntity,
        capability: DashboardEntityDomainCapability
    ) -> Bool {
        switch capability.iconAccentBehavior {
        case .lockState:
            return entity.state == "unlocked" || entity.state == "unlocking"
        case .mediaState:
            return entity.state == "playing"
        case .vacuumState:
            return entity.state == "cleaning"
        case .camera, .actionAccent:
            return entity.domain == .script && entity.state == "on"
        case .activeAccent, .sensorKind, .climateMode, .defaultAccent:
            return entity.state == "on" || entity.state == "open"
        }
    }

    private static func accentColor(
        for entity: HomeEntity,
        capability: DashboardEntityDomainCapability
    ) -> Color {
        switch capability.iconAccentBehavior {
        case .actionAccent:
            entity.domain == .scene ? .purple : .accentColor
        case .lockState:
            entity.state == "unlocked" ? .orange : .accentColor
        case .mediaState, .vacuumState:
            isActive(entity, capability: capability) ? .green : .accentColor
        case .camera:
            .blue
        case .activeAccent, .sensorKind, .climateMode, .defaultAccent:
            .accentColor
        }
    }

    private static func accentColor(
        for isActive: Bool,
        behavior: DashboardEntityIconAccentBehavior
    ) -> Color {
        switch behavior {
        case .mediaState where isActive:
            return .green
        case .vacuumState where isActive:
            return .green
        case .lockState where isActive:
            return .orange
        case .camera:
            return .blue
        case .actionAccent:
            return .purple
        case .activeAccent, .sensorKind, .climateMode, .defaultAccent, .mediaState, .vacuumState, .lockState:
            return .accentColor
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

    private static func sensorAccentColor(
        for sensor: SensorEntity,
        behavior: DashboardEntityIconAccentBehavior
    ) -> Color {
        guard sensor.isAvailable else { return .secondary }
        guard behavior == .sensorKind else { return .accentColor }
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

    private static func climateAccentColor(
        for climate: ClimateEntity,
        behavior: DashboardEntityIconAccentBehavior
    ) -> Color {
        guard behavior == .climateMode else { return .accentColor }

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
