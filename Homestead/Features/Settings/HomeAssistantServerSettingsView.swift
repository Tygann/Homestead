import SwiftUI

// MARK: - Home Assistant Server Settings View
struct HomeAssistantServerSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @FocusState private var focusedField: Field?
    @State private var isEditingConnection = false
    @State private var draftLocalAddress = ""
    @State private var draftRemoteAddress = ""

    var body: some View {
        @Bindable var connectionSettings = connectionSettings

        Form {
            Section {
                serverStatusCard
            }

            Section {
                if isEditingConnection {
                    addressEditorRow(
                        title: "Local Address",
                        placeholder: "homeassistant.local:8123",
                        text: $draftLocalAddress,
                        focus: .localURL
                    )
                    addressEditorRow(
                        title: "Remote Address",
                        placeholder: "https://example.ui.nabu.casa",
                        text: $draftRemoteAddress,
                        focus: .remoteURL
                    )
                } else {
                    SettingsServerAddressRow(
                        title: "Local Address",
                        value: configuredValue(connectionSettings.internalURL),
                        systemImage: "house"
                    )
                    SettingsServerAddressRow(
                        title: "Remote Address",
                        value: configuredValue(displayedRemoteAddress),
                        systemImage: "network"
                    )
                }
                SettingsServerAddressRow(
                    title: "Currently Using",
                    value: activeRouteTitle,
                    detail: activeRouteAddress,
                    systemImage: "arrow.triangle.branch"
                )
            } header: {
                Text("Addresses")
            } footer: {
                if isEditingConnection {
                    Text("Use the Local and Remote URLs from Home Assistant. Homestead signs in through the remote address when available, otherwise the local address.")
                }
            }

            Section("Home Assistant") {
                SettingsServerAddressRow(title: "Version", value: configValue(homeAssistantService.serverConfiguration?.homeAssistantVersion), systemImage: "number")
                SettingsServerAddressRow(title: "Location", value: configValue(homeAssistantService.serverConfiguration?.locationName), systemImage: "mappin.and.ellipse")
                SettingsServerAddressRow(title: "Time Zone", value: configValue(homeAssistantService.serverConfiguration?.timeZone), systemImage: "clock")
            }

            Section {
                DisclosureGroup("Advanced") {
                    LabeledContent("Authentication", value: homeAssistantService.authState.diagnosticTitle)
                    LabeledContent("Connection", value: homeAssistantService.connectionStatus.title)
                    LabeledContent("Mobile App", value: mobileAppStatusTitle)

                    if let signedInServerDisplayText {
                        LabeledContent("Signed-In Server", value: signedInServerDisplayText)
                    }

                    if let mobileAppStatusMessage {
                        Text(mobileAppStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if shouldShowSignIn || canRetryConnection || shouldShowRegistrationAction {
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
                                await homeAssistantService.connect(settings: connectionSettings)
                            }
                        } label: {
                            Text("Retry Connection")
                        }
                        .disabled(homeAssistantService.connectionStatus == .preparing ||
                                  homeAssistantService.connectionStatus == .connecting ||
                                  homeAssistantService.connectionStatus == .reconnecting)
                        .frame(maxWidth: .infinity)
                    }

                    if shouldShowRegistrationAction {
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
                                  !homeAssistantService.authState.isSignedIn ||
                                  homeAssistantService.mobileAppRegistrationState.isRegistering)
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    if shouldShowRegistrationAction {
                        Text("Homestead normally handles mobile app registration automatically after sign-in.")
                    }
                }
            }
        }
        .navigationTitle("Server")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditingConnection)
        .toolbar {
            if isEditingConnection {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelConnectionEditing() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveConnectionEditing() }
                        .disabled(draftLocalAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draftRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { beginConnectionEditing() }
                }
            }
        }
        .task(id: serverRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
            await homeAssistantService.refreshServerConfiguration()
        }
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var serverStatusCard: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: statusSystemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusTint)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(serverDisplayText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var activeRouteTitle: String {
        guard let route = homeAssistantService.activeRouteSummary else {
            return "Not selected"
        }

        return route.title
    }

    private var activeRouteAddress: String? {
        guard let route = homeAssistantService.activeRouteSummary else { return nil }
        return configuredValue(route.baseURLString)
    }

    private var statusSystemImage: String {
        if hasServerMismatch { return "exclamationmark.triangle.fill" }

        switch homeAssistantService.connectionStatus {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting, .preparing, .reconnecting:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "server.rack"
        }
    }

    private var statusMessage: String {
        if hasServerMismatch {
            return "This server is different from the saved Home Assistant sign-in."
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
        case .connected, .preparing, .connecting, .reconnecting:
            return false
        }
    }

    private var mobileAppStatusTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            "Not registered"
        case .registering:
            "Registering"
        case .registered:
            "Registered"
        case .failed:
            "Needs attention"
        }
    }

    private var mobileAppStatusMessage: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return nil
        case .registering:
            return "Homestead is registering with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return message
        }
    }

    private var shouldShowRegistrationAction: Bool {
        guard homeAssistantService.authState.isSignedIn else {
            return false
        }

        if case .failed = homeAssistantService.mobileAppRegistrationState {
            return true
        }

        return false
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

    private var serverRefreshTaskID: String {
        [
            authRefreshTaskID,
            homeAssistantService.connectionStatus.title
        ].joined(separator: "|")
    }

    private func configuredValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not set" : trimmed
    }

    private func configValue(_ value: String?) -> String {
        guard let value else {
            return "Not returned"
        }

        return value
    }

    private func addressEditorRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        focus: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .focused($focusedField, equals: focus)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private func beginConnectionEditing() {
        draftLocalAddress = connectionSettings.internalURL
        draftRemoteAddress = displayedRemoteAddress
        isEditingConnection = true
    }

    private func cancelConnectionEditing() {
        focusedField = nil
        isEditingConnection = false
    }

    private func saveConnectionEditing() {
        focusedField = nil
        let oldLocal = connectionSettings.internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldRemote = displayedRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let newLocal = draftLocalAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let newRemote = draftRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        connectionSettings.internalURL = newLocal
        connectionSettings.externalURL = newRemote
        if newRemote != oldRemote {
            connectionSettings.baseURL = newRemote.isEmpty ? newLocal : newRemote
        } else if newLocal != oldLocal, oldRemote.isEmpty {
            connectionSettings.baseURL = newLocal
        }
        isEditingConnection = false
    }

    private var displayedRemoteAddress: String {
        let remote = connectionSettings.externalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remote.isEmpty { return remote }
        let local = connectionSettings.internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return local.isEmpty ? connectionSettings.baseURL : ""
    }

    private enum Field {
        case localURL
        case remoteURL
    }
}

private struct SettingsServerAddressRow: View {
    let title: String
    let value: String
    var detail: String?
    let systemImage: String

    var body: some View {
        Label {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: AppSpacing.medium)

                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}
