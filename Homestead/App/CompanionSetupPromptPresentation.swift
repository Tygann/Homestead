import Foundation

nonisolated enum CompanionNotificationSetupPromptPresentation {
    static func shouldShow(
        hasServerURL: Bool,
        authState: HAAuthState,
        mobileAppRegistrationState: HAMobileAppRegistrationState,
        notificationStatus: NativeNotificationAuthorizationStatus,
        hasHandledPrompt: Bool,
        isShowingSettings: Bool
    ) -> Bool {
        hasServerURL &&
            authState.isSignedIn &&
            mobileAppRegistrationState.isRegistered &&
            notificationStatus.canRequestInApp &&
            !hasHandledPrompt &&
            !isShowingSettings
    }

    static func shouldRefreshNotificationStatus(
        hasServerURL: Bool,
        authState: HAAuthState,
        mobileAppRegistrationState: HAMobileAppRegistrationState,
        notificationStatus: NativeNotificationAuthorizationStatus,
        hasHandledPrompt: Bool
    ) -> Bool {
        hasServerURL &&
            authState.isSignedIn &&
            mobileAppRegistrationState.isRegistered &&
            !hasHandledPrompt &&
            notificationStatus == .unknown
    }
}
