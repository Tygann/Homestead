import SwiftUI
import UIKit

// MARK: - Settings View
struct SettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: HomeAssistantSettingsView()) {
                    HomeAssistantSettingsRow(
                        title: accountTitle,
                        server: serverDisplayText,
                        status: accountStatusText,
                        tint: accountStatusTint
                    )
                }
            }

            Section {
                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .task(id: authRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
        }
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var accountTitle: String {
        homeAssistantService.currentUserDisplayName ?? "Home Assistant"
    }

    private var accountStatusText: String {
        SettingsHomeAssistantStatus.summaryStatusText(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var accountStatusTint: Color {
        SettingsHomeAssistantStatus.tint(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var authRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }
}

// MARK: - Home Assistant Settings View
struct HomeAssistantSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @FocusState private var focusedField: Field?

    var body: some View {
        @Bindable var connectionSettings = connectionSettings

        Form {
            Section {
                HStack(spacing: 12) {
                    HomeAssistantAvatarView()

                    VStack(alignment: .leading, spacing: 3) {
                        Text(accountTitle)
                            .foregroundStyle(.primary)

                        Text(serverDisplayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)

                LabeledContent("Status") {
                    Text(statusTitle)
                        .foregroundStyle(statusTint)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let signedInServerDisplayText {
                    LabeledContent("Signed-In Server") {
                        Text(signedInServerDisplayText)
                            .foregroundStyle(hasServerMismatch ? .orange : .secondary)
                    }
                }

                if connectionSettings.hasServerURL {
                    DisclosureGroup("Change Server") {
                        TextField("Base URL", text: $connectionSettings.baseURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .baseURL)
                    }
                } else {
                    TextField("Base URL", text: $connectionSettings.baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .baseURL)
                }
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Use the address you normally use to open Home Assistant.")
            }

            if homeAssistantService.authState.isSignedIn {
                Section {
                    LabeledContent("Mobile App") {
                        Text(mobileAppStatusTitle)
                            .foregroundStyle(mobileAppStatusTint)
                    }

                    if let mobileAppStatusMessage {
                        Text(mobileAppStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        focusedField = nil
                        Task {
                            await homeAssistantService.registerMobileApp(settings: connectionSettings)
                        }
                    } label: {
                        Text(mobileAppButtonTitle)
                    }
                    .disabled(!connectionSettings.hasServerURL ||
                              hasServerMismatch ||
                              homeAssistantService.mobileAppRegistrationState.isRegistering)
                    .frame(maxWidth: .infinity)
                }
            }

            if shouldShowSignIn || canRetryConnection {
                Section {
                    if shouldShowSignIn {
                        Button {
                            focusedField = nil
                            Task {
                                await homeAssistantService.signInWithHomeAssistant(settings: connectionSettings)
                            }
                        } label: {
                            Text(signInButtonTitle)
                        }
                        .disabled(!connectionSettings.hasServerURL || homeAssistantService.authState == .signingIn)
                        .frame(maxWidth: .infinity)
                    }

                    if canRetryConnection {
                        Button {
                            focusedField = nil
                            Task {
                                await homeAssistantService.connect(
                                    baseURLString: connectionSettings.baseURL
                                )
                            }
                        } label: {
                            Text("Retry Connection")
                        }
                        .disabled(homeAssistantService.connectionStatus == .connecting ||
                                  homeAssistantService.connectionStatus == .reconnecting)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            if canSignOut {
                Section {
                    Button(role: .destructive) {
                        focusedField = nil
                        Task { await homeAssistantService.signOut() }
                    } label: {
                        Text("Sign Out")
                    }
                    .disabled(!canSignOut)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Home Assistant")
        .toolbarTitleDisplayMode(.inline)
        .task(id: authRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
        }
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var accountTitle: String {
        homeAssistantService.currentUserDisplayName ?? "Home Assistant"
    }

    private var statusTitle: String {
        SettingsHomeAssistantStatus.detailTitle(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var statusMessage: String {
        if hasServerMismatch {
            return "This server is different from the saved Home Assistant sign-in. Sign in again for this server."
        }

        return SettingsHomeAssistantStatus.detailMessage(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            serviceError: homeAssistantService.lastErrorMessage,
            storageError: connectionSettings.authStorageErrorMessage
        )
    }

    private var statusTint: Color {
        SettingsHomeAssistantStatus.tint(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var signInButtonTitle: String {
        switch homeAssistantService.authState {
        case .signedOut, .refreshFailed, .accessTokenExpired:
            "Sign in with Home Assistant"
        case .signingIn:
            "Signing In"
        case .refreshing:
            "Refreshing"
        case .signedIn:
            "Sign in again"
        }
    }

    private var shouldShowSignIn: Bool {
        if hasServerMismatch {
            return true
        }

        return switch homeAssistantService.authState {
        case .signedOut, .signingIn, .refreshFailed, .accessTokenExpired:
            true
        case .refreshing, .signedIn:
            false
        }
    }

    private var canRetryConnection: Bool {
        guard !hasServerMismatch else {
            return false
        }

        guard homeAssistantService.authState.isSignedIn else {
            return false
        }

        switch homeAssistantService.connectionStatus {
        case .failed, .disconnected:
            return true
        case .connected, .connecting, .reconnecting:
            return false
        }
    }

    private var canSignOut: Bool {
        if homeAssistantService.authState.isSignedIn {
            return true
        }

        if case .refreshFailed = homeAssistantService.authState {
            return true
        }

        return false
    }

    private var signedInServerDisplayText: String? {
        guard let summary = homeAssistantService.authState.sessionSummary else {
            return nil
        }

        return SettingsHomeAssistantStatus.serverDisplayText(summary.baseURLString)
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

    private var mobileAppStatusTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            "Not Registered"
        case .registering:
            "Registering"
        case .registered:
            "Registered"
        case .failed:
            "Needs Attention"
        }
    }

    private var mobileAppStatusMessage: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Homestead will register automatically after sign-in, or you can register again here."
        case .registering:
            return "Registering Homestead with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return message
        }
    }

    private var mobileAppStatusTint: Color {
        switch homeAssistantService.mobileAppRegistrationState {
        case .registered:
            .green
        case .registering:
            .orange
        case .failed:
            .red
        case .unregistered:
            .secondary
        }
    }

    private var mobileAppButtonTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .registering:
            "Registering"
        case .registered:
            "Register Again"
        case .unregistered, .failed:
            "Register Mobile App"
        }
    }

    private var authRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }

    private enum Field {
        case baseURL
    }
}

private extension HAAuthState {
    var sessionSummary: HAAuthSessionSummary? {
        switch self {
        case .signedIn(let summary), .accessTokenExpired(let summary), .refreshing(let summary?):
            summary
        case .refreshing(nil), .signedOut, .signingIn, .refreshFailed:
            nil
        }
    }
}

// MARK: - Home Assistant Settings Row
private struct HomeAssistantSettingsRow: View {
    let title: String
    let server: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(spacing: 15) {
            HomeAssistantAvatarView()
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(server)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fontDesign(.rounded)
            .lineLimit(1)

            Spacer()

            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())
        }
    }
}

// MARK: - Home Assistant Avatar View
private struct HomeAssistantAvatarView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
        .task(id: taskID) {
            await loadImage()
        }
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title
        ].joined(separator: "|")
    }

    private func loadImage() async {
        guard let request = await homeAssistantService.homeAssistantProfileImageRequest(settings: connectionSettings) else {
            image = nil
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                image = nil
                return
            }
            image = Image(uiImage: uiImage)
        } catch {
            image = nil
        }
    }
}

// MARK: - Settings Home Assistant Status
private enum SettingsHomeAssistantStatus {
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
        connectionStatus: HAConnectionStatus
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
            case .connecting:
                "Connecting"
            case .reconnecting:
                "Reconnecting"
            case .failed:
                "Error"
            case .disconnected:
                "Signed In"
            }
        }
    }

    static func tint(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus
    ) -> Color {
        if case .signedIn = authState,
           connectionStatus == .connected {
            return .green
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
            case .connecting:
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
            return message
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Homestead is connected to Home Assistant."
            case .connecting:
                return "Homestead is connecting to Home Assistant."
            case .reconnecting:
                return "Homestead is restoring the connection."
            case .failed(let message):
                return serviceError ?? message
            case .disconnected:
                return serviceError ?? "Homestead is signed in but not currently connected."
            }
        }
    }

    private static func connectionTint(_ connectionStatus: HAConnectionStatus) -> Color {
        switch connectionStatus {
        case .connected:
            .green
        case .failed:
            .red
        case .connecting, .reconnecting:
            .orange
        case .disconnected:
            .secondary
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
    }
    .withPreviewEnvironment()
}

#Preview("Home Assistant Settings") {
    NavigationStack {
        HomeAssistantSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
