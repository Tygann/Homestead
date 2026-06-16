import SwiftUI

struct EntityBrowserList<Accessory: View>: View {
    // MARK: - Properties

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var localSearchText = ""
    @State private var grouping: EntityBrowserGrouping = .device
    @State private var collapsedGroups: Set<String> = []
    @State private var selectedDomain: EntityDomain?
    @State private var includesUnavailable: Bool

    private let externalSearchText: Binding<String>?
    let hiddenEntityIDs: Set<String>
    let emptyTitle: String
    let emptySystemImage: String
    let showsFilters: Bool
    let showsSearchField: Bool
    let showsGroupingMenu: Bool
    let showsSingleGroupHeaders: Bool
    let allowsRefresh: Bool
    let allowedDomains: Set<EntityDomain>?
    let allowedEntityIDs: Set<String>?
    let rowAction: (HAEntityState) -> Void
    let rowDetail: (HAEntityState) -> String?
    private let accessory: (HAEntityState) -> Accessory

    // MARK: - Initialization

    init(
        hiddenEntityIDs: Set<String>,
        emptyTitle: String,
        emptySystemImage: String,
        showsFilters: Bool = false,
        includesUnavailableByDefault: Bool = true,
        searchText: Binding<String>? = nil,
        showsSearchField: Bool = true,
        showsGroupingMenu: Bool = true,
        showsSingleGroupHeaders: Bool = true,
        allowsRefresh: Bool = true,
        allowedDomains: Set<EntityDomain>? = nil,
        allowedEntityIDs: Set<String>? = nil,
        initialGrouping: EntityBrowserGrouping = .device,
        rowAction: @escaping (HAEntityState) -> Void,
        rowDetail: @escaping (HAEntityState) -> String? = { _ in nil },
        @ViewBuilder accessory: @escaping (HAEntityState) -> Accessory
    ) {
        self.externalSearchText = searchText
        self.hiddenEntityIDs = hiddenEntityIDs
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.showsFilters = showsFilters
        self.showsSearchField = showsSearchField
        self.showsGroupingMenu = showsGroupingMenu
        self.showsSingleGroupHeaders = showsSingleGroupHeaders
        self.allowsRefresh = allowsRefresh
        self.allowedDomains = allowedDomains
        self.allowedEntityIDs = allowedEntityIDs
        self.rowAction = rowAction
        self.rowDetail = rowDetail
        self.accessory = accessory
        _includesUnavailable = State(initialValue: includesUnavailableByDefault)
        _grouping = State(initialValue: initialGrouping)
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
                    Button {
                        rowAction(entityBox)
                    } label: {
                        EntityBrowserRow(
                            entityBox: entityBox,
                            displayNameOverride: displayNameOverride(for: entityID),
                            detailText: rowDetail(entityBox),
                            accessory: accessory(entityBox)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
            homeAssistantService.lastErrorMessage ?? "Check your connection settings and try again."
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
            ForEach(EntityBrowserGrouping.allCases, id: \.self) { option in
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
        if grouping == .device {
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
        showsSingleGroupHeaders || presentation.groups.count > 1 || collapsedGroups.contains(group.id)
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

enum EntityBrowserGrouping: CaseIterable {
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

struct EntityBrowserGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let entityIDs: [String]
}

private struct EntityBrowserPresentation {
    let groups: [EntityBrowserGroup]
    let filterDomains: [EntityDomain]
    let visibleCandidateEntityIDs: Set<String>
}
