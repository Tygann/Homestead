import Foundation

nonisolated struct WidgetLightSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let brightnessPercentage: Int?
    let areaName: String?
    let deviceName: String?
    var systemImage: String? = nil
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: "lightbulb.fill")
    }
}

nonisolated struct WidgetSwitchSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let systemImage: String?
    let areaName: String?
    let deviceName: String?
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: isOn ? "lightswitch.on.fill" : "lightswitch.off.fill")
    }
}

nonisolated struct WidgetCoverSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String?
    let isOpen: Bool
    let isClosed: Bool
    let isMoving: Bool
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed")
    }
}

nonisolated struct WidgetFanSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let isOn: Bool
    let statusText: String
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
    var systemImage: String? = nil
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: "fan.fill")
    }
}

nonisolated struct WidgetLockSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String?
    let isLocked: Bool
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: isLocked ? "lock.fill" : "lock.open.fill")
    }
}

nonisolated struct WidgetSensorSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String?
    let unit: String?
    let isNumeric: Bool?
    let isAlerting: Bool
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
    var icon: ResolvedIcon? = nil
    var gauge: WidgetGaugePresentation? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: "gauge.medium")
    }

    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .sensor,
            title: displayName,
            subtitle: subtitle,
            valueText: valueText,
            statusText: isAvailable ? subtitle : "Unavailable",
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Sensor unavailable"),
            affordances: Set([
                .read,
                gauge == nil ? nil : .gauge
            ].compactMap { $0 }),
            accessibilityLabel: gauge?.accessibilityLabel ?? "\(displayName) sensor",
            accessibilityValue: gauge?.accessibilityValue ?? valueText
        )
    }
}

nonisolated struct WidgetSensorLiveReading: Equatable, Sendable {
    let entityID: String
    let valueText: String
    let numericValue: Double?
    let isAvailable: Bool
    let icon: ResolvedIcon
}

nonisolated enum HomesteadWidgetItemKind: String, Codable, Equatable, Sendable {
    case sensorGauge
}

nonisolated struct HomesteadWidgetItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let kind: HomesteadWidgetItemKind
    let displayName: String
    let icon: ResolvedIcon
    let valueText: String
    let unitText: String?
    let isAvailable: Bool
    let gauge: WidgetGaugePresentation?
    let accessibilityLabel: String
    let accessibilityValue: String

    static func sensorGauge(from snapshot: WidgetSensorSnapshot) -> Self? {
        guard let gauge = snapshot.gauge else { return nil }
        let presentation = snapshot.sharedPresentation

        return Self(
            id: snapshot.entityID,
            kind: .sensorGauge,
            displayName: presentation.title,
            icon: presentation.icon,
            valueText: gauge.valueText,
            unitText: gauge.unitText,
            isAvailable: presentation.isAvailable,
            gauge: gauge,
            accessibilityLabel: presentation.accessibilityLabel,
            accessibilityValue: presentation.accessibilityValue ?? gauge.accessibilityValue
        )
    }

    func updating(with reading: WidgetSensorLiveReading) -> Self {
        guard reading.entityID == id else { return self }

        let resolvedGauge = reading.numericValue.map {
            gauge?.updating(value: $0, valueText: reading.valueText)
        } ?? gauge
        let resolvedIcon: ResolvedIcon
        switch icon.provenance {
        case .dashboardOverride, .appOverride, .haRegistryIcon:
            resolvedIcon = icon
        case .haExplicitIcon, .haSemanticMapping, .homesteadSemanticMapping, .fallback:
            resolvedIcon = reading.icon
        }

        return Self(
            id: id,
            kind: kind,
            displayName: displayName,
            icon: resolvedIcon,
            valueText: reading.valueText,
            unitText: resolvedGauge?.unitText ?? unitText,
            isAvailable: reading.isAvailable,
            gauge: resolvedGauge,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: reading.isAvailable ? reading.valueText : "Unavailable"
        )
    }
}

nonisolated enum HomesteadWidgetGridSelection {
    static let maximumItemCount = 6

    static func compacted(
        _ items: [HomesteadWidgetItem?],
        maximumItemCount: Int = maximumItemCount
    ) -> [HomesteadWidgetItem] {
        Array(items.compactMap { $0 }.prefix(max(0, maximumItemCount)))
    }
}

nonisolated enum WidgetGaugeStatus: String, Codable, Equatable, Sendable {
    case nominal
    case low
    case high
    case warning
    case critical
}

