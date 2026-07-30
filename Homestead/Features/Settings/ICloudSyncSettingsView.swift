import SwiftUI

struct ICloudSyncSettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

                if iCloudSyncService.isEnabled {
                    syncStatusRow
                }
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    syncStatusCopy

                    HStack {
                        Spacer()
                        syncStatusAccessory
                    }
                }
            } else {
                HStack(alignment: .center, spacing: AppSpacing.medium) {
                    syncStatusCopy
                    Spacer(minLength: AppSpacing.small)
                    syncStatusAccessory
                }
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private var syncStatusCopy: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(syncStatusTitle)

            Text(syncStatusDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var syncStatusTitle: String {
        switch iCloudSyncService.status {
        case .checking:
            "Checking iCloud"
        case .syncing:
            "Syncing"
        case .conflict, .restoreAvailable, .requiresPlus, .unavailable, .quotaExceeded:
            iCloudSyncService.status.title
        default:
            iCloudSyncService.lastSyncDate == nil ? "Not Synced Yet" : "Last Synced"
        }
    }

    private var syncStatusDetail: String {
        switch iCloudSyncService.status {
        case .checking, .syncing, .conflict, .restoreAvailable, .requiresPlus, .unavailable, .quotaExceeded:
            iCloudSyncService.status.detail
        default:
            if let lastSyncDate = iCloudSyncService.lastSyncDate {
                lastSyncDate.formatted(date: .abbreviated, time: .shortened)
            } else {
                "Preferences are ready to sync through iCloud."
            }
        }
    }

    @ViewBuilder
    private var syncStatusAccessory: some View {
        switch iCloudSyncService.status {
        case .syncing, .checking:
            HStack(spacing: AppSpacing.xSmall) {
                ProgressView()
                    .controlSize(.small)
                Text(iCloudSyncService.status.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .fixedSize()
            .accessibilityElement(children: .combine)
        case .requiresPlus:
            syncActionButton(title: "View Plus")
        case .unavailable, .quotaExceeded:
            syncActionButton(title: "Try Again")
        case .conflict, .restoreAvailable:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel(iCloudSyncService.status.title)
        default:
            syncActionButton(title: "Sync Now")
        }
    }

    private func syncActionButton(title: String) -> some View {
        Button(title) {
            syncNow()
        }
        .buttonStyle(.borderless)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .fixedSize()
        .accessibilityLabel("\(title) with iCloud")
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
