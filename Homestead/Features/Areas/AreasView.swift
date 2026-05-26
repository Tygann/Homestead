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

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
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
