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
}

nonisolated enum WidgetGaugeStatus: String, Codable, Equatable, Sendable {
    case nominal
    case low
    case high
    case warning
    case critical
}

nonisolated struct WidgetGaugeSection: Codable, Equatable, Sendable {
    let lowerBound: Double
    let upperBound: Double
    let status: WidgetGaugeStatus
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

    func applyingFiveZoneConfiguration(
        lowerBound: Double,
        boundaries: [Double],
        upperBound: Double
    ) -> WidgetGaugePresentation {
        let values = [lowerBound] + boundaries + [upperBound]
        guard boundaries.count == 4,
              zip(values, values.dropFirst()).allSatisfy({ $0.0 < $0.1 }) else { return self }

        let statuses: [WidgetGaugeStatus] = [.critical, .warning, .nominal, .warning, .critical]
        var lower = lowerBound
        let sections = zip(boundaries + [upperBound], statuses).map { upper, status in
            defer { lower = upper }
            return WidgetGaugeSection(lowerBound: lower, upperBound: upper, status: status)
        }
        let resolvedStatus = sections.first(where: { value >= $0.lowerBound && value <= $0.upperBound })?.status
            ?? .critical

        return WidgetGaugePresentation(
            value: value,
            lowerBound: lowerBound,
            upperBound: upperBound,
            valueText: valueText,
            unitText: unitText,
            status: resolvedStatus,
            statusDisplayText: Self.statusDisplayText(for: resolvedStatus),
            sections: sections,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: Self.accessibilityValue(valueText: valueText, status: resolvedStatus)
        )
    }

    func updating(value newValue: Double, valueText newValueText: String) -> WidgetGaugePresentation {
        let newStatus = status(for: newValue)
        let newStatusDisplayText = newStatus == status ? statusDisplayText : Self.statusDisplayText(for: newStatus)
        return WidgetGaugePresentation(
            value: newValue,
            lowerBound: lowerBound,
            upperBound: upperBound,
            valueText: newValueText,
            unitText: unitText,
            status: newStatus,
            statusDisplayText: newStatusDisplayText,
            sections: sections,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: Self.accessibilityValue(valueText: newValueText, status: newStatus)
        )
    }

    private func status(for value: Double) -> WidgetGaugeStatus {
        sections.first { section in
            value >= section.lowerBound && value <= section.upperBound
        }?.status ?? status
    }

    private static func statusDisplayText(for status: WidgetGaugeStatus) -> String {
        switch status {
        case .nominal:
            "Normal"
        case .low:
            "Low"
        case .high:
            "High"
        case .warning:
            "Warning"
        case .critical:
            "Critical"
        }
    }

    private static func accessibilityValue(valueText: String, status: WidgetGaugeStatus) -> String {
        switch status {
        case .nominal:
            valueText
        case .low:
            "\(valueText), low"
        case .high:
            "\(valueText), high"
        case .warning:
            "\(valueText), warning"
        case .critical:
            "\(valueText), critical"
        }
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
