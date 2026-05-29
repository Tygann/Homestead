import SwiftUI

struct AreasView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    private let areaCardSize = DashboardCardSize.square

    private var areas: [DashboardAreaSummary] {
        DashboardAreaBuilder.buildAreas(
            from: stateStore.allEntityBoxes(),
            areaNameForEntityID: stateStore.areaName(for:)
        )
    }

    var body: some View {
        ScrollView {
            CardGrid {
                ForEach(areas) { area in
                    NavigationLink {
                        AreaDetailView(area: area)
                    } label: {
                        AreaSummaryCard(area: area)
                    }
                    .buttonStyle(.plain)
                    .cardGridSpan(areaCardSize.layoutMetadata)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .refreshable {
            await homeAssistantService.refreshStates()
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Areas", systemImage: "square.grid.3x3")
            }
        }
        .navigationTitle("Areas")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}

private struct AreaSummaryCard: View {
    let area: DashboardAreaSummary

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

                AreaDomainStrip(domains: Array(area.topDomains.prefix(3)))
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
