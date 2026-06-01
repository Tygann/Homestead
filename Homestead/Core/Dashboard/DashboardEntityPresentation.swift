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
    case toggleAutomation
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
        case .toggleAutomation:
            .stateToggle(domain: "automation", onService: "turn_on", offService: "turn_off")
        case .activateScene:
            .call(domain: "scene", service: "turn_on")
        case .runScript:
            .call(domain: "script", service: "turn_on")
        }
    }

    func accessibilityLabel(title: String, isActive: Bool) -> String {
        switch self {
        case .toggleLight, .toggleSwitch, .toggleFan, .toggleAutomation:
            "\(isActive ? "Turn off" : "Turn on") \(title)"
        case .toggleCover:
            "\(isActive ? "Close" : "Open") \(title)"
        case .toggleLock:
            "\(isActive ? "Unlock" : "Lock") \(title)"
        case .activateScene:
            "Activate \(title)"
        case .runScript:
            "Run \(title)"
        }
    }
}

enum DashboardEntityDetailKind: String, Equatable, Sendable {
    case light
    case cover
    case climate
    case fan
    case lock
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
    case setClimateFanMode
    case setClimatePresetMode
    case setFanPercentage
    case setFanPresetMode
    case playPause
    case setMediaVolume
    case selectMediaSource
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
                detailKind: .fan,
                statusFormatter: .onOff(unavailableTitle: "Fan unavailable"),
                iconAccentBehavior: .activeAccent,
                secondaryActions: [.setFanPercentage, .setFanPresetMode]
            )
        case .lock:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .control,
                primaryAction: nil,
                detailKind: .lock,
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
                secondaryActions: [
                    .setClimateTemperature,
                    .setClimateHVACMode,
                    .setClimateFanMode,
                    .setClimatePresetMode
                ]
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
                secondaryActions: [.playPause, .setMediaVolume, .selectMediaSource]
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
        case .automation:
            DashboardEntityDomainCapability(
                domain: domain,
                cardStyle: .control,
                primaryAction: .toggleAutomation,
                detailKind: .toggle,
                statusFormatter: .onOff(unavailableTitle: "Automation unavailable"),
                iconAccentBehavior: .activeAccent,
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

    init(
        entityBox: HAEntityState,
        displayNameOverride: String? = nil,
        iconNameOverride: String? = nil
    ) {
        let resolvedDisplayNameOverride = displayNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let overrideTitle = resolvedDisplayNameOverride?.isEmpty == false ? resolvedDisplayNameOverride : nil
        let resolvedIconNameOverride = iconNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let overrideIconName = resolvedIconNameOverride?.isEmpty == false ? resolvedIconNameOverride : nil
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

            title = overrideTitle ?? light.displayName
            subtitle = Self.lightSubtitle(
                isOn: effectiveIsOn,
                brightnessPercentage: brightnessPercentage,
                pendingCommand: pendingCommand
            )
            headline = effectiveIsOn ? brightnessPercentage.map { "\($0)%" } : nil
            iconName = overrideIconName ?? light.iconName
            isActive = effectiveIsOn
            isAvailable = true
            accentColor = Self.accentColor(for: effectiveIsOn, behavior: capability.iconAccentBehavior)
        } else if let sensor = entityBox.sensorEntity {
            title = overrideTitle ?? sensor.displayName
            subtitle = sensor.displaySubtitle
            headline = sensor.formattedValue
            iconName = overrideIconName ?? sensor.iconName
            isActive = sensor.isAlerting
            isAvailable = sensor.isAvailable
            accentColor = Self.sensorAccentColor(for: sensor, behavior: capability.iconAccentBehavior)
        } else if let binarySensor = entityBox.binarySensorEntity {
            title = overrideTitle ?? binarySensor.displayName
            subtitle = binarySensor.displaySubtitle
            headline = nil
            iconName = overrideIconName ?? binarySensor.iconName
            isActive = binarySensor.isActive
            isAvailable = binarySensor.isAvailable
            accentColor = Self.accentColor(for: binarySensor.isActive, behavior: capability.iconAccentBehavior)
        } else if let cover = entityBox.coverEntity {
            title = overrideTitle ?? cover.displayName
            subtitle = Self.coverSubtitle(cover, pendingCommand: pendingCommand)
            headline = cover.positionPercentage.map { "\($0)%" }
            iconName = overrideIconName ?? cover.iconName
            isActive = cover.isOpen
            isAvailable = entityBox.homeEntity.isAvailable
            accentColor = Self.accentColor(for: cover.isOpen, behavior: capability.iconAccentBehavior)
        } else if let climate = entityBox.climateEntity {
            title = overrideTitle ?? climate.displayName
            subtitle = Self.climateSubtitle(climate, pendingCommand: pendingCommand)
            headline = climate.targetTemperatureRangeText ?? climate.targetTemperatureText ?? climate.currentTemperatureText
            iconName = overrideIconName ?? entityBox.homeEntity.iconName
            isActive = climate.isActive
            isAvailable = entityBox.homeEntity.isAvailable
            accentColor = Self.climateAccentColor(for: climate, behavior: capability.iconAccentBehavior)
        } else if let fan = entityBox.fanEntity {
            let effectiveIsOn = pendingCommand?.expectedState.map { $0 == "on" } ?? fan.isOn
            let percentage = pendingCommand?.expectedAttributes["percentage"]?.intValue ?? fan.percentage

            title = overrideTitle ?? fan.displayName
            subtitle = Self.fanSubtitle(
                fan,
                isOn: effectiveIsOn,
                percentage: percentage,
                pendingCommand: pendingCommand
            )
            headline = effectiveIsOn ? percentage.map { "\($0)%" } : nil
            iconName = overrideIconName ?? entityBox.homeEntity.iconName
            isActive = effectiveIsOn
            isAvailable = fan.isAvailable
            accentColor = Self.accentColor(for: effectiveIsOn, behavior: capability.iconAccentBehavior)
        } else if let mediaPlayer = entityBox.mediaPlayerEntity {
            title = overrideTitle ?? mediaPlayer.displayName
            subtitle = Self.mediaPlayerSubtitle(mediaPlayer, pendingCommand: pendingCommand)
            headline = mediaPlayer.nowPlayingText
            iconName = overrideIconName ?? entityBox.homeEntity.iconName
            isActive = mediaPlayer.isPlaying
            isAvailable = mediaPlayer.isAvailable
            accentColor = Self.accentColor(for: mediaPlayer.isPlaying, behavior: capability.iconAccentBehavior)
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
            title = overrideTitle ?? entity.displayName
            subtitle = pendingCommand == nil ? Self.subtitle(for: effectiveEntity, capability: capability) : Self.pendingSubtitle(for: effectiveEntity, capability: capability)
            headline = Self.headline(for: effectiveEntity, capability: capability)
            iconName = overrideIconName ?? effectiveEntity.iconName
            isActive = Self.isActive(effectiveEntity, capability: capability)
            isAvailable = entity.isAvailable
            accentColor = Self.accentColor(for: effectiveEntity, capability: capability)
        }
    }

    var accessibilityValue: String {
        subtitle
    }

    var accessibilityDetailLabel: String {
        "Open \(title) details"
    }

    var accessibilityDetailHint: String {
        "Shows controls and Home Assistant state."
    }

    var primaryActionAccessibilityLabel: String? {
        primaryAction?.accessibilityLabel(title: title, isActive: isActive)
    }

    var primaryActionAccessibilityHint: String {
        "Sends the action to Home Assistant."
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

            if let fanMode = pendingCommand.expectedAttributes["fan_mode"]?.stringValue {
                return "Setting fan to \(climate.displayName(forFanMode: fanMode))..."
            }

            if let presetMode = pendingCommand.expectedAttributes["preset_mode"]?.stringValue {
                return "Setting \(climate.displayName(forPresetMode: presetMode))..."
            }

            if let expectedState = pendingCommand.expectedState {
                return "Switching to \(climate.displayName(forHVACMode: expectedState))..."
            }

            return "Updating..."
        }

        return climate.displaySubtitle
    }

    private static func fanSubtitle(
        _ fan: FanEntity,
        isOn: Bool,
        percentage: Int?,
        pendingCommand: HAEntityPendingCommand?
    ) -> String {
        if let pendingCommand {
            if let percentage {
                return "Setting \(percentage)%..."
            }

            if let presetMode = pendingCommand.expectedAttributes["preset_mode"]?.stringValue {
                return "Setting \(fan.displayName(forPresetMode: presetMode))..."
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
        guard let percentage else { return fan.displaySubtitle }

        return "\(percentage)%"
    }

    private static func mediaPlayerSubtitle(
        _ mediaPlayer: MediaPlayerEntity,
        pendingCommand: HAEntityPendingCommand?
    ) -> String {
        if let pendingCommand {
            if let volumeLevel = pendingCommand.expectedAttributes["volume_level"]?.doubleValue {
                return "Setting volume \(Int((volumeLevel * 100).rounded()))%..."
            }

            if let source = pendingCommand.expectedAttributes["source"]?.stringValue {
                return "Switching to \(source)..."
            }

            return "Updating..."
        }

        return mediaPlayer.displaySubtitle
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
        case .toggleSwitch, .toggleFan, .toggleLock, .toggleAutomation:
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

struct DashboardEntityCardMetric: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
    let systemImage: String

    init(title: String, value: String, systemImage: String) {
        self.id = "\(title)-\(value)-\(systemImage)"
        self.title = title
        self.value = value
        self.systemImage = systemImage
    }
}

struct DashboardEntityCardContentModel: Equatable, Sendable {
    let headline: String?
    let metrics: [DashboardEntityCardMetric]

    static func make(
        presentation: DashboardEntityPresentation,
        size: DashboardCardSize
    ) -> DashboardEntityCardContentModel {
        guard size.supportsExtendedDashboardContent else {
            return DashboardEntityCardContentModel(
                headline: presentation.headline,
                metrics: []
            )
        }

        let metrics = extendedMetrics(for: presentation)
        return DashboardEntityCardContentModel(
            headline: presentation.headline,
            metrics: Array(metrics.prefix(size.maximumDashboardMetricCount))
        )
    }

    private static func extendedMetrics(for presentation: DashboardEntityPresentation) -> [DashboardEntityCardMetric] {
        let statusMetric = DashboardEntityCardMetric(
            title: statusTitle(for: presentation),
            value: statusValue(for: presentation),
            systemImage: statusSystemImage(for: presentation)
        )

        var metrics = [statusMetric]

        if let headline = presentation.headline, headline != statusMetric.value {
            metrics.append(
                DashboardEntityCardMetric(
                    title: headlineTitle(for: presentation),
                    value: headline,
                    systemImage: headlineSystemImage(for: presentation)
                )
            )
        }

        if let actionTitle = actionTitle(for: presentation) {
            metrics.append(
                DashboardEntityCardMetric(
                    title: "Action",
                    value: actionTitle,
                    systemImage: "hand.tap"
                )
            )
        }

        return metrics
    }

    private static func statusTitle(for presentation: DashboardEntityPresentation) -> String {
        switch presentation.capability.domain {
        case .climate:
            "Mode"
        case .sensor, .binarySensor:
            "Reading"
        case .mediaPlayer:
            "Now"
        case .scene:
            "Scene"
        case .script:
            "Script"
        default:
            "Status"
        }
    }

    private static func statusValue(for presentation: DashboardEntityPresentation) -> String {
        switch presentation.capability.domain {
        case .light, .fan, .switch, .automation:
            return presentation.isActive ? "On" : "Off"
        case .cover:
            return presentation.isActive ? "Open" : "Closed"
        case .lock:
            return presentation.isActive ? "Locked" : "Unlocked"
        default:
            return presentation.subtitle
        }
    }

    private static func statusSystemImage(for presentation: DashboardEntityPresentation) -> String {
        switch presentation.capability.domain {
        case .climate:
            "thermometer.medium"
        case .sensor, .binarySensor:
            "gauge.medium"
        case .mediaPlayer:
            "play.tv"
        case .camera:
            "camera"
        case .vacuum:
            "washer"
        case .scene, .script:
            "sparkles"
        default:
            "circle.fill"
        }
    }

    private static func headlineTitle(for presentation: DashboardEntityPresentation) -> String {
        switch presentation.capability.domain {
        case .light, .fan, .cover:
            "Level"
        case .climate:
            "Setpoint"
        case .sensor, .binarySensor:
            "Value"
        case .scene, .script:
            "Command"
        default:
            "Detail"
        }
    }

    private static func headlineSystemImage(for presentation: DashboardEntityPresentation) -> String {
        switch presentation.capability.domain {
        case .light:
            "slider.horizontal.below.sun.max"
        case .fan:
            "fan"
        case .cover:
            "arrow.up.and.down"
        case .climate:
            "target"
        case .sensor, .binarySensor:
            "number"
        case .scene, .script:
            "play.circle"
        default:
            "text.alignleft"
        }
    }

    private static func actionTitle(for presentation: DashboardEntityPresentation) -> String? {
        guard presentation.isAvailable else {
            return nil
        }

        if let label = presentation.primaryActionAccessibilityLabel {
            return label
        }

        switch presentation.capability.domain {
        case .camera, .climate, .lock, .mediaPlayer, .sensor, .binarySensor, .vacuum:
            return "Open details"
        case .light, .cover, .switch, .fan, .scene, .script, .automation, .other:
            return nil
        }
    }
}

private extension DashboardCardSize {
    var supportsExtendedDashboardContent: Bool {
        switch self {
        case .wide, .large:
            true
        case .mini, .compact, .row, .square:
            false
        }
    }

    var maximumDashboardMetricCount: Int {
        switch self {
        case .wide:
            1
        case .large:
            3
        case .mini, .compact, .row, .square:
            0
        }
    }
}
