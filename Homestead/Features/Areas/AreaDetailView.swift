import SwiftUI

struct AreaDetailView: View {
    let area: DashboardAreaSummary

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.medium) {
                ForEach(area.entityIDs, id: \.self) { entityID in
                    DashboardCardView(entityID: entityID, size: .compact)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(area.name)
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}
