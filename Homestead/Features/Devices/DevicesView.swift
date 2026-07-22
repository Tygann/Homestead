import SwiftUI

struct DevicesView: View {
    var body: some View {
        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: "No Devices",
            emptySystemImage: "square.grid.2x2",
            groupingPersistenceKey: "homestead.browse.grouping",
            initialGrouping: .name,
            rowAction: { _ in },
            rowDestination: { entityBox in
                AnyView(EntityDetailDestinationView(destination: EntityDetailDestination(
                    entityID: entityBox.entityID
                )))
            },
            accessory: { entityBox in
                DeviceEntityStateAccessory(entityBox: entityBox)
            }
        )
        .navigationTitle("Browse")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DevicesView()
    }
    .withPreviewEnvironment()
}
#endif
