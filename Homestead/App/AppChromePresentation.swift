import SwiftUI

nonisolated struct AppChromePresentation: Equatable {
    let connectionAccessoryState: ConnectionHealthAccessoryState?

    var serviceFeedbackBottomPadding: CGFloat {
        if connectionAccessoryState == nil {
            return AppSpacing.xxLarge + AppSpacing.large
        }

        return AppSpacing.xxLarge + AppSpacing.xLarge + AppSpacing.large + AppSpacing.small
    }

    static func make(
        hasServerURL: Bool,
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        dataFreshness: HADataFreshness
    ) -> AppChromePresentation {
        AppChromePresentation(
            connectionAccessoryState: ConnectionHealthAccessoryState.make(
                hasHomeAssistantSession: hasServerURL && authState.isSignedIn,
                connectionStatus: connectionStatus,
                dataFreshness: dataFreshness
            )
        )
    }
}
