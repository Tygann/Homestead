import SwiftUI

struct SoftwareDetailView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService

    @State private var createBackup = false
    @State private var loadedAppDetails: HASupervisorAppDetails?
    @State private var releaseNotesState = SoftwareReleaseNotesState.idle
    @State private var lifecycleActionInProgress: HASupervisorAppLifecycleAction?
    @State private var pendingLifecycleAction: HASupervisorAppLifecycleAction?
    @State private var lifecycleErrorMessage: String?
    @State private var isWhatsNewExpanded = false

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
            softwareActionsMenu
        }
        .confirmationDialog(
            lifecycleConfirmationTitle,
            isPresented: lifecycleConfirmationIsPresented,
            titleVisibility: .visible
        ) {
            if let pendingLifecycleAction {
                Button(
                    pendingLifecycleAction.title,
                    role: pendingLifecycleAction == .stop ? .destructive : nil
                ) {
                    performLifecycleAction(pendingLifecycleAction)
                }
            }

            Button("Cancel", role: .cancel) {
                pendingLifecycleAction = nil
            }
        } message: {
            Text(lifecycleConfirmationMessage)
        }
        .alert(
            "Unable to Control App",
            isPresented: lifecycleErrorIsPresented
        ) {
            Button("OK", role: .cancel) {
                lifecycleErrorMessage = nil
            }
        } message: {
            Text(lifecycleErrorMessage ?? "Home Assistant could not complete the request.")
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
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear
                        .frame(height: AppSpacing.large)
                }
                .clipped()
        }
    }

    private var identitySection: some View {
        HStack(alignment: .top, spacing: 16) {
            identityArtwork

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(identitySubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Spacer(minLength: 2)

                primaryAction
            }
            .frame(height: identityArtworkSize)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var identityArtwork: some View {
        if let app {
            SupervisorAppArtworkView(app: app, kind: .icon, height: identityArtworkSize)
        } else if let update {
            UpdateIconView(update: update, size: identityArtworkSize)
        }
    }

    private var identityArtworkSize: CGFloat {
        108
    }

    private var identitySubtitle: String {
        if let description = app?.description?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return description
        }

        return update?.status.title ?? "Status unavailable"
    }

    @ViewBuilder
    private var primaryAction: some View {
        if let update, actionAvailability(for: update).canInstall {
            Button(role: .confirm) {
                install(update)
            } label: {
                Text("Update")
                    .font(.headline)
                    .frame(width: 72, height: 20)
            }
            .buttonStyle(.borderedProminent)
            .glassEffect(.regular, in: .capsule)
            .clipShape(.capsule)
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
        } else if update?.status == .upToDate || (update == nil && app?.updateAvailable == false) {
            Text("Up to Date")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 72, height: 20)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.secondary, in: Capsule())
                .glassEffect(.regular, in: .capsule)
                .clipShape(.capsule)
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

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider()
                                .frame(height: 42)
                                .padding(.horizontal, 14)
                        }

                        VStack(spacing: 4) {
                            Text(item.title.uppercased())
                                .font(.caption)
                                .bold()
                                .lineLimit(1)

                            Text(item.value)
                                .font(.title3.bold())
                                .fontDesign(.rounded)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            if let detail = item.detail {
                                Text(detail)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(item.tint)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, 12)

            sectionDivider
        }
    }

    private var metadataItems: [SoftwareMetadataItem] {
        var items: [SoftwareMetadataItem] = []

        let installedVersion = update?.installedVersion ?? app?.installedVersion
        let latestVersion = update?.latestVersion ?? app?.latestVersion
        let hasDistinctUpdate = installedVersion != nil
            && latestVersion != nil
            && installedVersion != latestVersion

        if let installedVersion {
            items.append(SoftwareMetadataItem(
                id: hasDistinctUpdate ? "installed" : "version",
                title: hasDistinctUpdate ? "Installed" : "Version",
                value: installedVersion,
                detail: hasDistinctUpdate ? "Current version" : "Installed"
            ))
        }

        if hasDistinctUpdate, let latestVersion {
            items.append(SoftwareMetadataItem(
                id: "latest",
                title: "Available",
                value: latestVersion,
                detail: "Latest version"
            ))
        }

        if let app {
            items.append(SoftwareMetadataItem(
                id: "state",
                title: "Status",
                value: app.status.title,
                detail: "App state",
                tint: app.status.tint
            ))
        } else if let update {
            items.append(SoftwareMetadataItem(
                id: "status",
                title: "Status",
                value: update.status.shortTitle,
                detail: "Update state",
                tint: update.status.tint
            ))
        }

        if !hasDistinctUpdate, let stage = appDetails?.stage {
            items.append(SoftwareMetadataItem(
                id: "channel",
                title: "Channel",
                value: stage.capitalized,
                detail: "Release track"
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
        .padding(.horizontal, 20)
        .padding(.vertical, AppSpacing.small)
    }

    @ViewBuilder
    private var whatsNewSection: some View {
        if let update, update.showsUpdateDetails {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                nestedSectionDivider

                Text("What’s New")
                    .font(.title3.bold())
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
            .padding(.horizontal, 20)
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
                CollapsibleUpdateReleaseNotesView(
                    markdown: releaseNotes,
                    omittingLeadingHeading: update.latestVersion,
                    isExpanded: $isWhatsNewExpanded
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
            CollapsibleUpdateReleaseNotesView(
                markdown: releaseSummary,
                omittingLeadingHeading: update.latestVersion,
                isExpanded: $isWhatsNewExpanded
            )
        }
    }

    // MARK: - App Information

    @ViewBuilder
    private var aboutSection: some View {
        if let aboutText {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                nestedSectionDivider

                Text("About")
                    .font(.title2.bold())
                    .padding(.top, AppSpacing.medium)

                UpdateReleaseNotesMarkdownView(markdown: aboutText)
            }
            .padding(.horizontal, 20)
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
            VStack(alignment: .leading, spacing: 0) {
                nestedSectionDivider

                Text("Information")
                    .font(.title2.bold())
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider()
                    }

                    informationRow(row)
                }

                if !rows.isEmpty, !links.isEmpty {
                    Divider()
                }

                ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                    if index > 0 {
                        Divider()
                    }

                    informationLink(link)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, AppSpacing.medium)
        }
    }

    private func informationRow(_ row: SoftwareInformationRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
            Text(row.title)
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.medium)

            Text(row.value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func informationLink(_ link: SoftwareInformationLink) -> some View {
        Link(destination: link.url) {
            HStack(spacing: AppSpacing.medium) {
                Text(link.title)

                Spacer(minLength: AppSpacing.medium)

                Image(systemName: link.systemImage)
                    .font(.body)
            }
            .contentShape(Rectangle())
        }
        .font(.body)
        .padding(.vertical, 12)
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
            links.append(SoftwareInformationLink(
                id: "website",
                title: "Website",
                systemImage: "safari",
                url: url
            ))
        }

        if let url = validURL(appDetails?.repositoryURLString) {
            links.append(SoftwareInformationLink(
                id: "repository",
                title: "Repository",
                systemImage: "chevron.left.forwardslash.chevron.right",
                url: url
            ))
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

    private func requestLifecycleAction(_ action: HASupervisorAppLifecycleAction) {
        switch action {
        case .start:
            performLifecycleAction(action)
        case .stop, .restart:
            pendingLifecycleAction = action
        }
    }

    private func performLifecycleAction(_ action: HASupervisorAppLifecycleAction) {
        pendingLifecycleAction = nil
        guard lifecycleActionInProgress == nil, let slug = supervisorAppSlug else { return }

        lifecycleActionInProgress = action
        Task {
            do {
                let details = try await homeAssistantService.performSupervisorAppLifecycleAction(
                    settings: connectionSettings,
                    slug: slug,
                    action: action
                )
                loadedAppDetails = details

                if action == .restart {
                    try? await Task.sleep(for: .seconds(1.5))
                    if !Task.isCancelled {
                        await loadAppDetails()
                    }
                }
            } catch {
                lifecycleErrorMessage = error.localizedDescription
            }
            lifecycleActionInProgress = nil
        }
    }

    @ToolbarContentBuilder
    private var softwareActionsMenu: some ToolbarContent {
        if hasSoftwareMenuActions {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    lifecycleMenuActions
                    updateMenuActions
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
    }

    private var hasSoftwareMenuActions: Bool {
        if !lifecycleActions.isEmpty {
            return true
        }

        guard let update else { return false }
        let availability = actionAvailability(for: update)
        return availability.canSkip || availability.canClearSkipped
    }

    private var lifecycleActions: [HASupervisorAppLifecycleAction] {
        guard homeAssistantService.currentUserIsAdmin, let app else { return [] }

        switch app.status {
        case .running:
            return [.stop, .restart]
        case .stopped:
            return [.start]
        case .unknown:
            return []
        }
    }

    @ViewBuilder
    private var lifecycleMenuActions: some View {
        ForEach(lifecycleActions, id: \.self) { action in
            Button(role: action == .stop ? .destructive : nil) {
                requestLifecycleAction(action)
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
            .disabled(lifecycleActionInProgress != nil)
        }

        if !lifecycleActions.isEmpty, hasUpdateMenuActions {
            Divider()
        }
    }

    @ViewBuilder
    private var updateMenuActions: some View {
        if let update {
            let availability = actionAvailability(for: update)

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
        }
    }

    private var hasUpdateMenuActions: Bool {
        guard let update else { return false }
        let availability = actionAvailability(for: update)
        return availability.canSkip || availability.canClearSkipped
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
            .padding(.horizontal, 14)
    }

    // Section content uses a 20-point inset; extend its divider back to the
    // 14-point App Store-style page inset.
    private var nestedSectionDivider: some View {
        Divider()
            .padding(.horizontal, -6)
    }

    private func relativeDescription(for date: Date) -> String {
        SoftwareRelativeTimeFormatter.string(for: date)
    }

    private func validURL(_ value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }

    private var lifecycleConfirmationTitle: String {
        guard let pendingLifecycleAction else { return "Control App?" }
        return "\(pendingLifecycleAction.title) \(displayName)?"
    }

    private var lifecycleConfirmationMessage: String {
        switch pendingLifecycleAction {
        case .stop:
            return "\(displayName) will be unavailable until it is started again."
        case .restart:
            return "\(displayName) will be briefly unavailable while it restarts."
        case .start, .none:
            return ""
        }
    }

    private var lifecycleConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { pendingLifecycleAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingLifecycleAction = nil
                }
            }
        )
    }

    private var lifecycleErrorIsPresented: Binding<Bool> {
        Binding(
            get: { lifecycleErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    lifecycleErrorMessage = nil
                }
            }
        )
    }
}

nonisolated enum SoftwareRelativeTimeFormatter {
    static func string(for date: Date, relativeTo referenceDate: Date = Date()) -> String {
        let elapsed = max(0, referenceDate.timeIntervalSince(date))

        switch elapsed {
        case ..<60:
            return "Now"
        case ..<3_600:
            return "\(Int(elapsed / 60))m ago"
        case ..<86_400:
            return "\(Int(elapsed / 3_600))h ago"
        case ..<604_800:
            return "\(Int(elapsed / 86_400))d ago"
        case ..<2_592_000:
            return "\(Int(elapsed / 604_800))w ago"
        case ..<31_536_000:
            return "\(Int(elapsed / 2_592_000))mo ago"
        default:
            return "\(Int(elapsed / 31_536_000))y ago"
        }
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
    var detail: String?
    var tint: Color = .secondary
}

private struct SoftwareInformationRow: Identifiable {
    let id: String
    let title: String
    let value: String
}

private struct SoftwareInformationLink: Identifiable {
    let id: String
    let title: String
    let systemImage: String
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
