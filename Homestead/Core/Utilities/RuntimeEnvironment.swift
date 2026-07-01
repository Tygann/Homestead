import Foundation

enum RuntimeEnvironment {
    nonisolated static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

#if DEBUG
    nonisolated static var isLivePreviewLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("--live-preview")
            || ProcessInfo.processInfo.environment["HOMESTEAD_LIVE_PREVIEW"] == "1"
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
#endif
}
