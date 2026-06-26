import SwiftUI
// MARK: - Home Assistant Avatar View
struct HomeAssistantAvatarView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    var body: some View {
        HomeAssistantAsyncImage(
            id: taskID,
            request: {
                await homeAssistantService.homeAssistantProfileImageRequest(settings: connectionSettings)
            }
        ) { image in
            if let image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray)
            }
        }
        .clipShape(Circle())
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title
        ].joined(separator: "|")
    }

}

// MARK: - Settings Status Chip
struct SettingsStatusChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - Settings Home Assistant Status
enum SettingsHomeAssistantStatus {
    static func serverDisplayText(_ baseURL: String) -> String {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            return "No server set"
        }

        let normalizedURL: String
        if trimmedURL.contains("://") {
            normalizedURL = trimmedURL
        } else {
            normalizedURL = "http://\(trimmedURL)"
        }

        guard let host = URL(string: normalizedURL)?.host(percentEncoded: false) else {
            return trimmedURL
        }

        return host
    }

    static func summaryStatusText(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        dataFreshness: HADataFreshness = .empty
    ) -> String {
        switch authState {
        case .signedOut:
            "Signed Out"
        case .signingIn:
            "Signing In"
        case .refreshing:
            "Refreshing"
        case .refreshFailed:
            "Error"
        case .accessTokenExpired:
            "Needs Sign-In"
        case .signedIn:
            switch connectionStatus {
            case .connected:
                "Connected"
            case .preparing, .connecting:
                dataFreshness.isUsable ? "Updating" : "Connecting"
            case .reconnecting:
                dataFreshness.isUsable ? "Updating" : "Reconnecting"
            case .failed:
                dataFreshness.isUsable ? "Offline" : "Error"
            case .disconnected:
                dataFreshness.isUsable ? "Offline" : "Signed In"
            }
        }
    }

    static func tint(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        dataFreshness: HADataFreshness = .empty
    ) -> Color {
        if case .signedIn = authState,
           connectionStatus == .connected {
            return .green
        }

        if case .signedIn = authState,
           dataFreshness.isUsable {
            return .orange
        }

        switch authState {
        case .signedIn:
            return connectionTint(connectionStatus)
        case .signingIn, .refreshing, .accessTokenExpired:
            return .orange
        case .refreshFailed:
            return .red
        case .signedOut:
            return .secondary
        }
    }

    static func detailTitle(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus
    ) -> String {
        switch authState {
        case .signedOut:
            return "Signed Out"
        case .signingIn:
            return "Signing In"
        case .refreshing:
            return "Refreshing"
        case .accessTokenExpired, .refreshFailed:
            return "Needs Attention"
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Connected"
            case .preparing, .connecting:
                return "Connecting"
            case .reconnecting:
                return "Reconnecting"
            case .failed:
                return "Connection Issue"
            case .disconnected:
                return "Not Connected"
            }
        }
    }

    static func detailMessage(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        serviceError: String?,
        storageError: String?
    ) -> String {
        if let storageError {
            return storageError
        }

        switch authState {
        case .signedOut:
            return "Sign in to connect Homestead to Home Assistant."
        case .signingIn:
            return "Waiting for Home Assistant authorization."
        case .refreshing:
            return "Refreshing your Home Assistant session."
        case .accessTokenExpired:
            return "Sign in again to continue using Home Assistant."
        case .refreshFailed(let message):
            return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: message)
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Homestead is connected to Home Assistant."
            case .preparing, .connecting:
                return "Homestead is connecting to Home Assistant."
            case .reconnecting:
                return "Homestead is restoring the connection."
            case .failed(let message):
                return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: serviceError ?? message)
            case .disconnected:
                if let serviceError {
                    return HAConnectionIssuePresentation.fallbackMessage(forRawMessage: serviceError)
                }
                return "Homestead is signed in but not currently connected."
            }
        }
    }

    private static func connectionTint(_ connectionStatus: HAConnectionStatus) -> Color {
        switch connectionStatus {
        case .connected:
            .green
        case .failed:
            .red
        case .preparing, .connecting, .reconnecting:
            .orange
        case .disconnected:
            .secondary
        }
    }
}

