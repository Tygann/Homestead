import SwiftUI

struct DashboardSummaryView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HAStateStore.self) private var stateStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedEntityDetailRoute: DashboardEntityDetailRoute?
    @State private var selectedSecurityTab: SecuritySummaryTab = .devices
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
            guard kind == .security, let detail else { return }
            await refreshSecurityActivity(entityIDs: securityActivityEntityIDs())
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard kind == .security,
                  newPhase == .active,
                  let detail,
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

        if horizontalSizeClass == .regular {
            HStack(alignment: .top, spacing: 0) {
                devicesContent(detail: detail)

                SecuritySummaryActivityView(
                    presentation: activityPresentation,
                    isLoading: isLoadingSecurityActivity,
                    errorMessage: securityActivityErrorMessage,
                    transitionNamespace: cardTransitionNamespace,
                    refresh: { await refreshSecurityActivity(entityIDs: entityIDs) },
                    openEntity: openActivityEntity
                )
                .frame(width: 390)
            }
        } else {
            Group {
                switch selectedSecurityTab {
                case .devices:
                    devicesContent(detail: detail)
                case .activity:
                    SecuritySummaryActivityView(
                        presentation: activityPresentation,
                        isLoading: isLoadingSecurityActivity,
                        errorMessage: securityActivityErrorMessage,
                        transitionNamespace: cardTransitionNamespace,
                        refresh: { await refreshSecurityActivity(entityIDs: entityIDs) },
                        openEntity: openActivityEntity
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Picker("Security View", selection: $selectedSecurityTab) {
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

    private func devicesContent(detail: DashboardSummaryDetailPresentation) -> some View {
        let areasByID = Dictionary(uniqueKeysWithValues: DashboardAreaBuilder.buildAreas(
            from: stateStore.allEntityBoxes(),
            areaContextForEntityID: stateStore.areaContext(for:)
        ).compactMap { area in
            area.areaID.map { ($0, area) }
        })

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                DashboardSummaryHeader(presentation: detail.summary)

                ForEach(detail.groups) { group in
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Label(group.title, systemImage: group.systemImage)
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
        guard kind == .security, let detail else { return "inactive" }
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
        } catch {
            securityActivityErrorMessage = "Couldn't load activity from Home Assistant."
        }
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

private struct SecuritySummaryActivityView: View {
    let presentation: HALogbookPresentation
    let isLoading: Bool
    let errorMessage: String?
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
                        VStack(alignment: .leading, spacing: AppSpacing.large) {
                            ForEach(Array(presentation.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                    Text(section.title)
                                        .font(.headline)

                                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { rowIndex, row in
                                        if rowIndex > 0 {
                                            Divider()
                                        }

                                        activityRow(row)
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
    private func activityRow(_ row: HAActivityRow) -> some View {
        if let entityID = row.entityID {
            Button {
                openEntity(row)
            } label: {
                HAActivityRowView(row: row, showsDetailText: false, showsRelativeTime: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(
                id: "summary-security-activity-\(row.id)",
                in: transitionNamespace
            )
            .accessibilityHint("Opens \(entityID) details")
        } else {
            HAActivityRowView(row: row, showsDetailText: false, showsRelativeTime: true)
        }
    }
}

private struct DashboardSummaryHeader: View {
    let presentation: DashboardChipPresentation

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: presentation.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(presentation.value)
                    .font(.headline)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.value)
    }

    private var iconColor: Color {
        guard presentation.isAvailable else { return .red }
        return presentation.isActive ? .accentColor : .secondary
    }

    private var valueColor: Color {
        guard presentation.isAvailable else { return .red }
        return presentation.isActive ? .primary : .secondary
    }

    private var iconBackground: Color {
        guard presentation.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }
}
