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

        let dashboardPresentation = DashboardEntityPresentation(entityBox: entityState)
        let subjectKind: SharedFeatureSubjectKind = switch entityState.domain {
        case .scene, .script, .button, .automation:
            .action
        case .person:
            .status
        default:
            .control
        }

        var affordances: Set<SharedFeatureAffordance> = [.read]
        if dashboardPresentation.primaryAction != nil {
            affordances.insert(.primaryAction)
        }

        let presentation = SharedFeaturePresentation(
            subjectID: entityState.entityID,
            subjectKind: subjectKind,
            title: dashboardPresentation.title,
            subtitle: dashboardPresentation.subtitle,
            valueText: dashboardPresentation.headline,
            statusText: dashboardPresentation.subtitle,
            icon: dashboardPresentation.icon,
            availability: dashboardPresentation.isAvailable
                ? .available
                : .unavailable(reason: "Entity unavailable"),
            affordances: affordances,
            accessibilityLabel: dashboardPresentation.title,
            accessibilityValue: dashboardPresentation.accessibilityValue
        )

        return presentation.applyingTitleOverride(titleOverride)
    }

    static func sensorPresentation(
        for entityState: HAEntityState,
        titleOverride: String? = nil
    ) -> SharedFeaturePresentation? {
        guard let sensor = entityState.sensorEntity else { return nil }

        let gauge = sensor.gaugePresentation
        let availability: SharedFeatureAvailability = sensor.isAvailable
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
            title: sensor.displayName,
            subtitle: sensor.displaySubtitle,
            valueText: sensor.formattedValue,
            statusText: sensor.isAvailable ? sensor.displaySubtitle : "Unavailable",
            icon: entityState.homeEntity.resolvedIcon,
            availability: availability,
            affordances: affordances,
            accessibilityLabel: "\(sensor.displayName) sensor",
            accessibilityValue: sensor.formattedValue
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
