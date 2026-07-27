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

    var body: some View {
        Form {
            Section {
                Toggle("Sync with iCloud", isOn: Binding(
                    get: { iCloudSyncService.isEnabled },
                    set: { setSyncEnabled($0) }
                ))

                LabeledContent("Status", value: iCloudSyncService.status.title)
                if let lastSyncDate = iCloudSyncService.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSyncDate.formatted(date: .abbreviated, time: .shortened))
                }
                if let lastRemoteChangeDate = iCloudSyncService.lastRemoteChangeDate {
                    LabeledContent("Latest iCloud Change", value: lastRemoteChangeDate.formatted(date: .abbreviated, time: .shortened))
                }

                Button {
                    syncNow()
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!iCloudSyncService.isEnabled)
            } footer: {
                Text("Changes sync automatically when enabled. Sync Now checks both this device and iCloud immediately. \(iCloudSyncService.status.detail)")
            }

            Section {
                SettingsSyncIncludedRow(
                    title: "Server Settings",
                    detail: serverSyncDetail,
                    systemImage: "server.rack"
                )
                SettingsSyncIncludedRow(
                    title: "Dashboard Preferences",
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
        .sheet(isPresented: $isShowingPlus) {
            HomesteadPlusSheet(context: .iCloudSync)
        }
    }

    private var serverSyncDetail: String {
        connectionSettings.hasServerURL ? SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL) : "No server saved"
    }

    private var dashboardSyncDetail: String {
        let dashboardCount = dashboardConfiguration.dashboards.count
        let itemCount = dashboardConfiguration.dashboards.reduce(0) { $0 + $1.items.count }
        let dashboardText = dashboardCount == 1 ? "1 dashboard" : "\(dashboardCount) dashboards"
        let itemText = itemCount == 1 ? "1 item" : "\(itemCount) items"
        return "\(dashboardText), \(itemText)"
    }

    private var appearanceSyncDetail: String {
        if appearanceSettings.hasWallpaper {
            return appearanceSettings.isWallpaperEnabled ? "Wallpaper enabled on devices with the same image" : "Wallpaper off"
        }

        return "Small appearance preferences only"
    }

    private func syncNow() {
        guard entitlementStore.hasPlus else {
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
