import SwiftUI

struct AreasView: View {
    @Environment(HAStateStore.self) private var stateStore

    private var areas: [DashboardAreaSummary] {
        DashboardAreaBuilder.buildAreas(
            from: stateStore.allEntityBoxes(),
            areaNameForEntityID: stateStore.areaName(for:)
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.large) {
                ForEach(areas) { area in
                    NavigationLink {
                        AreaDetailView(area: area)
                    } label: {
                        AreaSummaryCard(area: area)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
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
        CardContainer {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                CardIconView(systemName: area.systemImage)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(area.name)
                        .font(.headline)

                    Text(area.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: AppSpacing.medium)

                AreaDomainStrip(domains: Array(area.topDomains.prefix(3)))

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
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
