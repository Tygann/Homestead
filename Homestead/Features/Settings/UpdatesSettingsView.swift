import SwiftUI

struct UpdatesSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var searchText = ""
    @State private var updateToInstall: HAUpdateEntity?
    @State private var isConfirmingUpdateAll = false

    var body: some View {
        let updates = stateStore.updateEntities
        let presentation = HAUpdatePresentation.makeActionable(
            updates: updates,
            searchText: searchText
        )
        let availableUpdates = updates.filter { $0.status == .available }.sortedByUpdatePriority

        List {
            if !availableUpdates.isEmpty {
                updateAllSection(count: presentation.summary.availableCount)
            }

            ForEach(presentation.sections) { section in
                Section(section.title) {
                    ForEach(section.updates) { update in
                        UpdateRowLink(update: update) {
                            updateToInstall = update
                        }
                    }
                }
            }
        }
        .overlay {
            if updates.isEmpty {
                ContentUnavailableView("No Updates", systemImage: EntityDomain.update.systemImage)
            } else if presentation.sections.isEmpty {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("All Updates Installed", systemImage: "checkmark.circle")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("Updates")
        .toolbarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Install update?",
            isPresented: Binding(
                get: { updateToInstall != nil },
                set: { isPresented in
                    if !isPresented {
                        updateToInstall = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: updateToInstall
        ) { update in
            Button("Install with Backup") {
                Task { await homeAssistantService.installUpdate(entityID: update.entityID, backup: true) }
            }

            Button("Install Without Backup") {
                Task { await homeAssistantService.installUpdate(entityID: update.entityID, backup: false) }
            }

            Button("Cancel", role: .cancel) {}
        } message: { update in
            Text(installConfirmationMessage(for: update))
        }
        .confirmationDialog(
            "Update all?",
            isPresented: $isConfirmingUpdateAll,
            titleVisibility: .visible
        ) {
            Button("Install All with Backup") {
                Task { await homeAssistantService.installAvailableUpdates(availableUpdates, backup: true) }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(updateAllConfirmationMessage(count: availableUpdates.count))
        }
    }

    private func updateAllSection(count: Int) -> some View {
        Section {
            Button {
                isConfirmingUpdateAll = true
            } label: {
                HStack {
                    Text("Update All")
                    Spacer()
                    Text(count, format: .number)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func installConfirmationMessage(for update: HAUpdateEntity) -> String {
        let versionText = update.latestVersion.map { " to \($0)" } ?? ""
        return "Install \(update.title)\(versionText). Some updates may restart Home Assistant, an add-on, or a device. Choose backup when the integration supports it or when you are unsure."
    }

    private func updateAllConfirmationMessage(count: Int) -> String {
        "Install \(count) available \(count == 1 ? "update" : "updates") with backup enabled. Some updates may restart Home Assistant, add-ons, or devices."
    }
}

private struct UpdateRowLink: View {
    let update: HAUpdateEntity
    let install: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            NavigationLink {
                UpdateDetailSettingsView(entityID: update.entityID)
            } label: {
                UpdateRowContent(update: update)
            }
            .buttonStyle(.plain)

            UpdateRowAction(status: update.status, progressText: update.progressText, install: install)
        }
    }
}

private struct UpdateRowContent: View {
    let update: HAUpdateEntity

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            UpdateIconView(update: update, size: 52)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(update.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                versionText
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    @ViewBuilder
    private var versionText: some View {
        if let installed = update.installedVersion,
           let latest = update.latestVersion,
           installed != latest {
            HStack(spacing: 4) {
                Text(installed)
                Image(systemName: "arrowshape.right.fill")
                    .imageScale(.small)
                Text(latest)
            }
        } else {
            Text(update.installedVersion ?? update.latestVersion ?? "Version unknown")
        }
    }
}

private struct UpdateIconView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

    let update: HAUpdateEntity
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: update.iconSystemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(update.status.tint)
                    .frame(width: size, height: size)
                    .background(update.status.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: taskID) {
            await loadImage()
        }
        .accessibilityHidden(true)
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            update.entityPicturePath ?? "no-picture"
        ].joined(separator: "|")
    }

    private func loadImage() async {
        guard let entityPicturePath = update.entityPicturePath,
              let request = await homeAssistantService.homeAssistantImageRequest(
                settings: connectionSettings,
                pathOrURL: entityPicturePath
              ) else {
            image = nil
            return
        }

        guard let uiImage = await HomeAssistantImageCache.shared.image(for: request) else {
            image = nil
            return
        }

        image = Image(uiImage: uiImage)
    }
}

private struct UpdateRowAction: View {
    let status: HAUpdateStatus
    let progressText: String
    let install: () -> Void

    var body: some View {
        switch status {
        case .available:
            Button("Update", action: install)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        case .inProgress:
            Text(progressText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.tint)
                .lineLimit(1)
        default:
            Text(status.shortTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.tint)
                .lineLimit(1)
        }
    }
}

private struct UpdateDetailSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isConfirmingInstall = false

    let entityID: String

    var body: some View {
        Group {
            if let update {
                Form {
                    statusSection(update)
                    releaseSection(update)
                    contextSection(update)
                    actionsSection(update)
                }
                .confirmationDialog(
                    "Install update?",
                    isPresented: $isConfirmingInstall,
                    titleVisibility: .visible,
                    presenting: update
                ) { update in
                    Button("Install with Backup") {
                        Task { await homeAssistantService.installUpdate(entityID: update.entityID, backup: true) }
                    }

                    Button("Install Without Backup") {
                        Task { await homeAssistantService.installUpdate(entityID: update.entityID, backup: false) }
                    }

                    Button("Cancel", role: .cancel) {}
                } message: { update in
                    Text(installConfirmationMessage(for: update))
                }
            } else {
                ContentUnavailableView("Update Missing", systemImage: EntityDomain.update.systemImage)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(update?.title ?? "Update")
        .toolbarTitleDisplayMode(.inline)
    }

    private var update: HAUpdateEntity? {
        stateStore.updateEntity(for: entityID)
    }

    private func statusSection(_ update: HAUpdateEntity) -> some View {
        Section("Status") {
            Label {
                Text(update.status.title)
            } icon: {
                Image(systemName: update.status.systemImage)
                    .foregroundStyle(update.status.tint)
            }

            LabeledContent("Installed", value: update.installedVersion ?? "Unknown")
            LabeledContent("Latest", value: update.latestVersion ?? "Unknown")

            if let skippedVersion = update.skippedVersion {
                LabeledContent("Skipped", value: skippedVersion)
            }

            if update.isInProgress {
                LabeledContent("Progress", value: update.progressText)
            }

            LabeledContent("Entity", value: update.entityID)

            if let lastUpdated = update.lastUpdated {
                LabeledContent("Updated") {
                    Text(lastUpdated.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func releaseSection(_ update: HAUpdateEntity) -> some View {
        if update.releaseSummary != nil || update.releaseNotesURL != nil {
            Section("Release") {
                if let releaseSummary = update.releaseSummary {
                    Text(releaseSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let releaseNotesURL = update.releaseNotesURL {
                    Link(destination: releaseNotesURL) {
                        Label("Release Notes", systemImage: "safari")
                    }
                }
            }
        }
    }

    private func contextSection(_ update: HAUpdateEntity) -> some View {
        Section("Context") {
            LabeledContent("Name", value: update.name)

            if let areaName = update.context.areaName {
                LabeledContent("Area", value: areaName)
            }

            if let floorName = update.context.floorName {
                LabeledContent("Floor", value: floorName)
            }

            if let deviceName = update.context.deviceName {
                LabeledContent("Device", value: deviceName)
            }

            if let deviceClass = update.deviceClass {
                LabeledContent("Type", value: deviceClass.replacingOccurrences(of: "_", with: " ").capitalized)
            }
        }
    }

    private func actionsSection(_ update: HAUpdateEntity) -> some View {
        let availability = HAUpdateSettingsActionAvailability.make(
            update: update,
            serviceActionAvailable: { domain, service in
                homeAssistantService.serviceActionAvailable(domain: domain, service: service)
            }
        )

        return Section {
            Button {
                isConfirmingInstall = true
            } label: {
                Label("Install Update", systemImage: "square.and.arrow.down")
            }
            .disabled(!availability.canInstall)

            Button {
                Task { await homeAssistantService.skipUpdate(entityID: update.entityID) }
            } label: {
                Label("Skip Update", systemImage: "forward")
            }
            .disabled(!availability.canSkip)

            Button {
                Task { await homeAssistantService.clearSkippedUpdate(entityID: update.entityID) }
            } label: {
                Label("Clear Skipped Update", systemImage: "arrow.uturn.backward")
            }
            .disabled(!availability.canClearSkipped)
        } footer: {
            Text(actionFooterText(availability: availability))
        }
    }

    private func installConfirmationMessage(for update: HAUpdateEntity) -> String {
        let versionText = update.latestVersion.map { " to \($0)" } ?? ""
        return "Install \(update.title)\(versionText). Some updates may restart Home Assistant, an add-on, or a device. Choose backup when the integration supports it or when you are unsure."
    }

    private func actionFooterText(availability: HAUpdateSettingsActionAvailability) -> String {
        [
            availability.installUnavailableReason,
            availability.skipUnavailableReason,
            availability.clearSkippedUnavailableReason
        ]
            .compactMap { $0 }
            .first ?? "Actions use Home Assistant's official update services."
    }
}

private struct UpdateStatusBadge: View {
    let status: HAUpdateStatus

    var body: some View {
        Text(status.shortTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .lineLimit(1)
            .frame(width: 88, alignment: .trailing)
    }
}

private extension HAUpdateEntity {
    var releaseNotesURL: URL? {
        guard let releaseURLString else { return nil }
        return URL(string: releaseURLString)
    }

    var progressText: String {
        guard let progress else {
            return "In progress"
        }

        let clampedProgress = min(max(progress, 0), 100)
        return "\(Int(clampedProgress.rounded()))%"
    }
}

private extension HAUpdateStatus {
    var tint: Color {
        switch self {
        case .available:
            Color.accentColor
        case .skipped:
            .orange
        case .inProgress:
            .blue
        case .unavailable:
            .red
        case .upToDate:
            .green
        case .unknown:
            .secondary
        }
    }
}

#if DEBUG
#Preview("Updates Settings") {
    NavigationStack {
        UpdatesSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
