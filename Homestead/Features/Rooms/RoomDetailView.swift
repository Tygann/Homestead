import SwiftUI

struct RoomDetailView: View {
    let room: DashboardRoomSummary

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.medium) {
                ForEach(room.entityIDs, id: \.self) { entityID in
                    DashboardCardView(entityID: entityID, size: .compact)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(room.name)
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}
