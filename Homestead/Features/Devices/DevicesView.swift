import SwiftUI

struct DevicesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedEntity: SelectedEntity?

    var body: some View {
        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: "No Devices",
            emptySystemImage: "square.grid.2x2",
            rowAction: { entityBox in
                selectedEntity = SelectedEntity(entityID: entityBox.entityID)
            },
            allowsDashboardMembershipEditing: true,
            accessory: { entityBox in
                HStack(spacing: AppSpacing.small) {
                    if dashboardConfiguration.contains(entityBox.entityID) {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("On dashboard")
                    }

                    DeviceEntityStateAccessory(entityBox: entityBox)
                }
            }
        )
        .navigationTitle("Browse")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(item: $selectedEntity) { selectedEntity in
            if let entityBox = stateStore.entityBox(for: selectedEntity.entityID) {
                EntityDetailSheet(entityBox: entityBox)
            }
        }
    }
}

private struct SelectedEntity: Identifiable {
    let entityID: String

    var id: String { entityID }
}

#if DEBUG
#Preview {
    NavigationStack {
        DevicesView()
    }
    .withPreviewEnvironment()
}
#endif
