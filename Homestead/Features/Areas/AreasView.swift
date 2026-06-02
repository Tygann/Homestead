import SwiftUI

struct AreasView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedSummaryKind: DashboardSummaryKind?
    private let areaCardSize = DashboardCardSize.square

    var body: some View {
        let presentation = AreasOverviewPresentation.make(from: stateStore)

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if !presentation.summaryChips.isEmpty {
                    areaSummaryChipRow(items: presentation.summaryChips)
                }

                ForEach(presentation.sections) { section in
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        if section.title != nil {
                            AreaGroupHeader(section: section)
                        }

                        CardGrid {
                            ForEach(section.areas) { area in
                                NavigationLink {
                                    AreaDetailView(area: area)
                                } label: {
                                    AreaSummaryCard(area: area)
                                }
                                .buttonStyle(.plain)
                                .cardGridSpan(areaCardSize.layoutMetadata)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .refreshable {
            await homeAssistantService.refreshStates()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedSummaryKind) { kind in
            DashboardSummaryView(kind: kind)
        }
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Areas", systemImage: "square.grid.3x3")
            }
        }
        .navigationTitle("Areas")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    private func areaSummaryChipRow(items: [AreasOverviewPresentation.SummaryChipItem]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                ForEach(items) { item in
                    Button {
                        selectedSummaryKind = item.kind
                    } label: {
                        DashboardChipView(presentation: item.presentation)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 1, for: .scrollContent)
        .accessibilityElement(children: .contain)
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
        let preferredClimateReadingEntityIDs = stateStore.preferredClimateReadingEntityIDs()
        let nonPrimaryEntityIDs = stateStore.nonPrimaryEntityIDs()
        let diagnosticEntityIDs = stateStore.diagnosticEntityIDs()

        let areas = DashboardAreaBuilder.buildAreas(
            from: entityBoxes,
            areaContextForEntityID: stateStore.areaContext(for:)
        )

        return AreasOverviewPresentation(
            sections: DashboardAreaBuilder.buildSections(from: areas),
            summaryChips: DashboardSummaryKind.areasOverviewOrder.compactMap { kind in
                DashboardSummaryProvider.makeSummary(
                    kind: kind,
                    entityBoxes: entityBoxes,
                    preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
                    nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                    diagnosticEntityIDs: diagnosticEntityIDs
                ).map { SummaryChipItem(kind: kind, presentation: $0) }
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

private struct AreaSummaryCard: View {
    let area: DashboardAreaSummary
    private let visibleDomainChips: [DashboardAreaDomainChip]

    init(area: DashboardAreaSummary) {
        self.area = area
        self.visibleDomainChips = Array(area.domainChips.prefix(3))
    }

    var body: some View {
        CardContainer(minHeight: cardContentMinHeight) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    CardIconView(systemName: area.systemImage)

                    Spacer(minLength: AppSpacing.small)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, AppSpacing.small)
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
        guard chip.isActive else {
            return .secondary
        }

        switch chip.domain {
        case .light:
            return .yellow
        case .climate, .fan:
            return .blue
        case .binarySensor, .lock, .camera:
            return .mint
        case .mediaPlayer:
            return .indigo
        case .sensor, .cover, .switch, .vacuum, .scene, .script, .automation, .other:
            return .accentColor
        }
    }

    private func iconBackground(for chip: DashboardAreaDomainChip) -> Color {
        chip.isActive ? iconColor(for: chip).opacity(0.16) : Color(.tertiarySystemGroupedBackground)
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
