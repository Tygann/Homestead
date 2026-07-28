import Foundation

// MARK: - Shared Snapshot Presentation

nonisolated extension WidgetLightSnapshot {
    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .control,
            title: displayName,
            subtitle: brightnessPercentage.map { isOn ? "On • \($0)%" : "Off" } ?? (isOn ? "On" : "Off"),
            valueText: isOn ? brightnessPercentage.map { "\($0)%" } : "Off",
            statusText: isOn ? "On" : "Off",
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Light unavailable"),
            affordances: [.read, .primaryAction],
            accessibilityLabel: "\(displayName) light",
            accessibilityValue: isOn ? brightnessPercentage.map { "On, \($0)%" } ?? "On" : "Off"
        )
    }
}

nonisolated extension WidgetSwitchSnapshot {
    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .control,
            title: displayName,
            subtitle: isOn ? "On" : "Off",
            valueText: isOn ? "On" : "Off",
            statusText: isOn ? "On" : "Off",
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Switch unavailable"),
            affordances: [.read, .primaryAction],
            accessibilityLabel: "\(displayName) switch",
            accessibilityValue: isOn ? "On" : "Off"
        )
    }
}

nonisolated extension WidgetFanSnapshot {
    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .control,
            title: displayName,
            subtitle: statusText,
            valueText: statusText,
            statusText: statusText,
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Fan unavailable"),
            affordances: [.read, .primaryAction],
            accessibilityLabel: "\(displayName) fan",
            accessibilityValue: statusText
        )
    }
}

nonisolated extension WidgetCoverSnapshot {
    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .control,
            title: displayName,
            subtitle: statusText,
            valueText: nil,
            statusText: statusText,
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Cover unavailable"),
            affordances: [.read, .primaryAction],
            accessibilityLabel: "\(displayName) cover",
            accessibilityValue: statusText
        )
    }
}

nonisolated extension WidgetLockSnapshot {
    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .control,
            title: displayName,
            subtitle: statusText,
            valueText: statusText,
            statusText: statusText,
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Lock unavailable"),
            affordances: [.read, .primaryAction],
            accessibilityLabel: "\(displayName) lock",
            accessibilityValue: statusText
        )
    }
}

nonisolated extension WidgetPresenceSnapshot {
    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .status,
            title: displayName,
            subtitle: "Presence",
            valueText: statusText,
            statusText: statusText,
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Presence unavailable"),
            affordances: [.read],
            accessibilityLabel: "\(displayName) presence",
            accessibilityValue: statusText
        )
    }
}

nonisolated extension WidgetActionSnapshot {
    var sharedPresentation: SharedFeaturePresentation {
        SharedFeaturePresentation(
            subjectID: entityID,
            subjectKind: .action,
            title: displayName,
            subtitle: domain == "scene" ? "Scene" : domain == "script" ? "Script" : "Button",
            valueText: nil,
            statusText: nil,
            icon: resolvedIcon,
            availability: isAvailable ? .available : .unavailable(reason: "Action unavailable"),
            affordances: [.read, .primaryAction],
            accessibilityLabel: "\(displayName) action",
            accessibilityValue: nil
        )
    }
}
