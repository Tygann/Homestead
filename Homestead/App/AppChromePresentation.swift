import SwiftUI

nonisolated struct AppChromePresentation: Equatable {
    let statusAccessoryState: AppStatusAccessoryState?

    static func make(
        hasServerURL: Bool,
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        dataFreshness: HADataFreshness,
        serviceFeedback: HAServiceFeedback?,
        suppressTransientConnectionHealth: Bool = false
    ) -> AppChromePresentation {
        let hasHomeAssistantSession = hasServerURL && authState.isSignedIn
        guard hasHomeAssistantSession else {
            return AppChromePresentation(statusAccessoryState: nil)
        }

        let connectionState = AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: connectionStatus,
            dataFreshness: dataFreshness,
            suppressTransientConnectionHealth: suppressTransientConnectionHealth
        )

        if serviceFeedback?.style == .failure {
            return AppChromePresentation(
                statusAccessoryState: serviceFeedback.map(AppStatusAccessoryState.init(feedback:))
            )
        }

        return AppChromePresentation(
            statusAccessoryState: connectionState ?? serviceFeedback.map(AppStatusAccessoryState.init(feedback:))
        )
    }
}
