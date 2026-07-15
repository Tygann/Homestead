import SwiftUI

// MARK: - Server Management

struct HomeAssistantServersView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(\.openAddServer) private var openAddServer
    @Environment(\.switchServer) private var switchServer

    var body: some View {
        List {
            Section {
                ForEach(connectionSettings.profiles) { profile in
                    NavigationLink {
                        HomeAssistantServerDetailView(profileID: profile.id)
                    } label: {
                        ServerProfileRow(
                            profile: profile,
                            isActive: profile.id == connectionSettings.activeProfileID
                        )
                    }
                    .swipeActions(edge: .leading) {
                        if profile.id != connectionSettings.activeProfileID {
                            Button("Use", systemImage: "checkmark") {
                                switchServer(profile.id)
                            }
                            .tint(.accentColor)
                        }
                    }
                }
            } footer: {
                Text("Homestead keeps one server active at a time. Saved servers stay signed in until you remove them.")
            }

            Section {
                Button(action: openAddServer) {
                    Label("Add Server", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Servers")
    }
}

private struct ServerProfileRow: View {
    let profile: HAConnectionProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "server.rack")
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.resolvedDisplayName)
                    .foregroundStyle(.primary)
                Text(profileHost)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Active Server")
            }
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
    @Environment(\.switchServer) private var switchServer
    @Environment(\.dismiss) private var dismiss

    let profileID: UUID

    @State private var draftName = ""
    @State private var isConfirmingRemoval = false
    @State private var isRemoving = false
    @State private var isReauthenticating = false
    @State private var removalFailureMessage: String?

    var body: some View {
        Form {
            if let profile {
                Section("Server") {
                    TextField("Name", text: $draftName)
                        .onSubmit(saveName)

                    LabeledContent("Address", value: profile.baseURL)
                    if !profile.internalURL.isEmpty {
                        LabeledContent("Internal URL", value: profile.internalURL)
                    }
                    if !profile.externalURL.isEmpty {
                        LabeledContent("External URL", value: profile.externalURL)
                    }
                }

                if !isActive {
                    Section {
                        Button("Use This Server") { switchServer(profileID) }
                    }
                }

                Section {
                    Button("Sign In Again") { reauthenticate() }
                        .disabled(isRemoving || isReauthenticating)
                }

                Section {
                    Button("Remove Server", role: .destructive) {
                        isConfirmingRemoval = true
                    }
                    .disabled(isRemoving)
                } footer: {
                    Text("Removing signs this device out of this server and deletes its local Homestead data.")
                }
            }
        }
        .navigationTitle(profile?.resolvedDisplayName ?? "Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isRemoving || isReauthenticating { ProgressView() }
            }
        }
        .onAppear { draftName = profile?.displayName ?? "" }
        .onDisappear { saveName() }
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
    }

    private var profile: HAConnectionProfile? {
        connectionSettings.profileStore.profile(id: profileID)
    }

    private var isActive: Bool { connectionSettings.activeProfileID == profileID }

    private var removalFailureBinding: Binding<Bool> {
        Binding(
            get: { removalFailureMessage != nil },
            set: { if !$0 { removalFailureMessage = nil } }
        )
    }

    private func saveName() {
        connectionSettings.profileStore.renameProfile(id: profileID, name: draftName)
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
            _ = await homeAssistantService.reauthenticateServer(profileID: profileID, settings: connectionSettings)
            isReauthenticating = false
        }
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
