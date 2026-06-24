import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    var body: some View {
        let peopleRecords = stateStore.presenceRecords().filter(\.isPerson)
        let visiblePeopleRecords = peopleRecords.filter {
            !$0.isCurrentUser(
                currentUserDisplayName: homeAssistantService.currentUserDisplayName,
                currentUserEntityPicturePath: homeAssistantService.currentUserEntityPicturePath
            )
        }

        Form {
            Section {
                NavigationLink(destination: HomeAssistantSettingsView()) {
                    HomeAssistantSettingsRow(
                        title: accountTitle,
                        server: serverDisplayText,
                        status: accountStatusText,
                        tint: accountStatusTint
                    )
                }
                NavigationLink {
                    PeopleSettingsView()
                } label: {
                    PeopleSettingsRow(records: visiblePeopleRecords)
                }
            }

            Section("Home Assistant") {
                NavigationLink {
                    DevicesAndServicesManagementView()
                } label: {
                    Label("Devices & Services", systemImage: "laptopcomputer.and.iphone")
                }

                NavigationLink {
                    AutomationsAndScenesManagementView()
                } label: {
                    Label("Automations & Scenes", systemImage: "sparkles")
                }

                NavigationLink {
                    AppsSettingsView()
                } label: {
                    Label("Apps", systemImage: "puzzlepiece.extension")
                }

                NavigationLink {
                    UpdatesSettingsView()
                } label: {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                }

                NavigationLink {
                    LogbookSettingsView()
                } label: {
                    Label("Logbook", systemImage: "list.bullet.clipboard")
                }
            }

            Section("Customize") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Appearance", systemImage: "paintpalette")
                }

                NavigationLink {
                    DashboardSettingsView()
                } label: {
                    Label("Dashboards", systemImage: "rectangle.grid.2x2")
                }
            }

            Section("App") {
                NavigationLink {
                    NativeNotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }

                NavigationLink {
                    ActionConfirmationSettingsView()
                } label: {
                    Label("Safety", systemImage: "hand.raised.circle")
                }

                NavigationLink {
                    NativePermissionsSettingsView()
                } label: {
                    Label("Privacy & Permissions", systemImage: "hand.raised")
                }

                NavigationLink {
                    ICloudSyncSettingsView()
                } label: {
                    Label("iCloud", systemImage: "icloud")
                }
            }

            Section {
                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .task(id: authRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
        }
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var accountTitle: String {
        homeAssistantService.currentUserDisplayName ?? "Home Assistant"
    }

    private var accountStatusText: String {
        SettingsHomeAssistantStatus.summaryStatusText(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            dataFreshness: homeAssistantService.dataFreshness
        )
    }

    private var accountStatusTint: Color {
        SettingsHomeAssistantStatus.tint(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            dataFreshness: homeAssistantService.dataFreshness
        )
    }

    private var authRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }
}

private struct PeopleSettingsRow: View {
    let records: [HAPresenceRecord]

    var body: some View {
        HStack(spacing: 15) {
            PeoplePresenceAvatarStackView(records: records, size: 30, width: 60, maximumVisibleCount: records.count)

            Text("People")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

private struct HomeAssistantSettingsRow: View {
    let title: String
    let server: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(spacing: 15) {
            HomeAssistantAvatarView()
                .frame(width: 60, height: 60)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)

                Text(server)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer()

            SettingsStatusChip(title: status, tint: tint)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
    }
    .withPreviewEnvironment()
}
#endif
