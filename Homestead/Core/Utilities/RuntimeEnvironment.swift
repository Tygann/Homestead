import Foundation

enum RuntimeEnvironment {
    nonisolated static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

nonisolated enum HomesteadPreviewScreen: String, Sendable {
    case activity
    case appearance
    case dashboardChangeEntity = "dashboard-change-entity"
    case dashboardCardEditor = "dashboard-card-editor"
    case dashboardCards = "dashboard-cards"
    case dashboardSettings = "dashboard-settings"
    case entityDetailCard = "entity-detail-card"
    case entityDetails = "entity-details"
    case home
    case notifications
    case onboarding
    case settings
    case updates
    case widgets
}

nonisolated enum HomesteadPreviewNotificationState: String, Sendable {
    case ready
    case needsSetup = "needs-setup"
}

nonisolated enum HomesteadPreviewOnboardingStep: String, Sendable {
    case welcome
    case setup
}

extension HomesteadPreviewScreen {
    nonisolated init?(argumentValue: String?) {
        guard let argumentValue else {
            return nil
        }

        switch argumentValue {
        case Self.activity.rawValue:
            self = .activity
        case Self.appearance.rawValue:
            self = .appearance
        case Self.dashboardChangeEntity.rawValue:
            self = .dashboardChangeEntity
        case Self.dashboardCardEditor.rawValue:
            self = .dashboardCardEditor
        case Self.dashboardCards.rawValue:
            self = .dashboardCards
        case Self.dashboardSettings.rawValue:
            self = .dashboardSettings
        case Self.entityDetailCard.rawValue:
            self = .entityDetailCard
        case Self.entityDetails.rawValue:
            self = .entityDetails
        case Self.home.rawValue:
            self = .home
        case Self.notifications.rawValue:
            self = .notifications
        case Self.onboarding.rawValue:
            self = .onboarding
        case Self.settings.rawValue:
            self = .settings
        case Self.updates.rawValue:
            self = .updates
        case Self.widgets.rawValue:
            self = .widgets
        default:
            return nil
        }
    }
}

#if DEBUG
extension RuntimeEnvironment {
    nonisolated static var isLivePreviewLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("--live-preview")
            || ProcessInfo.processInfo.environment["HOMESTEAD_LIVE_PREVIEW"] == "1"
    }

    nonisolated static var previewScreen: HomesteadPreviewScreen? {
        HomesteadPreviewScreen(argumentValue: argumentValue(after: "--preview-screen"))
    }

    nonisolated static var previewNotificationState: HomesteadPreviewNotificationState {
        guard let value = argumentValue(after: "--preview-notification-state") else {
            return .ready
        }
        return HomesteadPreviewNotificationState(rawValue: value) ?? .ready
    }

    nonisolated static var previewOnboardingStep: HomesteadPreviewOnboardingStep {
        guard let value = argumentValue(after: "--preview-onboarding-step") else {
            return .welcome
        }
        return HomesteadPreviewOnboardingStep(rawValue: value) ?? .welcome
    }

    nonisolated static var livePreviewEntityID: String? {
        argumentValue(after: "--preview-entity")
    }

    nonisolated static var livePreviewCardSize: DashboardCardSize {
        requestedPreviewCardSize ?? .square
    }

    nonisolated static var requestedPreviewCardSize: DashboardCardSize? {
        argumentValue(after: "--preview-size")
            .flatMap(DashboardCardSize.init(rawValue:))
    }

    nonisolated static var dashboardCardReferenceState: String? {
        argumentValue(after: "--preview-card-state")
    }

    nonisolated static var livePreviewPresentationKind: DashboardPresentationKind? {
        argumentValue(after: "--preview-presentation")
            .flatMap(DashboardPresentationKind.init(rawValue:))
    }

    nonisolated static var livePreviewAppearanceMode: HomesteadAppearanceMode? {
        argumentValue(after: "--preview-appearance")
            .flatMap(HomesteadAppearanceMode.init(rawValue:))
    }

    nonisolated static var entityDetailReferenceFamily: String? {
        argumentValue(after: "--preview-detail-family")
    }

    nonisolated static var entityDetailReferenceVariant: String? {
        argumentValue(after: "--preview-detail-state")
    }

    private nonisolated static func argumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: flag),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }

        let value = arguments[flagIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
#endif
