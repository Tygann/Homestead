import SwiftUI
import UIKit

// MARK: - Native Notification Settings View
struct NativeNotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativeNotificationService.self) private var nativeNotificationService

    var body: some View {
        Form {
            Section {
                notificationStatusHeader

                if let message = nativeNotificationService.lastErrorMessage {
                    Text(UserFacingErrorPresentation.message(forRawMessage: message))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Use Settings to adjust banners, sounds, badges, lock screen visibility, and notification grouping.")
            }

            Section {
                if shouldShowAllowNotificationsAction {
                    Button {
                        Task { await nativeNotificationService.requestAuthorization() }
                    } label: {
                        Text(nativeNotificationService.isRequestingAuthorization ? "Requesting Permission" : "Allow Notifications")
                    }
                    .disabled(nativeNotificationService.isRequestingAuthorization)
                    .frame(maxWidth: .infinity)
                }

                Button {
                    openIOSNotificationSettings()
                } label: {
                    Label("Open Homestead in Settings", systemImage: "gearshape")
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                homeAssistantStatusHeader

                if shouldShowMobileAppRegistrationAction {
                    Button {
                        Task { await homeAssistantService.registerMobileApp(settings: connectionSettings) }
                    } label: {
                        Text(mobileAppButtonTitle)
                    }
                    .disabled(!canRegisterMobileApp)
                    .frame(maxWidth: .infinity)
                }

            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Homestead receives Home Assistant notifications while connected to your server.")
            }

            Section {
                DisclosureGroup("Details") {
                    LabeledContent("Permission", value: permissionBadgeText)
                    LabeledContent("Alerts", value: nativeNotificationService.status.alertSetting.settingsTitle)
                    LabeledContent("Sounds", value: nativeNotificationService.status.soundSetting.settingsTitle)
                    LabeledContent("Badges", value: nativeNotificationService.status.badgeSetting.settingsTitle)
                    LabeledContent("Account", value: accountReadinessTitle)
                    LabeledContent("Mobile App", value: mobileAppReadinessTitle)
                    LabeledContent("Delivery Channel", value: homeAssistantService.mobileAppPushNotificationState.settingsTitle)

                    if let mobileAppMessage {
                        Text(mobileAppMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let pushDeliveryMessage {
                        Text(pushDeliveryMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await nativeNotificationService.refreshAuthorizationStatus()
                            homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
                        }
                    } label: {
                        Text(nativeNotificationService.isRefreshing ? "Refreshing" : "Refresh Status")
                    }
                    .disabled(nativeNotificationService.isRefreshing)
                }
            }
        }
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.inline)
        .task(id: notificationRefreshTaskID) {
            await nativeNotificationService.refreshAuthorizationStatus()
            homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
        }
    }

    private var notificationStatusHeader: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(permissionTitle)
                        .font(.headline)

                    Spacer()

                    Text(permissionBadgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(nativePermissionTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(nativePermissionTint.opacity(0.12), in: Capsule())
                }

                Text(permissionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: permissionSystemImage)
                .foregroundStyle(nativePermissionTint)
        }
    }

    private var nativePermissionTint: Color {
        nativeNotificationService.status.authorizationStatus.settingsTint
    }

    private var permissionTitle: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications Enabled"
        case .denied:
            return "Notifications Off"
        case .notDetermined:
            return "Set Up Notifications"
        case .unknown:
            return "Checking Notifications"
        }
    }

    private var permissionBadgeText: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Permission Granted"
        case .provisional:
            return "Quietly Allowed"
        case .ephemeral:
            return "Temporarily Allowed"
        case .denied:
            return "Permission Off"
        case .notDetermined:
            return "Not Set Up"
        case .unknown:
            return "Checking"
        }
    }

    private var permissionMessage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Homestead can show Home Assistant notifications on this device."
        case .provisional:
            return "Homestead can deliver Home Assistant notifications quietly."
        case .ephemeral:
            return "Homestead has temporary permission to show notifications."
        case .denied:
            return "Turn on notifications in Settings to receive Home Assistant alerts."
        case .notDetermined:
            return "Allow Homestead to show notifications from Home Assistant."
        case .unknown:
            return "Homestead is checking notification permission."
        }
    }

    private var permissionSystemImage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined, .unknown:
            return "bell.badge"
        }
    }

    private var shouldShowAllowNotificationsAction: Bool {
        nativeNotificationService.status.authorizationStatus.canRequestInApp
    }

    private var homeAssistantStatusHeader: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(homeAssistantStatusTitle)
                        .font(.headline)

                    Spacer()

                    Text(homeAssistantStatusBadgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(homeAssistantStatusTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(homeAssistantStatusTint.opacity(0.12), in: Capsule())
                }

                Text(homeAssistantStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: "house.badge.wifi")
                .foregroundStyle(homeAssistantStatusTint)
        }
    }

    private var homeAssistantStatusTitle: String {
        if homeAssistantService.mobileAppPushNotificationState.isSubscribed,
           homeAssistantService.mobileAppRegistrationState.isRegistered,
           homeAssistantService.authState.isSignedIn,
           !hasServerMismatch {
            return "Connected and Ready"
        }

        if hasServerMismatch {
            return "Server Needs Attention"
        }

        if homeAssistantService.mobileAppPushNotificationState == .subscribing {
            return "Connecting Notifications"
        }

        switch homeAssistantService.mobileAppRegistrationState {
        case .failed:
            return "Registration Issue"
        case .unregistered:
            return "Registration Needed"
        case .registering:
            return "Registering"
        case .registered:
            return homeAssistantService.authState.isSignedIn ? "Delivery Not Connected" : "Sign In Needed"
        }
    }

    private var homeAssistantStatusBadgeText: String {
        if homeAssistantService.mobileAppPushNotificationState.isSubscribed,
           homeAssistantService.mobileAppRegistrationState.isRegistered,
           homeAssistantService.authState.isSignedIn,
           !hasServerMismatch {
            return "Ready"
        }

        switch homeAssistantService.mobileAppPushNotificationState {
        case .subscribing:
            return "Connecting"
        case .failed:
            return "Action Needed"
        case .unavailable, .subscribed:
            return "Not Ready"
        }
    }

    private var homeAssistantStatusMessage: String {
        if let homeAssistantSetupMessage {
            return homeAssistantSetupMessage
        }

        return "Home Assistant notifications are ready for this device."
    }

    private var homeAssistantStatusTint: Color {
        if homeAssistantService.mobileAppPushNotificationState.isSubscribed,
           homeAssistantService.mobileAppRegistrationState.isRegistered,
           homeAssistantService.authState.isSignedIn,
           !hasServerMismatch {
            return .green
        }

        switch homeAssistantService.mobileAppPushNotificationState {
        case .failed:
            return .red
        case .subscribing:
            return .orange
        case .unavailable, .subscribed:
            return .secondary
        }
    }

    private var homeAssistantSetupMessage: String? {
        if hasServerMismatch {
            return "Sign in again for the selected Home Assistant server."
        }

        guard homeAssistantService.authState.isSignedIn else {
            return "Sign in with Home Assistant before receiving notifications."
        }

        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Register Homestead with Home Assistant to receive notifications."
        case .registering:
            return "Homestead is registering this device with Home Assistant."
        case .failed(let message):
            return message
        case .registered:
            break
        }

        switch homeAssistantService.mobileAppPushNotificationState {
        case .unavailable:
            return "Connect to Home Assistant to start notification delivery."
        case .subscribing:
            return "Homestead is opening the Home Assistant notification channel."
        case .subscribed:
            return nil
        case .failed(let message):
            return message
        }
    }

    private var accountReadinessTitle: String {
        if hasServerMismatch {
            return "Server mismatch"
        }

        guard connectionSettings.hasServerURL else {
            return "Server needed"
        }

        switch homeAssistantService.authState {
        case .signedIn:
            return "Signed in"
        case .signingIn, .refreshing:
            return "Checking"
        case .accessTokenExpired, .refreshFailed:
            return "Needs sign-in"
        case .signedOut:
            return "Signed out"
        }
    }

    private var mobileAppReadinessTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Not registered"
        case .registering:
            return "Registering"
        case .registered:
            return "Ready"
        case .failed:
            return "Needs attention"
        }
    }

    private var mobileAppMessage: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            guard homeAssistantService.authState.isSignedIn else {
                return "Sign in with Home Assistant before registering Homestead as a mobile app."
            }
            return "Register Homestead with this Home Assistant server before notification delivery can be enabled."
        case .registering:
            return "Homestead is registering with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return message
        }
    }

    private var pushDeliveryMessage: String? {
        switch homeAssistantService.mobileAppPushNotificationState {
        case .unavailable:
            return "Connect to Home Assistant to start notification delivery."
        case .subscribing:
            return "Homestead is opening Home Assistant's mobile-app notification channel."
        case .subscribed(let date):
            return "Ready since \(date.formatted(date: .abbreviated, time: .shortened))."
        case .failed(let message):
            return message
        }
    }

    private var shouldShowMobileAppRegistrationAction: Bool {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered, .failed:
            return true
        case .registering, .registered:
            return false
        }
    }

    private var canRegisterMobileApp: Bool {
        connectionSettings.hasServerURL &&
            !hasServerMismatch &&
            homeAssistantService.authState.isSignedIn &&
            !homeAssistantService.mobileAppRegistrationState.isRegistering
    }

    private var mobileAppButtonTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .registering:
            return "Registering"
        case .registered:
            return "Register Again"
        case .unregistered, .failed:
            return "Register Mobile App"
        }
    }

    private var hasServerMismatch: Bool {
        guard connectionSettings.hasServerURL,
              let summary = homeAssistantService.authState.sessionSummary else {
            return false
        }

        let signedInServer = HAConnectionConfiguration(
            baseURLString: summary.baseURLString,
            accessToken: ""
        ).dataSourceID
        let enteredServer = HAConnectionConfiguration(
            baseURLString: connectionSettings.baseURL,
            accessToken: ""
        ).dataSourceID
        return signedInServer != enteredServer
    }

    private var notificationRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.mobileAppRegistrationState.settingsTaskID
        ].joined(separator: "|")
    }

    private func openIOSNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }
}

#if DEBUG
#Preview("Notification Settings") {
    NavigationStack {
        NativeNotificationSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