nonisolated enum WidgetGaugeColor: String, Codable, Equatable, Sendable {
    case blue
    case green
    case orange
    case red
    case purple
    case gray

    static func standard(for status: WidgetGaugeStatus) -> Self {
        switch status {
        case .nominal: .green
        case .low: .blue
        case .high, .warning: .orange
        case .critical: .red
        }
    }
}

nonisolated struct WidgetGaugeSection: Codable, Equatable, Sendable {
    let lowerBound: Double
    let upperBound: Double
    let color: WidgetGaugeColor
}

nonisolated struct WidgetGaugePresentation: Codable, Equatable, Sendable {
    let value: Double
    let lowerBound: Double
    let upperBound: Double
    let valueText: String
    let unitText: String?
    let status: WidgetGaugeStatus
    let statusDisplayText: String
    let sections: [WidgetGaugeSection]
    let accessibilityLabel: String
    let accessibilityValue: String

    var normalizedValue: Double {
        guard upperBound > lowerBound else { return 0 }
        let normalized = (value - lowerBound) / (upperBound - lowerBound)
        return min(max(normalized, 0), 1)
    }

    var currentColor: WidgetGaugeColor {
        sections.first(where: { value >= $0.lowerBound && value <= $0.upperBound })?.color
            ?? (value < lowerBound ? sections.first?.color : sections.last?.color)
            ?? .green
    }

    var fiveZoneValues: [Double] {
        if sections.count == 5 {
            return [lowerBound] + sections.dropLast().map(\.upperBound) + [upperBound]
        }

        let span = upperBound - lowerBound
        return [
            lowerBound,
            lowerBound + (span * 0.2),
            lowerBound + (span * 0.3),
            lowerBound + (span * 0.6),
            lowerBound + (span * 0.7),
            upperBound
        ]
    }

    func applyingConfiguration(
        lowerBound: Double,
        boundaries: [Double],
        upperBound: Double,
        colors: [WidgetGaugeColor]
    ) -> WidgetGaugePresentation {
        let values = [lowerBound] + boundaries + [upperBound]
        guard colors.count == boundaries.count + 1,
              !colors.isEmpty,
              zip(values, values.dropFirst()).allSatisfy({ $0.0 < $0.1 }) else { return self }

        var lower = lowerBound
        let sections = zip(boundaries + [upperBound], colors).map { upper, color in
            defer { lower = upper }
            return WidgetGaugeSection(lowerBound: lower, upperBound: upper, color: color)
        }

        return WidgetGaugePresentation(
            value: value,
            lowerBound: lowerBound,
            upperBound: upperBound,
            valueText: valueText,
            unitText: unitText,
            status: status,
            statusDisplayText: statusDisplayText,
            sections: sections,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: accessibilityValue
        )
    }

    func applyingFiveZoneConfiguration(
        lowerBound: Double,
        boundaries: [Double],
        upperBound: Double
    ) -> WidgetGaugePresentation {
        applyingConfiguration(
            lowerBound: lowerBound,
            boundaries: boundaries,
            upperBound: upperBound,
            colors: [.red, .orange, .green, .orange, .red]
        )
    }

    func updating(value newValue: Double, valueText newValueText: String) -> WidgetGaugePresentation {
        return WidgetGaugePresentation(
            value: newValue,
            lowerBound: lowerBound,
            upperBound: upperBound,
            valueText: newValueText,
            unitText: unitText,
            status: status,
            statusDisplayText: statusDisplayText,
            sections: sections,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: newValueText
        )
    }
}

nonisolated struct WidgetPresenceSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let statusText: String
    let isHome: Bool
    let systemImage: String?
    let isAvailable: Bool
    let areaName: String?
    let deviceName: String?
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: isHome ? "person.fill" : "person")
    }
}

nonisolated struct WidgetActionSnapshot: Codable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let domain: String
    let systemImage: String?
    let areaName: String?
    let deviceName: String?
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: domain == "scene" ? "sparkles" : "play.circle")
    }
}

nonisolated struct WidgetEntityContext: Codable, Equatable, Sendable {
    let areaName: String?
    let deviceName: String?

    static let empty = WidgetEntityContext(areaName: nil, deviceName: nil)
}

nonisolated private extension WidgetLightSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}

nonisolated private extension WidgetSwitchSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}

nonisolated private extension WidgetCoverSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}

nonisolated private extension WidgetFanSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}

nonisolated private extension WidgetLockSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}

nonisolated private extension WidgetSensorSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}

nonisolated private extension WidgetPresenceSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}

nonisolated private extension WidgetActionSnapshot {
    func legacyIcon(fallback: String) -> ResolvedIcon {
        .sfSymbol(systemImage ?? fallback, provenance: .homesteadSemanticMapping)
    }
}
