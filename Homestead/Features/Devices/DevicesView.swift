import SwiftUI

struct DevicesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""
    @State private var selectedDomain: EntityDomain?
    @State private var collapsedDomains: Set<EntityDomain> = []

    var body: some View {
        List {
            ForEach(filteredEntityGroups, id: \.domain) { group in
                Section {
                    if !collapsedDomains.contains(group.domain) {
                        ForEach(group.entities) { entity in
                            DeviceEntityRow(entity: entity)
                        }
                    }
                } header: {
                    Button {
                        toggleSection(group.domain)
                    } label: {
                        HStack {
                            Label(group.domain.displayName, systemImage: group.domain.systemImage)
                            Spacer()
                            Image(systemName: collapsedDomains.contains(group.domain) ? "chevron.right" : "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                domainFilterMenu
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
    }

    private var domainFilterMenu: some View {
        Menu {
            Button {
                selectedDomain = nil
            } label: {
                Label("All", systemImage: selectedDomain == nil ? "checkmark" : "square.grid.2x2")
            }

            ForEach(availableDomains, id: \.self) { domain in
                Button {
                    selectedDomain = domain
                } label: {
                    Label(domain.displayName, systemImage: selectedDomain == domain ? "checkmark" : domain.systemImage)
                }
            }
        } label: {
            Image(systemName: selectedDomain == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter devices")
    }

    private func toggleSection(_ domain: EntityDomain) {
        if collapsedDomains.contains(domain) {
            collapsedDomains.remove(domain)
        } else {
            collapsedDomains.insert(domain)
        }
    }

    private var availableDomains: [EntityDomain] {
        stateStore.entitiesByDomain.map(\.domain)
    }

    private var filteredEntityGroups: [(domain: EntityDomain, entities: [HomeEntity])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let domainGroups = stateStore.entitiesByDomain.filter { group in
            selectedDomain == nil || group.domain == selectedDomain
        }

        guard !query.isEmpty else {
            return domainGroups
        }

        return domainGroups.compactMap { group in
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
