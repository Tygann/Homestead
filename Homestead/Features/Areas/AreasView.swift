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

                CardGrid {
                    ForEach(presentation.areas) { area in
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

    let areas: [DashboardAreaSummary]
    let summaryChips: [SummaryChipItem]

    @MainActor
    static func make(from stateStore: HAStateStore) -> AreasOverviewPresentation {
        let entityBoxes = stateStore.allEntityBoxes()
        let preferredClimateReadingEntityIDs = stateStore.preferredClimateReadingEntityIDs()
        let nonPrimaryEntityIDs = stateStore.nonPrimaryEntityIDs()
        let diagnosticEntityIDs = stateStore.diagnosticEntityIDs()

        return AreasOverviewPresentation(
            areas: DashboardAreaBuilder.buildAreas(
                from: entityBoxes,
                areaNameForEntityID: stateStore.areaName(for:)
            ),
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

private struct AreaSummaryCard: View {
    let area: DashboardAreaSummary
    private let visibleDomains: [EntityDomain]

    init(area: DashboardAreaSummary) {
        self.area = area
        self.visibleDomains = Array(area.topDomains.prefix(3))
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

                    Text(area.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                AreaDomainStrip(domains: visibleDomains)
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
    let domains: [EntityDomain]

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            ForEach(domains, id: \.self) { domain in
                Image(systemName: domain.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                    .accessibilityLabel(domain.displayName)
            }
        }
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
