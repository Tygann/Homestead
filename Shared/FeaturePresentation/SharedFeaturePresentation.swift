import Foundation

// MARK: - Shared Feature Presentation

nonisolated enum SharedFeatureSubjectKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case sensor
    case control
    case status
    case action
}

nonisolated enum SharedFeatureCategory: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case controls
    case status
    case sensors
    case actions
}

nonisolated enum SharedFeatureSurface: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case dashboard
    case widget
}

nonisolated enum SharedFeatureAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

nonisolated enum SharedFeatureAffordance: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case read
    case primaryAction
    case history
    case gauge
}

nonisolated enum SharedWidgetFamilyIdentifier: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case systemSmall
    case systemMedium
    case systemLarge
    case accessoryCircular
    case accessoryRectangular
}

nonisolated struct SharedFeaturePresentation: Equatable, Sendable {
    let subjectID: String
    let subjectKind: SharedFeatureSubjectKind
    let title: String
    let subtitle: String?
    let valueText: String?
    let statusText: String?
    let icon: ResolvedIcon
    let availability: SharedFeatureAvailability
    let affordances: Set<SharedFeatureAffordance>
    let accessibilityLabel: String
    let accessibilityValue: String?

    var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    func applyingTitleOverride(_ override: String?) -> Self {
        let normalized = override?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else { return self }

        return Self(
            subjectID: subjectID,
            subjectKind: subjectKind,
            title: normalized,
            subtitle: subtitle,
            valueText: valueText,
            statusText: statusText,
            icon: icon,
            availability: availability,
            affordances: affordances,
            accessibilityLabel: normalized,
            accessibilityValue: accessibilityValue
        )
    }
}

nonisolated struct SharedFeatureDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let category: SharedFeatureCategory
    let subjectKind: SharedFeatureSubjectKind
    let supportedSurfaces: Set<SharedFeatureSurface>
    let dashboardPresentationIDs: Set<String>
    let relatedWidgetKinds: Set<HomesteadWidgetKind>
    let affordances: Set<SharedFeatureAffordance>

    var supportsDashboard: Bool { supportedSurfaces.contains(.dashboard) }
    var supportsWidget: Bool { supportedSurfaces.contains(.widget) }
}

nonisolated struct WidgetFeatureDescriptor: Identifiable, Equatable, Sendable {
    let kind: HomesteadWidgetKind
    let featureID: String
    let displayName: String
    let description: String
    let supportedFamilies: Set<SharedWidgetFamilyIdentifier>
    let requiresConfiguration: Bool

    var id: HomesteadWidgetKind { kind }
}

nonisolated enum SharedFeatureCatalog {
    static let descriptors: [SharedFeatureDescriptor] = [
        SharedFeatureDescriptor(
            id: "control",
            title: "Control",
            systemImage: "switch.2",
            category: .controls,
            subjectKind: .control,
            supportedSurfaces: [.dashboard, .widget],
            dashboardPresentationIDs: ["control"],
            relatedWidgetKinds: [.control],
            affordances: [.read, .primaryAction]
        ),
        SharedFeatureDescriptor(
            id: "status",
            title: "Status",
            systemImage: "circle.lefthalf.filled",
            category: .status,
            subjectKind: .status,
            supportedSurfaces: [.dashboard, .widget],
            dashboardPresentationIDs: ["status"],
            relatedWidgetKinds: [.status],
            affordances: [.read]
        ),
        SharedFeatureDescriptor(
            id: "sensor",
            title: "Sensor",
            systemImage: "thermometer.medium",
            category: .sensors,
            subjectKind: .sensor,
            supportedSurfaces: [.widget],
            dashboardPresentationIDs: ["graph"],
            relatedWidgetKinds: [.sensor],
            affordances: [.read, .history]
        ),
        SharedFeatureDescriptor(
            id: "sensor-gauge",
            title: "Sensor Gauge",
            systemImage: "gauge.with.dots.needle.33percent",
            category: .sensors,
            subjectKind: .sensor,
            supportedSurfaces: [.dashboard, .widget],
            dashboardPresentationIDs: ["gauge"],
            relatedWidgetKinds: [.sensor, .gaugeGrid, .largeGaugeGrid],
            affordances: [.read, .gauge]
        ),
        SharedFeatureDescriptor(
            id: "action",
            title: "Action",
            systemImage: "sparkles",
            category: .actions,
            subjectKind: .action,
            supportedSurfaces: [.dashboard, .widget],
            dashboardPresentationIDs: ["action"],
            relatedWidgetKinds: [.action],
            affordances: [.read, .primaryAction]
        )
    ]

    static let widgetDescriptors: [WidgetFeatureDescriptor] = [
        WidgetFeatureDescriptor(
            kind: .control,
            featureID: "control",
            displayName: "Homestead Control",
            description: "Control a Home Assistant light, switch, fan, cover, or lock.",
            supportedFamilies: [.systemSmall, .accessoryCircular, .accessoryRectangular],
            requiresConfiguration: true
        ),
        WidgetFeatureDescriptor(
            kind: .status,
            featureID: "status",
            displayName: "Homestead Status",
            description: "Show a Home Assistant sensor or person status.",
            supportedFamilies: [.systemSmall, .accessoryCircular, .accessoryRectangular],
            requiresConfiguration: true
        ),
        WidgetFeatureDescriptor(
            kind: .sensor,
            featureID: "sensor",
            displayName: "Homestead Sensor",
            description: "Show a Home Assistant sensor reading, trend, or gauge.",
            supportedFamilies: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular],
            requiresConfiguration: true
        ),
        WidgetFeatureDescriptor(
            kind: .gaugeGrid,
            featureID: "sensor-gauge",
            displayName: "Homestead Gauge Grid",
            description: "Show up to three Home Assistant gauges.",
            supportedFamilies: [.systemMedium],
            requiresConfiguration: true
        ),
        WidgetFeatureDescriptor(
            kind: .largeGaugeGrid,
            featureID: "sensor-gauge",
            displayName: "Homestead Large Gauge Grid",
            description: "Show up to nine Home Assistant gauges.",
            supportedFamilies: [.systemLarge],
            requiresConfiguration: true
        ),
        WidgetFeatureDescriptor(
            kind: .action,
            featureID: "action",
            displayName: "Homestead Action",
            description: "Run a Home Assistant scene, script, or button action.",
            supportedFamilies: [.systemSmall, .accessoryCircular, .accessoryRectangular],
            requiresConfiguration: true
        )
    ]

    static func descriptor(id: String) -> SharedFeatureDescriptor? {
        descriptors.first { $0.id == id }
    }

    static func widgetDescriptor(for kind: HomesteadWidgetKind) -> WidgetFeatureDescriptor? {
        widgetDescriptors.first { $0.kind == kind }
    }
}
