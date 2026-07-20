import Foundation

enum RuntimeEnvironment {
    nonisolated static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

nonisolated enum HomesteadPreviewScreen: String, Sendable {
    case appearance
    case entityDetails = "entity-details"
    case gaugeWidget = "gauge-widget"
}

extension HomesteadPreviewScreen {
    nonisolated init?(argumentValue: String?) {
        guard let argumentValue else {
            return nil
        }

        switch argumentValue {
        case Self.appearance.rawValue:
            self = .appearance
        case Self.entityDetails.rawValue:
            self = .entityDetails
        case Self.gaugeWidget.rawValue:
            self = .gaugeWidget
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

    nonisolated static var livePreviewEntityID: String? {
        argumentValue(after: "--preview-entity")
    }

    nonisolated static var livePreviewCardSize: DashboardCardSize {
        argumentValue(after: "--preview-size")
            .flatMap(DashboardCardSize.init(rawValue:))
            ?? .square
    }

    nonisolated static var livePreviewAppearanceMode: HomesteadAppearanceMode? {
        argumentValue(after: "--preview-appearance")
            .flatMap(HomesteadAppearanceMode.init(rawValue:))
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
