import SwiftUI

struct ICloudSyncSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(HomesteadICloudSyncService.self) private var iCloudSyncService
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore
    @State private var conflictSummary: HomesteadICloudRestoreSummary?
    @State private var errorMessage: String?
    @State private var isShowingPlus = false
    @State private var pendingPlusAction: ICloudPlusContinuation?

    var body: some View {
        Form {
            Section {
                Toggle("iCloud Sync", isOn: Binding(
                    get: { iCloudSyncService.isEnabled },
                    set: { setSyncEnabled($0) }
                ))

                syncStatusRow

                Button {
                    syncNow()
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!iCloudSyncService.isEnabled)
            } footer: {
                Text(syncFooterText)
            }

            Section {
                SettingsSyncIncludedRow(
                    title: "Servers",
                    detail: serverSyncDetail,
                    systemImage: "server.rack"
                )
                SettingsSyncIncludedRow(
                    title: "Dashboards",
                    detail: dashboardSyncDetail,
                    systemImage: "rectangle.grid.2x2"
                )
                SettingsSyncIncludedRow(
                    title: "Safety",
                    detail: actionConfirmationSettings.mode.displayName,
                    systemImage: "hand.raised.circle"
                )
                SettingsSyncIncludedRow(
                    title: "Appearance",
                    detail: appearanceSyncDetail,
                    systemImage: "paintpalette"
                )
            } header: {
                Text("Included")
            } footer: {
                Text("Your Home Assistant sign-in, live home data, notification setup, widgets, and wallpaper images stay on this device.")
            }
        }
        .navigationTitle("iCloud")
        .toolbarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Choose Which Setup to Keep",
            isPresented: Binding(get: { conflictSummary != nil }, set: { if !$0 { conflictSummary = nil } }),
            titleVisibility: .visible
        ) {
            Button("Use iCloud") { resolveConflict(.useICloud) }
            Button("Keep This Device") { resolveConflict(.keepThisDevice) }
            Button("Cancel", role: .cancel) { resolveConflict(.cancel) }
        } message: {
            Text("iCloud and this device have different Homestead preferences. Your Home Assistant credentials always remain on this device.")
        }
        .alert("iCloud Unavailable", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again later.")
        }
        .sheet(isPresented: $isShowingPlus, onDismiss: resumePendingPlusAction) {
            HomesteadPlusSheet(context: .iCloudSync)
        }
    }

    private var syncStatusRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("Status")

                if let lastSyncDate = iCloudSyncService.lastSyncDate {
                    Text("Last synced \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: AppSpacing.small)

            syncStatusAccessory
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    @ViewBuilder
    private var syncStatusAccessory: some View {
        switch iCloudSyncService.status {
        case .synced:
            Label(iCloudSyncService.status.title, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .syncing, .checking:
            HStack(spacing: AppSpacing.xSmall) {
                ProgressView()
                    .controlSize(.small)
                Text(iCloudSyncService.status.title)
            }
            .foregroundStyle(.secondary)
        case .conflict, .unavailable, .quotaExceeded:
            Label(iCloudSyncService.status.title, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        default:
            Text(iCloudSyncService.status.title)
                .foregroundStyle(.secondary)
        }
    }

    private var syncFooterText: String {
        let automaticSyncText = "Changes sync automatically when enabled."
        switch iCloudSyncService.status {
        case .requiresPlus, .restoreAvailable, .conflict, .unavailable, .quotaExceeded:
            return "\(automaticSyncText) \(iCloudSyncService.status.detail)"
        default:
            return automaticSyncText
        }
    }

    private var serverSyncDetail: String {
        let serverCount = connectionSettings.profileStore.configuredProfiles.count
        if serverCount == 0 {
            return "No servers"
        }
        return serverCount == 1 ? "1 server" : "\(serverCount) servers"
    }

    private var dashboardSyncDetail: String {
        let dashboardCount = dashboardConfiguration.dashboards.count
        let itemCount = dashboardConfiguration.dashboards.reduce(0) { $0 + $1.items.count }
        let dashboardText = dashboardCount == 1 ? "1 dashboard" : "\(dashboardCount) dashboards"
        let itemText = itemCount == 1 ? "1 item" : "\(itemCount) items"
        return "\(dashboardText), \(itemText)"
    }

    private var appearanceSyncDetail: String {
        "Theme and appearance preferences"
    }

    private func syncNow() {
        guard entitlementStore.hasPlus else {
            pendingPlusAction = .syncNow
            isShowingPlus = true
            return
        }
        iCloudSyncService.syncNow(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
    }

    private func setSyncEnabled(_ enabled: Bool) {
        guard enabled else {
            iCloudSyncService.disable()
            return
        }
        guard entitlementStore.hasPlus else {
            pendingPlusAction = .enable
            isShowingPlus = true
            return
        }
        switch iCloudSyncService.requestEnable(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        ) {
        case .enabled:
            break
        case .conflict(let summary):
            conflictSummary = summary
        case .unavailable(let message):
            errorMessage = message
        }
    }

    private func resolveConflict(_ resolution: HomesteadICloudConflictResolution) {
        iCloudSyncService.resolveEnableConflict(
            resolution,
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
        conflictSummary = nil
    }

    private func resumePendingPlusAction() {
        guard let action = HomesteadPlusContinuationPolicy.consume(
            &pendingPlusAction,
            hasPlus: entitlementStore.hasPlus
        ) else { return }

        Task { @MainActor in
            await Task.yield()
            switch action {
            case .enable:
                setSyncEnabled(true)
            case .syncNow:
                syncNow()
            }
        }
    }
}

private enum ICloudPlusContinuation {
    case enable
    case syncNow
}

private struct SettingsSyncIncludedRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}

#if DEBUG
#Preview("iCloud Settings") {
    NavigationStack {
        ICloudSyncSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
