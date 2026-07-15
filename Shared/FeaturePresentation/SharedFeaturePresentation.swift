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

    var supportsDashboard: Bool { supportedSurfaces.contains(.dashboard) }
    var supportsWidget: Bool { supportedSurfaces.contains(.widget) }
}

nonisolated enum SharedFeatureCatalog {
    static let descriptors: [SharedFeatureDescriptor] = [
        SharedFeatureDescriptor(
            id: "control",
            title: "Control",
            systemImage: "switch.2",
            category: .controls,
            subjectKind: .control,
            supportedSurfaces: [.dashboard, .widget]
        ),
        SharedFeatureDescriptor(
            id: "status",
            title: "Status",
            systemImage: "circle.lefthalf.filled",
            category: .status,
            subjectKind: .status,
            supportedSurfaces: [.dashboard, .widget]
        ),
        SharedFeatureDescriptor(
            id: "sensor",
            title: "Sensor",
            systemImage: "thermometer.medium",
            category: .sensors,
            subjectKind: .sensor,
            supportedSurfaces: [.widget]
        ),
        SharedFeatureDescriptor(
            id: "sensor-gauge",
            title: "Sensor Gauge",
            systemImage: "gauge.with.dots.needle.33percent",
            category: .sensors,
            subjectKind: .sensor,
            supportedSurfaces: [.dashboard, .widget]
        ),
        SharedFeatureDescriptor(
            id: "action",
            title: "Action",
            systemImage: "sparkles",
            category: .actions,
            subjectKind: .action,
            supportedSurfaces: [.dashboard, .widget]
        )
    ]

    static func descriptor(id: String) -> SharedFeatureDescriptor? {
        descriptors.first { $0.id == id }
    }
}
