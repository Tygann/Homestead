import SwiftUI

struct AreasView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Namespace private var areaTransitionNamespace
    @Namespace private var summaryTransitionNamespace
    private let areaCardSize = DashboardCardSize.square

    var body: some View {
        let presentation = AreasOverviewPresentation.make(from: stateStore)

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if !stateStore.hasLoadedInitialSnapshot {
                    AreasRestoringSnapshotView()
                } else {
                    if !presentation.summaryChips.isEmpty {
                        areaSummaryChipRow(items: presentation.summaryChips)
                    }

                    areaSections(presentation.sections)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .refreshable {
            await homeAssistantService.refreshStates()
        }
        .homesteadWallpaperBackground()
        .overlay {
            if showsInitialSnapshotFailure {
                ContentUnavailableView {
                    Label("Unable to Load Areas", systemImage: homeAssistantService.connectionStatus.systemImage)
                } description: {
                    Text(homeAssistantService.lastErrorMessage.map(HAConnectionIssuePresentation.fallbackMessage(forRawMessage:)) ?? "Check your connection settings and try again.")
                } actions: {
                    Button("Reconnect", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if stateStore.hasLoadedInitialSnapshot && !stateStore.hasEntities {
                ContentUnavailableView("No Areas", systemImage: "square.grid.3x3")
            }
        }
        .navigationTitle("Areas")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SettingsAccountButton()
            }
        }
    }

    private var showsInitialSnapshotFailure: Bool {
        guard !stateStore.hasLoadedInitialSnapshot,
              homeAssistantService.hasCompletedInitialCacheLoad,
              !homeAssistantService.isLoadingCachedStates,
              case .failed = homeAssistantService.connectionStatus else {
            return false
        }

        return true
    }

    private func areaSections(_ sections: [DashboardAreaSection]) -> some View {
        ForEach(sections) { section in
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                if section.title != nil {
                    AreaGroupHeader(section: section)
                }

                CardGrid {
                    ForEach(section.areas) { area in
                        NavigationLink {
                            AreaDetailView(area: area)
                                .navigationTransition(.zoom(sourceID: areaTransitionID(for: area), in: areaTransitionNamespace))
                        } label: {
                            AreaSummaryCard(area: area)
                                .matchedTransitionSource(id: areaTransitionID(for: area), in: areaTransitionNamespace)
                        }
                        .buttonStyle(.plain)
                        .cardGridSpan(areaCardSize.layoutMetadata)
                    }
                }
            }
        }
    }

    private func areaSummaryChipRow(items: [AreasOverviewPresentation.SummaryChipItem]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                ForEach(items) { item in
                    NavigationLink {
                        DashboardSummaryView(kind: item.kind)
                            .navigationTransition(.zoom(sourceID: summaryTransitionID(for: item), in: summaryTransitionNamespace))
                    } label: {
                        DashboardChipView(presentation: item.presentation)
                            .matchedTransitionSource(id: summaryTransitionID(for: item), in: summaryTransitionNamespace)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -AppSpacing.large)
        .accessibilityElement(children: .contain)
    }

    private func summaryTransitionID(for item: AreasOverviewPresentation.SummaryChipItem) -> String {
        "areas-summary-\(item.id.rawValue)"
    }

    private func areaTransitionID(for area: DashboardAreaSummary) -> String {
        "area-\(area.id)"
    }
}

private struct AreasOverviewPresentation {
    struct SummaryChipItem: Identifiable {
        let kind: DashboardSummaryKind
        let presentation: DashboardChipPresentation

        var id: DashboardSummaryKind { kind }
    }

    let sections: [DashboardAreaSection]
    let summaryChips: [SummaryChipItem]

    @MainActor
    static func make(from stateStore: HAStateStore) -> AreasOverviewPresentation {
        let entityBoxes = stateStore.allEntityBoxes()
        let membershipContext = stateStore.dashboardSummaryMembershipContext()
        let summaryPresentations = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.areasOverviewOrder,
            entityBoxes: entityBoxes,
            membershipContext: membershipContext
        )

        let areas = DashboardAreaBuilder.buildAreas(
            from: entityBoxes,
            areaContextForEntityID: stateStore.areaContext(for:)
        )

        return AreasOverviewPresentation(
            sections: DashboardAreaBuilder.buildSections(from: areas),
            summaryChips: DashboardSummaryKind.areasOverviewOrder.compactMap { kind in
                summaryPresentations[kind].map { SummaryChipItem(kind: kind, presentation: $0) }
            }
        )
    }
}

