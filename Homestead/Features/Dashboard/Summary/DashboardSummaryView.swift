import SwiftUI

struct DashboardSummaryView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HAStateStore.self) private var stateStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedEntityDetailRoute: DashboardEntityDetailRoute?
    @State private var securityActivityRows: [HAActivityRow] = []
    @State private var isLoadingSecurityActivity = false
    @State private var securityActivityErrorMessage: String?
    @State private var lastSecurityActivityLoadAt: Date?
    @Namespace private var cardTransitionNamespace

    let kind: DashboardSummaryKind
    let titleOverride: String?
    let iconNameOverride: String?

    init(
        kind: DashboardSummaryKind,
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) {
        self.kind = kind
        self.titleOverride = titleOverride
        self.iconNameOverride = iconNameOverride
    }

    var body: some View {
        let detail = DashboardSummaryProvider.makeDetail(
            kind: kind,
            entityBoxes: stateStore.allEntityBoxes(),
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride,
            membershipContext: stateStore.dashboardSummaryMembershipContext(),
            areaNameForEntityID: stateStore.areaName(for:),
            areaContextForEntityID: stateStore.areaContext(for:)
        )

        Group {
            if let detail {
                summaryContent(detail: detail)
            } else {
                ContentUnavailableView("No Summary Available", systemImage: kind.systemImage)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(detail?.summary.title ?? kind.title)
        .toolbarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedEntityDetailRoute) { route in
            if let entityBox = stateStore.entityBox(for: route.entityID) {
                EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation)
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: cardTransitionNamespace))
            } else {
                ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: cardTransitionNamespace))
            }
        }
        .task(id: securityActivityTaskID(for: detail)) {
            guard kind == .security, detail != nil else { return }
            await loadSecurityActivity(entityIDs: securityActivityEntityIDs())
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard kind == .security,
                  newPhase == .active,
                  detail != nil,
                  shouldRefreshSecurityActivity else {
                return
            }

            Task {
                await refreshSecurityActivity(entityIDs: securityActivityEntityIDs())
            }
        }
    }

    @ViewBuilder
    private func summaryContent(detail: DashboardSummaryDetailPresentation) -> some View {
        if kind == .security {
            securitySummaryContent(detail: detail)
        } else {
            devicesContent(detail: detail)
        }
    }

    @ViewBuilder
    private func securitySummaryContent(detail: DashboardSummaryDetailPresentation) -> some View {
        let entityIDs = securityActivityEntityIDs()
        let activityPresentation = HALogbookPresentation.makeSecurityActivity(
            rows: securityActivityRows,
            entityIDs: entityIDs
        )
        let peopleByEntityID = Dictionary(
            uniqueKeysWithValues: stateStore.presenceRecords()
                .filter(\.isPerson)
                .map { ($0.entityID, $0) }
        )

        if horizontalSizeClass == .regular {
            HStack(alignment: .top, spacing: 0) {
                devicesContent(detail: detail)

                SecuritySummaryActivityView(
                    presentation: activityPresentation,
                    isLoading: isLoadingSecurityActivity,
                    errorMessage: securityActivityErrorMessage,
                    peopleByEntityID: peopleByEntityID,
                    transitionNamespace: cardTransitionNamespace,
                    refresh: { await refreshSecurityActivity(entityIDs: entityIDs) },
                    openEntity: openActivityEntity
                )
                .frame(width: 390)
            }
        } else {
            SecuritySummaryCompactView(
                devices: devicesContent(detail: detail),
                activity: SecuritySummaryActivityView(
                    presentation: activityPresentation,
                    isLoading: isLoadingSecurityActivity,
                    errorMessage: securityActivityErrorMessage,
                    peopleByEntityID: peopleByEntityID,
                    transitionNamespace: cardTransitionNamespace,
                    refresh: { await refreshSecurityActivity(entityIDs: entityIDs) },
                    openEntity: openActivityEntity
                )
            )
        }
    }

    private func devicesContent(detail: DashboardSummaryDetailPresentation) -> some View {
        let areasByID = Dictionary(uniqueKeysWithValues: DashboardAreaBuilder.buildAreas(
            from: stateStore.allEntityBoxes(),
            areaContextForEntityID: stateStore.areaContext(for:)
        ).compactMap { area in
            area.areaID.map { ($0, area) }
        })

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                ForEach(detail.groups) { group in
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Group {
                            if let systemImage = group.systemImage {
                                Label(group.title, systemImage: systemImage)
                            } else {
                                Text(group.title)
                            }
                        }
                        .font(.title3.weight(.semibold))

                        ForEach(group.sections) { section in
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                if let title = section.title {
                                    summaryAreaHeader(
                                        title: title,
                                        area: section.areaID.flatMap { areasByID[$0] }
                                    )
                                }

                                CardGrid {
                                    ForEach(section.items) { item in
                                        let entityBox = stateStore.entityBox(for: item.entityID)
                                        let size = cardSize(for: entityBox)

                                        DashboardCardView(
                                            entityID: item.entityID,
                                            size: size,
                                            featureVisibility: featureVisibility(for: entityBox, size: size),
                                            contextualAreaName: section.title,
                                            openDetails: {
                                                selectedEntityDetailRoute = DashboardEntityDetailRoute(
                                                    entityID: item.entityID,
                                                    sourceID: cardTransitionID(for: item)
                                                )
                                            }
                                        )
                                        .cardGridSpan(size.layoutMetadata)
                                        .matchedTransitionSource(id: cardTransitionID(for: item), in: cardTransitionNamespace)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func summaryAreaHeader(title: String, area: DashboardAreaSummary?) -> some View {
        if let area {
            NavigationLink {
                AreaDetailView(area: area)
            } label: {
                HStack(spacing: AppSpacing.small) {
                    Text(title)
                        .font(.headline)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func securityActivityEntityIDs() -> Set<String> {
        HomeAssistantSummaryClassifier.securityActivityEntityIDs(
            from: stateStore.allEntityBoxes(),
            context: stateStore.dashboardSummaryMembershipContext()
        )
    }

    private func securityActivityTaskID(for detail: DashboardSummaryDetailPresentation?) -> String {
        guard kind == .security, detail != nil else { return "inactive" }
        return [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            securityActivityEntityIDs().sorted().joined(separator: ",")
        ].joined(separator: "|")
    }

    private var shouldRefreshSecurityActivity: Bool {
        guard let lastSecurityActivityLoadAt else { return true }
        return Date().timeIntervalSince(lastSecurityActivityLoadAt) >= 60
    }

    private func loadSecurityActivity(entityIDs: Set<String>) async {
        let cacheKey = securityActivityCacheKey(entityIDs: entityIDs)
        if let cached = await HASecurityActivityCache.shared.snapshot(for: cacheKey) {
            securityActivityRows = cached.rows
            lastSecurityActivityLoadAt = cached.loadedAt

            guard Date().timeIntervalSince(cached.loadedAt) >= 60 else {
                return
            }
        }

        await refreshSecurityActivity(entityIDs: entityIDs)
    }

    private func refreshSecurityActivity(entityIDs: Set<String>) async {
        guard !entityIDs.isEmpty, !isLoadingSecurityActivity else { return }

        isLoadingSecurityActivity = true
        securityActivityErrorMessage = nil
        defer { isLoadingSecurityActivity = false }

        let endDate = Date()
        let request = HALogbookRequest(
            startDate: endDate.addingTimeInterval(-86_400),
            endDate: endDate
        )

        do {
            let rows = try await homeAssistantService.fetchLogbook(
                settings: connectionSettings,
                request: request
            )
            securityActivityRows = Array(
                rows
                    .filter { row in
                        row.entityID.map(entityIDs.contains) == true
                    }
                    .sorted { lhs, rhs in
                        lhs.occurredAt > rhs.occurredAt
                    }
                    .prefix(50)
            )
            lastSecurityActivityLoadAt = endDate
            await HASecurityActivityCache.shared.store(
                HASecurityActivityCacheSnapshot(
                    rows: securityActivityRows,
                    loadedAt: endDate
                ),
                for: securityActivityCacheKey(entityIDs: entityIDs)
            )
        } catch {
            securityActivityErrorMessage = "Couldn't load activity from Home Assistant."
        }
    }

    private func securityActivityCacheKey(entityIDs: Set<String>) -> String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.activityCacheUserIdentifier,
            entityIDs.sorted().joined(separator: ",")
        ].joined(separator: "|")
    }

    private func openActivityEntity(_ row: HAActivityRow) {
        guard let entityID = row.entityID else { return }
        guard stateStore.entityBox(for: entityID) != nil else { return }
        selectedEntityDetailRoute = DashboardEntityDetailRoute(
            entityID: entityID,
            sourceID: securityActivityTransitionID(for: row)
        )
    }

    @MainActor
    private func cardSize(for entityBox: HAEntityState?) -> DashboardCardSize {
        guard let entityBox else { return .compact }
        return DashboardCardSize.defaultGeneratedSize(entityBox: entityBox)
    }

    @MainActor
    private func featureVisibility(
        for entityBox: HAEntityState?,
        size: DashboardCardSize
    ) -> DashboardCardFeatureVisibility {
        guard let entityBox else { return .automatic }
        return DashboardCardSize.defaultGeneratedFeatureVisibility(entityBox: entityBox, size: size)
    }

    private func cardTransitionID(for item: DashboardSummaryEntityPresentation) -> String {
        "summary-\(kind.rawValue)-card-\(item.entityID)"
    }

    private func securityActivityTransitionID(for row: HAActivityRow) -> String {
        "summary-security-activity-\(row.id)"
    }
}

private enum SecuritySummaryTab: String, CaseIterable, Identifiable {
    case devices
    case activity

    var id: Self { self }

    var title: String {
        rawValue.capitalized
    }
}

private struct SecuritySummaryCompactView<Devices: View, Activity: View>: View {
    @State private var selectedTab: SecuritySummaryTab = .devices

    let devices: Devices
    let activity: Activity

    var body: some View {
        Group {
            switch selectedTab {
            case .devices:
                devices
            case .activity:
                activity
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Picker("Security View", selection: $selectedTab) {
                ForEach(SecuritySummaryTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.xLarge)
            .padding(.vertical, AppSpacing.medium)
            .background(.bar)
        }
    }
}

private struct SecuritySummaryActivityView: View {
    let presentation: HALogbookPresentation
    let isLoading: Bool
    let errorMessage: String?
    let peopleByEntityID: [String: HAPresenceRecord]
    let transitionNamespace: Namespace.ID
    let refresh: () async -> Void
    let openEntity: (HAActivityRow) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(spacing: AppSpacing.small) {
                    Text("Activity")
                        .font(.title2.weight(.bold))

                    if isLoading, !presentation.sections.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let errorMessage, presentation.sections.isEmpty {
                    ContentUnavailableView(
                        "Activity Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if isLoading, presentation.sections.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if presentation.sections.isEmpty {
                    ContentUnavailableView(
                        "No Recent Activity",
                        systemImage: "clock",
                        description: Text("Security activity from the last 24 hours will appear here.")
                    )
                } else {
                    if errorMessage != nil {
                        Label("Showing saved activity. Pull to refresh.", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    CardContainer(minHeight: 0, padding: AppSpacing.large) {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                            ForEach(Array(presentation.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                                LazyVStack(alignment: .leading, spacing: AppSpacing.medium) {
                                    Text(section.title)
                                        .font(.headline)

                                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { rowIndex, row in
                                        if rowIndex > 0 {
                                            Divider()
                                        }

                                        activityRow(row, personRecord: row.entityID.flatMap { peopleByEntityID[$0] })
                                    }
                                }

                                if sectionIndex < presentation.sections.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refresh()
        }
    }

    @ViewBuilder
    private func activityRow(_ row: HAActivityRow, personRecord: HAPresenceRecord?) -> some View {
        if let entityID = row.entityID {
            Button {
                openEntity(row)
            } label: {
                SecurityActivityRowView(
                    row: row,
                    personRecord: personRecord
                )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(
                id: "summary-security-activity-\(row.id)",
                in: transitionNamespace
            )
            .accessibilityHint("Opens \(entityID) details")
        } else {
            SecurityActivityRowView(row: row, personRecord: nil)
        }
    }
}

private struct SecurityActivityRowView: View {
    let row: HAActivityRow
    let personRecord: HAPresenceRecord?

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            activityIcon

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                narrativeText
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: AppSpacing.xSmall) {
                    Text(row.occurredAt.formatted(date: .omitted, time: .standard))
                    Text("-")
                    Text(row.occurredAt.formatted(.relative(presentation: .named, unitsStyle: .wide)))

                    if let attributionName = row.attributionName {
                        Text("-")
                        Text(attributionName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(row.occurredAt.formatted(date: .abbreviated, time: .standard))
    }

    private var narrativeText: Text {
        guard row.message != "Updated" else {
            return Text(row.title).foregroundStyle(Color.accentColor)
        }

        let base = Text("\(Text(row.title).foregroundStyle(Color.accentColor)) \(Text(row.message).foregroundStyle(Color.primary))")
        guard let triggerText = row.triggerText else {
            return base
        }

        return Text("\(base) \(Text(triggerText).foregroundStyle(Color.primary))")
    }

    private var accessibilityLabel: String {
        [
            row.message == "Updated" ? row.title : "\(row.title) \(row.message)",
            row.triggerText,
            row.attributionName.map { "by \($0)" }
        ]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    @ViewBuilder
    private var activityIcon: some View {
        if let personRecord {
            PeoplePresenceAvatarView(record: personRecord, size: 32)
        } else {
            Image(systemName: row.iconSystemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
        }
    }
}
