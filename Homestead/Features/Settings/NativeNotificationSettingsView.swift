import SwiftUI
import UIKit

// MARK: - Native Notification Settings View

struct NativeNotificationSettingsView: View {
    // MARK: - Properties

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativeNotificationService.self) private var nativeNotificationService
    @State private var isPerformingDeliveryAction = false

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                NotificationSettingsStatusRow(
                    title: "System Notifications",
                    message: systemStatusMessage,
                    systemImage: systemStatusImage,
                    iconTint: .accentColor,
                    accessory: systemAccessory,
                    action: handleRowAction
                )

                NotificationSettingsStatusRow(
                    title: "Home Assistant Delivery",
                    message: homeAssistantStatusMessage,
                    systemImage: "house.badge.wifi",
                    iconTint: .accentColor,
                    accessory: homeAssistantAccessory,
                    action: handleRowAction
                )

                if let message = nativeNotificationService.lastErrorMessage {
                    Label {
                        Text(UserFacingErrorPresentation.message(forRawMessage: message))
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.red)
                }
            } footer: {
                Text("Both are required to receive notifications.")
            }

            if shouldShowNotificationSettingsAction {
                Section {
                    Button {
                        openIOSNotificationSettings()
                    } label: {
                        SettingsNavigationRowLabel("Notification Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Homestead’s notification settings in the Settings app")
                } footer: {
                    Text("Manage alerts in iOS Settings.")
                }
            }
        }
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.inline)
        .task(id: notificationRefreshTaskID) {
            await refreshDisplayedStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshDisplayedStatus() }
        }
    }

    // MARK: - System Presentation

    private var systemStatusMessage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Banners, sounds, and badges are allowed."
        case .provisional:
            return "Notifications are delivered quietly."
        case .ephemeral:
            return "Notifications are temporarily allowed."
        case .denied:
            return "Turn on notifications in iOS Settings."
        case .notDetermined:
            return "Allow alerts from Homestead on this iPhone."
        case .unknown:
            return "Checking notification access."
        }
    }

    private var systemStatusImage: String {
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
            .status(title: "Quiet", tone: .positive)
        case .ephemeral:
            .status(title: "Temporary", tone: .positive)
        case .denied:
            .action(title: "Settings", action: .openSystemSettings, isEnabled: true)
        case .notDetermined:
            .action(title: "Allow", action: .requestSystemPermission, isEnabled: true)
        case .unknown:
            .status(title: "Checking", tone: .neutral)
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

    // MARK: - Home Assistant Presentation

    private var homeAssistantAccessory: NotificationSettingsRowAccessory {
        if isPerformingDeliveryAction {
            return .progress(title: "Setting Up")
        }

        if hasDeliveryFailure {
            return canSetUpHomeAssistant
                ? .action(title: "Retry", action: .setUpHomeAssistant, isEnabled: true)
                : .status(title: "Needs Attention", tone: .negative)
        }

        if isHomeAssistantDeliveryReady {
            return .status(title: "Ready", tone: .positive)
        }

        if shouldOfferHomeAssistantSetup {
            return canSetUpHomeAssistant
                ? .action(title: "Set Up", action: .setUpHomeAssistant, isEnabled: true)
                : .status(title: "Needs Setup", tone: .neutral)
        }

        return .status(title: "Needs Setup", tone: .neutral)
    }

    private var homeAssistantStatusMessage: String {
        if isPerformingDeliveryAction {
            return "Finishing notification setup."
        }

        if hasServerMismatch {
            return "Sign in again for the selected Home Assistant server."
        }

        guard homeAssistantService.authState.isSignedIn else {
            return "Sign in with Home Assistant to receive notifications."
        }

        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Connect this iPhone to Home Assistant notifications."
        case .registering:
            return hasCloudPushRegistration
                ? "Notifications are ready from your Home Assistant server."
                : "Connecting this iPhone to Home Assistant."
        case .failed(let message):
            return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: message)
        case .registered(let summary):
            guard summary.supportsCloudPushNotifications else {
                return "Finish connecting this iPhone to Home Assistant."
            }
        }

        switch nativeNotificationService.remoteRegistrationState {
        case .failed(let message):
            return UserFacingErrorPresentation.message(forRawMessage: message)
        case .notRegistered, .registeringWithAPNS, .registeringWithBackend, .registered:
            break
        }

        if case .failed(let message) = homeAssistantService.mobileAppPushNotificationState {
            return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: message)
        }

        return "Notifications are ready from your Home Assistant server."
    }

    private var isHomeAssistantDeliveryReady: Bool {
        homeAssistantService.authState.isSignedIn &&
            !hasServerMismatch &&
            hasCloudPushRegistration &&
            !hasDeliveryFailure
    }

    private var hasDeliveryFailure: Bool {
        if case .failed = homeAssistantService.mobileAppRegistrationState {
            return true
        }
        if case .failed = nativeNotificationService.remoteRegistrationState {
            return true
        }
        if case .failed = homeAssistantService.mobileAppPushNotificationState {
            return true
        }
        return false
    }

    private var shouldOfferHomeAssistantSetup: Bool {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered, .failed:
            return true
        case .registering:
            return false
        case .registered(let summary):
            return !summary.supportsCloudPushNotifications
        }
    }

    private var canSetUpHomeAssistant: Bool {
        connectionSettings.hasServerURL &&
            !hasServerMismatch &&
            homeAssistantService.authState.isSignedIn &&
            !homeAssistantService.mobileAppRegistrationState.isRegistering
    }

    private var hasCloudPushRegistration: Bool {
        guard case .registered(let summary) = homeAssistantService.mobileAppRegistrationState else {
            return false
        }
        return summary.supportsCloudPushNotifications
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

    // MARK: - Actions

    private func handleRowAction(_ action: NotificationSettingsRowAction) {
        switch action {
        case .requestSystemPermission:
            Task { await nativeNotificationService.requestAuthorization() }
        case .openSystemSettings:
            openIOSNotificationSettings()
        case .setUpHomeAssistant:
            Task { await setUpHomeAssistantDelivery() }
        }
    }

    private func setUpHomeAssistantDelivery() async {
        guard !isPerformingDeliveryAction else { return }
        isPerformingDeliveryAction = true
        defer { isPerformingDeliveryAction = false }

        if shouldOfferHomeAssistantSetup {
            await homeAssistantService.registerMobileApp(settings: connectionSettings)
        } else {
            await homeAssistantService.refreshMobileAppPushRegistrationIfNeeded(settings: connectionSettings)
        }

        await nativeNotificationService.registerForRemoteNotificationsIfAllowed()
        homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
    }

    private func refreshDisplayedStatus() async {
        await nativeNotificationService.refreshAuthorizationStatus()
    }

    private func openIOSNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
            return
        }
        openURL(url)
    }

    // MARK: - Helpers

    private var notificationRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }
}

// MARK: - Status Row

private enum NotificationSettingsRowAction {
    case requestSystemPermission
    case openSystemSettings
    case setUpHomeAssistant
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
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
            .fixedSize()
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
    .withPreviewEnvironment(.settingsSample(.healthy))
}
#endif
