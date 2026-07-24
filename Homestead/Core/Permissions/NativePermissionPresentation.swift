import SwiftUI

nonisolated enum NativePermissionRowAction: Equatable, Sendable {
    case allow
    case openSettings
}

nonisolated enum NativePermissionStatusTone: Equatable, Sendable {
    case positive
    case caution
    case negative
    case neutral
}

nonisolated enum NativePermissionRowAccessory: Equatable, Sendable {
    case action(title: String, action: NativePermissionRowAction)
    case progress(title: String)
    case status(title: String, tone: NativePermissionStatusTone)
}

nonisolated struct NativePermissionRowPresentation: Equatable, Sendable {
    let accessory: NativePermissionRowAccessory

    static func make(
        status: NativeCapabilityAuthorizationStatus,
        isRequesting: Bool = false,
        supportsInAppRequest: Bool = true
    ) -> NativePermissionRowPresentation {
        if isRequesting {
            return NativePermissionRowPresentation(accessory: .progress(title: "Requesting"))
        }

        let accessory: NativePermissionRowAccessory = switch status {
        case .unknown:
            .progress(title: "Checking")
        case .notDetermined where supportsInAppRequest:
            .action(title: "Allow", action: .allow)
        case .notDetermined:
            .status(title: "Not Determined", tone: .neutral)
        case .allowed:
            .status(title: "Allowed", tone: .positive)
        case .limited:
            .status(title: "Limited", tone: .caution)
        case .denied:
            .action(title: "Settings", action: .openSettings)
        case .restricted:
            .status(title: "Restricted", tone: .negative)
        case .unavailable:
            .status(title: "Unavailable", tone: .neutral)
        case .managedBySystem:
            .status(title: "System Managed", tone: .neutral)
        }

        return NativePermissionRowPresentation(accessory: accessory)
    }
}

nonisolated enum NativePermissionRefreshPolicy {
    static func shouldRefresh(when scenePhase: ScenePhase) -> Bool {
        scenePhase == .active
    }
}
