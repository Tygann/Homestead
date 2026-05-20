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
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!connectionSettings.hasCredentials || homeAssistantService.smokeTestState.isTesting)

                Button {
                    focusedField = nil
                    Task {
                        await homeAssistantService.connect(
                            baseURLString: connectionSettings.baseURL,
                            accessToken: connectionSettings.accessToken
                        )
                    }
                } label: {
                    Label("Connect", systemImage: "bolt.horizontal.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    !connectionSettings.hasCredentials ||
                    homeAssistantService.connectionStatus == .connecting ||
                    homeAssistantService.connectionStatus == .reconnecting
                )

                Button(role: .destructive) {
                    Task { await homeAssistantService.disconnect() }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(homeAssistantService.connectionStatus == .disconnected)
            }

            Section {
                Label(
                    homeAssistantService.smokeTestState.title,
                    systemImage: homeAssistantService.smokeTestState.systemImage
                )

                if let detail = homeAssistantService.smokeTestState.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Label(
                    homeAssistantService.connectionStatus.title,
                    systemImage: homeAssistantService.connectionStatus.systemImage
                )

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

    private enum Field {
        case baseURL
        case accessToken
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
