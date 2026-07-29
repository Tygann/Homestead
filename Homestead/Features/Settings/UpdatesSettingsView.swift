import SwiftUI

struct UpdatesSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isConfirmingUpdateAll = false
    @State private var selectedUpdate: UpdateRoute?

    var body: some View {
        let updates = stateStore.updateEntities
        let presentation = HAUpdatePresentation.makeActionable(updates: updates)
        let availableUpdates = updates
            .filter { $0.status == .available && $0.supportsInstall }
            .sortedByUpdatePriority

        List {
            if !availableUpdates.isEmpty {
                updateAllSection(count: availableUpdates.count)
            }

            ForEach(presentation.sections) { section in
                Section(section.title) {
                    ForEach(section.updates) { update in
                        UpdateRowView(
                            update: update,
                            openDetail: {
                                selectedUpdate = UpdateRoute(entityID: update.entityID)
                            },
                            install: {
                                Task {
                                    await homeAssistantService.installUpdate(
                                        entityID: update.entityID,
                                        version: update.supportsSpecificVersion ? update.latestVersion : nil
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
        .overlay {
            if updates.isEmpty {
                ContentUnavailableView("No Updates", systemImage: EntityDomain.update.systemImage)
            } else if presentation.sections.isEmpty {
                ContentUnavailableView("All Updates Installed", systemImage: "checkmark.circle")
            }
        }
        .refreshable {
            await homeAssistantService.refreshStates()
        }
        .navigationDestination(item: $selectedUpdate) { route in
            UpdateDetailSettingsView(entityID: route.entityID)
        }
        .navigationTitle("Updates")
        .toolbarTitleDisplayMode(.inline)
        .alert(
            "Update all?",
            isPresented: $isConfirmingUpdateAll,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Update All") {
                    Task { await homeAssistantService.installAvailableUpdates(availableUpdates) }
                }
            },
            message: {
                Text(updateAllConfirmationMessage(count: availableUpdates.count))
            }
        )
    }

    private func updateAllSection(count: Int) -> some View {
        Section {
            Button {
                isConfirmingUpdateAll = true
            } label: {
                HStack {
                    Text("Update All")
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Text(count, format: .number)
                        .foregroundStyle(Color.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func updateAllConfirmationMessage(count: Int) -> String {
        "Install \(count) available \(count == 1 ? "update" : "updates"). Some updates may restart Home Assistant, add-ons, or devices."
    }
}

private struct UpdateRoute: Identifiable, Hashable {
    let entityID: String

    var id: String { entityID }
}

private struct UpdateRowView: View {
    let update: HAUpdateEntity
    let openDetail: () -> Void
    let install: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            UpdateRowContent(update: update)
                .contentShape(Rectangle())
                .onTapGesture(perform: openDetail)

            Spacer(minLength: AppSpacing.small)

            UpdateRowAction(
                status: update.status,
                canInstall: update.supportsInstall,
                progressText: update.progressText,
                install: install
            )
        }
    }
}

private struct UpdateRowContent: View {
    let update: HAUpdateEntity

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            UpdateIconView(update: update, size: 52)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(update.displayTitle)
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

    let update: HAUpdateEntity
    let size: CGFloat

    var body: some View {
        HomeAssistantAsyncImage(
            id: taskID,
            request: {
                guard let entityPicturePath = update.entityPicturePath else {
                    return nil
                }

                return await homeAssistantService.homeAssistantImageRequest(
                    settings: connectionSettings,
                    pathOrURL: entityPicturePath
                )
            }
        ) { image in
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                HomesteadIconView(icon: update.resolvedIcon, pointSize: size * 0.42)
                    .foregroundStyle(update.status.tint)
                    .frame(width: size, height: size)
                    .background(update.status.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

}

private struct UpdateRowAction: View {
    let status: HAUpdateStatus
    let canInstall: Bool
    let progressText: String
    let install: () -> Void

    var body: some View {
        switch status {
        case .available where canInstall:
            Button(action: install) {
                Text("Update")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color(.secondarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)
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

struct UpdateDetailSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var createBackup = false
    @State private var releaseNotesState = UpdateReleaseNotesState.idle

    let entityID: String
    var releaseNotesProvider: UpdateReleaseNotesProvider?

    var body: some View {
        Group {
            if let update {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        overviewSection(update)

                        if update.supportsBackup, actionAvailability(for: update).canInstall {
                            Divider()
                                .padding(.horizontal, AppSpacing.medium)
                            backupOption(update)
                        }

                        releaseSection(update)
                        locationSection(update)
                    }
                    .padding(.bottom, AppSpacing.large)
                }
                .background(Color(.systemBackground))
                .task(id: update.releaseNotesTaskID) {
                    await loadReleaseNotes(for: update)
                }
            } else {
                ContentUnavailableView("Update Missing", systemImage: EntityDomain.update.systemImage)
                    .background(Color(.systemBackground))
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if let update {
                updateActionsMenu(update)
            }
        }
    }

    private var update: HAUpdateEntity? {
        stateStore.updateEntity(for: entityID)
    }

    private func overviewSection(_ update: HAUpdateEntity) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            UpdateIconView(update: update, size: 80)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(update.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let installedVersion = update.installedVersion {
                    Text("Installed \(installedVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if actionAvailability(for: update).canInstall {
                    Button {
                        install(update)
                    } label: {
                        Text("Update")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .padding(.top, AppSpacing.xSmall)
                } else if update.isInProgress {
                    HStack(spacing: AppSpacing.xSmall) {
                        ProgressView()
                            .controlSize(.small)
                        Text(update.progressText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, AppSpacing.xSmall)
                } else {
                    Text(update.status.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(update.status.tint)
                        .padding(.top, AppSpacing.xSmall)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.large)
    }

    @ViewBuilder
    private func releaseSection(_ update: HAUpdateEntity) -> some View {
        if update.supportsReleaseNotes || update.releaseSummary != nil || update.releaseNotesURL != nil {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Divider()

                Text("What’s New")
                    .font(.title2.bold())
                    .padding(.top, AppSpacing.medium)

                HStack {
                    if let latestVersion = update.latestVersion {
                        Text("Version \(latestVersion)")
                    }

                    Spacer()

                    if let lastChanged = update.lastChanged {
                        Text(relativeDescription(for: lastChanged))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                switch releaseNotesState {
                case .idle, .loading:
                    if update.supportsReleaseNotes {
                        HStack(spacing: AppSpacing.small) {
                            ProgressView()
                            Text("Loading release notes…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        releaseNotesFallback(update)
                    }
                case .loaded(let releaseNotes):
                    if let releaseNotes {
                        UpdateReleaseNotesMarkdownView(
                            markdown: releaseNotes,
                            omittingLeadingHeading: update.latestVersion
                        )
                    } else {
                        releaseNotesFallback(update)
                    }
                case .failed:
                    releaseNotesFallback(update)
                    if update.releaseSummary == nil, update.releaseNotesURL == nil {
                        Text("Release notes are unavailable.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let releaseNotesURL = update.releaseNotesURL {
                    Link(destination: releaseNotesURL) {
                        Label("View Full Release Notes", systemImage: "safari")
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.medium)
        }
    }

    @ViewBuilder
    private func releaseNotesFallback(_ update: HAUpdateEntity) -> some View {
        if let releaseSummary = update.releaseSummary {
            UpdateReleaseNotesMarkdownView(
                markdown: releaseSummary,
                omittingLeadingHeading: update.latestVersion
            )
        }
    }

    @ViewBuilder
    private func locationSection(_ update: HAUpdateEntity) -> some View {
        if update.distinctDeviceName != nil || update.context.areaName != nil {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Divider()

                Text("Details")
                    .font(.headline)
                    .padding(.top, AppSpacing.medium)

                if let deviceName = update.distinctDeviceName {
                    LabeledContent("Device", value: deviceName)
                }

                if let areaName = update.context.areaName {
                    LabeledContent("Area", value: areaName)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.medium)
        }
    }

    private func backupOption(_ update: HAUpdateEntity) -> some View {
        Toggle(isOn: $createBackup) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Back Up Before Updating")
                    .font(.subheadline)

                if let installedVersion = update.installedVersion {
                    Text("Keeps version \(installedVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
    }

    private func actionAvailability(for update: HAUpdateEntity) -> HAUpdateSettingsActionAvailability {
        HAUpdateSettingsActionAvailability.make(
            update: update,
            serviceActionAvailable: { domain, service in
                homeAssistantService.serviceActionAvailable(domain: domain, service: service)
            }
        )
    }

    private func install(_ update: HAUpdateEntity) {
        Task {
            await homeAssistantService.installUpdate(
                entityID: update.entityID,
                backup: update.supportsBackup && createBackup ? true : nil,
                version: update.supportsSpecificVersion ? update.latestVersion : nil
            )
        }
    }

    @ToolbarContentBuilder
    private func updateActionsMenu(_ update: HAUpdateEntity) -> some ToolbarContent {
        let availability = actionAvailability(for: update)

        if availability.canSkip || availability.canClearSkipped {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if availability.canSkip {
                        Button {
                            Task { await homeAssistantService.skipUpdate(entityID: update.entityID) }
                        } label: {
                            Label("Skip This Version", systemImage: "forward")
                        }
                    }

                    if availability.canClearSkipped {
                        Button {
                            Task { await homeAssistantService.clearSkippedUpdate(entityID: update.entityID) }
                        } label: {
                            Label("Show This Version Again", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
    }

    private func relativeDescription(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadReleaseNotes(for update: HAUpdateEntity) async {
        guard update.supportsReleaseNotes else {
            releaseNotesState = .loaded(nil)
            return
        }

        releaseNotesState = .loading

        do {
            let releaseNotes: String?
            if let releaseNotesProvider {
                releaseNotes = try await releaseNotesProvider(update.entityID)
            } else {
                releaseNotes = try await homeAssistantService.fetchUpdateReleaseNotes(entityID: update.entityID)
            }

            guard !Task.isCancelled else { return }
            let trimmedNotes = releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
            releaseNotesState = .loaded(trimmedNotes?.isEmpty == false ? trimmedNotes : nil)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            releaseNotesState = .failed
        }
    }
}

typealias UpdateReleaseNotesProvider = @MainActor @Sendable (String) async throws -> String?

private enum UpdateReleaseNotesState: Equatable {
    case idle
    case loading
    case loaded(String?)
    case failed
}

private extension HAUpdateEntity {
    var releaseNotesURL: URL? {
        guard let releaseURLString else { return nil }
        return URL(string: releaseURLString)
    }

    var releaseNotesTaskID: String {
        "\(entityID)|\(latestVersion ?? "unknown")|\(supportsReleaseNotes)"
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
