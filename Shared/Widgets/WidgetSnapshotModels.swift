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

    var resolvedIcon: ResolvedIcon {
        icon ?? legacyIcon(fallback: "gauge.medium")
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
