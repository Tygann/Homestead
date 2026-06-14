import SwiftUI

// MARK: - Home Assistant Settings View
struct HomeAssistantSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isConfirmingSignOut = false

    var body: some View {
        Form {
            accountSection

            serverNavigationSection

            if shouldShowSupport {
                Section {
                    NavigationLink {
                        HomeAssistantDiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "stethoscope")
                    }
                } footer: {
                    Text("Support details are available if something is not working as expected.")
                }
            }

            if canSignOut {
                Section {
                    Button(role: .destructive) {
                        isConfirmingSignOut = true
                    } label: {
                        Text("Sign Out")
                    }
                    .disabled(!canSignOut)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inline)
        .padding(.top, -30)
        .task(id: authRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
        }
        .confirmationDialog(
            "Sign out of Home Assistant?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await homeAssistantService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved Home Assistant credentials and mobile app registration from this device.")
        }
    }

    private var serverNavigationSection: some View {
        Section {
            NavigationLink {
                HomeAssistantServerSettingsView()
            } label: {
                Label {
                    HStack(spacing: AppSpacing.medium) {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text("Server")
                                .foregroundStyle(.primary)

                            Text(serverDisplayText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(accountStatusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accountStatusTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accountStatusTint.opacity(0.12), in: Capsule())
                    }
                } icon: {
                    Image(systemName: "server.rack")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var accountSection: some View {
        Section {
            VStack(alignment: .center, spacing: 10) {
                HomeAssistantAvatarView()
                    .frame(width: 100, height: 100)

                Text(accountTitle)
                    .font(.title)

                Text(serverDisplayText)
                    .foregroundColor(.gray)
                    .fontDesign(.rounded)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)

            if let primaryStatusMessage {
                Text(primaryStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if hasServerMismatch, let signedInServerDisplayText {
                LabeledContent("Signed-In Server") {
                    Text(signedInServerDisplayText)
                        .foregroundStyle(.orange)
                }
            }
        }
        .listRowBackground(Color.clear)
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var accountTitle: String {
        homeAssistantService.currentUserDisplayName ?? "Home Assistant"
    }

    private var primaryStatusMessage: String? {
        if hasServerMismatch {
            return "This server is different from the saved Home Assistant sign-in. Sign in again for this server."
        }

        if connectionSettings.authStorageErrorMessage != nil {
            return "Unable to access saved sign-in."
        }

        switch homeAssistantService.authState {
        case .signedOut:
            return "Sign in to connect Homestead to Home Assistant."
        case .signingIn:
            return "Waiting for Home Assistant authorization."
        case .refreshing:
            return "Refreshing your Home Assistant session."
        case .refreshFailed:
            return "Authentication failed."
        case .accessTokenExpired:
            return "Sign in again to continue using Home Assistant."
        case .signedIn:
            switch homeAssistantService.connectionStatus {
            case .failed, .disconnected:
                return "Unable to reach server."
            case .connected, .preparing, .connecting, .reconnecting:
                return nil
            }
        }
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

    private var shouldShowSupport: Bool {
        connectionSettings.hasServerURL || homeAssistantService.authState.isSignedIn || homeAssistantService.hasCompletedInitialCacheLoad
    }

    private var authRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }
}

#if DEBUG
#Preview("Account Settings") {
    NavigationStack {
        HomeAssistantSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
