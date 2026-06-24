import SwiftUI

struct EntityBrowserList<Accessory: View>: View {
    // MARK: - Properties

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var localSearchText = ""
    @State private var grouping: EntityBrowserGrouping
    @State private var collapsedGroups: Set<String> = []
    @State private var selectedDomain: EntityDomain?
    @State private var includesUnavailable: Bool

    private let externalSearchText: Binding<String>?
    private let groupingPersistenceKey: String?
    let hiddenEntityIDs: Set<String>
    let emptyTitle: String
    let emptySystemImage: String
    let showsFilters: Bool
    let showsSearchField: Bool
    let allowedGroupings: [EntityBrowserGrouping]
    let showsGroupingMenu: Bool
    let showsSingleGroupHeaders: Bool
    let allowsRefresh: Bool
    let allowedDomains: Set<EntityDomain>?
    let allowedEntityIDs: Set<String>?
    let rowAction: (HAEntityState) -> Void
    let rowDetail: (HAEntityState) -> String?
    private let typeGroup: ((HAEntityState) -> EntityBrowserGroup?)?
    private let rowDestination: ((HAEntityState) -> AnyView)?
    private let accessory: (HAEntityState) -> Accessory

    // MARK: - Initialization

    init(
        hiddenEntityIDs: Set<String>,
        emptyTitle: String,
        emptySystemImage: String,
        showsFilters: Bool = false,
        includesUnavailableByDefault: Bool = true,
        searchText: Binding<String>? = nil,
        groupingPersistenceKey: String? = nil,
        showsSearchField: Bool = true,
        allowedGroupings: [EntityBrowserGrouping] = EntityBrowserGrouping.allCases,
        showsGroupingMenu: Bool = true,
        showsSingleGroupHeaders: Bool = true,
        allowsRefresh: Bool = true,
        allowedDomains: Set<EntityDomain>? = nil,
        allowedEntityIDs: Set<String>? = nil,
        initialGrouping: EntityBrowserGrouping = .device,
        rowAction: @escaping (HAEntityState) -> Void,
        rowDetail: @escaping (HAEntityState) -> String? = { _ in nil },
        typeGroup: ((HAEntityState) -> EntityBrowserGroup?)? = nil,
        rowDestination: ((HAEntityState) -> AnyView)? = nil,
        @ViewBuilder accessory: @escaping (HAEntityState) -> Accessory
    ) {
        self.externalSearchText = searchText
        self.groupingPersistenceKey = groupingPersistenceKey
        self.hiddenEntityIDs = hiddenEntityIDs
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.showsFilters = showsFilters
        self.showsSearchField = showsSearchField
        self.allowedGroupings = allowedGroupings
        self.showsGroupingMenu = showsGroupingMenu
        self.showsSingleGroupHeaders = showsSingleGroupHeaders
        self.allowsRefresh = allowsRefresh
        self.allowedDomains = allowedDomains
        self.allowedEntityIDs = allowedEntityIDs
        self.rowAction = rowAction
        self.rowDetail = rowDetail
        self.typeGroup = typeGroup
        self.rowDestination = rowDestination
        self.accessory = accessory
        _includesUnavailable = State(initialValue: includesUnavailableByDefault)
        _grouping = State(initialValue: Self.resolvedInitialGrouping(
            key: groupingPersistenceKey,
            fallback: initialGrouping,
            allowedGroupings: allowedGroupings
        ))
    }

    // MARK: - Body

    var body: some View {
        let presentation = entityBrowserPresentation

        VStack(spacing: 0) {
            if showsFilters {
                filterBar(filterDomains: presentation.filterDomains)
            }

            List {
                ForEach(presentation.groups) { group in
                    if showsHeader(for: group, in: presentation) {
                        Section {
                            groupRows(group)
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
                    } else {
                        Section {
                            groupRows(group)
                        }
                    }
                }
            }
            .overlay {
                if connectionSettings.hasServerURL && homeAssistantService.authState.isSignedIn && !stateStore.hasLoadedInitialSnapshot {
                    ContentUnavailableView {
                        Label(entityLoadingTitle, systemImage: homeAssistantService.connectionStatus.systemImage)
                    } description: {
                        Text(entityLoadingMessage)
                    }
                } else if !stateStore.hasEntities {
                    ContentUnavailableView(emptyTitle, systemImage: emptySystemImage)
                } else if presentation.groups.isEmpty && presentation.visibleCandidateEntityIDs.isEmpty {
                    ContentUnavailableView(emptyTitle, systemImage: emptySystemImage)
                } else if presentation.groups.isEmpty && currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasActiveFilters {
                    ContentUnavailableView("No Matching Entities", systemImage: "line.3.horizontal.decrease.circle")
                } else if presentation.groups.isEmpty && currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(emptyTitle, systemImage: emptySystemImage)
                } else if presentation.groups.isEmpty {
                    ContentUnavailableView.search(text: currentSearchText)
                }
            }
        }
        .modifier(EntityBrowserRefreshModifier(isEnabled: allowsRefresh) {
            await homeAssistantService.refreshStates()
        })
        .onChange(of: grouping) { _, newValue in
            persistGrouping(newValue)
        }
        .toolbar {
            if showsGroupingMenu {
                ToolbarItem(placement: .topBarTrailing) {
                    groupingMenu
                }
            }
        }
        .modifier(EntityBrowserSearchModifier(searchText: searchTextBinding, isEnabled: showsSearchField))
    }

