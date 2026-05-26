import SwiftUI

struct RoomsView: View {
    @Environment(HAStateStore.self) private var stateStore

    private var rooms: [DashboardRoomSummary] {
        DashboardRoomBuilder.buildRooms(from: stateStore.allEntityBoxes())
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.large) {
                ForEach(rooms) { room in
                    NavigationLink {
                        RoomDetailView(room: room)
                    } label: {
                        RoomSummaryCard(room: room)
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
                ContentUnavailableView("No Rooms", systemImage: "square.grid.3x3")
            }
        }
        .navigationTitle("Rooms")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}

private struct RoomSummaryCard: View {
    let room: DashboardRoomSummary

    var body: some View {
        CardContainer {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                CardIconView(systemName: room.systemImage)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(room.name)
                        .font(.headline)

                    Text(room.subtitle)
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
        RoomsView()
    }
    .withPreviewEnvironment()
}
#endif
