import SwiftUI

struct UpdatesSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""
    @State private var filter: HAUpdateFilter = .all
    @State private var grouping: HAUpdateGrouping = .status

    var body: some View {
        let updates = stateStore.updateEntities
        let presentation = HAUpdatePresentation.make(
            updates: updates,
            searchText: searchText,
            filter: filter,
            grouping: grouping
        )

        List {
            if !updates.isEmpty {
                controlsSection(summary: presentation.summary, visibleCount: presentation.visibleCount)
            }

            ForEach(presentation.sections) { section in
                Section(section.title) {
                    ForEach(section.updates) { update in
                        NavigationLink {
                            UpdateDetailSettingsView(entityID: update.entityID)
                        } label: {
                            UpdateRowView(update: update)
                        }
                    }
                }
            }
        }
        .overlay {
            if updates.isEmpty {
                ContentUnavailableView("No Updates", systemImage: EntityDomain.update.systemImage)
            } else if presentation.sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("Updates")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !updates.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    groupingMenu
                }
            }
        }
    }

    private func controlsSection(summary: HAUpdateSummary, visibleCount: Int) -> some View {
        Section {
            Picker("Filter", selection: $filter) {
                ForEach(HAUpdateFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)

            LabeledContent("Showing", value: "\(visibleCount) of \(summary.totalCount)")

            if summary.availableCount > 0 {
                LabeledContent("Available", value: String(summary.availableCount))
            }

            if summary.skippedCount > 0 {
                LabeledContent("Skipped", value: String(summary.skippedCount))
            }

            if summary.inProgressCount > 0 {
                LabeledContent("In Progress", value: String(summary.inProgressCount))
            }

            if summary.unavailableCount > 0 {
                LabeledContent("Unavailable", value: String(summary.unavailableCount))
            }
        }
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(HAUpdateGrouping.allCases) { option in
                Button {
                    grouping = option
                } label: {
                    Label(option.title, systemImage: grouping == option ? "checkmark" : option.systemImage)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Group updates")
    }
}

private struct UpdateRowView: View {
    let update: HAUpdateEntity

    var body: some View {
        Label {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(update.title)
                        .font(.headline)
                        .lineLimit(1)

                    if update.name != update.title {
                        Text(update.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(update.versionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(update.contextSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.medium)

                UpdateStatusBadge(status: update.status)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: update.iconSystemName)
                .foregroundStyle(update.status.tint)
                .frame(width: 28)
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
