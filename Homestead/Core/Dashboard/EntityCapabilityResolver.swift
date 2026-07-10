import Foundation

nonisolated enum PresentationUnavailableReason: Equatable, Sendable {
    case requiresNumericState
    case requiresAvailableEntity
    case requiresGaugeRange
    case unsupportedDomain
}

nonisolated enum PresentationAvailability: Equatable, Sendable {
    case available
    case configurable(String)
    case unavailable(PresentationUnavailableReason)

    var isSelectable: Bool {
        switch self {
        case .available, .configurable:
            true
        case .unavailable:
            false
        }
    }
}

nonisolated enum EntityAffordance: Equatable, Sendable {
    case primaryAction
    case level
    case setpoint
    case options
    case commands
    case numericReading
    case history
    case media
    case camera
    case trigger
    case genericActions
}

nonisolated struct EntityCapabilities: Equatable, Sendable {
    let domain: EntityDomain
    let deviceClass: String?
    let stateClass: SensorStateClass?
    let affordances: Set<EntityAffordance>
}

@MainActor
enum EntityCapabilityResolver {
    static func capabilities(
        for entityBox: HAEntityState,
        serviceRegistry: HAServiceRegistry = .empty
    ) -> EntityCapabilities {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let features = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation)
        var affordances: Set<EntityAffordance> = []

        if presentation.primaryAction != nil { affordances.insert(.primaryAction) }
        if entityBox.domain == .camera { affordances.insert(.camera) }
        if entityBox.domain == .mediaPlayer { affordances.insert(.media) }
        if [.scene, .script, .button].contains(entityBox.domain) { affordances.insert(.trigger) }
        if DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: .square) {
            affordances.insert(.history)
        }
        if entityBox.sensorEntity?.numericValue != nil { affordances.insert(.numericReading) }
        if !serviceRegistry.actions(for: entityBox.entityID).isEmpty { affordances.insert(.genericActions) }

        for feature in features {
            switch feature.content {
            case .level: affordances.insert(.level)
            case .setpoint: affordances.insert(.setpoint)
            case .options: affordances.insert(.options)
            case .commandGroup: affordances.insert(.commands)
            case .gauge: affordances.insert(.numericReading)
            }
        }

        return EntityCapabilities(
            domain: entityBox.domain,
            deviceClass: entityBox.sensorEntity?.deviceClass,
            stateClass: entityBox.sensorEntity?.stateClass,
            affordances: affordances
        )
    }
}
