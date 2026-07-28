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

nonisolated struct EntityCapabilities: Equatable, Sendable {
    let domain: EntityDomain
    let deviceClass: String?
    let stateClass: SensorStateClass?
    let affordances: Set<EntityPresentationAffordance>
}

@MainActor
enum EntityCapabilityResolver {
    static func presentationInput(
        for entityBox: HAEntityState,
        serviceRegistry: HAServiceRegistry = .empty
    ) -> EntityPresentationInput {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let features = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation)
        var runtimeAffordances: Set<EntityPresentationAffordance> = []

        if presentation.primaryAction != nil { runtimeAffordances.insert(.primaryAction) }
        if DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: .square) {
            runtimeAffordances.insert(.history)
        }

        for feature in features {
            switch feature.content {
            case .level:
                runtimeAffordances.insert(.level)
            case .setpoint:
                runtimeAffordances.insert(.setpoint)
            case .options:
                runtimeAffordances.insert(.options)
            case .commandGroup:
                runtimeAffordances.insert(.commands)
            case .gauge:
                runtimeAffordances.insert(.gauge)
            }
        }

        return EntityPresentationInput(
            entityID: entityBox.entityID,
            domain: entityBox.domain,
            state: entityBox.homeEntity.state,
            displayName: entityBox.homeEntity.displayName,
            deviceClass: entityBox.sensorEntity?.deviceClass,
            stateClass: entityBox.sensorEntity?.stateClass?.rawValue,
            unit: entityBox.sensorEntity?.unit,
            numericValue: entityBox.sensorEntity?.numericValue,
            displayPrecision: entityBox.sensorEntity?.displayPrecision,
            icon: entityBox.homeEntity.resolvedIcon,
            runtimeAffordances: runtimeAffordances,
            hasGaugeSpecification: entityBox.sensorEntity?.gaugePresentation != nil
        )
    }

    static func capabilities(
        for entityBox: HAEntityState,
        serviceRegistry: HAServiceRegistry = .empty
    ) -> EntityCapabilities {
        let input = presentationInput(for: entityBox, serviceRegistry: serviceRegistry)
        let semantic = EntityPresentationResolver.resolve(input)

        return EntityCapabilities(
            domain: entityBox.domain,
            deviceClass: entityBox.sensorEntity?.deviceClass,
            stateClass: entityBox.sensorEntity?.stateClass,
            affordances: semantic.affordances
        )
    }
}
