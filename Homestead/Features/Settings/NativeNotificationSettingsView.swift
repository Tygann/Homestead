import SwiftUI
import UIKit

// MARK: - Native Notification Settings View
struct NativeNotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativeNotificationService.self) private var nativeNotificationService

    var body: some View {
        Form {
            Section {
                NotificationSettingsStatusRow(
                    title: "Notifications",
                    message: permissionMessage,
                    systemImage: permissionSystemImage,
                    iconTint: nativePermissionTint,
                    accessory: systemAccessory,
                    action: handleNotificationRowAction
                )

                if let message = nativeNotificationService.lastErrorMessage {
                    Text(UserFacingErrorPresentation.message(forRawMessage: message))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if shouldShowNotificationSettingsAction {
                    Button {
                        openIOSNotificationSettings()
                    } label: {
                        SettingsNavigationRowLabel("Notification Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Homestead’s notification settings in the Settings app")
                }
            } header: {
                Text("System")
            } footer: {
                Text("Banners, sounds, badges, Lock Screen alerts, and notification grouping are managed by iOS.")
            }

            Section {
                NotificationSettingsStatusRow(
                    title: "Notification Delivery",
                    message: homeAssistantStatusMessage,
                    systemImage: "house.badge.wifi",
                    iconTint: homeAssistantStatusTint,
                    accessory: homeAssistantAccessory,
                    action: handleNotificationRowAction
                )
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("This device must be registered with Home Assistant before it can receive notifications.")
            }

            Section {
                DisclosureGroup("Delivery Details") {
                    LabeledContent("Permission", value: permissionDetailText)
                    LabeledContent("Alerts", value: nativeNotificationService.status.alertSetting.settingsTitle)
                    LabeledContent("Sounds", value: nativeNotificationService.status.soundSetting.settingsTitle)
                    LabeledContent("Badges", value: nativeNotificationService.status.badgeSetting.settingsTitle)
                    LabeledContent("Device Setup", value: mobileAppReadinessTitle)
                    LabeledContent("Background Delivery", value: nativeNotificationService.remoteRegistrationState.settingsTitle)
                    LabeledContent("Notification Delivery", value: homeAssistantService.mobileAppPushNotificationState.settingsTitle)

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
                            await nativeNotificationService.registerForRemoteNotificationsIfAllowed()
                            homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
                        }
                    } label: {
                        Text(nativeNotificationService.isRefreshing ? "Refreshing" : "Refresh Status")
                    }
                    .disabled(nativeNotificationService.isRefreshing)
                }
            } footer: {
                Text("Use these details if notifications aren’t arriving as expected.")
            }
        }
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.inline)
        .task(id: notificationRefreshTaskID) {
            await refreshStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshStatus() }
        }
    }

    private var nativePermissionTint: Color {
        nativeNotificationService.status.authorizationStatus.settingsTint
    }

    private var permissionDetailText: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Quietly Allowed"
        case .ephemeral:
            return "Temporarily Allowed"
        case .denied:
            return "Not Allowed"
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

    private var systemAccessory: NotificationSettingsRowAccessory {
        if nativeNotificationService.isRequestingAuthorization {
            return .progress(title: "Requesting")
        }

        return switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            .status(title: "Allowed", tone: .positive)
        case .provisional:
            .status(title: "Quietly Allowed", tone: .positive)
        case .ephemeral:
            .status(title: "Temporarily Allowed", tone: .positive)
        case .denied:
            .action(title: "Settings", action: .openSystemSettings, isEnabled: true)
        case .notDetermined:
            .action(title: "Allow", action: .requestSystemPermission, isEnabled: true)
        case .unknown:
            .progress(title: "Checking")
        }
    }

    private var shouldShowNotificationSettingsAction: Bool {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined, .unknown:
            return false
        }
    }

    private var homeAssistantAccessory: NotificationSettingsRowAccessory {
        if isHomeAssistantNotificationReady {
            return .status(title: "Ready", tone: .positive)
        }

        if isHomeAssistantNotificationSetupInProgress {
            return .progress(title: "Setting Up")
        }

        if shouldShowMobileAppRegistrationAction {
            return .action(
                title: "Set Up",
                action: .registerHomeAssistant,
                isEnabled: canRegisterMobileApp
            )
        }

        if canFinishNotificationDelivery {
            return .action(title: "Set Up", action: .finishDelivery, isEnabled: true)
        }

        return .status(title: "Needs Setup", tone: .neutral)
    }

    private var isHomeAssistantNotificationSetupInProgress: Bool {
        if homeAssistantService.mobileAppRegistrationState.isRegistering {
            return true
        }

        switch nativeNotificationService.remoteRegistrationState {
        case .registeringWithAPNS, .registeringWithBackend:
            return true
        case .notRegistered, .registered, .failed:
            break
        }

        if case .subscribing = homeAssistantService.mobileAppPushNotificationState {
            return true
        }

        return false
    }

    private var canFinishNotificationDelivery: Bool {
        hasCloudPushRegistration &&
            homeAssistantService.authState.isSignedIn &&
            !hasServerMismatch &&
            nativeNotificationService.status.authorizationStatus.isAllowed
    }

    private var homeAssistantStatusMessage: String {
        if let homeAssistantSetupMessage {
            return homeAssistantSetupMessage
        }

        return "Home Assistant notifications are ready for this device."
    }

    private var homeAssistantStatusTint: Color {
        if isHomeAssistantNotificationReady {
            return .green
        }

        switch homeAssistantService.mobileAppRegistrationState {
        case .failed:
            return .red
        case .registering:
            return .orange
        case .unregistered, .registered:
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

        guard nativeNotificationService.status.authorizationStatus.isAllowed else {
            return "Allow system notifications before delivery can finish."
        }

        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Set up this device for Home Assistant notifications."
        case .registering:
            return "Homestead is setting up this device with Home Assistant."
        case .failed(let message):
            return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: message)
        case .registered(let summary):
            guard summary.supportsCloudPushNotifications else {
                return "Set up this device again to finish notification delivery."
            }
            break
        }

        switch homeAssistantService.mobileAppPushNotificationState {
        case .unavailable:
            return remoteDeliveryMessage
        case .subscribing:
            return "Homestead is connecting notifications."
        case .subscribed:
            return remoteDeliveryMessage
        case .failed(let message):
            return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: message)
        }
    }

    private var mobileAppReadinessTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Not registered"
        case .registering:
            return "Setting up"
        case .registered:
            return hasCloudPushRegistration ? "Ready" : "Needs setup"
        case .failed:
            return "Needs attention"
        }
    }

    private var mobileAppMessage: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            guard homeAssistantService.authState.isSignedIn else {
                return "Sign in with Home Assistant before setting up this device."
            }
            return "Set up this device before Home Assistant notifications can be delivered."
        case .registering:
            return "Homestead is setting up this device with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            if !summary.supportsCloudPushNotifications {
                return "Set up this device again to finish notification delivery."
            }
            return "Set up as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: message)
        }
    }

    private var pushDeliveryMessage: String? {
        switch homeAssistantService.mobileAppPushNotificationState {
        case .unavailable:
            return "Connect to Home Assistant to start notification delivery."
        case .subscribing:
            return "Homestead is connecting notifications."
        case .subscribed(let date):
            return "Ready since \(date.formatted(date: .abbreviated, time: .shortened))."
        case .failed(let message):
            return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: message)
        }
    }

    private var shouldShowMobileAppRegistrationAction: Bool {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered, .failed:
            return true
        case .registering:
            return false
        case .registered(let summary):
            return !summary.supportsCloudPushNotifications
        }
    }

    private var canRegisterMobileApp: Bool {
        connectionSettings.hasServerURL &&
            !hasServerMismatch &&
            homeAssistantService.authState.isSignedIn &&
            !homeAssistantService.mobileAppRegistrationState.isRegistering
    }

    private var isHomeAssistantNotificationReady: Bool {
        hasCloudPushRegistration &&
            homeAssistantService.authState.isSignedIn &&
            !hasServerMismatch &&
            nativeNotificationService.status.authorizationStatus.isAllowed &&
            nativeNotificationService.remoteRegistrationState.isRegistered
    }

    private var hasCloudPushRegistration: Bool {
        guard case .registered(let summary) = homeAssistantService.mobileAppRegistrationState else {
            return false
        }

        return summary.supportsCloudPushNotifications
    }

    private var remoteDeliveryMessage: String? {
        switch nativeNotificationService.remoteRegistrationState {
        case .notRegistered:
            return nativeNotificationService.status.authorizationStatus.isAllowed
                ? "Open Homestead once on this device to finish notification setup."
                : nil
        case .registeringWithAPNS, .registeringWithBackend:
            return "Homestead is finishing notification setup."
        case .registered(let date):
            return "Background delivery set up \(date.formatted(date: .abbreviated, time: .shortened))."
        case .failed(let message):
            return UserFacingErrorPresentation.message(forRawMessage: message)
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

    private func refreshStatus() async {
        await nativeNotificationService.refreshAuthorizationStatus()
        await nativeNotificationService.registerForRemoteNotificationsIfAllowed()
        homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
    }

    private func handleNotificationRowAction(_ action: NotificationSettingsRowAction) {
        switch action {
        case .requestSystemPermission:
            Task { await nativeNotificationService.requestAuthorization() }
        case .openSystemSettings:
            openIOSNotificationSettings()
        case .registerHomeAssistant:
            Task { await homeAssistantService.registerMobileApp(settings: connectionSettings) }
        case .finishDelivery:
            Task { await refreshStatus() }
        }
    }

    private func openIOSNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
            return
        }

        openURL(url)
    }
}

