import Foundation

// MARK: - Dashboard Feature Presentation Adapter

@MainActor
enum DashboardFeaturePresentationAdapter {
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
}
