import SwiftUI

struct DevicesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var selectedEntity: SelectedEntity?

    var body: some View {
        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: "No Devices",
            emptySystemImage: "square.grid.2x2",
            groupingPersistenceKey: "homestead.browse.grouping",
            initialGrouping: .name,
            rowAction: { entityBox in
                selectedEntity = SelectedEntity(entityID: entityBox.entityID)
            },
            accessory: { entityBox in
                DeviceEntityStateAccessory(entityBox: entityBox)
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
