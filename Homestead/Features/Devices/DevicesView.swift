import SwiftUI

struct DevicesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""

    var body: some View {
        List {
            ForEach(filteredEntityGroups, id: \.domain) { group in
                Section {
                    ForEach(group.entities) { entity in
                        DeviceEntityRow(entity: entity)
                    }
                } header: {
                    Label(group.domain.displayName, systemImage: group.domain.systemImage)
                }
            }
        }
        .overlay {
            if stateStore.allEntities.isEmpty {
                ContentUnavailableView("No Devices", systemImage: "square.grid.2x2")
            } else if filteredEntityGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("Devices")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
    }

    private var filteredEntityGroups: [(domain: EntityDomain, entities: [HomeEntity])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return stateStore.entitiesByDomain
        }

        return stateStore.entitiesByDomain.compactMap { group in
            let matchingEntities = group.entities.filter { entity in
                entity.displayName.localizedCaseInsensitiveContains(query) ||
                    entity.entityID.localizedCaseInsensitiveContains(query) ||
                    entity.state.localizedCaseInsensitiveContains(query)
            }

            guard !matchingEntities.isEmpty else {
                return nil
            }

            return (domain: group.domain, entities: matchingEntities)
        }
    }
}

private struct DeviceEntityRow: View {
    let entity: HomeEntity

    var body: some View {
        Label {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(entity.displayName)
                        .font(.headline)
                    Text(entity.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: AppSpacing.medium)

                Text(entity.state.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entity.isAvailable ? .secondary : Color.red)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: entity.iconName)
                .foregroundStyle(entity.isAvailable ? Color.accentColor : Color.secondary)
        }
        .padding(.vertical, AppSpacing.xSmall)
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
