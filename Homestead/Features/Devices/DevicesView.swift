import SwiftUI

struct DevicesView: View {
    @Environment(HAStateStore.self) private var stateStore

    var body: some View {
        List {
            ForEach(stateStore.allEntities) { entity in
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(entity.displayName)
                            .font(.headline)
                        Text(entity.entityID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: entity.iconName)
                        .foregroundStyle(entity.isAvailable ? Color.accentColor : Color.secondary)
                }
                .padding(.vertical, AppSpacing.xSmall)
            }
        }
        .overlay {
            if stateStore.allEntities.isEmpty {
                ContentUnavailableView("No Devices", systemImage: "square.grid.2x2")
            }
        }
        .navigationTitle("Devices")
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
