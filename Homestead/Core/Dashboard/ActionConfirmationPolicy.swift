import Foundation

struct ActionConfirmationPresentation: Equatable, Sendable {
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
}

enum ActionConfirmationPolicy {
    static func confirmation(
        for entityBox: HAEntityState,
        domain: String,
        service: String,
        settings: ActionConfirmationSettingsSnapshot
    ) -> ActionConfirmationPresentation? {
        switch settings.mode {
        case .off:
            return nil
        case .all:
            return presentation(for: entityBox, domain: domain, service: service, fallbackSensitive: false)
        case .smart:
            guard shouldConfirmSmartMode(
                entityBox: entityBox,
                domain: domain,
                service: service,
                settings: settings
            ) else {
                return nil
            }

            return presentation(for: entityBox, domain: domain, service: service, fallbackSensitive: true)
        }
    }

    private static func shouldConfirmSmartMode(
        entityBox: HAEntityState,
        domain: String,
        service: String,
        settings: ActionConfirmationSettingsSnapshot
    ) -> Bool {
        switch (domain, service) {
        case ("lock", "unlock"):
            return settings.confirmsLockUnlocks && entityBox.homeEntity.state == "locked"
        case ("cover", "open_cover"):
            return settings.confirmsSecurityCoverOpens && isSecurityCover(entityBox.coverEntity)
        case ("scene", "turn_on"):
            return settings.confirmsScenes
        case ("script", "turn_on"):
            return settings.confirmsScripts
        case ("button", "press"),
             ("vacuum", "start"),
             ("vacuum", "stop"),
             ("vacuum", "return_to_base"):
            return settings.confirmsOtherImpactfulActions
        case ("alarm_control_panel", _):
            return settings.confirmsOtherImpactfulActions && service.hasPrefix("alarm_")
        case ("siren", "turn_on"), ("siren", "toggle"):
            return settings.confirmsOtherImpactfulActions
        default:
            return false
        }
    }

    private static func isSecurityCover(_ cover: CoverEntity?) -> Bool {
        guard let deviceClass = cover?.deviceClass?.trimmingCharacters(in: .whitespacesAndNewlines),
              !deviceClass.isEmpty else {
            return true
        }

        return ["door", "garage", "gate", "window"].contains(deviceClass)
    }

    private static func presentation(
        for entityBox: HAEntityState,
        domain: String,
        service: String,
        fallbackSensitive: Bool
    ) -> ActionConfirmationPresentation {
        let name = entityBox.homeEntity.displayName

        switch (domain, service) {
        case ("lock", "unlock"):
            return ActionConfirmationPresentation(
                title: "Unlock \(name)?",
                message: "This will unlock the selected lock.",
                confirmTitle: "Unlock",
                isDestructive: true
            )
        case ("cover", "open_cover"):
            return ActionConfirmationPresentation(
                title: "Open \(name)?",
                message: coverMessage(for: entityBox.coverEntity),
                confirmTitle: "Open",
                isDestructive: true
            )
        case ("scene", "turn_on"):
            return ActionConfirmationPresentation(
                title: "Activate \(name)?",
                message: "This may change multiple devices.",
                confirmTitle: "Activate",
                isDestructive: false
            )
        case ("script", "turn_on"):
            return ActionConfirmationPresentation(
                title: "Run \(name)?",
                message: "This may run several Home Assistant actions.",
                confirmTitle: "Run",
                isDestructive: false
            )
        case ("button", "press"):
            return ActionConfirmationPresentation(
                title: "Press \(name)?",
                message: "This can trigger a Home Assistant action.",
                confirmTitle: "Press",
                isDestructive: fallbackSensitive
            )
        case ("alarm_control_panel", _):
            return ActionConfirmationPresentation(
                title: "\(readableAlarmAction(service))?",
                message: "This will update the alarm mode.",
                confirmTitle: alarmConfirmTitle(service),
                isDestructive: service == "alarm_disarm"
            )
        case ("vacuum", "start"), ("vacuum", "stop"), ("vacuum", "return_to_base"):
            return ActionConfirmationPresentation(
                title: "\(readableServiceName(service)) \(name)?",
                message: "This will control the vacuum.",
                confirmTitle: readableServiceName(service),
                isDestructive: false
            )
        default:
            return ActionConfirmationPresentation(
                title: "\(readableServiceName(service)) \(name)?",
                message: "This will send the action to Home Assistant.",
                confirmTitle: readableServiceName(service),
                isDestructive: fallbackSensitive
            )
        }
    }

    private static func coverMessage(for cover: CoverEntity?) -> String {
        switch cover?.deviceClass {
        case "garage":
            "This will open the garage door."
        case "gate":
            "This will open the gate."
        case "door":
            "This will open the door."
        case "window":
            "This will open the window."
        default:
            "This will open the selected cover."
        }
    }

    private static func readableAlarmAction(_ service: String) -> String {
        switch service {
        case "alarm_disarm":
            "Disarm alarm"
        case "alarm_arm_home":
            "Arm home"
        case "alarm_arm_away":
            "Arm away"
        case "alarm_arm_night":
            "Arm night"
        default:
            readableServiceName(service)
        }
    }

    private static func alarmConfirmTitle(_ service: String) -> String {
        switch service {
        case "alarm_disarm":
            "Disarm"
        case "alarm_arm_home":
            "Arm Home"
        case "alarm_arm_away":
            "Arm Away"
        case "alarm_arm_night":
            "Arm Night"
        default:
            readableServiceName(service)
        }
    }

    private static func readableServiceName(_ service: String) -> String {
        service
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
