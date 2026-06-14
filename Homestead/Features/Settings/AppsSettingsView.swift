import SwiftUI
import UIKit

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
                    SupervisorAppDetailView(app: app)
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
            SupervisorAppIconView(app: app, size: 34)
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

private struct SupervisorAppDetailView: View {
    let app: HASupervisorApp

    var body: some View {
        List {
            Section {
                VStack(spacing: AppSpacing.small) {
                    SupervisorAppIconView(app: app, size: 72, prefersLogo: true)

                    Text(app.name)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text(app.status.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusTint.opacity(0.12), in: Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.small)
            }
            .listRowBackground(Color.clear)

            if let description = app.description {
                Section("About") {
                    Text(description)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Status") {
                LabeledContent("State", value: app.status.title)

                if let installedVersion = app.installedVersion {
                    LabeledContent("Installed", value: installedVersion)
                }

                if let latestVersion = app.latestVersion {
                    LabeledContent("Latest", value: latestVersion)
                }

                if app.updateAvailable {
                    LabeledContent("Update") {
                        Text("Available")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Home Assistant") {
                LabeledContent("Slug", value: app.slug)
            }
        }
        .navigationTitle(app.name)
        .toolbarTitleDisplayMode(.inline)
    }

    private var statusTint: Color {
        app.status.tint
    }
}

private struct SupervisorAppIconView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

    let app: HASupervisorApp
    let size: CGFloat
    var prefersLogo = false

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.06)
            } else {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(app.status.tint)
                    .frame(width: size, height: size)
                    .background(app.status.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .task(id: taskID) {
            await loadImage()
        }
        .accessibilityHidden(true)
    }

    private var imagePath: String? {
        if prefersLogo, let logoPath = app.logoPath {
            return logoPath
        }

        return app.iconPath ?? app.logoPath
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            imagePath ?? "no-image"
        ].joined(separator: "|")
    }

    private var cornerRadius: CGFloat {
        max(10, size * 0.22)
    }

    private func loadImage() async {
        guard let imagePath,
              let request = await homeAssistantService.homeAssistantImageRequest(
                settings: connectionSettings,
                pathOrURL: imagePath
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

private extension HASupervisorAppStatus {
    var tint: Color {
        switch self {
        case .running:
            return .green
        case .stopped:
            return .secondary
        case .unknown:
            return .gray
        }
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
