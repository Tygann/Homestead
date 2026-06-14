import SwiftUI

struct ICloudSyncSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(HomesteadICloudSyncService.self) private var iCloudSyncService

    var body: some View {
        @Bindable var iCloudSyncService = iCloudSyncService

        Form {
            Section {
                Toggle("Sync with iCloud", isOn: $iCloudSyncService.isEnabled)

                LabeledContent("Status", value: iCloudSyncService.status.title)
                if let lastSyncDate = iCloudSyncService.lastSyncDate {
                    LabeledContent("Last Upload", value: lastSyncDate.formatted(date: .abbreviated, time: .shortened))
                }
                if let lastRemoteChangeDate = iCloudSyncService.lastRemoteChangeDate {
                    LabeledContent("Last Download", value: lastRemoteChangeDate.formatted(date: .abbreviated, time: .shortened))
                }

                Button {
                    syncNow()
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!iCloudSyncService.isEnabled)
            } footer: {
                Text(iCloudSyncService.status.detail)
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
                    title: "Action Confirmations",
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
                Text("Home Assistant credentials, tokens, entity state, registry cache, mobile-app registration secrets, widget snapshots, and wallpaper image files stay on this device.")
            }
        }
        .navigationTitle("iCloud Sync")
        .toolbarTitleDisplayMode(.inline)
    }

    private var serverSyncDetail: String {
        connectionSettings.hasServerURL ? SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL) : "No server saved"
    }

    private var dashboardSyncDetail: String {
        let itemCount = dashboardConfiguration.items.count
        return itemCount == 1 ? "1 dashboard item" : "\(itemCount) dashboard items"
    }

    private var appearanceSyncDetail: String {
        if appearanceSettings.hasWallpaper {
            return appearanceSettings.isWallpaperEnabled ? "Wallpaper enabled on devices with the same image" : "Wallpaper off"
        }

        return "Small appearance preferences only"
    }

    private func syncNow() {
        iCloudSyncService.syncNow(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
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
#Preview("iCloud Sync Settings") {
    NavigationStack {
        ICloudSyncSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
