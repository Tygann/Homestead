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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshApps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh apps")
            }
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
        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: AppSpacing.small) {
                        if let versionText {
                            Text(versionText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if app.updateAvailable {
                            Label("Update", systemImage: "arrow.down.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .labelStyle(.titleAndIcon)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: AppSpacing.small)

                Text(app.status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusTint.opacity(0.12), in: Capsule())
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            SupervisorAppArtworkView(app: app, kind: .icon, height: 34)
        }
    }

    private var versionText: String? {
        guard let installedVersion = app.installedVersion?.nonEmptyValue else {
            return nil
        }

        return installedVersion
    }

    private var statusTint: Color {
        app.status.tint
    }
}

nonisolated private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
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
