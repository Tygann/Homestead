import SwiftUI

struct DashboardEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    var body: some View {
        NavigationStack {
            List {
                selectedSection
                availableSection
            }
            .navigationTitle("Edit Home")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    EditButton()

                    Button("Reset") {
                        dashboardConfiguration.reset(using: stateStore.allEntities)
                    }
                    .disabled(stateStore.allEntities.isEmpty)
                }
            }
        }
    }

    private var selectedEntities: [HomeEntity] {
        dashboardConfiguration
            .visibleEntityIDs(from: stateStore.allEntities)
            .compactMap { stateStore.entity(for: $0) }
    }

    private var selectedSection: some View {
        Section {
            if selectedEntities.isEmpty {
                Text("No cards selected")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(selectedEntities) { entity in
                    DashboardEntityRow(entity: entity, isSelected: true) {
                        dashboardConfiguration.remove(entity.entityID)
                    }
                }
                .onMove { source, destination in
                    dashboardConfiguration.move(from: source, to: destination)
                }
            }
        } header: {
            Text("Home Cards")
        } footer: {
            Text("Drag selected cards to change the order on the Home tab.")
        }
    }

    private var availableSection: some View {
        Section {
            ForEach(stateStore.entitiesByDomain, id: \.domain) { group in
                DisclosureGroup {
                    ForEach(group.entities) { entity in
                        DashboardEntityRow(
                            entity: entity,
                            isSelected: dashboardConfiguration.contains(entity.entityID)
                        ) {
                            dashboardConfiguration.setEntity(
                                entity.entityID,
                                isVisible: !dashboardConfiguration.contains(entity.entityID)
                            )
                        }
                    }
                } label: {
                    Label(group.domain.displayName, systemImage: group.domain.systemImage)
                }
            }
        } header: {
            Text("Available Entities")
        }
    }
}

private struct DashboardEntityRow: View {
    let entity: HomeEntity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(entity.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(entity.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : entity.iconName)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    DashboardEditView()
        .withPreviewEnvironment()
}
#endif
