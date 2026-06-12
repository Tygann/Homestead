import SwiftUI

struct UpdatesSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var updateToInstall: HAUpdateEntity?
    @State private var isConfirmingUpdateAll = false
    @State private var selectedUpdate: UpdateRoute?

    var body: some View {
        let updates = stateStore.updateEntities
        let presentation = HAUpdatePresentation.makeActionable(updates: updates)
        let availableUpdates = updates.filter { $0.status == .available }.sortedByUpdatePriority

        List {
            if !availableUpdates.isEmpty {
                updateAllSection(count: presentation.summary.availableCount)
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
                                updateToInstall = update
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
        .alert(
            "Update all?",
            isPresented: $isConfirmingUpdateAll,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Install All with Backup") {
                    Task { await homeAssistantService.installAvailableUpdates(availableUpdates, backup: true) }
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

    private func installConfirmationMessage(for update: HAUpdateEntity) -> String {
        let versionText = update.latestVersion.map { " to \($0)" } ?? ""
        return "Install \(update.title)\(versionText). Some updates may restart Home Assistant, an add-on, or a device. Choose backup when the integration supports it or when you are unsure."
    }

    private func updateAllConfirmationMessage(count: Int) -> String {
        "Install \(count) available \(count == 1 ? "update" : "updates") with backup enabled. Some updates may restart Home Assistant, add-ons, or devices."
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
    @State private var image: Image?

    let update: HAUpdateEntity
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(3)
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

private struct UpdateDetailSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isConfirmingInstall = false

    let entityID: String

    var body: some View {
        Group {
            if let update {
                Form {
                    overviewSection(update)
                    releaseSection(update)
                    locationSection(update)
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
        .navigationTitle(update?.displayTitle ?? "Update")
        .toolbarTitleDisplayMode(.inline)
    }

    private var update: HAUpdateEntity? {
        stateStore.updateEntity(for: entityID)
    }

    private func overviewSection(_ update: HAUpdateEntity) -> some View {
        Section {
            HStack(spacing: AppSpacing.medium) {
                UpdateIconView(update: update, size: 64)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(update.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(update.status.title)
                        .font(.subheadline)
                        .foregroundStyle(update.status.tint)

                    Text(update.versionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if update.isInProgress {
                LabeledContent("Progress", value: update.progressText)
            }

            if let skippedVersion = update.skippedVersion {
                LabeledContent("Skipped", value: skippedVersion)
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

    @ViewBuilder
    private func locationSection(_ update: HAUpdateEntity) -> some View {
        if update.context.deviceName != nil || update.context.areaName != nil || update.lastUpdated != nil {
            Section {
                if let deviceName = update.context.deviceName {
                    LabeledContent("Device", value: deviceName)
                }

                if let areaName = update.context.areaName {
                    LabeledContent("Area", value: areaName)
                }

                if let lastUpdated = update.lastUpdated {
                    LabeledContent("Last checked") {
                        Text(lastUpdated.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
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
            if availability.canInstall {
                Button {
                    isConfirmingInstall = true
                } label: {
                    Label("Update", systemImage: "square.and.arrow.down")
                }
            }

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
        } footer: {
            if let reason = actionFooterText(availability: availability) {
                Text(reason)
            }
        }
    }

    private func installConfirmationMessage(for update: HAUpdateEntity) -> String {
        let versionText = update.latestVersion.map { " to \($0)" } ?? ""
        return "Install \(update.title)\(versionText). Some updates may restart Home Assistant, an add-on, or a device. Choose backup when the integration supports it or when you are unsure."
    }

    private func actionFooterText(availability: HAUpdateSettingsActionAvailability) -> String? {
        [
            availability.installUnavailableReason,
            availability.skipUnavailableReason,
            availability.clearSkippedUnavailableReason
        ]
            .compactMap { $0 }
            .first
    }
}

private extension HAUpdateEntity {
    var displayTitle: String {
        trimmedUpdateSuffix(from: title)
    }

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

    private func trimmedUpdateSuffix(from value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = " Update"
        guard trimmedValue.localizedCaseInsensitiveContains(suffix),
              trimmedValue.range(of: suffix, options: [.caseInsensitive, .backwards])?.upperBound == trimmedValue.endIndex,
              let range = trimmedValue.range(of: suffix, options: [.caseInsensitive, .backwards]) else {
            return trimmedValue
        }

        let result = trimmedValue[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? trimmedValue : result
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
