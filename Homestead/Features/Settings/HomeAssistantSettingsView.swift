import SwiftUI

// MARK: - Home Assistant Settings View
struct HomeAssistantSettingsView: View {
    // MARK: - Properties

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isConfirmingSignOut = false

    // MARK: - Body

    var body: some View {
        Form {
            accountSection

            serverSelectionSection

            serverSection

            homeAssistantSection

            advancedSection

            if shouldShowSupport {
                Section {
                    NavigationLink {
                        HomeAssistantDiagnosticsView()
                    } label: {
                        SettingsNavigationRowLabel("Diagnostics", systemImage: "stethoscope")
                    }
                } footer: {
                    Text("Support details are available if something is not working as expected.")
                }
            }

            bottomAuthActionSection
        }
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .padding(.top, -30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Account")
                    .font(.headline)
            }
        }
        .task(id: serverRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
            await homeAssistantService.refreshServerConfiguration()
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

    // MARK: - Sections

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

    private var serverSelectionSection: some View {
        Section {
            NavigationLink {
                HomeAssistantServersView()
            } label: {
                SettingsServerAddressRow(
                    title: "Server",
                    value: serverName,
                    systemImage: "server.rack"
                )
            }
        }
    }

    private var serverSection: some View {
        Section {
            NavigationLink {
                HomeAssistantNameSettingsView(currentName: serverName)
            } label: {
                SettingsServerAddressRow(
                    title: "Name",
                    value: serverName,
                    systemImage: "tag"
                )
            }

            NavigationLink {
                InternalURLSettingsView()
            } label: {
                SettingsServerAddressRow(
                    title: "Internal URL",
                    value: configuredValue(connectionSettings.internalURL),
                    systemImage: "wifi.router"
                )
            }

            NavigationLink {
                ExternalURLSettingsView()
            } label: {
                SettingsServerAddressRow(
                    title: "External URL",
                    value: configuredValue(connectionSettings.displayedExternalURL),
                    systemImage: "globe"
                )
            }

            SettingsServerAddressRow(
                title: "Active Connection",
                value: activeConnectionValue,
                systemImage: "arrow.triangle.branch"
            )
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

    private var bottomAuthActionSection: some View {
        Section {
            if canSignOut {
                Button(role: .destructive) {
                    isConfirmingSignOut = true
                } label: {
                    Text("Sign Out")
                }
                .disabled(!canSignOut)
                .frame(maxWidth: .infinity)
            } else {
                Button {
                    Task {
                        await homeAssistantService.signInWithHomeAssistant(settings: connectionSettings)
                    }
                } label: {
                    Text(signInButtonTitle)
                }
                .disabled(!shouldShowSignIn ||
                          !connectionSettings.hasServerURL ||
                          homeAssistantService.authState == .signingIn)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private var serverName: String {
        homeAssistantService.serverConfiguration?.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue
            ?? connectionSettings.activeProfile.resolvedDisplayName
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
            if normalizedURL(route.baseURLString) == normalizedURL(connectionSettings.displayedExternalURL) {
                return "External"
            }
            return "Saved Address"
        }
    }

    private var canSignOut: Bool {
        switch homeAssistantService.authState {
        case .signedIn, .refreshing:
            return true
        case .signedOut, .signingIn, .accessTokenExpired, .refreshFailed:
            return false
        }
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

    private func normalizedURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }
}

// MARK: - Home Assistant Name Settings View

private struct HomeAssistantNameSettingsView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var draftName: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let currentName: String

    init(currentName: String) {
        self.currentName = currentName
        _draftName = State(initialValue: currentName)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draftName)
                    .textContentType(.organizationName)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
            } footer: {
                Text("This changes the instance name in Home Assistant. Administrator access is required.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Name")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .task {
            isNameFocused = true
        }
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName != currentName && !isSaving
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        Task {
            if await homeAssistantService.updateServerName(trimmedName) {
                dismiss()
            } else {
                errorMessage = homeAssistantService.serverOperationErrorMessage
                    ?? "Home Assistant couldn’t update the server name."
                isSaving = false
            }
        }
    }
}

// MARK: - Internal URL Settings View

private struct InternalURLSettingsView: View {
    // MARK: - Properties

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativePermissionService.self) private var nativePermissionService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var draftInternalURL = ""
    @State private var draftSSIDs: [String] = []
    @State private var draftSSID = ""
    @State private var currentWiFiErrorMessage: String?

    // MARK: - Body

    var body: some View {
        Form {
            Section("Internal URL") {
                TextField("homeassistant.local:8123", text: $draftInternalURL, axis: .horizontal)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .internalURL)
            }

            Section {
                ForEach(draftSSIDs, id: \.self) { ssid in
                    Text(ssid)
                }
                .onDelete(perform: removeSSIDs)

                HStack {
                    TextField("Network Name", text: $draftSSID, axis: .horizontal)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .ssid)
                        .submitLabel(.done)
                        .onSubmit(addManualSSID)

                    Button("Add") {
                        addManualSSID()
                    }
                    .buttonStyle(.borderless)
                    .disabled(draftSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Button {
                    Task { await addCurrentWiFiSSID() }
                } label: {
                    Label("Add Current Network", systemImage: "location")
                }
                .disabled(nativePermissionService.isRequestingLocationAccess)
            } header: {
                Text("Home Networks")
            } footer: {
                Text("Homestead uses the Internal URL when connected to one of these trusted home networks.")
            }
        }
        .navigationTitle("Internal URL")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .onAppear {
            draftInternalURL = connectionSettings.internalURL
            draftSSIDs = HAConnectionSettings.normalizedSSIDs(connectionSettings.internalNetworkSSIDs)
        }
        .alert("Network Name Unavailable", isPresented: Binding(
            get: { currentWiFiErrorMessage != nil },
            set: { if !$0 { currentWiFiErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(currentWiFiErrorMessage ?? "Homestead could not read the current network name.")
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !draftInternalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !connectionSettings.displayedExternalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func addManualSSID() {
        let normalized = HAConnectionSettings.normalizedSSIDs(draftSSIDs + [draftSSID])
        guard normalized != draftSSIDs else {
            draftSSID = ""
            return
        }

        draftSSIDs = normalized
        draftSSID = ""
        focusedField = nil
    }

    private func addCurrentWiFiSSID() async {
        await nativePermissionService.requestLocationAccess()
        guard let ssid = await homeAssistantService.refreshCurrentWiFiSSID() else {
            currentWiFiErrorMessage = "Homestead could not read the current network name. Check Location permission and that this device is connected to a supported network."
            return
        }

        draftSSIDs = HAConnectionSettings.normalizedSSIDs(draftSSIDs + [ssid])
    }

    private func removeSSIDs(at offsets: IndexSet) {
        draftSSIDs.remove(atOffsets: offsets)
        draftSSIDs = HAConnectionSettings.normalizedSSIDs(draftSSIDs)
    }

    private func save() {
        focusedField = nil
        connectionSettings.saveInternalURLSettings(
            internalURL: draftInternalURL,
            internalNetworkSSIDs: HAConnectionSettings.normalizedSSIDs(draftSSIDs + [draftSSID])
        )
        dismiss()
    }

    private enum Field {
        case internalURL
        case ssid
    }
}

// MARK: - External URL Settings View

private struct ExternalURLSettingsView: View {
    // MARK: - Properties

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var draftExternalURL = ""

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                TextField("https://example.ui.nabu.casa", text: $draftExternalURL, axis: .horizontal)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .focused($isFocused)
            } header: {
                Text("External URL")
            } footer: {
                Text("Homestead uses the External URL when you're away from home or not connected to a trusted home network.")
            }
        }
        .navigationTitle("External URL")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .onAppear {
            draftExternalURL = connectionSettings.displayedExternalURL
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !draftExternalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !connectionSettings.internalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func save() {
        isFocused = false
        connectionSettings.saveExternalURL(draftExternalURL)
        dismiss()
    }
}

// MARK: - Settings Server Address Row

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