private struct AreaGroupHeader: View {
    let section: DashboardAreaSection

    var body: some View {
        Text(section.title ?? "")
            .font(.title3.weight(.semibold))
        .accessibilityElement(children: .combine)
    }
}

private struct AreasRestoringSnapshotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.small) {
                ForEach(0..<4, id: \.self) { index in
                    AreasSkeletonChip(width: chipWidth(at: index))
                }
            }
            .accessibilityHidden(true)

            CardGrid {
                ForEach(0..<6, id: \.self) { _ in
                    AreaSkeletonCard()
                        .cardGridSpan(DashboardCardSize.square.layoutMetadata)
                }
            }
        }
        .opacity(skeletonOpacity)
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
        .task {
            guard !reduceMotion else {
                isPulsing = false
                return
            }

            isPulsing = true
        }
        .accessibilityLabel("Restoring areas")
    }

    private var skeletonOpacity: Double {
        reduceMotion ? 0.72 : (isPulsing ? 0.46 : 0.72)
    }

    private func chipWidth(at index: Int) -> CGFloat {
        [92, 104, 86, 112][index % 4]
    }
}

private struct AreasSkeletonChip: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
            .frame(width: width, height: 36)
    }
}

private struct AreaSkeletonCard: View {
    var body: some View {
        CardContainer(minHeight: cardContentMinHeight) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    skeletonLine(width: 104, height: 14)
                    skeletonLine(width: 72, height: 12)
                }

                Spacer(minLength: 0)

                HStack(spacing: AppSpacing.xSmall) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }

    private var cardContentMinHeight: CGFloat {
        DashboardCardSize.square.contentMinHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
            .frame(width: width, height: height)
    }
}

private struct AreaSummaryCard: View {
    let area: DashboardAreaSummary
    private let visibleDomainChips: [DashboardAreaDomainChip]

    init(area: DashboardAreaSummary) {
        self.area = area
        self.visibleDomainChips = area.domainChips.filter(\.isActive)
    }

    var body: some View {
        CardContainer(minHeight: cardContentMinHeight) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    CardIconView(icon: area.resolvedIcon)

                    Spacer(minLength: AppSpacing.small)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(area.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                AreaDomainStrip(chips: visibleDomainChips)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var cardContentMinHeight: CGFloat {
        DashboardCardSize.square.contentMinHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }
}

private struct AreaDomainStrip: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let chips: [DashboardAreaDomainChip]

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            ForEach(chips, id: \.self) { chip in
                Image(systemName: chip.domain.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor(for: chip))
                    .frame(width: 24, height: 24)
                    .background(iconBackground(for: chip), in: Circle())
                    .accessibilityLabel(chip.domain.displayName)
                    .accessibilityValue(chip.isActive ? "Active" : "Idle")
            }
        }
    }

    private func iconColor(for chip: DashboardAreaDomainChip) -> Color {
        switch chip.domain {
        case .light:
            return .yellow
        case .climate, .fan:
            return .blue
        case .binarySensor, .lock, .camera:
            return .mint
        case .mediaPlayer:
            return .indigo
        default:
            return .accentColor
        }
    }

    private func iconBackground(for chip: DashboardAreaDomainChip) -> AnyShapeStyle {
        if isWallpaperSurfaceActive {
            return HomesteadSurfaceStyle.cardBackground(isWallpaperActive: true)
        }

        return AnyShapeStyle(iconColor(for: chip).opacity(0.16))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AreasView()
    }
    .withPreviewEnvironment()
}
#endif
