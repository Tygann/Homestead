import SwiftUI

// MARK: - Home Assistant Settings View
struct HomeAssistantSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativePermissionService.self) private var nativePermissionService
    @FocusState private var focusedField: Field?
    @State private var isConfirmingSignOut = false
    @State private var isEditingServer = false
    @State private var draftLocalAddress = ""
    @State private var draftRemoteAddress = ""
    @State private var draftInternalNetworkSSIDs: [String] = []
    @State private var draftSSID = ""
    @State private var currentWiFiErrorMessage: String?

    var body: some View {
        Form {
            accountSection

            serverSection

            if isEditingServer {
                localNetworksSection
            }

            homeAssistantSection

            advancedSection

            serverActionsSection

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
        .task(id: serverRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
            await homeAssistantService.refreshServerConfiguration()
        }
        .alert("Wi-Fi Name Unavailable", isPresented: Binding(
            get: { currentWiFiErrorMessage != nil },
            set: { if !$0 { currentWiFiErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(currentWiFiErrorMessage ?? "Homestead could not read the current Wi-Fi name.")
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

    private var serverSection: some View {
        Section {
            serverStatusRow

            if isEditingServer {
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
                if !connectionSettings.internalNetworkSSIDs.isEmpty {
                    SettingsServerAddressRow(
                        title: "Local Networks",
                        value: localNetworksSummary(connectionSettings.internalNetworkSSIDs),
                        systemImage: "wifi"
                    )
                }
            }

            SettingsServerAddressRow(
                title: "Currently Using",
                value: activeRouteTitle,
                detail: activeRouteAddress,
                systemImage: "arrow.triangle.branch"
            )

            if isEditingServer {
                HStack {
                    Button("Cancel") {
                        cancelServerEditing()
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button("Save") {
                        saveServerEditing()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveServerEdits)
                }
                .padding(.vertical, AppSpacing.xSmall)
            } else {
                Button {
                    beginServerEditing()
                } label: {
                    Label("Edit Server", systemImage: "pencil")
                }
            }
        } header: {
            Text("Server")
        } footer: {
            if isEditingServer {
                Text("Remote Address is used away from home. Local Address is used only on saved Wi-Fi networks.")
            }
        }
    }

    private var serverStatusRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: statusSystemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accountStatusTint)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(serverDisplayText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(serverStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var localNetworksSection: some View {
        Section {
            if draftInternalNetworkSSIDs.isEmpty {
                Text("No Wi-Fi networks added.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(draftInternalNetworkSSIDs, id: \.self) { ssid in
                    HStack {
                        Text(ssid)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            removeSSID(ssid)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(ssid)")
                    }
                }
            }

            HStack {
                TextField("Wi-Fi Name", text: $draftSSID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .ssid)

                Button("Add") {
                    addSSID(draftSSID)
                    draftSSID = ""
                }
                .disabled(draftSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button {
                Task { await addCurrentWiFiSSID() }
            } label: {
                Label("Use Current Wi-Fi", systemImage: "wifi")
            }
            .disabled(nativePermissionService.isRequestingLocationAccess)
        } header: {
            Text("Use Local Address On")
        } footer: {
            Text("Reading the current Wi-Fi name requires Location permission.")
        }
    }

    private var homeAssistantSection: some View {
        Section("Home Assistant") {
            SettingsServerAddressRow(title: "Version", value: configValue(homeAssistantService.serverConfiguration?.homeAssistantVersion), systemImage: "number")
            SettingsServerAddressRow(title: "Location", value: configValue(homeAssistantService.serverConfiguration?.locationName), systemImage: "mappin.and.ellipse")
            SettingsServerAddressRow(title: "Time Zone", value: configValue(homeAssistantService.serverConfiguration?.timeZone), systemImage: "clock")
        }
    }

    private var advancedSection: some View {
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
    }

    @ViewBuilder
    private var serverActionsSection: some View {
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

    private var serverStatusMessage: String {
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

    private var canSaveServerEdits: Bool {
        !draftLocalAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draftRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func beginServerEditing() {
        draftLocalAddress = connectionSettings.internalURL
        draftRemoteAddress = displayedRemoteAddress
        draftInternalNetworkSSIDs = connectionSettings.internalNetworkSSIDs
        draftSSID = ""
        currentWiFiErrorMessage = nil
        isEditingServer = true
    }

    private func cancelServerEditing() {
        focusedField = nil
        isEditingServer = false
    }

    private func saveServerEditing() {
        focusedField = nil
        let oldLocal = connectionSettings.internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldRemote = displayedRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let newLocal = draftLocalAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let newRemote = draftRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        connectionSettings.internalURL = newLocal
        connectionSettings.externalURL = newRemote
        connectionSettings.internalNetworkSSIDs = HAConnectionSettings.normalizedSSIDs(draftInternalNetworkSSIDs)
        if newRemote != oldRemote {
            connectionSettings.baseURL = newRemote.isEmpty ? newLocal : newRemote
        } else if newLocal != oldLocal, oldRemote.isEmpty {
            connectionSettings.baseURL = newLocal
        }
        isEditingServer = false
    }

    private func addSSID(_ ssid: String) {
        draftInternalNetworkSSIDs = HAConnectionSettings.normalizedSSIDs(draftInternalNetworkSSIDs + [ssid])
    }

    private func removeSSID(_ ssid: String) {
        draftInternalNetworkSSIDs.removeAll { $0.caseInsensitiveCompare(ssid) == .orderedSame }
    }

    private func addCurrentWiFiSSID() async {
        await nativePermissionService.requestLocationAccess()
        guard let ssid = await homeAssistantService.refreshCurrentWiFiSSID() else {
            currentWiFiErrorMessage = "Homestead could not read the current Wi-Fi name. Check Location permission, the Wi-Fi Information capability, and that this device is connected to Wi-Fi."
            return
        }

        addSSID(ssid)
    }

    private func localNetworksSummary(_ ssids: [String]) -> String {
        let normalized = HAConnectionSettings.normalizedSSIDs(ssids)
        if normalized.isEmpty { return "Not set" }
        if normalized.count == 1 { return normalized[0] }
        return "\(normalized.count) networks"
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
        case ssid
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
