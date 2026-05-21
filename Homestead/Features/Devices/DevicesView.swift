import SwiftUI

struct DevicesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""
    @State private var grouping: DevicesGrouping = .device
    @State private var collapsedGroups: Set<String> = []

    var body: some View {
        let groups = filteredEntityGroups

        List {
            ForEach(groups) { group in
                Section {
                    if !collapsedGroups.contains(group.id) {
                        ForEach(group.entityIDs, id: \.self) { entityID in
                            if let entityBox = stateStore.entityBox(for: entityID) {
                                DeviceEntityRow(
                                    entityBox: entityBox,
                                    displayNameOverride: displayNameOverride(for: entityID)
                                )
                            }
                        }
                    }
                } header: {
                    Button {
                        toggleSection(group.id)
                    } label: {
                        HStack {
                            Label(group.title, systemImage: group.systemImage)
                            Spacer()
                            Image(systemName: collapsedGroups.contains(group.id) ? "chevron.right" : "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Devices", systemImage: "square.grid.2x2")
            } else if groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("Devices")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                groupingMenu
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(DevicesGrouping.allCases, id: \.self) { option in
                Button {
                    grouping = option
                    collapsedGroups.removeAll()
                } label: {
                    Label(option.displayName, systemImage: grouping == option ? "checkmark" : option.systemImage)
                }
            }
        } label: {
            Image(systemName: "square.3.layers.3d")
        }
        .accessibilityLabel("Group devices")
    }

    private func toggleSection(_ groupID: String) {
        if collapsedGroups.contains(groupID) {
            collapsedGroups.remove(groupID)
        } else {
            collapsedGroups.insert(groupID)
        }
    }

    private func displayNameOverride(for entityID: String) -> String? {
        guard grouping == .device else { return nil }
        return stateStore.displayNameForDeviceGroupedEntity(entityID: entityID)
    }

    private var filteredEntityGroups: [DevicesEntityGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = unfilteredEntityGroups

        guard !query.isEmpty else {
            return groups
        }

        return groups.compactMap { group in
            let matchingEntityIDs = group.entityIDs.filter { entityID in
                guard let entity = stateStore.entityBox(for: entityID)?.homeEntity else {
                    return false
                }
                let displayName = displayNameOverride(for: entityID) ?? entity.displayName

                return displayName.localizedCaseInsensitiveContains(query) ||
                    group.title.localizedCaseInsensitiveContains(query) ||
                    entity.entityID.localizedCaseInsensitiveContains(query) ||
                    entity.state.localizedCaseInsensitiveContains(query)
            }

            guard !matchingEntityIDs.isEmpty else {
                return nil
            }

            return DevicesEntityGroup(
                id: group.id,
                title: group.title,
                systemImage: group.systemImage,
                entityIDs: matchingEntityIDs
            )
        }
    }

    private var unfilteredEntityGroups: [DevicesEntityGroup] {
        switch grouping {
        case .device:
            if !stateStore.entityIDGroupsByDevice.isEmpty {
                return stateStore.entityIDGroupsByDevice.map { group in
                    DevicesEntityGroup(
                        id: "device-\(group.id)",
                        title: group.title,
                        systemImage: "laptopcomputer.and.iphone",
                        entityIDs: group.entityIDs
                    )
                }
            }

            fallthrough
        case .type:
            return stateStore.entityIDGroupsByDomain.map { group in
                DevicesEntityGroup(
                    id: "type-\(group.domain.rawValue)",
                    title: group.domain.displayName,
                    systemImage: group.domain.systemImage,
                    entityIDs: group.entityIDs
                )
            }
        }
    }
}

private enum DevicesGrouping: CaseIterable {
    case device
    case type

    var displayName: String {
        switch self {
        case .device:
            "Device"
        case .type:
            "Type"
        }
    }

    var systemImage: String {
        switch self {
        case .device:
            "laptopcomputer.and.iphone"
        case .type:
            "square.grid.2x2"
        }
    }
}

private struct DevicesEntityGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let entityIDs: [String]
}

private struct DeviceEntityRow: View {
    let entityBox: HAEntityState
    var displayNameOverride: String?

    var body: some View {
        let entity = entityBox.homeEntity

        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(displayNameOverride ?? entity.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(entity.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(1)

                Spacer(minLength: AppSpacing.medium)

                if let detailText {
                    DeviceEntityDetailSlot(
                        detailText: detailText,
                        isAvailable: entity.isAvailable
                    )
                }
            }
            .frame(minHeight: 48)
        } icon: {
            Image(systemName: entity.iconName)
                .foregroundStyle(entity.isAvailable ? Color.accentColor : Color.secondary)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private var detailText: String? {
        let entity = entityBox.homeEntity

        guard entity.isAvailable else {
            return "Unavailable"
        }

        if let sensor = entityBox.sensorEntity {
            return conciseDetail(sensor.formattedValue)
        }

        return conciseDetail(
            entity.state
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        )
    }

    private func conciseDetail(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private struct DeviceEntityDetailSlot: View {
    let detailText: String
    let isAvailable: Bool

    var body: some View {
        Text(detailText)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(isAvailable ? .secondary : Color.red)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .truncationMode(.tail)
            .frame(width: 86, alignment: .trailing)
            .accessibilityLabel("State \(detailText)")
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
