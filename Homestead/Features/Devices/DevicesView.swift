import SwiftUI

struct DevicesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var selectedEntity: SelectedEntity?

    var body: some View {
        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: "No Devices",
            emptySystemImage: "square.grid.2x2",
            rowAction: { entityBox in
                selectedEntity = SelectedEntity(entityID: entityBox.entityID)
            },
            accessory: { entityBox in
                DeviceEntityStateAccessory(entityBox: entityBox)
            }
        )
        .navigationTitle("Devices")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(item: $selectedEntity) { selectedEntity in
            if let entityBox = stateStore.entityBox(for: selectedEntity.entityID) {
                EntityDetailView(entityBox: entityBox)
            }
        }
    }
}

struct EntityBrowserList<Accessory: View>: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var searchText = ""
    @State private var grouping: DevicesGrouping = .device
    @State private var collapsedGroups: Set<String> = []

    let hiddenEntityIDs: Set<String>
    let emptyTitle: String
    let emptySystemImage: String
    let rowAction: (HAEntityState) -> Void
    private let accessory: (HAEntityState) -> Accessory

    init(
        hiddenEntityIDs: Set<String>,
        emptyTitle: String,
        emptySystemImage: String,
        rowAction: @escaping (HAEntityState) -> Void,
        @ViewBuilder accessory: @escaping (HAEntityState) -> Accessory
    ) {
        self.hiddenEntityIDs = hiddenEntityIDs
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.rowAction = rowAction
        self.accessory = accessory
    }

    var body: some View {
        let groups = filteredEntityGroups

        List {
            ForEach(groups) { group in
                Section {
                    if !collapsedGroups.contains(group.id) {
                        ForEach(group.entityIDs, id: \.self) { entityID in
                            if let entityBox = stateStore.entityBox(for: entityID) {
                                Button {
                                    rowAction(entityBox)
                                } label: {
                                    EntityBrowserRow(
                                        entityBox: entityBox,
                                        displayNameOverride: displayNameOverride(for: entityID),
                                        accessory: accessory(entityBox)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Button {
                        toggleSection(group.id)
                    } label: {
                        HStack {
                            groupHeaderLabel(for: group)
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
            if connectionSettings.hasCredentials && !stateStore.hasLoadedInitialSnapshot {
                ContentUnavailableView {
                    Label(entityLoadingTitle, systemImage: homeAssistantService.connectionStatus.systemImage)
                } description: {
                    Text(entityLoadingMessage)
                }
            } else if !stateStore.hasEntities {
                ContentUnavailableView(emptyTitle, systemImage: emptySystemImage)
            } else if groups.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: emptySystemImage)
            } else if groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                groupingMenu
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
    }

    private var entityLoadingTitle: String {
        switch homeAssistantService.connectionStatus {
        case .failed:
            "Unable to Load Devices"
        case .disconnected:
            "Loading Home Assistant"
        case .reconnecting:
            "Reconnecting"
        case .connected, .connecting:
            "Loading Home Assistant"
        }
    }

    private var entityLoadingMessage: String {
        switch homeAssistantService.connectionStatus {
        case .failed:
            homeAssistantService.lastErrorMessage ?? "Check your connection settings and try again."
        case .disconnected:
            "Preparing to fetch your latest entity state."
        case .reconnecting:
            "Restoring your live entity state."
        case .connected, .connecting:
            "Fetching your latest entity state."
        }
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
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Group devices")
    }

    @ViewBuilder
    private func groupHeaderLabel(for group: DevicesEntityGroup) -> some View {
        if grouping == .device {
            Text(group.title)
        } else {
            Label(group.title, systemImage: group.systemImage)
        }
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
                return stateStore.entityIDGroupsByDevice.compactMap { group in
                    let visibleEntityIDs = group.entityIDs.filter { !hiddenEntityIDs.contains($0) }
                    guard !visibleEntityIDs.isEmpty else { return nil }

                    return DevicesEntityGroup(
                        id: "device-\(group.id)",
                        title: group.title,
                        systemImage: "laptopcomputer.and.iphone",
                        entityIDs: visibleEntityIDs
                    )
                }
            }

            fallthrough
        case .type:
            return stateStore.entityIDGroupsByDomain.compactMap { group in
                let visibleEntityIDs = group.entityIDs.filter { !hiddenEntityIDs.contains($0) }
                guard !visibleEntityIDs.isEmpty else { return nil }

                return DevicesEntityGroup(
                    id: "type-\(group.domain.rawValue)",
                    title: group.domain.displayName,
                    systemImage: group.domain.systemImage,
                    entityIDs: visibleEntityIDs
                )
            }
        }
    }
}

enum DevicesGrouping: CaseIterable {
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

struct DevicesEntityGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let entityIDs: [String]
}

private struct SelectedEntity: Identifiable {
    let entityID: String

    var id: String { entityID }
}

private struct EntityBrowserRow<Accessory: View>: View {
    let entityBox: HAEntityState
    var displayNameOverride: String?
    let accessory: Accessory

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

                accessory
            }
            .frame(minHeight: 48)
        } icon: {
            Image(systemName: entity.iconName)
                .foregroundStyle(entity.isAvailable ? Color.accentColor : Color.secondary)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

private struct DeviceEntityStateAccessory: View {
    let entityBox: HAEntityState

    var body: some View {
        if let detailText {
            DeviceEntityDetailSlot(
                detailText: detailText,
                isAvailable: entityBox.homeEntity.isAvailable
            )
        }
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
