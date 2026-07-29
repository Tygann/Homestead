import SwiftUI

struct SoftwareDetailView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService

    @State private var createBackup = false
    @State private var loadedAppDetails: HASupervisorAppDetails?
    @State private var releaseNotesState = SoftwareReleaseNotesState.idle

    private let initialApp: HASupervisorApp?
    private let initialAppDetails: HASupervisorAppDetails?
    private let updateEntityID: String?
    private let releaseNotesProvider: SoftwareReleaseNotesProvider?
    private let appDetailsProvider: SupervisorAppDetailsProvider?

    init(
        app: HASupervisorApp? = nil,
        appDetails: HASupervisorAppDetails? = nil,
        updateEntityID: String? = nil,
        releaseNotesProvider: SoftwareReleaseNotesProvider? = nil,
        appDetailsProvider: SupervisorAppDetailsProvider? = nil
    ) {
        initialApp = app ?? appDetails?.app
        initialAppDetails = appDetails
        self.updateEntityID = updateEntityID
        self.releaseNotesProvider = releaseNotesProvider
        self.appDetailsProvider = appDetailsProvider
    }

    var body: some View {
        Group {
            if app != nil || update != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroArtwork
                        identitySection
                        metadataSection

                        if let update, update.supportsBackup, actionAvailability(for: update).canInstall {
                            sectionDivider
                            backupOption(update)
                        }

                        whatsNewSection
                        aboutSection
                        informationSection
                    }
                    .padding(.bottom, AppSpacing.large)
                }
                .ignoresSafeArea(.container, edges: app?.hasLogo == true ? .top : [])
                .background(Color(.systemBackground))
                .task(id: appDetailsTaskID) {
                    await loadAppDetails()
                }
                .task(id: releaseNotesTaskID) {
                    await loadReleaseNotes()
                }
            } else {
                ContentUnavailableView("Software Missing", systemImage: "shippingbox")
                    .background(Color(.systemBackground))
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            updateActionsMenu
        }
    }

    // MARK: - Source Resolution

    private var appDetails: HASupervisorAppDetails? {
        loadedAppDetails ?? initialAppDetails
    }

    private var app: HASupervisorApp? {
        appDetails?.app ?? initialApp
    }

    private var update: HAUpdateEntity? {
        if let updateEntityID {
            return stateStore.updateEntity(for: updateEntityID)
        }

        if let slug = app?.slug {
            return stateStore.updateEntity(forSupervisorAppSlug: slug)
        }

        return nil
    }

    private var supervisorAppSlug: String? {
        if let slug = app?.slug {
            return slug
        }

        guard let updateEntityID else { return nil }
        return stateStore.supervisorAppSlug(forUpdateEntityID: updateEntityID)
    }

    private var displayName: String {
        app?.name ?? update?.displayTitle ?? "Software"
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroArtwork: some View {
        if let app, app.hasLogo {
            SupervisorAppArtworkView(app: app, kind: .logo, height: 220)
                .containerRelativeFrame(.horizontal)
                .frame(maxWidth: .infinity)
        }
    }

    private var identitySection: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            identityArtwork

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(identitySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                primaryAction
                    .padding(.top, AppSpacing.xSmall)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.large)
    }

    @ViewBuilder
    private var identityArtwork: some View {
        if let app {
            SupervisorAppArtworkView(app: app, kind: .icon, height: 82)
        } else if let update {
            UpdateIconView(update: update, size: 82)
        }
    }

    private var identitySubtitle: String {
        if let app {
            return app.status.title
        }

        return update?.status.title ?? "Status unavailable"
    }

    @ViewBuilder
    private var primaryAction: some View {
        if let update, actionAvailability(for: update).canInstall {
            Button {
                install(update)
            } label: {
                Text("Update")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        } else if let update, update.isInProgress {
            HStack(spacing: AppSpacing.xSmall) {
                ProgressView()
                    .controlSize(.small)
                Text(update.progressText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if app?.updateAvailable == true {
            Text("Update Available")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        } else if let update {
            Text(update.status.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(update.status.tint)
        }
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSection: some View {
        let items = metadataItems
        if !items.isEmpty {
            sectionDivider

            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .frame(height: 38)
                    }

                    VStack(spacing: 3) {
                        Text(item.title.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)

                        Text(item.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(item.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, AppSpacing.medium)
        }
    }

    private var metadataItems: [SoftwareMetadataItem] {
        var items: [SoftwareMetadataItem] = []

        if let app {
            items.append(SoftwareMetadataItem(
                id: "state",
                title: "State",
                value: app.status.title,
                tint: app.status.tint
            ))
        }

        if let installedVersion = update?.installedVersion ?? app?.installedVersion {
            items.append(SoftwareMetadataItem(
                id: "installed",
                title: "Installed",
                value: installedVersion
            ))
        }

        if let latestVersion = update?.latestVersion ?? app?.latestVersion {
            items.append(SoftwareMetadataItem(
                id: "latest",
                title: "Latest",
                value: latestVersion
            ))
        }

        return items
    }

    // MARK: - Update Sections

    private func backupOption(_ update: HAUpdateEntity) -> some View {
        Toggle(isOn: $createBackup) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Back Up Before Updating")
                    .font(.subheadline)

                if let installedVersion = update.installedVersion {
                    Text("Keeps version \(installedVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
    }

    @ViewBuilder
    private var whatsNewSection: some View {
        if let update, update.showsUpdateDetails {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                sectionDivider

                Text("What’s New")
                    .font(.title2.bold())
                    .padding(.top, AppSpacing.medium)

                HStack {
                    if let latestVersion = update.latestVersion {
                        Text("Version \(latestVersion)")
                    }

                    Spacer()

                    if let lastChanged = update.lastChanged {
                        Text(relativeDescription(for: lastChanged))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                releaseNotesContent(update)

                if let releaseNotesURL = update.releaseNotesURL {
                    Link(destination: releaseNotesURL) {
                        Label("View Full Release Notes", systemImage: "safari")
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.medium)
        }
    }

    @ViewBuilder
    private func releaseNotesContent(_ update: HAUpdateEntity) -> some View {
        switch releaseNotesState {
        case .idle, .loading:
            if update.supportsReleaseNotes {
                HStack(spacing: AppSpacing.small) {
                    ProgressView()
                    Text("Loading release notes…")
                        .foregroundStyle(.secondary)
                }
            } else {
                releaseNotesFallback(update)
            }
        case .loaded(let releaseNotes):
            if let releaseNotes {
                UpdateReleaseNotesMarkdownView(
                    markdown: releaseNotes,
                    omittingLeadingHeading: update.latestVersion
                )
            } else {
                releaseNotesFallback(update)
            }
        case .failed:
            releaseNotesFallback(update)
            if update.releaseSummary == nil, update.releaseNotesURL == nil {
                Text("Release notes are unavailable.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func releaseNotesFallback(_ update: HAUpdateEntity) -> some View {
        if let releaseSummary = update.releaseSummary {
            UpdateReleaseNotesMarkdownView(
                markdown: releaseSummary,
                omittingLeadingHeading: update.latestVersion
            )
        }
    }

    // MARK: - App Information

    @ViewBuilder
    private var aboutSection: some View {
        if let aboutText {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                sectionDivider

                Text("About")
                    .font(.title2.bold())
                    .padding(.top, AppSpacing.medium)

                UpdateReleaseNotesMarkdownView(markdown: aboutText)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.medium)
        }
    }

    private var aboutText: String? {
        appDetails?.longDescription ?? app?.description
    }

    @ViewBuilder
    private var informationSection: some View {
        let rows = informationRows
        let links = informationLinks

        if !rows.isEmpty || !links.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                sectionDivider

                Text("Information")
                    .font(.title2.bold())
                    .padding(.top, AppSpacing.medium)

                ForEach(rows) { row in
                    LabeledContent(row.title, value: row.value)
                        .font(.subheadline)
                }

                ForEach(links) { link in
                    Link(destination: link.url) {
                        Label(link.title, systemImage: "arrow.up.right")
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.bottom, AppSpacing.medium)
        }
    }

    private var informationRows: [SoftwareInformationRow] {
        var rows: [SoftwareInformationRow] = []

        if let stage = appDetails?.stage {
            rows.append(SoftwareInformationRow(
                id: "stage",
                title: "Release Channel",
                value: stage.capitalized
            ))
        }

        if let autoUpdate = update?.autoUpdate ?? appDetails?.autoUpdate {
            rows.append(SoftwareInformationRow(
                id: "auto-update",
                title: "Automatic Updates",
                value: autoUpdate ? "On" : "Off"
            ))
        }

        if let minimumVersion = appDetails?.minimumHomeAssistantVersion {
            rows.append(SoftwareInformationRow(
                id: "minimum-ha",
                title: "Requires Home Assistant",
                value: minimumVersion
            ))
        }

        if let update {
            if let deviceName = update.distinctDeviceName {
                rows.append(SoftwareInformationRow(id: "device", title: "Device", value: deviceName))
            }

            if let manufacturer = update.context.deviceManufacturer {
                rows.append(SoftwareInformationRow(
                    id: "manufacturer",
                    title: "Developer",
                    value: manufacturer
                ))
            }

            if let model = update.context.deviceModel {
                rows.append(SoftwareInformationRow(id: "model", title: "Model", value: model))
            }

            if let areaName = update.context.areaName {
                rows.append(SoftwareInformationRow(id: "area", title: "Area", value: areaName))
            }

            if app == nil, let deviceClass = update.deviceClass {
                rows.append(SoftwareInformationRow(
                    id: "type",
                    title: "Type",
                    value: deviceClass.capitalized
                ))
            }
        }

        if let architectures = appDetails?.supportedArchitectures, !architectures.isEmpty {
            rows.append(SoftwareInformationRow(
                id: "architectures",
                title: "Architectures",
                value: architectures.joined(separator: ", ")
            ))
        }

        return rows
    }

    private var informationLinks: [SoftwareInformationLink] {
        var links: [SoftwareInformationLink] = []

        if let url = validURL(appDetails?.websiteURLString) {
            links.append(SoftwareInformationLink(id: "website", title: "Website", url: url))
        }

        if let url = validURL(appDetails?.repositoryURLString) {
            links.append(SoftwareInformationLink(id: "repository", title: "Repository", url: url))
        }

        return links
    }

    // MARK: - Actions

    private func actionAvailability(for update: HAUpdateEntity) -> HAUpdateSettingsActionAvailability {
        HAUpdateSettingsActionAvailability.make(
            update: update,
            serviceActionAvailable: { domain, service in
                homeAssistantService.serviceActionAvailable(domain: domain, service: service)
            }
        )
    }

    private func install(_ update: HAUpdateEntity) {
        Task {
            await homeAssistantService.installUpdate(
                entityID: update.entityID,
                backup: update.supportsBackup && createBackup ? true : nil,
                version: update.supportsSpecificVersion ? update.latestVersion : nil
            )
        }
    }

    @ToolbarContentBuilder
    private var updateActionsMenu: some ToolbarContent {
        if let update {
            let availability = actionAvailability(for: update)

            if availability.canSkip || availability.canClearSkipped {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if availability.canSkip {
                            Button {
                                Task { await homeAssistantService.skipUpdate(entityID: update.entityID) }
                            } label: {
                                Label("Skip This Version", systemImage: "forward")
                            }
                        }

                        if availability.canClearSkipped {
                            Button {
                                Task { await homeAssistantService.clearSkippedUpdate(entityID: update.entityID) }
                            } label: {
                                Label("Show This Version Again", systemImage: "arrow.uturn.backward")
                            }
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis")
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private var appDetailsTaskID: String {
        [
            supervisorAppSlug ?? "no-app",
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }

    private func loadAppDetails() async {
        guard let slug = supervisorAppSlug else { return }

        do {
            let details: HASupervisorAppDetails
            if let appDetailsProvider {
                details = try await appDetailsProvider(slug)
            } else {
                details = try await homeAssistantService.fetchSupervisorAppDetails(
                    settings: connectionSettings,
                    slug: slug
                )
            }

            guard !Task.isCancelled else { return }
            loadedAppDetails = details
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private var releaseNotesTaskID: String {
        guard let update else { return "no-update" }
        return "\(update.entityID)|\(update.latestVersion ?? "unknown")|\(update.supportsReleaseNotes)"
    }

    private func loadReleaseNotes() async {
        guard let update, update.showsUpdateDetails, update.supportsReleaseNotes else {
            releaseNotesState = .loaded(nil)
            return
        }

        releaseNotesState = .loading

        do {
            let releaseNotes: String?
            if let releaseNotesProvider {
                releaseNotes = try await releaseNotesProvider(update.entityID)
            } else {
                releaseNotes = try await homeAssistantService.fetchUpdateReleaseNotes(entityID: update.entityID)
            }

            guard !Task.isCancelled else { return }
            let trimmedNotes = releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
            releaseNotesState = .loaded(trimmedNotes?.isEmpty == false ? trimmedNotes : nil)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            releaseNotesState = .failed
        }
    }

    // MARK: - Helpers

    private var sectionDivider: some View {
        Divider()
            .padding(.horizontal, AppSpacing.medium)
    }

    private func relativeDescription(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func validURL(_ value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }
}

typealias SoftwareReleaseNotesProvider = @MainActor @Sendable (String) async throws -> String?
typealias SupervisorAppDetailsProvider = @MainActor @Sendable (String) async throws -> HASupervisorAppDetails

private enum SoftwareReleaseNotesState: Equatable {
    case idle
    case loading
    case loaded(String?)
    case failed
}

private struct SoftwareMetadataItem: Identifiable {
    let id: String
    let title: String
    let value: String
    var tint: Color = .primary
}

private struct SoftwareInformationRow: Identifiable {
    let id: String
    let title: String
    let value: String
}

private struct SoftwareInformationLink: Identifiable {
    let id: String
    let title: String
    let url: URL
}

private extension HAUpdateEntity {
    var releaseNotesURL: URL? {
        guard let releaseURLString else { return nil }
        return URL(string: releaseURLString)
    }

    var progressText: String {
        guard let progress else {
            return "In progress"
        }

        let clampedProgress = min(max(progress, 0), 100)
        return "\(Int(clampedProgress.rounded()))%"
    }

    var showsUpdateDetails: Bool {
        status == .available || status == .skipped || status == .inProgress
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
