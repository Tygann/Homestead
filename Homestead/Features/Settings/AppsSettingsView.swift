import SwiftUI

struct AppsSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    @State private var loadState: AppsSettingsLoadState = .loading
    @State private var isRefreshing = false

    var body: some View {
        List {
            switch loadState {
            case .loading:
                loadingSection
            case .loaded(let apps):
                if apps.isEmpty {
                    emptySection
                } else {
                    appsSection(apps)
                }
            case .unavailable(let reason):
                unavailableSection(reason)
            case .failed(let message):
                errorSection(message)
            }
        }
        .navigationTitle("Apps")
        .toolbarTitleDisplayMode(.inline)
        .refreshable {
            await refreshApps()
        }
        .task(id: loadTaskID) {
            await refreshApps()
        }
    }

    private var loadingSection: some View {
        Section {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }

    private var emptySection: some View {
        Section {
            ContentUnavailableView("No Apps", systemImage: "puzzlepiece.extension")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private func appsSection(_ apps: [HASupervisorApp]) -> some View {
        Section("Installed Apps") {
            ForEach(apps) { app in
                NavigationLink {
                    SoftwareDetailView(app: app)
                } label: {
                    SupervisorAppRow(app: app)
                }
            }
        }
    }

    private func unavailableSection(_ reason: HASupervisorAppsUnavailableReason) -> some View {
        Section {
            ContentUnavailableView {
                Label(reason.title, systemImage: "puzzlepiece.extension")
            } description: {
                Text(reason.message)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Button {
                Task { await refreshApps() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)

            Button {
                Task { await refreshApps() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
        }
    }

    private var loadTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }

    private func refreshApps() async {
        if !loadState.hasLoadedApps {
            loadState = .loading
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let result = await homeAssistantService.fetchSupervisorApps(settings: connectionSettings)
        switch result {
        case .available(let apps):
            loadState = .loaded(apps)
        case .unavailable(let reason):
            loadState = .unavailable(reason)
        case .failed(let message):
            loadState = .failed(message)
        }
    }
}

private struct SupervisorAppRow: View {
    let app: HASupervisorApp

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            SupervisorAppArtworkView(app: app, kind: .icon, height: 52)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(app.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)

                    Text(app.status.title)

                    if let installedVersion = app.installedVersionText {
                        Text("·")
                            .accessibilityHidden(true)
                        Text(installedVersion)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                    }

                    Spacer(minLength: 6)

                    if app.updateAvailable {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Update available")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .fixedSize(horizontal: true, vertical: true)
                        .layoutPriority(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var statusTint: Color {
        app.status.tint
    }
}

private enum AppsSettingsLoadState: Equatable {
    case loading
    case loaded([HASupervisorApp])
    case unavailable(HASupervisorAppsUnavailableReason)
    case failed(String)

    var hasLoadedApps: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }
}
