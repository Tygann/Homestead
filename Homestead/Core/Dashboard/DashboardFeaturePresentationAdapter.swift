import Foundation

// MARK: - Dashboard Feature Presentation Adapter

@MainActor
enum DashboardFeaturePresentationAdapter {
    static func presentation(
        for entityState: HAEntityState,
        titleOverride: String? = nil
    ) -> SharedFeaturePresentation {
        if entityState.sensorEntity != nil {
            return sensorPresentation(for: entityState, titleOverride: titleOverride)
                ?? fallbackPresentation(for: entityState, titleOverride: titleOverride)
        }

        let semantic = EntityPresentationResolver.resolve(
            EntityCapabilityResolver.presentationInput(for: entityState)
        )
        let subjectKind: SharedFeatureSubjectKind = switch entityState.domain {
        case .scene, .script, .button, .automation:
            .action
        case .person:
            .status
        default:
            .control
        }

        var affordances: Set<SharedFeatureAffordance> = [.read]
        if semantic.affordances.contains(.primaryAction) {
            affordances.insert(.primaryAction)
        }

        let presentation = SharedFeaturePresentation(
            subjectID: entityState.entityID,
            subjectKind: subjectKind,
            title: semantic.title,
            subtitle: semantic.statusText,
            valueText: semantic.valueText,
            statusText: semantic.statusText,
            icon: semantic.icon,
            availability: semantic.isAvailable
                ? .available
                : .unavailable(reason: "Entity unavailable"),
            affordances: affordances,
            accessibilityLabel: semantic.title,
            accessibilityValue: semantic.valueText
        )

        return presentation.applyingTitleOverride(titleOverride)
    }

    static func sensorPresentation(
        for entityState: HAEntityState,
        titleOverride: String? = nil
    ) -> SharedFeaturePresentation? {
        guard let sensor = entityState.sensorEntity else { return nil }

        let semantic = EntityPresentationResolver.resolve(
            EntityCapabilityResolver.presentationInput(for: entityState)
        )
        let gauge = sensor.gaugePresentation
        let availability: SharedFeatureAvailability = semantic.isAvailable
            ? .available
            : .unavailable(reason: "Sensor unavailable")

        var affordances: Set<SharedFeatureAffordance> = [.read]
        if gauge != nil {
            affordances.insert(.gauge)
        }
        if entityState.domain == .sensor, sensor.stateClass != nil {
            affordances.insert(.history)
        }

        let presentation = SharedFeaturePresentation(
            subjectID: entityState.entityID,
            subjectKind: .sensor,
            title: semantic.title,
            subtitle: sensor.displaySubtitle,
            valueText: semantic.valueText,
            statusText: sensor.isAvailable ? sensor.displaySubtitle : "Unavailable",
            icon: semantic.icon,
            availability: availability,
            affordances: affordances,
            accessibilityLabel: "\(sensor.displayName) sensor",
            accessibilityValue: semantic.valueText
        )

        return presentation.applyingTitleOverride(titleOverride)
    }

    private static func fallbackPresentation(
        for entityState: HAEntityState,
        titleOverride: String?
    ) -> SharedFeaturePresentation {
        let entity = entityState.homeEntity
        return SharedFeaturePresentation(
            subjectID: entityState.entityID,
            subjectKind: .status,
            title: titleOverride ?? entity.displayName,
            subtitle: entity.state,
            valueText: entity.state,
            statusText: entity.state,
            icon: entity.resolvedIcon,
            availability: entity.isAvailable ? .available : .unavailable(reason: "Entity unavailable"),
            affordances: [.read],
            accessibilityLabel: entity.displayName,
            accessibilityValue: entity.state
        )
    }
}