// MARK: - Status Row

private enum NotificationSettingsRowAction {
    case requestSystemPermission
    case openSystemSettings
    case registerHomeAssistant
    case finishDelivery
}

private enum NotificationSettingsRowAccessory {
    case action(title: String, action: NotificationSettingsRowAction, isEnabled: Bool)
    case progress(title: String)
    case status(title: String, tone: NativePermissionStatusTone)
}

private struct NotificationSettingsStatusRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let message: String
    let systemImage: String
    let iconTint: Color
    let accessory: NotificationSettingsRowAccessory
    let action: (NotificationSettingsRowAction) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var standardLayout: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            statusIcon
            statusCopy
            Spacer(minLength: AppSpacing.small)
            accessoryView
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(spacing: AppSpacing.medium) {
                statusIcon
                Text(title)
                    .font(.body)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            accessoryView
        }
    }

    private var statusIcon: some View {
        Image(systemName: systemImage)
            .foregroundStyle(iconTint)
            .frame(width: 28)
            .accessibilityHidden(true)
    }

    private var statusCopy: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.body)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .action(let title, let rowAction, let isEnabled):
            Button(title) {
                action(rowAction)
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
            .disabled(!isEnabled)
            .accessibilityLabel("\(title) \(self.title)")

        case .progress(let title):
            HStack(spacing: AppSpacing.xSmall) {
                ProgressView()
                    .controlSize(.small)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(self.title), \(title)")

        case .status(let title, _):
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accessoryTint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accessoryTint.opacity(0.12), in: Capsule())
                .fixedSize()
                .accessibilityLabel("\(self.title), \(title)")
        }
    }

    private var accessoryTint: Color {
        switch accessory {
        case .action:
            return .accentColor
        case .progress:
            return .secondary
        case .status(_, let tone):
            return switch tone {
            case .positive:
                .green
            case .caution:
                .orange
            case .negative:
                .red
            case .neutral:
                .secondary
            }
        }
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
