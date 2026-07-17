import SwiftUI

// MARK: - Server Management

struct HomeAssistantServersView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(\.dismiss) private var dismiss
    @State private var switchingProfileID: UUID?
    @State private var switchErrorMessage: String?
    @State private var removalCandidateID: UUID?
    @State private var removingProfileID: UUID?
    @State private var removalFailureProfileID: UUID?
    @State private var removalFailureMessage: String?
    @State private var presentedSheet: ServerSheetDestination?
    @State private var shouldDismissAfterAddingServer = false

    var body: some View {
        List {
            Section {
                ForEach(connectionSettings.profiles) { profile in
                    Button {
                        if profile.id != connectionSettings.activeProfileID {
                            switchToServer(profile.id)
                        }
                    } label: {
                        ServerProfileRow(
                            profile: profile,
                            isActive: profile.id == connectionSettings.activeProfileID,
                            isSwitching: switchingProfileID == profile.id,
                            isRemoving: removingProfileID == profile.id
                        )
                    }
                    .contentShape(Rectangle())
                    .disabled(isOperationInProgress)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isOperationInProgress {
                            Button(role: .destructive) {
                                beginRemoving(profile)
                            } label: {
                                Label("Remove", systemImage: "trash")
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
        .sheet(item: $presentedSheet, onDismiss: handleSheetDismissal) { destination in
            switch destination {
            case .addServer:
                NavigationStack {
                    AddHomeAssistantServerView {
                        shouldDismissAfterAddingServer = true
                    }
                }
            }
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
            Text(removalPresentation.message)
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
        removalPresentation.title
    }

    private var removalPresentation: ServerRemovalPresentation {
        let profile = removalCandidateID.flatMap { connectionSettings.profileStore.profile(id: $0) }
        let configuredServerCount = connectionSettings.profiles.filter(\.hasServerURL).count
        return ServerRemovalPresentation(
            profile: profile,
            isRemovingFinalServer: configuredServerCount == 1
        )
    }

    private func beginRemoving(_ profile: HAConnectionProfile) {
        removalCandidateID = profile.id
    }

    private func removeServer(_ profileID: UUID, forceLocal: Bool) {
        guard !isOperationInProgress else { return }
        let wasActive = connectionSettings.activeProfileID == profileID
        removingProfileID = profileID
        switchErrorMessage = nil
        resetRemovalFailure()
        Task {
            let removed = await homeAssistantService.removeServer(
                profileID: profileID,
                removeFromDeviceAnyway: forceLocal,
                settings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                appearanceSettings: appearanceSettings
            )
            removingProfileID = nil
            if !removed {
                removalFailureProfileID = profileID
                removalFailureMessage = homeAssistantService.serverOperationErrorMessage
                    ?? "Home Assistant could not be reached."
            } else if wasActive {
                dismiss()
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
            if switched {
                dismiss()
            } else if !switched {
                switchErrorMessage = homeAssistantService.serverOperationErrorMessage ?? "Homestead couldn’t switch servers."
            }
        }
    }

    private func handleSheetDismissal() {
        guard shouldDismissAfterAddingServer else { return }
        shouldDismissAfterAddingServer = false
        dismiss()
    }
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

// MARK: - Add Server

struct AddHomeAssistantServerView: View {
    @Environment(HomeAssistantDiscoveryService.self) private var discoveryService
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(\.dismiss) private var dismiss

    private let onServerAdded: () -> Void

    @State private var draftAddress = ""
    @State private var selectedInstance: HomeAssistantDiscoveredInstance?
    @State private var isAdding = false

    init(onServerAdded: @escaping () -> Void = {}) {
        self.onServerAdded = onServerAdded
    }

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
            onServerAdded()
            dismiss()
        }
    }
}

// MARK: - Removal Presentation

struct ServerRemovalPresentation: Equatable {
    let title: String
    let message: String

    init(profile: HAConnectionProfile?, isRemovingFinalServer: Bool) {
        guard let profile else {
            title = "Remove Server?"
            message = "Homestead will ask Home Assistant to revoke this sign-in before removing its local data."
            return
        }

        title = "Remove \(profile.resolvedDisplayName)?"
        var resolvedMessage = "Homestead will ask Home Assistant to revoke the sign-in for \(profile.serverHostDisplayText) before removing its local data."
        if isRemovingFinalServer {
            resolvedMessage += " You’ll return to setup."
        }
        message = resolvedMessage
    }
}

private extension HAConnectionProfile {
    var serverHostDisplayText: String {
        URL(string: baseURL)?.host(percentEncoded: false) ?? baseURL
    }
}
