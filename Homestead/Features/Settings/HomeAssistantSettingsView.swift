import SwiftUI

// MARK: - Home Assistant Settings View
struct HomeAssistantSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativePermissionService.self) private var nativePermissionService
    @FocusState private var focusedField: Field?
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDiscard = false
    @State private var isEditingServer = false
    @State private var draftLocalAddress = ""
    @State private var draftRemoteAddress = ""
    @State private var draftInternalNetworkSSIDs: [String] = []
    @State private var draftSSID = ""
    @State private var isShowingManualNetworkEntry = false
    @State private var isReplacingHomeNetwork = false
    @State private var currentWiFiErrorMessage: String?

    var body: some View {
        Form {
            accountSection

            serverSection

            if !isEditingServer {
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
        }
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditingServer)
        .toolbarBackground(.hidden, for: .navigationBar)
        .padding(.top, -30)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if isEditingServer {
                    Button("Cancel") {
                        requestCancelServerEditing()
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Account")
                    .font(.headline)
            }

            if isEditingServer {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveServerEditing()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .fontWeight(.semibold)
                    .disabled(!canSaveServerEdits)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        beginServerEditing()
                    }
                }
            }
        }
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
        .confirmationDialog(
            "Discard server changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                cancelServerEditing()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your edited server settings will be lost.")
        }
    }

    private var accountSection: some View {
        Section {
            VStack(alignment: .center, spacing: 10) {
                HomeAssistantAvatarView()
                    .frame(width: 100, height: 100)

                Text(accountTitle)
                    .font(.title)
                    .bold()

                statusChip
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }

    private var statusChip: some View {
        SettingsStatusChip(title: headerStatusTitle, tint: headerStatusTint)
            .accessibilityLabel("Connection status, \(headerStatusTitle)")
    }

    private var serverSection: some View {
        Section {
            SettingsServerAddressRow(
                title: "Server Name",
                value: serverName,
                systemImage: "house"
            )

            if isEditingServer {
                addressEditorRow(
                    title: "Internal URL",
                    systemImage: "network",
                    placeholder: "homeassistant.local:8123",
                    text: $draftLocalAddress,
                    focus: .localURL
                )
                localNetworkEditorRows
                addressEditorRow(
                    title: "External URL",
                    systemImage: "globe",
                    placeholder: "https://example.ui.nabu.casa",
                    text: $draftRemoteAddress,
                    focus: .remoteURL
                )
            } else {
                SettingsServerAddressRow(
                    title: "Internal URL",
                    value: configuredValue(connectionSettings.internalURL),
                    systemImage: "network"
                )
                SettingsServerAddressRow(
                    title: "Home Network",
                    value: homeNetworkValue(connectionSettings.internalNetworkSSIDs),
                    systemImage: "wifi"
                )
                SettingsServerAddressRow(
                    title: "External URL",
                    value: configuredValue(displayedRemoteAddress),
                    systemImage: "globe"
                )
            }

            SettingsServerAddressRow(
                title: "Active Connection",
                value: activeConnectionValue,
                systemImage: "arrow.triangle.branch"
            )
        } header: {
            Text("Server")
        }
    }

    @ViewBuilder
    private var localNetworkEditorRows: some View {
        SettingsServerAddressRow(
            title: "Home Network",
            value: homeNetworkValue(draftInternalNetworkSSIDs),
            systemImage: "wifi"
        )

        if isShowingManualNetworkEntry {
            manualHomeNetworkEntryRow
            networkActionRow("Cancel", systemImage: "xmark") {
                cancelManualHomeNetworkEntry()
            }
        } else if draftInternalNetworkSSIDs.isEmpty {
            networkActionRow("Use Current Wi-Fi", systemImage: "location") {
                Task { await addCurrentWiFiSSID() }
            }
            .disabled(nativePermissionService.isRequestingLocationAccess)

            networkActionRow("Add Manually", systemImage: "plus") {
                beginManualHomeNetworkEntry(replacing: false)
            }
        } else {
            networkActionRow("Change", systemImage: "pencil") {
                beginManualHomeNetworkEntry(replacing: true)
            }

            networkActionRow("Remove", systemImage: "trash", role: .destructive) {
                draftInternalNetworkSSIDs.removeAll()
                cancelManualHomeNetworkEntry()
            }

            networkActionRow("Use Current Wi-Fi", systemImage: "location") {
                Task { await addCurrentWiFiSSID() }
            }
            .disabled(nativePermissionService.isRequestingLocationAccess)
        }
    }

    private var homeAssistantSection: some View {
        Section("Home Assistant") {
            SettingsServerAddressRow(
                title: "Installation",
                value: homeAssistantService.serverEnvironment?.installationMethod.title ?? "Not available",
                systemImage: "shippingbox"
            )
            SettingsServerAddressRow(
                title: "Core",
                value: configValue(homeAssistantService.serverEnvironment?.coreVersion),
                systemImage: "cpu"
            )
            SettingsServerAddressRow(
                title: "Supervisor",
                value: configValue(homeAssistantService.serverEnvironment?.supervisorVersion),
                systemImage: "gearshape"
            )
            SettingsServerAddressRow(
                title: "OS",
                value: configValue(homeAssistantService.serverEnvironment?.operatingSystemVersion),
                systemImage: "desktopcomputer"
            )
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

    private var serverName: String {
        homeAssistantService.serverConfiguration?.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue ?? "Home"
    }

    private var accountTitle: String {
        homeAssistantService.currentUserDisplayName ?? "Home Assistant"
    }

    private var headerStatusTitle: String {
        if hasServerMismatch || connectionSettings.authStorageErrorMessage != nil {
            return "Error"
        }

        switch homeAssistantService.authState {
        case .signedOut, .accessTokenExpired:
            return "Disconnected"
        case .signingIn, .refreshing:
            return "Connecting"
        case .refreshFailed:
            return "Error"
        case .signedIn:
            switch homeAssistantService.connectionStatus {
            case .connected:
                return "Connected"
            case .preparing, .connecting, .reconnecting:
                return "Connecting"
            case .failed:
                return "Error"
            case .disconnected:
                return "Disconnected"
            }
        }
    }

    private var headerStatusTint: Color {
        switch headerStatusTitle {
        case "Connected":
            return .green
        case "Connecting":
            return .orange
        case "Error":
            return .red
        default:
            return .secondary
        }
    }

    private var activeConnectionValue: String {
        guard let route = homeAssistantService.activeRouteSummary else {
            return "Not selected"
        }

        switch route.route {
        case .internalURL:
            return "Internal"
        case .externalURL:
            return "External"
        case .current:
            if normalizedURL(route.baseURLString) == normalizedURL(connectionSettings.internalURL) {
                return "Internal"
            }
            if normalizedURL(route.baseURLString) == normalizedURL(displayedRemoteAddress) {
                return "External"
            }
            return "Saved Address"
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

    private var hasUnsavedServerEdits: Bool {
        draftLocalAddress.trimmingCharacters(in: .whitespacesAndNewlines) != connectionSettings.internalURL.trimmingCharacters(in: .whitespacesAndNewlines) ||
            draftRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines) != displayedRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines) ||
            HAConnectionSettings.normalizedSSIDs(draftInternalNetworkSSIDs) != HAConnectionSettings.normalizedSSIDs(connectionSettings.internalNetworkSSIDs) ||
            !draftSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            return "Not available"
        }

        return value
    }

    private func addressEditorRow(
        title: String,
        systemImage: String,
        placeholder: String,
        text: Binding<String>,
        focus: Field
    ) -> some View {
        editableValueRow(title: title, systemImage: systemImage) {
            TextField(placeholder, text: text, axis: .horizontal)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .focused($focusedField, equals: focus)
                .multilineTextAlignment(.trailing)
        }
    }

    private func editableValueRow<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Label {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: AppSpacing.medium)

                content()
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }

    private var manualHomeNetworkEntryRow: some View {
        Label {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                TextField("Wi-Fi Name", text: $draftSSID, axis: .horizontal)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .ssid)
                    .submitLabel(.done)
                    .onSubmit {
                        saveManualHomeNetworkIfPossible()
                    }

                Button(isReplacingHomeNetwork ? "Save" : "Add") {
                    saveManualHomeNetworkIfPossible()
                }
                .disabled(draftSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: "text.cursor")
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }

    private func networkActionRow(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label {
                HStack {
                    Text(title)
                    Spacer()
                }
                .padding(.vertical, AppSpacing.xSmall)
            } icon: {
                Image(systemName: systemImage)
                    .frame(width: 28)
            }
        }
    }

    private func beginServerEditing() {
        draftLocalAddress = connectionSettings.internalURL
        draftRemoteAddress = displayedRemoteAddress
        draftInternalNetworkSSIDs = connectionSettings.internalNetworkSSIDs
        draftSSID = ""
        isShowingManualNetworkEntry = false
        isReplacingHomeNetwork = false
        currentWiFiErrorMessage = nil
        isEditingServer = true
    }

    private func requestCancelServerEditing() {
        if hasUnsavedServerEdits {
            isConfirmingDiscard = true
        } else {
            cancelServerEditing()
        }
    }

    private func cancelServerEditing() {
        focusedField = nil
        draftSSID = ""
        isShowingManualNetworkEntry = false
        isReplacingHomeNetwork = false
        currentWiFiErrorMessage = nil
        isEditingServer = false
    }

    private func saveServerEditing() {
        focusedField = nil
        let oldLocal = connectionSettings.internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldRemote = displayedRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let newLocal = draftLocalAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let newRemote = draftRemoteAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSSIDs = HAConnectionSettings.normalizedSSIDs(draftInternalNetworkSSIDs + [draftSSID])

        connectionSettings.internalURL = newLocal
        connectionSettings.externalURL = newRemote
        connectionSettings.internalNetworkSSIDs = newSSIDs
        if newRemote != oldRemote {
            connectionSettings.baseURL = newRemote.isEmpty ? newLocal : newRemote
        } else if newLocal != oldLocal, oldRemote.isEmpty {
            connectionSettings.baseURL = newLocal
        }
        draftSSID = ""
        isShowingManualNetworkEntry = false
        isReplacingHomeNetwork = false
        isEditingServer = false
    }

    private func addSSID(_ ssid: String) {
        draftInternalNetworkSSIDs = HAConnectionSettings.normalizedSSIDs(draftInternalNetworkSSIDs + [ssid])
    }

    private func saveManualHomeNetwork() {
        if isReplacingHomeNetwork {
            draftInternalNetworkSSIDs = HAConnectionSettings.normalizedSSIDs([draftSSID])
        } else {
            addSSID(draftSSID)
        }
    }

    private func beginManualHomeNetworkEntry(replacing: Bool) {
        draftSSID = replacing ? draftInternalNetworkSSIDs.first ?? "" : ""
        isShowingManualNetworkEntry = true
        isReplacingHomeNetwork = replacing
        focusedField = .ssid
    }

    private func cancelManualHomeNetworkEntry() {
        draftSSID = ""
        isShowingManualNetworkEntry = false
        isReplacingHomeNetwork = false
        focusedField = nil
    }

    private func saveManualHomeNetworkIfPossible() {
        guard !draftSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        saveManualHomeNetwork()
        cancelManualHomeNetworkEntry()
    }

    private func homeNetworkValue(_ ssids: [String]) -> String {
        let normalized = HAConnectionSettings.normalizedSSIDs(ssids)
        return normalized.isEmpty ? "Not Set" : normalized.joined(separator: ", ")
    }

    private func addCurrentWiFiSSID() async {
        await nativePermissionService.requestLocationAccess()
        guard let ssid = await homeAssistantService.refreshCurrentWiFiSSID() else {
            currentWiFiErrorMessage = "Homestead could not read the current Wi-Fi name. Check Location permission, the Wi-Fi Information capability, and that this device is connected to Wi-Fi."
            return
        }

        addSSID(ssid)
    }

    private func normalizedURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
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

private struct SettingsServerAddressRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

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

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
