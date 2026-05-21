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

                SecureField("Long-lived access token", text: $connectionSettings.accessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .accessToken)
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Long-lived access tokens are stored in Keychain.")
            }

            Section {
                Button {
                    focusedField = nil
                    Task {
                        await homeAssistantService.testConnection(
                            baseURLString: connectionSettings.baseURL,
                            accessToken: connectionSettings.accessToken
                        )
                    }
                } label: {
                    Label("Test Connection", systemImage: "network")
//                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!connectionSettings.hasCredentials || homeAssistantService.smokeTestState.isTesting)

                if homeAssistantService.connectionStatus == .connected {
                    Label("Connected", systemImage: homeAssistantService.connectionStatus.systemImage)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Button {
                        focusedField = nil
                        Task {
                            await homeAssistantService.connect(
                                baseURLString: connectionSettings.baseURL,
                                accessToken: connectionSettings.accessToken
                            )
                        }
                    } label: {
                        Label(connectButtonTitle, systemImage: "bolt.horizontal.circle.fill")
//                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !connectionSettings.hasCredentials ||
                        homeAssistantService.connectionStatus == .connecting ||
                        homeAssistantService.connectionStatus == .reconnecting
                    )
                }

                Button(role: .destructive) {
                    Task { await homeAssistantService.disconnect() }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
//                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(homeAssistantService.connectionStatus == .disconnected)
            }

            Section {
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

                if let message = connectionSettings.credentialStorageErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

    private enum Field {
        case baseURL
        case accessToken
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
