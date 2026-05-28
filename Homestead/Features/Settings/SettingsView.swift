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
//                    HomeAssistantAvatarView(size: 42, tint: statusTint)
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

            if shouldShowSignIn || canRetryConnection {
                Section {
                    if shouldShowSignIn {
                        Button {
                            focusedField = nil
                            Task {
                                await homeAssistantService.signInWithHomeAssistant(settings: connectionSettings)
                            }
                        } label: {
                            Label(signInButtonTitle, systemImage: "")
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
                            Label("Retry Connection", systemImage: "")
                        }
                        .disabled(homeAssistantService.connectionStatus == .connecting ||
                                  homeAssistantService.connectionStatus == .reconnecting)
                        .frame(maxWidth: .infinity)
                    }
//                } header: {
//                    Text("Account")
                }
            }

            if canSignOut {
                Section {
                    Button(role: .destructive) {
                        focusedField = nil
                        Task { await homeAssistantService.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "")
                    }
                    .disabled(!canSignOut)
                    .frame(maxWidth: .infinity)
//                } header: {
//                    Text("Session")
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
        SettingsHomeAssistantStatus.detailMessage(
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
        switch homeAssistantService.authState {
        case .signedOut, .signingIn, .refreshFailed, .accessTokenExpired:
            true
        case .refreshing, .signedIn:
            false
        }
    }

    private var canRetryConnection: Bool {
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
//                    .lineLimit(1)
            }
            .fontDesign(.rounded)
            .lineLimit(1)
        }
    }
}

private struct HomeAssistantSettingsRow_Backup: View {
    let title: String
    let server: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
//            HomeAssistantAvatarView(size: 32, tint: tint)
            HomeAssistantAvatarView()

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)

                Text(server)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(status)
                .font(.footnote)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Home Assistant Avatar View
private struct HomeAssistantAvatarView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

//    let size: CGFloat
//    let tint: Color

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
//                    .font(.system(size: size * 0.48, weight: .semibold))
//                    .foregroundStyle(tint)
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 60, height: 60)
//        .frame(width: size, height: size)
//        .background(.quaternary, in: Circle())
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
