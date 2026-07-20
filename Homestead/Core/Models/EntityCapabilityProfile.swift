import Foundation

/// The stable family grammar used to compose entity detail experiences.
///
/// Families describe the interaction model, not the Home Assistant domain. A
/// new domain should join an existing family whenever its detail anatomy and
/// state behavior already fit.
nonisolated enum EntityDetailFamily: String, CaseIterable, Equatable, Sendable {
    case metric
    case simpleControl
    case positionalSecurity
    case environmental
    case mediaVisual
    case autonomousAppliance
    case actionWorkflow
    case editableValue
    case informationContent
    case generic
}

nonisolated enum EntityDetailHeroKind: String, Equatable, Sendable {
    case status
    case metric
    case environment
    case media
    case activity
    case progress
}

/// Surface-neutral routes. Dashboard code adapts these to its legacy detail
/// kind while detail presentation routes from this source directly.
nonisolated enum EntityDetailRoute: String, Equatable, Sendable {
    case light
    case cover
    case climate
    case fan
    case lock
    case toggle
    case action
    case automation
    case sensor
    case mediaPlayer
    case camera
    case vacuum
    case weather
    case alarmControlPanel
    case button
    case select
    case number
    case generic
}

nonisolated enum EntityCapability: String, Hashable, Sendable {
    case toggle
    case activate
    case setLevel
    case setPosition
    case setTemperature
    case chooseMode
    case chooseOption
    case playMedia
    case showMedia
    case startStop
    case returnToBase
    case secureAccess
    case showHistory
    case showActivity
    case editValue
}

nonisolated struct EntityCapabilityProfile: Equatable, Sendable {
    let domain: EntityDomain
    let family: EntityDetailFamily
    let heroKind: EntityDetailHeroKind
    let detailRoute: EntityDetailRoute
    let categoryTitle: String
    let capabilities: Set<EntityCapability>

    func supports(_ capability: EntityCapability) -> Bool {
        capabilities.contains(capability)
    }
}

nonisolated enum EntityCapabilityRegistry {
    static func profile(for domain: EntityDomain) -> EntityCapabilityProfile {
        switch domain {
        case .light:
            profile(domain, .simpleControl, .status, .light, "Light", [.toggle, .setLevel, .showActivity])
        case .switch:
            profile(domain, .simpleControl, .status, .toggle, "Switch", [.toggle, .showActivity])
        case .fan:
            profile(domain, .simpleControl, .status, .fan, "Fan", [.toggle, .setLevel, .chooseMode, .showActivity])
        case .remote:
            profile(domain, .simpleControl, .status, .generic, "Remote", [.toggle, .showActivity])
        case .cover:
            profile(domain, .positionalSecurity, .progress, .cover, "Cover", [.activate, .setPosition, .showActivity])
        case .lock:
            profile(domain, .positionalSecurity, .status, .lock, "Lock", [.secureAccess, .showActivity])
        case .valve:
            profile(domain, .positionalSecurity, .progress, .generic, "Valve", [.activate, .setPosition, .showActivity])
        case .siren:
            profile(domain, .positionalSecurity, .status, .generic, "Siren", [.activate, .showActivity])
        case .alarmControlPanel:
            profile(domain, .positionalSecurity, .status, .alarmControlPanel, "Alarm", [.secureAccess, .chooseMode, .showActivity])
        case .climate:
            profile(domain, .environmental, .environment, .climate, "Climate", [.setTemperature, .chooseMode, .showHistory])
        case .humidifier:
            profile(domain, .environmental, .environment, .generic, "Humidifier", [.toggle, .setLevel, .chooseMode, .showHistory])
        case .waterHeater:
            profile(domain, .environmental, .environment, .generic, "Water Heater", [.setTemperature, .chooseMode, .showHistory])
        case .sensor:
            profile(domain, .metric, .metric, .sensor, "Sensor", [.showHistory])
        case .binarySensor:
            profile(domain, .metric, .status, .sensor, "Binary Sensor", [.showActivity])
        case .airQuality:
            profile(domain, .metric, .metric, .generic, "Air Quality", [.showHistory])
        case .mediaPlayer:
            profile(domain, .mediaVisual, .media, .mediaPlayer, "Media Player", [.playMedia, .setLevel, .chooseOption, .showActivity])
        case .camera:
            profile(domain, .mediaVisual, .media, .camera, "Camera", [.showMedia, .showActivity])
        case .image:
            profile(domain, .mediaVisual, .media, .generic, "Image", [.showMedia])
        case .imageProcessing:
            profile(domain, .mediaVisual, .media, .generic, "Image Processing", [.showMedia, .showActivity])
        case .vacuum:
            profile(domain, .autonomousAppliance, .activity, .vacuum, "Vacuum", [.startStop, .returnToBase, .showActivity])
        case .lawnMower:
            profile(domain, .autonomousAppliance, .activity, .generic, "Lawn Mower", [.startStop, .returnToBase, .showActivity])
        case .scene:
            profile(domain, .actionWorkflow, .activity, .action, "Scene", [.activate, .showActivity])
        case .script:
            profile(domain, .actionWorkflow, .activity, .action, "Script", [.activate, .showActivity])
        case .automation:
            profile(domain, .actionWorkflow, .status, .automation, "Automation", [.toggle, .showActivity])
        case .button:
            profile(domain, .actionWorkflow, .activity, .button, "Button", [.activate, .showActivity])
        case .select:
            profile(domain, .editableValue, .status, .select, "Select", [.chooseOption, .editValue, .showActivity])
        case .number:
            profile(domain, .editableValue, .metric, .number, "Number", [.editValue, .showHistory])
        case .text:
            profile(domain, .editableValue, .status, .generic, "Text", [.editValue, .showActivity])
        case .date:
            profile(domain, .editableValue, .status, .generic, "Date", [.editValue, .showActivity])
        case .time:
            profile(domain, .editableValue, .status, .generic, "Time", [.editValue, .showActivity])
        case .datetime:
            profile(domain, .editableValue, .status, .generic, "Date & Time", [.editValue, .showActivity])
        case .weather:
            profile(domain, .informationContent, .environment, .weather, "Weather", [.showHistory])
        case .calendar:
            profile(domain, .informationContent, .activity, .generic, "Calendar", [.showActivity])
        case .todo:
            profile(domain, .informationContent, .activity, .generic, "To-do List", [.showActivity])
        case .event:
            profile(domain, .informationContent, .activity, .generic, "Event", [.showActivity])
        case .deviceTracker:
            profile(domain, .informationContent, .status, .generic, "Device Tracker", [.showActivity])
        case .person:
            profile(domain, .informationContent, .status, .generic, "Person", [.showActivity])
        case .update:
            profile(domain, .informationContent, .status, .generic, "Update", [.activate, .showActivity])
        case .other:
            profile(domain, .generic, .status, .generic, "Entity", [.showActivity])
        }
    }

    private static func profile(
        _ domain: EntityDomain,
        _ family: EntityDetailFamily,
        _ heroKind: EntityDetailHeroKind,
        _ detailRoute: EntityDetailRoute,
        _ categoryTitle: String,
        _ capabilities: Set<EntityCapability>
    ) -> EntityCapabilityProfile {
        EntityCapabilityProfile(
            domain: domain,
            family: family,
            heroKind: heroKind,
            detailRoute: detailRoute,
            categoryTitle: categoryTitle,
            capabilities: capabilities
        )
    }
}