    // MARK: - Sections

    @ViewBuilder
    private func groupRows(_ group: EntityBrowserGroup) -> some View {
        if !collapsedGroups.contains(group.id) {
            ForEach(group.entityIDs, id: \.self) { entityID in
                if let entityBox = stateStore.entityBox(for: entityID) {
                    if let rowDestination {
                        NavigationLink {
                            rowDestination(entityBox)
                        } label: {
                            entityRow(entityBox, entityID: entityID)
                        }
                    } else {
                        Button {
                            rowAction(entityBox)
                        } label: {
                            entityRow(entityBox, entityID: entityID)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func entityRow(_ entityBox: HAEntityState, entityID: String) -> some View {
        EntityBrowserRow(
            entityBox: entityBox,
            displayNameOverride: displayNameOverride(for: entityID),
            detailText: rowDetail(entityBox),
            accessory: accessory(entityBox)
        )
    }

    private var entityLoadingTitle: String {
        switch homeAssistantService.connectionStatus {
        case .failed:
            "Unable to Load Devices"
        case .disconnected:
            "Loading Home Assistant"
        case .reconnecting:
            "Reconnecting"
        case .connected, .preparing, .connecting:
            "Loading Home Assistant"
        }
    }

    private var entityLoadingMessage: String {
        switch homeAssistantService.connectionStatus {
        case .failed:
            homeAssistantService.lastErrorMessage.map(HAConnectionIssuePresentation.fallbackMessage(forRawMessage:)) ??
                "Check your connection settings and try again."
        case .disconnected:
            "Preparing to fetch your latest entity state."
        case .reconnecting:
            "Restoring your live entity state."
        case .connected, .preparing, .connecting:
            "Fetching your latest entity state."
        }
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(allowedGroupings, id: \.self) { option in
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

    private func filterBar(filterDomains: [EntityDomain]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                filterChip(
                    title: "All",
                    systemImage: "square.grid.2x2",
                    isSelected: selectedDomain == nil
                ) {
                    selectedDomain = nil
                    collapsedGroups.removeAll()
                }

                ForEach(filterDomains, id: \.self) { domain in
                    filterChip(
                        title: domain.displayName,
                        systemImage: domain.systemImage,
                        isSelected: selectedDomain == domain
                    ) {
                        selectedDomain = domain
                        collapsedGroups.removeAll()
                    }
                }

                Button {
                    includesUnavailable.toggle()
                    collapsedGroups.removeAll()
                } label: {
                    Label("Unavailable", systemImage: includesUnavailable ? "eye" : "eye.slash")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, AppSpacing.medium)
                        .frame(height: 34)
                        .background(includesUnavailable ? Color.accentColor.opacity(0.14) : Color(.tertiarySystemGroupedBackground), in: Capsule())
                        .foregroundStyle(includesUnavailable ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(includesUnavailable ? "Hide unavailable entities" : "Show unavailable entities")
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func filterChip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AppSpacing.medium)
                .frame(height: 34)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func groupHeaderLabel(for group: EntityBrowserGroup) -> some View {
        if grouping == .name || grouping == .device {
            Text(group.title)
        } else {
            Label(group.title, systemImage: group.systemImage)
        }
    }

    // MARK: - Actions

    private func toggleSection(_ groupID: String) {
        if collapsedGroups.contains(groupID) {
            collapsedGroups.remove(groupID)
        } else {
            collapsedGroups.insert(groupID)
        }
    }

    // MARK: - Helpers

    private func showsHeader(for group: EntityBrowserGroup, in presentation: EntityBrowserPresentation) -> Bool {
        if grouping == .name {
            return collapsedGroups.contains(group.id)
        }

        return showsSingleGroupHeaders || presentation.groups.count > 1 || collapsedGroups.contains(group.id)
    }

    private func displayNameOverride(for entityID: String) -> String? {
        guard grouping == .device else { return nil }
        return stateStore.displayNameForDeviceGroupedEntity(entityID: entityID)
    }

    private var entityBrowserPresentation: EntityBrowserPresentation {
        let query = currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleCandidateEntityIDs = stateStore.availableEntityIDs
            .subtracting(hiddenEntityIDs)
            .filter { entityID in
                if let allowedEntityIDs, !allowedEntityIDs.contains(entityID) {
                    return false
                }

                guard let allowedDomains else {
                    return true
                }

                return stateStore.entityBox(for: entityID).map { allowedDomains.contains($0.homeEntity.domain) } ?? false
            }
        let filterDomains = EntityDomain.allCases.filter { domain in
            if let allowedDomains, !allowedDomains.contains(domain) {
                return false
            }

            return visibleCandidateEntityIDs.contains { entityID in
                stateStore.entityBox(for: entityID)?.homeEntity.domain == domain
            }
        }

        let unfilteredGroups: [EntityBrowserGroup]
        switch grouping {
        case .name:
            let entityIDs = visibleCandidateEntityIDs
                .filter(entityPassesVisibility)
                .sortedByEntityDisplayName(in: stateStore)

            unfilteredGroups = entityIDs.isEmpty ? [] : [
                EntityBrowserGroup(
                    id: "name",
                    title: "Entities",
                    systemImage: "textformat",
                    entityIDs: entityIDs
                )
            ]
        case .device:
            if !stateStore.entityIDGroupsByDevice.isEmpty {
                unfilteredGroups = stateStore.entityIDGroupsByDevice.compactMap { group in
                    let visibleEntityIDs = group.entityIDs.filter(entityPassesVisibility)
                    guard !visibleEntityIDs.isEmpty else { return nil }

                    return EntityBrowserGroup(
                        id: "device-\(group.id)",
                        title: group.title,
                        systemImage: "laptopcomputer.and.iphone",
                        entityIDs: visibleEntityIDs
                    )
                }
            } else {
                unfilteredGroups = stateStore.entityIDGroupsByDomain.compactMap { group in
                    let visibleEntityIDs = group.entityIDs.filter(entityPassesVisibility)
                    guard !visibleEntityIDs.isEmpty else { return nil }

                    return EntityBrowserGroup(
                        id: "type-\(group.domain.rawValue)",
                        title: group.domain.displayName,
                        systemImage: group.domain.systemImage,
                        entityIDs: visibleEntityIDs
                    )
                }
            }
        case .type:
            if let typeGroup {
                unfilteredGroups = Dictionary(grouping: visibleCandidateEntityIDs.filter(entityPassesVisibility)) { entityID in
                    stateStore.entityBox(for: entityID).flatMap(typeGroup) ?? EntityBrowserGroup(
                        id: "type-other",
                        title: "Other",
                        systemImage: "square.grid.2x2",
                        entityIDs: []
                    )
                }
                .map { descriptor, entityIDs in
                    EntityBrowserGroup(
                        id: descriptor.id,
                        title: descriptor.title,
                        systemImage: descriptor.systemImage,
                        entityIDs: entityIDs.sortedByEntityDisplayName(in: stateStore)
                    )
                }
                .sortedByTitle
            } else {
                unfilteredGroups = stateStore.entityIDGroupsByDomain.compactMap { group in
                    let visibleEntityIDs = group.entityIDs.filter(entityPassesVisibility)
                    guard !visibleEntityIDs.isEmpty else { return nil }

                    return EntityBrowserGroup(
                        id: "type-\(group.domain.rawValue)",
                        title: group.domain.displayName,
                        systemImage: group.domain.systemImage,
                        entityIDs: visibleEntityIDs
                    )
                }
            }
        }

        let groups: [EntityBrowserGroup]
        if query.isEmpty {
            groups = unfilteredGroups
        } else {
            groups = unfilteredGroups.compactMap { group in
                let matchingEntityIDs = group.entityIDs.filter { entityID in
                    guard let entity = stateStore.entityBox(for: entityID)?.homeEntity else {
                        return false
                    }
                    let displayName = displayNameOverride(for: entityID) ?? entity.displayName
                    let detailText = stateStore.entityBox(for: entityID).flatMap(rowDetail) ?? ""

                    return displayName.localizedCaseInsensitiveContains(query) ||
                        group.title.localizedCaseInsensitiveContains(query) ||
                        entity.entityID.localizedCaseInsensitiveContains(query) ||
                        entity.state.localizedCaseInsensitiveContains(query) ||
                        detailText.localizedCaseInsensitiveContains(query)
                }

                guard !matchingEntityIDs.isEmpty else {
                    return nil
                }

                return EntityBrowserGroup(
                    id: group.id,
                    title: group.title,
                    systemImage: group.systemImage,
                    entityIDs: matchingEntityIDs
                )
            }
        }

        return EntityBrowserPresentation(
            groups: groups,
            filterDomains: filterDomains,
            visibleCandidateEntityIDs: visibleCandidateEntityIDs
        )
    }

    private var hasActiveFilters: Bool {
        selectedDomain != nil || !includesUnavailable
    }

    private var currentSearchText: String {
        externalSearchText?.wrappedValue ?? localSearchText
    }

    private var searchTextBinding: Binding<String> {
        externalSearchText ?? $localSearchText
    }

    private func entityPassesVisibility(_ entityID: String) -> Bool {
        guard !hiddenEntityIDs.contains(entityID),
              let entity = stateStore.entityBox(for: entityID)?.homeEntity else {
            return false
        }

        if let allowedEntityIDs, !allowedEntityIDs.contains(entityID) {
            return false
        }

        if let allowedDomains, !allowedDomains.contains(entity.domain) {
            return false
        }

        if let selectedDomain, entity.domain != selectedDomain {
            return false
        }

        if !includesUnavailable, !entity.isAvailable {
            return false
        }

        return true
    }

    private func persistGrouping(_ grouping: EntityBrowserGrouping) {
        guard let groupingPersistenceKey else { return }
        UserDefaults.standard.set(grouping.rawValue, forKey: groupingPersistenceKey)
    }

    private static func resolvedInitialGrouping(
        key: String?,
        fallback: EntityBrowserGrouping,
        allowedGroupings: [EntityBrowserGrouping]
    ) -> EntityBrowserGrouping {
        guard let key,
              let storedValue = UserDefaults.standard.string(forKey: key),
              let storedGrouping = EntityBrowserGrouping(rawValue: storedValue),
              allowedGroupings.contains(storedGrouping) else {
            return fallback
        }

        return storedGrouping
    }
}

// MARK: - Refresh Support

private struct EntityBrowserRefreshModifier: ViewModifier {
    let isEnabled: Bool
    let refresh: () async -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.refreshable {
                await refresh()
            }
        } else {
            content
        }
    }
}

// MARK: - Search Support

private struct EntityBrowserSearchModifier: ViewModifier {
    @Binding var searchText: String
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        } else {
            content
        }
    }
}

// MARK: - Grouping Models

enum EntityBrowserGrouping: String, CaseIterable {
    case name
    case device
    case type

    var displayName: String {
        switch self {
        case .name:
            "Name"
        case .device:
            "Device"
        case .type:
            "Type"
        }
    }

    var systemImage: String {
        switch self {
        case .name:
            "textformat"
        case .device:
            "laptopcomputer.and.iphone"
        case .type:
            "square.grid.2x2"
        }
    }
}

struct EntityBrowserGroup: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let entityIDs: [String]
}

private extension Array where Element == EntityBrowserGroup {
    var sortedByTitle: [EntityBrowserGroup] {
        sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension Set where Element == String {
    func sortedByEntityDisplayName(in stateStore: HAStateStore) -> [String] {
        sorted { lhs, rhs in
            let lhsName = stateStore.entityBox(for: lhs)?.homeEntity.displayName ?? lhs
            let rhsName = stateStore.entityBox(for: rhs)?.homeEntity.displayName ?? rhs
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }
}

private extension Array where Element == String {
    func sortedByEntityDisplayName(in stateStore: HAStateStore) -> [String] {
        sorted { lhs, rhs in
            let lhsName = stateStore.entityBox(for: lhs)?.homeEntity.displayName ?? lhs
            let rhsName = stateStore.entityBox(for: rhs)?.homeEntity.displayName ?? rhs
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }
}

private struct EntityBrowserPresentation {
    let groups: [EntityBrowserGroup]
    let filterDomains: [EntityDomain]
    let visibleCandidateEntityIDs: Set<String>
}