extension HAAuthState {
    var sessionSummary: HAAuthSessionSummary? {
        switch self {
        case .signedIn(let summary), .accessTokenExpired(let summary), .refreshing(let summary?):
            summary
        case .refreshing(nil), .signedOut, .signingIn, .refreshFailed:
            nil
        }
    }

    var diagnosticTitle: String {
        switch self {
        case .signedOut:
            "Signed Out"
        case .signingIn:
            "Signing In"
        case .refreshing:
            "Refreshing"
        case .signedIn:
            "Signed In"
        case .accessTokenExpired:
            "Access Token Expired"
        case .refreshFailed:
            "Refresh Failed"
        }
    }
}

extension HADataFreshness {
    var settingsTitle: String {
        switch self {
        case .empty:
            "No state loaded"
        case .cached:
            "Showing Last Update"
        case .refreshing:
            "Refreshing"
        case .live:
            "Live"
        case .stale:
            "Stale"
        }
    }

    var settingsTint: Color {
        switch self {
        case .live:
            .green
        case .cached, .refreshing:
            .orange
        case .stale:
            .red
        case .empty:
            .secondary
        }
    }
}

extension NativeNotificationAuthorizationStatus {
    var settingsTitle: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .notDetermined:
            return "Not Set Up"
        case .denied:
            return "Off"
        case .authorized:
            return "On"
        case .provisional:
            return "Quietly Allowed"
        case .ephemeral:
            return "Temporarily Allowed"
        }
    }

    var settingsMessage: String {
        switch self {
        case .unknown:
            return "Homestead has not checked notification permission yet."
        case .notDetermined:
            return "Allow notifications before Home Assistant notification delivery is enabled."
        case .denied:
            return "Notifications are turned off for Homestead in Settings."
        case .authorized:
            return "The system allows Homestead to show notifications on this device."
        case .provisional:
            return "The system allows Homestead to deliver notifications quietly."
        case .ephemeral:
            return "The system has granted temporary notification permission."
        }
    }

    var settingsTint: Color {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .notDetermined, .unknown:
            return .orange
        case .denied:
            return .red
        }
    }
}

extension NativeNotificationDeliverySetting {
    var settingsTitle: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .unavailable:
            return "Unavailable"
        case .disabled:
            return "Off"
        case .enabled:
            return "On"
        }
    }
}

extension NativeRemoteNotificationRegistrationState {
    var settingsTitle: String {
        switch self {
        case .notRegistered:
            return "Needs setup"
        case .registeringWithAPNS, .registeringWithBackend:
            return "Setting up"
        case .registered:
            return "On"
        case .failed:
            return "Needs attention"
        }
    }
}

extension HAMobileAppPushNotificationState {
    var settingsTitle: String {
        switch self {
        case .unavailable:
            return "Not connected"
        case .subscribing:
            return "Connecting"
        case .subscribed:
            return "Ready"
        case .failed:
            return "Needs attention"
        }
    }
}

extension HAMobileAppRegistrationState {
    var diagnosticTitle: String {
        switch self {
        case .unregistered:
            return "Not Registered"
        case .registering:
            return "Registering"
        case .registered(let summary):
            let cloudhook = summary.usesCloudhook ? "cloudhook" : "local webhook"
            let encryptedSecret = summary.hasEncryptedWebhookSecret ? "secret present" : "no secret"
            return "Registered as \(summary.deviceName), app \(summary.appVersion), \(cloudhook), \(encryptedSecret)"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    var settingsTaskID: String {
        switch self {
        case .unregistered:
            return "unregistered"
        case .registering:
            return "registering"
        case .registered(let summary):
            return "registered-\(summary.deviceName)-\(summary.registeredAt.timeIntervalSince1970)"
        case .failed(let message):
            return "failed-\(message)"
        }
    }
}
