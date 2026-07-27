import SwiftUI

enum SettingsRoute: Hashable {
    case dashboards
    case plus
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore
    @State private var isShowingRatePlaceholder = false

    var body: some View {
        let peopleRecords = stateStore.presenceRecords().filter(\.isPerson)
        let visiblePeopleRecords = peopleRecords.filter {
            !$0.isCurrentUser(
                currentUserDisplayName: homeAssistantService.currentUserDisplayName,
                currentUserEntityPicturePath: homeAssistantService.currentUserEntityPicturePath
            )
        }
        let availableUpdateCount = stateStore.updateEntities.count { $0.status == .available }

        Form {
            Section {
                NavigationLink {
                    HomesteadPlusView()
                } label: {
                    SettingsNavigationRowLabel(systemImage: "house.and.flag") {
                        HStack {
                            Text("Homestead Plus")
                            Spacer()
                            Text(entitlementStore.statusTitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

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
                    SettingsNavigationRowLabel("Devices & Services", systemImage: "laptopcomputer.and.iphone")
                }

                NavigationLink {
                    AutomationsAndScenesManagementView()
                } label: {
                    SettingsNavigationRowLabel("Automations & Scenes", systemImage: "sparkles")
                }

                NavigationLink {
                    AppsSettingsView()
                } label: {
                    SettingsNavigationRowLabel("Apps", systemImage: "puzzlepiece.extension")
                }

                NavigationLink {
                    UpdatesSettingsView()
                } label: {
                    SettingsNavigationRowLabel(systemImage: "arrow.triangle.2.circlepath.circle") {
                        HStack {
                            Text("Updates")
                            Spacer()

                            if availableUpdateCount > 0 {
                                Text(availableUpdateCount, format: .number)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(
                                        "\(availableUpdateCount) \(availableUpdateCount == 1 ? "update" : "updates") available"
                                    )
                            }
                        }
                    }
                }

                NavigationLink {
                    LogbookSettingsView()
                } label: {
                    SettingsNavigationRowLabel("Logbook", systemImage: "list.bullet.clipboard")
                }
            }

            Section("Customize") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    SettingsNavigationRowLabel("Appearance", systemImage: "circle.righthalf.filled")
                }

                NavigationLink(value: SettingsRoute.dashboards) {
                    SettingsNavigationRowLabel("Dashboards", systemImage: "rectangle.grid.2x2")
                }
            }

            Section("App") {
                NavigationLink {
                    NativeNotificationSettingsView()
                } label: {
                    SettingsNavigationRowLabel("Notifications", systemImage: "bell.badge")
                }

                NavigationLink {
                    ActionConfirmationSettingsView()
                } label: {
                    SettingsNavigationRowLabel("Safety", systemImage: "hand.raised.circle")
                }

                NavigationLink {
                    NativePermissionsSettingsView()
                } label: {
                    SettingsNavigationRowLabel("Privacy & Permissions", systemImage: "hand.raised")
                }

                NavigationLink {
                    ICloudSyncSettingsView()
                } label: {
                    SettingsNavigationRowLabel("iCloud", systemImage: "icloud")
                }
            }

            Section {
                ShareLink(
                    item: HomesteadDistributionPresentation.publicInstallURL,
                    preview: SharePreview("Homestead")
                ) {
                    SettingsNavigationRowLabel("Share Homestead", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)

                Button {
                    isShowingRatePlaceholder = true
                } label: {
                    SettingsNavigationRowLabel("Rate Homestead", systemImage: "star")
                }
                .buttonStyle(.plain)

                NavigationLink(destination: AboutView()) {
                    SettingsNavigationRowLabel("About", systemImage: "info.circle")
                }
            }
        }
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .dashboards:
                DashboardSettingsView()
            case .plus:
                HomesteadPlusView()
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .task(id: authRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
        }
        .alert(
            HomesteadDistributionPresentation.ratePlaceholder.title,
            isPresented: $isShowingRatePlaceholder
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(HomesteadDistributionPresentation.ratePlaceholder.message)
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
