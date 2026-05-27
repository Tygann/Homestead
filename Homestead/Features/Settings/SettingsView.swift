import SwiftUI

struct SettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @FocusState private var focusedField: Field?

    var body: some View {
        @Bindable var connectionSettings = connectionSettings

        Form {
            Section {
                TextField("Base URL", text: $connectionSettings.baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .baseURL)
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Sign in opens Home Assistant and stores the refresh token in Keychain.")
            }

            Section {
                Button {
                    focusedField = nil
                    Task {
                        await homeAssistantService.signInWithHomeAssistant(settings: connectionSettings)
                    }
                } label: {
                    Label(signInButtonTitle, systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!connectionSettings.hasServerURL || homeAssistantService.authState == .signingIn)

                Button {
                    focusedField = nil
                    Task {
                        await homeAssistantService.testConnection(
                            baseURLString: connectionSettings.baseURL
                        )
                    }
                } label: {
                    Label("Test Connection", systemImage: "network")
                }
                .disabled(!homeAssistantService.authState.isSignedIn || homeAssistantService.smokeTestState.isTesting)

                if homeAssistantService.connectionStatus == .connected {
                    Label("Connected", systemImage: homeAssistantService.connectionStatus.systemImage)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Button {
                        focusedField = nil
                        Task {
                            await homeAssistantService.connect(
                                baseURLString: connectionSettings.baseURL
                            )
                        }
                    } label: {
                        Label(connectButtonTitle, systemImage: "bolt.horizontal.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !homeAssistantService.authState.isSignedIn ||
                        homeAssistantService.connectionStatus == .connecting ||
                        homeAssistantService.connectionStatus == .reconnecting
                    )
                }

                Button(role: .destructive) {
                    Task { await homeAssistantService.disconnect() }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .disabled(homeAssistantService.connectionStatus == .disconnected)

                Button(role: .destructive) {
                    focusedField = nil
                    Task { await homeAssistantService.signOut() }
                } label: {
                    Label("Sign Out", systemImage: "person.crop.circle.badge.xmark")
                }
                .disabled(!canSignOut)
            }

            Section {
                SettingsStatusRow(
                    title: homeAssistantService.authState.title,
                    systemImage: authStatusSystemImage,
                    tint: authStatusTint
                )

                if let detail = authStatusDetail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsStatusRow(
                    title: homeAssistantService.connectionStatus.title,
                    systemImage: homeAssistantService.connectionStatus.systemImage,
                    tint: connectionStatusTint
                )

                if homeAssistantService.smokeTestState != .idle {
                    SettingsStatusRow(
                        title: homeAssistantService.smokeTestState.title,
                        systemImage: homeAssistantService.smokeTestState.systemImage,
                        tint: smokeTestTint
                    )

                    if let detail = homeAssistantService.smokeTestState.detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = homeAssistantService.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let message = connectionSettings.authStorageErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                SettingsStatusRow(
                    title: mobileAppRegistrationTitle,
                    systemImage: mobileAppRegistrationSystemImage,
                    tint: mobileAppRegistrationTint
                )

                if let detail = mobileAppRegistrationDetail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    focusedField = nil
                    Task { await homeAssistantService.registerMobileApp(settings: connectionSettings) }
                } label: {
                    Label("Register App", systemImage: "iphone.gen3")
                }
                .disabled(
                    !homeAssistantService.authState.isSignedIn ||
                    homeAssistantService.mobileAppRegistrationState.isRegistering
                )
            } header: {
                Text("Native App")
            } footer: {
                Text("Homestead registers automatically after sign-in when no matching mobile-app registration is saved.")
            }

#if DEBUG
            Section {
                LabeledContent("Preview WebSocket URL") {
                    Text(webSocketEndpointDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Safe to share: this endpoint does not include your access token.")
            }
#endif
            Section {
                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .task(id: mobileAppRegistrationTaskID) {
            await homeAssistantService.refreshAuthState()
            homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
        }
    }

#if DEBUG
    private var webSocketEndpointDescription: String {
        do {
            return try HomeAssistantEndpointBuilder
                .webSocketURL(from: connectionSettings.baseURL)
                .absoluteString
        } catch {
            return "Invalid Home Assistant URL"
        }
    }
#endif

    private var connectButtonTitle: String {
        switch homeAssistantService.connectionStatus {
        case .failed, .disconnected:
            "Connect"
        case .connecting:
            "Connecting"
        case .reconnecting:
            "Reconnecting"
        case .connected:
            "Connected"
        }
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

    private var authStatusSystemImage: String {
        switch homeAssistantService.authState {
        case .signedIn:
            "checkmark.seal.fill"
        case .signingIn, .refreshing:
            "arrow.triangle.2.circlepath"
        case .accessTokenExpired:
            "clock.badge.exclamationmark"
        case .refreshFailed:
            "exclamationmark.triangle.fill"
        case .signedOut:
            "person.crop.circle"
        }
    }

    private var authStatusTint: Color {
        switch homeAssistantService.authState {
        case .signedIn:
            .green
        case .signingIn, .refreshing, .accessTokenExpired:
            .orange
        case .refreshFailed:
            .red
        case .signedOut:
            .secondary
        }
    }

    private var authStatusDetail: String? {
        switch homeAssistantService.authState {
        case .signedIn(let summary), .accessTokenExpired(let summary):
            return "Access token expires \(summary.accessTokenExpiresAt.formatted(date: .abbreviated, time: .shortened))."
        case .refreshing(let summary):
            guard let summary else { return "Refreshing Home Assistant access." }
            return "Refreshing token for \(summary.baseURLString)."
        case .refreshFailed(let message):
            return message
        case .signedOut:
            return "No Home Assistant refresh token is saved."
        case .signingIn:
            return "Waiting for Home Assistant authorization."
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

    private var connectionStatusTint: Color {
        switch homeAssistantService.connectionStatus {
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

    private var smokeTestTint: Color {
        switch homeAssistantService.smokeTestState {
        case .succeeded:
            .green
        case .failed:
            .red
        case .testing:
            .orange
        case .idle:
            .secondary
        }
    }

    private var mobileAppRegistrationTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            "Not Registered"
        case .registering:
            "Registering"
        case .registered:
            "Registered"
        case .failed:
            "Registration Error"
        }
    }

    private var mobileAppRegistrationSystemImage: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .registered:
            "checkmark.icloud.fill"
        case .registering:
            "arrow.triangle.2.circlepath"
        case .failed:
            "exclamationmark.triangle.fill"
        case .unregistered:
            "iphone.gen3"
        }
    }

    private var mobileAppRegistrationTint: Color {
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

    private var mobileAppRegistrationDetail: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .registered(let summary):
            "\(summary.deviceName) · Homestead \(summary.appVersion)"
        case .failed(let message):
            message
        case .registering:
            "Creating a Home Assistant mobile app registration."
        case .unregistered:
            nil
        }
    }

    private var mobileAppRegistrationTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }

    private enum Field {
        case baseURL
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
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
#endif
