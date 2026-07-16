import SwiftUI

// MARK: - Server Management

struct HomeAssistantServersView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(\.colorScheme) private var colorScheme
    @State private var switchingProfileID: UUID?
    @State private var switchErrorMessage: String?
    @State private var renamingProfileID: UUID?
    @State private var profileNameDraft = ""
    @State private var removalCandidateID: UUID?
    @State private var removingProfileID: UUID?
    @State private var removalFailureProfileID: UUID?
    @State private var removalFailureMessage: String?
    @State private var presentedSheet: ServerSheetDestination?
    @State private var selectedRoute: ServerSettingsRoute?

    var body: some View {
        List {
            Section {
                ForEach(connectionSettings.profiles) { profile in
                    NavigationLink {
                        HomeAssistantServerDetailView(profileID: profile.id)
                    } label: {
                        ServerProfileRow(
                            profile: profile,
                            isActive: profile.id == connectionSettings.activeProfileID,
                            isSwitching: switchingProfileID == profile.id,
                            isRemoving: removingProfileID == profile.id
                        )
                    }
                    .disabled(isOperationInProgress)
                    .contextMenu {
                        serverActions(for: profile)
                            .disabled(isOperationInProgress)
                            .preferredColorScheme(colorScheme)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if profile.id != connectionSettings.activeProfileID,
                           !isOperationInProgress {
                            Button {
                                switchToServer(profile.id)
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            .tint(.accentColor)
                            .accessibilityLabel("Use This Server")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isOperationInProgress {
                            Button(role: .destructive) {
                                beginRemoving(profile)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Remove Server")
                        }
                    }
                }
            }

            if let switchErrorMessage {
                Section {
                    Label(switchErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Servers")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentedSheet = .addServer
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .disabled(isOperationInProgress)
            }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .addServer:
                NavigationStack {
                    AddHomeAssistantServerView()
                }
            }
        }
        .navigationDestination(item: $selectedRoute) { route in
            switch route {
            case .reorder:
                ServerReorderSettingsView()
            }
        }
        .alert("Rename Server", isPresented: isRenamingServer) {
            TextField("Name", text: $profileNameDraft)
            Button("Cancel", role: .cancel) {
                resetRenamingState()
            }
            Button("Save") {
                saveProfileName()
            }
        } message: {
            Text("Choose the name Homestead uses for this server.")
        }
        .confirmationDialog(
            removalDialogTitle,
            isPresented: isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Server", role: .destructive) {
                if let profileID = removalCandidateID {
                    removeServer(profileID, forceLocal: false)
                }
                removalCandidateID = nil
            }
            Button("Cancel", role: .cancel) {
                removalCandidateID = nil
            }
        } message: {
            Text("Homestead will ask Home Assistant to revoke this sign-in before removing its local data.")
        }
        .alert("Couldn’t Revoke Sign-In", isPresented: removalFailureBinding) {
            Button("Retry") {
                retryRemoval(forceLocal: false)
            }
            Button("Remove From This Device Anyway", role: .destructive) {
                retryRemoval(forceLocal: true)
            }
            Button("Cancel", role: .cancel) {
                resetRemovalFailure()
            }
        } message: {
            Text(removalFailureMessage ?? "Home Assistant could not be reached.")
        }
    }

    private var isOperationInProgress: Bool {
        switchingProfileID != nil || removingProfileID != nil
    }

    private var isRenamingServer: Binding<Bool> {
        Binding(
            get: { renamingProfileID != nil },
            set: { if !$0 { resetRenamingState() } }
        )
    }

    private var isConfirmingRemoval: Binding<Bool> {
        Binding(
            get: { removalCandidateID != nil },
            set: { if !$0 { removalCandidateID = nil } }
        )
    }

    private var removalFailureBinding: Binding<Bool> {
        Binding(
            get: { removalFailureMessage != nil },
            set: { if !$0 { resetRemovalFailure() } }
        )
    }

    private var removalDialogTitle: String {
        guard let removalCandidateID,
              let profile = connectionSettings.profileStore.profile(id: removalCandidateID) else {
            return "Remove Server?"
        }
        return "Remove \(profile.resolvedDisplayName)?"
    }

    @ViewBuilder
    private func serverActions(for profile: HAConnectionProfile) -> some View {
        if profile.id != connectionSettings.activeProfileID {
            Section {
                Button {
                    switchToServer(profile.id)
                } label: {
                    Label("Use This Server", systemImage: "checkmark.circle")
                }
            }
        }

        Section {
            Button {
                beginRenaming(profile)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
        }

        if connectionSettings.profiles.count > 1 {
            Section {
                Button {
                    selectedRoute = .reorder
                } label: {
                    Label("Reorder Servers", systemImage: "line.3.horizontal")
                }
            }
        }

        Section {
            Button(role: .destructive) {
                beginRemoving(profile)
            } label: {
                Label("Remove Server", systemImage: "trash")
            }
        }
    }

    private func beginRenaming(_ profile: HAConnectionProfile) {
        profileNameDraft = profile.displayName
        renamingProfileID = profile.id
    }

    private func saveProfileName() {
        if let renamingProfileID {
            connectionSettings.profileStore.renameProfile(id: renamingProfileID, name: profileNameDraft)
        }
        resetRenamingState()
    }

    private func resetRenamingState() {
        renamingProfileID = nil
        profileNameDraft = ""
    }

    private func beginRemoving(_ profile: HAConnectionProfile) {
        removalCandidateID = profile.id
    }

    private func removeServer(_ profileID: UUID, forceLocal: Bool) {
        guard !isOperationInProgress else { return }
        removingProfileID = profileID
        switchErrorMessage = nil
        resetRemovalFailure()
        Task {
            let removed = await homeAssistantService.removeServer(
                profileID: profileID,
                removeFromDeviceAnyway: forceLocal,
                settings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration
            )
            removingProfileID = nil
            if !removed {
                removalFailureProfileID = profileID
                removalFailureMessage = homeAssistantService.serverOperationErrorMessage
                    ?? "Home Assistant could not be reached."
            }
        }
    }

    private func retryRemoval(forceLocal: Bool) {
        guard let profileID = removalFailureProfileID else {
            resetRemovalFailure()
            return
        }
        resetRemovalFailure()
        removeServer(profileID, forceLocal: forceLocal)
    }

    private func resetRemovalFailure() {
        removalFailureProfileID = nil
        removalFailureMessage = nil
    }

    private func switchToServer(_ profileID: UUID) {
        guard !isOperationInProgress else { return }
        switchingProfileID = profileID
        switchErrorMessage = nil
        Task {
            let authenticationState = await homeAssistantService.authenticationState(for: profileID)
            guard authenticationState.isSignedIn else {
                switchingProfileID = nil
                switchErrorMessage = "Sign in to this server again before switching."
                return
            }
            let switched = await homeAssistantService.switchActiveProfile(
                to: profileID,
                settings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration
            )
            switchingProfileID = nil
            if !switched {
                switchErrorMessage = homeAssistantService.serverOperationErrorMessage ?? "Homestead couldn’t switch servers."
            }
        }
    }
}

private struct ServerReorderSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(connectionSettings.profiles) { profile in
                ServerProfileRow(
                    profile: profile,
                    isActive: profile.id == connectionSettings.activeProfileID,
                    isSwitching: false,
                    isRemoving: false
                )
            }
            .onMove { source, destination in
                connectionSettings.profileStore.moveProfiles(from: source, to: destination)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Reorder Servers")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

private enum ServerSettingsRoute: String, Identifiable {
    case reorder

    var id: String { rawValue }
}

private enum ServerSheetDestination: String, Identifiable {
    case addServer

    var id: String { rawValue }
}

private struct ServerProfileRow: View {
    let profile: HAConnectionProfile
    let isActive: Bool
    let isSwitching: Bool
    let isRemoving: Bool

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            if isSwitching || isRemoving {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22)
                    .accessibilityLabel(isRemoving ? "Removing Server" : "Switching Servers")
            } else {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isActive ? Color.accentColor : Color.clear)
                    .frame(width: 22)
                    .accessibilityHidden(!isActive)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.resolvedDisplayName)
                    .foregroundStyle(.primary)
                Text(profileHost)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
    }

    private var profileHost: String {
        URL(string: profile.baseURL)?.host(percentEncoded: false) ?? profile.baseURL
    }
}

// MARK: - Server Detail

private struct HomeAssistantServerDetailView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    @State private var draftName = ""
    @State private var isRenaming = false
    @State private var isConfirmingRemoval = false
    @State private var isRemoving = false
    @State private var isReauthenticating = false
    @State private var isSwitching = false
    @State private var switchErrorMessage: String?
    @State private var removalFailureMessage: String?
    @State private var profileAuthState: HAAuthState?

    var body: some View {
        Form {
            if let profile {
                overviewSection(profile)
                if showsActionsSection {
                    actionsSection
                }

                if let switchErrorMessage {
                    Section {
                        Label(switchErrorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                removeSection
            }
        }
        .navigationTitle(profile?.resolvedDisplayName ?? "Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isRemoving || isReauthenticating || isSwitching { ProgressView() }
            }
        }
        .alert("Rename Server", isPresented: $isRenaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveName() }
        } message: {
            Text("Choose the name Homestead uses for this server.")
        }
        .confirmationDialog(
            "Remove \(profile?.resolvedDisplayName ?? "Server")?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Server", role: .destructive) {
                removeServer(forceLocal: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Homestead will ask Home Assistant to revoke this sign-in before removing its local data.")
        }
        .alert("Couldn’t Revoke Sign-In", isPresented: removalFailureBinding) {
            Button("Retry") { removeServer(forceLocal: false) }
            Button("Remove From This Device Anyway", role: .destructive) {
                removeServer(forceLocal: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(removalFailureMessage ?? "Home Assistant could not be reached.")
        }
        .task(id: profileID) {
            await refreshProfileAuthState()
        }
    }

    private var profile: HAConnectionProfile? {
        connectionSettings.profileStore.profile(id: profileID)
    }

    private var isActive: Bool { connectionSettings.activeProfileID == profileID }

    private var authenticationState: HAAuthState? {
        isActive ? homeAssistantService.authState : profileAuthState
    }

    private var isAuthenticationReady: Bool {
        authenticationState?.isSignedIn == true
    }

    private var requiresSignIn: Bool {
        guard let authenticationState else { return false }
        return !authenticationState.isSignedIn
    }

    private var showsActionsSection: Bool {
        if isActive { return requiresSignIn }
        return authenticationState != nil
    }

    private var removalFailureBinding: Binding<Bool> {
        Binding(
            get: { removalFailureMessage != nil },
            set: { if !$0 { removalFailureMessage = nil } }
        )
    }

    private func overviewSection(_ profile: HAConnectionProfile) -> some View {
        Section {
            Button {
                draftName = profile.displayName
                isRenaming = true
            } label: {
                LabeledContent("Name") {
                    Text(profile.resolvedDisplayName)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: AppSpacing.medium) {
                Text("Address")
                    .layoutPriority(1)

                Text(profileHost(profile))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)

            if showsConnectionDetails(profile) {
                NavigationLink("Connection Details") {
                    HomeAssistantServerConnectionDetailsView(profile: profile)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            if !isActive, isAuthenticationReady {
                Button {
                    switchToServer()
                } label: {
                    Text(isSwitching ? "Making Active…" : "Make Active")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .accessibilityLabel("Make \(profile?.resolvedDisplayName ?? "this server") the active server")
                .disabled(isSwitching)
            }

            if requiresSignIn {
                Button {
                    reauthenticate()
                } label: {
                    Text("Sign In Again")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(isRemoving || isReauthenticating || isSwitching)
            }
        }
    }

    private var removeSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingRemoval = true
            } label: {
                Text("Remove Server")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(isRemoving)
        } footer: {
            Text("This removes the server and its local Homestead data from this device.")
        }
    }

    private func saveName() {
        connectionSettings.profileStore.renameProfile(id: profileID, name: draftName)
    }

    private func profileHost(_ profile: HAConnectionProfile) -> String {
        URL(string: profile.baseURL)?.host(percentEncoded: false) ?? profile.baseURL
    }

    private func showsConnectionDetails(_ profile: HAConnectionProfile) -> Bool {
        let baseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let internalURL = profile.internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let externalURL = profile.externalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!internalURL.isEmpty && internalURL != baseURL) ||
            (!externalURL.isEmpty && externalURL != baseURL)
    }

    private func removeServer(forceLocal: Bool) {
        isRemoving = true
        Task {
            let removed = await homeAssistantService.removeServer(
                profileID: profileID,
                removeFromDeviceAnyway: forceLocal,
                settings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration
            )
            isRemoving = false
            if removed {
                dismiss()
            } else {
                removalFailureMessage = homeAssistantService.serverOperationErrorMessage ?? "Home Assistant could not be reached."
            }
        }
    }

    private func reauthenticate() {
        isReauthenticating = true
        Task {
            let succeeded = await homeAssistantService.reauthenticateServer(
                profileID: profileID,
                settings: connectionSettings
            )
            if succeeded {
                await refreshProfileAuthState()
            }
            isReauthenticating = false
        }
    }

    private func refreshProfileAuthState() async {
        profileAuthState = await homeAssistantService.authenticationState(for: profileID)
    }

    private func switchToServer() {
        isSwitching = true
        switchErrorMessage = nil
        Task {
            let switched = await homeAssistantService.switchActiveProfile(
                to: profileID,
                settings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration
            )
            isSwitching = false
            if switched {
                dismiss()
            } else {
                switchErrorMessage = homeAssistantService.serverOperationErrorMessage ?? "Homestead couldn’t switch servers."
            }
        }
    }
}

// MARK: - Connection Details

private struct HomeAssistantServerConnectionDetailsView: View {
    let profile: HAConnectionProfile

    var body: some View {
        Form {
            Section("Sign-In Address") {
                addressText(profile.baseURL)
            }

            if !profile.internalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Internal URL") {
                    addressText(profile.internalURL)
                }
            }

            if !profile.externalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("External URL") {
                    addressText(profile.externalURL)
                }
            }
        }
        .navigationTitle("Connection Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addressText(_ address: String) -> some View {
        Text(address)
            .font(.footnote.monospaced())
            .textSelection(.enabled)
    }
}

// MARK: - Add Server

struct AddHomeAssistantServerView: View {
    @Environment(HomeAssistantDiscoveryService.self) private var discoveryService
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(\.dismiss) private var dismiss

    @State private var draftName = ""
    @State private var draftAddress = ""
    @State private var selectedInstance: HomeAssistantDiscoveredInstance?
    @State private var isAdding = false

    var body: some View {
        Form {
            Section("Nearby") {
                Button {
                    discoveryService.start()
                } label: {
                    Label("Find Home Assistant", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(isAdding)

                if discoveryService.state == .browsing {
                    HStack {
                        ProgressView()
                        Text("Looking for servers…")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(discoveryService.instances) { instance in
                    Button {
                        selectedInstance = instance
                        draftName = instance.name
                        draftAddress = instance.signInURL
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(instance.name)
                                Text(instance.signInURL)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedInstance?.id == instance.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Server") {
                TextField("Name (Optional)", text: $draftName)
                    .textContentType(.organizationName)
                TextField("Home Assistant Address", text: $draftAddress)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if let message = homeAssistantService.serverOperationErrorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isAdding)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") { addServer() }
                    .disabled(draftAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
            }
        }
        .overlay {
            if isAdding {
                ProgressView("Signing In…")
                    .padding(AppSpacing.large)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .onDisappear { discoveryService.stop() }
    }

    private func addServer() {
        isAdding = true
        discoveryService.stop()
        Task {
            guard let profileID = await homeAssistantService.addServer(
                baseURLString: draftAddress,
                displayName: draftName,
                settings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration
            ) else {
                isAdding = false
                return
            }

            if let selectedInstance {
                connectionSettings.profileStore.updateProfile(id: profileID) { profile in
                    profile.discoveredName = selectedInstance.name
                    profile.internalURL = selectedInstance.internalURL ?? ""
                    profile.externalURL = selectedInstance.externalURL ?? ""
                }
            }
            dismiss()
        }
    }
}
