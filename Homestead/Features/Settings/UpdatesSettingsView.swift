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
            SoftwareDetailView(updateEntityID: route.entityID)
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

struct UpdateIconView: View {
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

private extension HAUpdateEntity {
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
