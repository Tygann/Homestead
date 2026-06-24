import Foundation
import Observation

struct DashboardItemConfiguration: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var type: DashboardItemType
    var entityID: String?
    var title: String?
    var displayNameOverride: String?
    var iconNameOverride: String?
    var size: DashboardCardSize?
    var featureVisibility: DashboardCardFeatureVisibility?
    var chipKind: DashboardChipKind?
    var summaryKind: DashboardSummaryKind?

    init(
        id: UUID,
        type: DashboardItemType,
        entityID: String?,
        title: String?,
        displayNameOverride: String?,
        iconNameOverride: String?,
        size: DashboardCardSize?,
        featureVisibility: DashboardCardFeatureVisibility? = nil,
        chipKind: DashboardChipKind?,
        summaryKind: DashboardSummaryKind?
    ) {
        self.id = id
        self.type = type
        self.entityID = entityID
        self.title = title
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.size = size
        self.featureVisibility = featureVisibility
        self.chipKind = chipKind
        self.summaryKind = summaryKind
    }

    static func entity(
        entityID: String,
        size: DashboardCardSize = .compact,
        id: UUID = UUID()
    ) -> DashboardItemConfiguration {
        DashboardItemConfiguration(
            id: id,
            type: .entity,
            entityID: entityID,
            title: nil,
            displayNameOverride: nil,
            iconNameOverride: nil,
            size: size,
            featureVisibility: nil,
            chipKind: nil,
            summaryKind: nil
        )
    }

    static func header(
        title: String,
        id: UUID = UUID()
    ) -> DashboardItemConfiguration {
        DashboardItemConfiguration(
            id: id,
            type: .header,
            entityID: nil,
            title: title,
            displayNameOverride: nil,
            iconNameOverride: nil,
            size: nil,
            featureVisibility: nil,
            chipKind: nil,
            summaryKind: nil
        )
    }

    static func summaryChip(
        kind: DashboardSummaryKind,
        id: UUID = UUID()
    ) -> DashboardItemConfiguration {
        DashboardItemConfiguration(
            id: id,
            type: .chip,
            entityID: nil,
            title: nil,
            displayNameOverride: nil,
            iconNameOverride: nil,
            size: nil,
            featureVisibility: nil,
            chipKind: .summary,
            summaryKind: kind
        )
    }

    static func entityChip(
        entityID: String,
        id: UUID = UUID()
    ) -> DashboardItemConfiguration {
        DashboardItemConfiguration(
            id: id,
            type: .chip,
            entityID: entityID,
            title: nil,
            displayNameOverride: nil,
            iconNameOverride: nil,
            size: nil,
            featureVisibility: nil,
            chipKind: .entity,
            summaryKind: nil
        )
    }

    var resolvedTitle: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? "Untitled Section" : trimmedTitle
    }

    var resolvedCardSize: DashboardCardSize {
        size ?? .compact
    }

    var resolvedFeatureVisibility: DashboardCardFeatureVisibility {
        featureVisibility ?? .automatic
    }

    func resolvedDisplayName(default defaultDisplayName: String) -> String {
        let trimmedOverride = displayNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedOverride.isEmpty ? defaultDisplayName : trimmedOverride
    }

    func resolvedIconName(default defaultIconName: String) -> String {
        let trimmedOverride = iconNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedOverride.isEmpty ? defaultIconName : trimmedOverride
    }

    var layoutMetadata: DashboardCardLayoutMetadata {
        switch type {
        case .entity:
            resolvedCardSize.layoutMetadata
        case .header:
            DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 1)
        case .chip:
            DashboardCardLayoutMetadata(columnSpan: 2, rowSpan: 1)
        }
    }
}

enum DashboardItemType: String, Codable, Equatable, Sendable {
    case entity
    case header
    case chip
}

enum DashboardReorderGroup: Equatable, Sendable {
    case chips
    case cards
}

struct SavedDashboardConfiguration: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var items: [DashboardItemConfiguration]
    var entityDisplayNameOverrides: [String: String]

    var resolvedName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Untitled Dashboard" : trimmedName
    }
}

@MainActor
@Observable
final class DashboardConfiguration {
    private(set) var dashboards: [SavedDashboardConfiguration] {
        didSet { saveDashboards() }
    }
    private(set) var selectedDashboardID: UUID {
        didSet { saveSelectedDashboardID() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let itemsKey = "dashboardItems"
    @ObservationIgnored private let entityDisplayNameOverridesKey = "entityDisplayNameOverrides"
    @ObservationIgnored private let dashboardsKey = "homestead.dashboard.savedDashboards"
    @ObservationIgnored private let selectedDashboardIDKey = "homestead.dashboard.selectedDashboardID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loadedDashboards = Self.loadDashboards(
            from: defaults,
            dashboardsKey: dashboardsKey,
            itemsKey: itemsKey,
            entityDisplayNameOverridesKey: entityDisplayNameOverridesKey
        )
        dashboards = loadedDashboards
        selectedDashboardID = Self.loadSelectedDashboardID(
            from: defaults,
            key: selectedDashboardIDKey,
            dashboards: loadedDashboards
        )
    }

    var hasCustomLayout: Bool {
        !items.isEmpty
    }

    var syncSnapshot: DashboardConfigurationSyncSnapshot {
        DashboardConfigurationSyncSnapshot(
            dashboards: dashboards
        )
    }

    var selectedDashboard: SavedDashboardConfiguration {
        dashboards.first { $0.id == selectedDashboardID } ?? dashboards[0]
    }

    var items: [DashboardItemConfiguration] {
        selectedDashboard.items
    }

    var entityDisplayNameOverrides: [String: String] {
        selectedDashboard.entityDisplayNameOverrides
    }

    var entityIDs: [String] {
        items.compactMap { item in
            guard item.type == .entity else { return nil }
            return item.entityID
        }
    }

    func seedIfNeeded(from entities: [HomeEntity]) {
        guard items.isEmpty else {
            return
        }

        updateSelectedDashboardItems(Self.defaultEntityIDs(from: entities).map {
            DashboardItemConfiguration.entity(entityID: $0)
        })
    }

    func reconcile(with entities: [HomeEntity]) {
        reconcile(withAvailableEntityIDs: Set(entities.map(\.entityID)))
        seedIfNeeded(from: entities)
    }

    func reconcile(withAvailableEntityIDs _: Set<String>) {
        let currentItems = items.filter { item in
            switch item.type {
            case .entity:
                return item.entityID != nil
            case .header:
                return true
            case .chip:
                return item.chipKind == .summary || item.entityID != nil
            }
        }

        if currentItems != items {
            updateSelectedDashboardItems(currentItems)
        }
    }

    func visibleItems(from entities: [HomeEntity]) -> [DashboardItemConfiguration] {
        visibleItems(fromAvailableEntityIDs: Set(entities.map(\.entityID)))
    }

    func visibleItems(fromAvailableEntityIDs availableIDs: Set<String>) -> [DashboardItemConfiguration] {
        items.filter { item in
            switch item.type {
            case .entity:
                guard let entityID = item.entityID else { return false }
                return availableIDs.contains(entityID)
            case .header:
                return true
            case .chip:
                switch item.chipKind ?? .summary {
                case .summary:
                    return true
                case .entity:
                    guard let entityID = item.entityID else { return false }
                    return availableIDs.contains(entityID)
                }
            }
        }
    }

    func visibleEntityIDs(from entities: [HomeEntity]) -> [String] {
        visibleEntityIDs(fromAvailableEntityIDs: Set(entities.map(\.entityID)))
    }

    func visibleEntityIDs(fromAvailableEntityIDs availableIDs: Set<String>) -> [String] {
        visibleItems(fromAvailableEntityIDs: availableIDs).compactMap { item in
            guard item.type == .entity else { return nil }
            return item.entityID
        }
    }

    func addableEntityIDs(fromAvailableEntityIDs availableIDs: Set<String>) -> Set<String> {
        availableIDs.subtracting(Set(entityIDs))
    }

    func contains(_ entityID: String) -> Bool {
        entityIDs.contains(entityID)
    }

    func itemType(for itemID: UUID) -> DashboardItemType? {
        items.first { $0.id == itemID }?.type
    }

    func setEntity(_ entityID: String, isVisible: Bool) {
        if isVisible {
            add(entityID)
        } else {
            remove(entityID)
        }
    }

    @discardableResult
    func add(_ entityID: String, size: DashboardCardSize = .compact) -> UUID {
        if let existingItem = items.first(where: { $0.type == .entity && $0.entityID == entityID }) {
            return existingItem.id
        }

        let item = DashboardItemConfiguration.entity(entityID: entityID, size: size)
        appendSelectedDashboardItem(item)
        return item.id
    }

    @discardableResult
    func addHeader(title: String) -> UUID {
        let item = DashboardItemConfiguration.header(title: normalizedHeaderTitle(title))
        appendSelectedDashboardItem(item)
        return item.id
    }

    @discardableResult
    func addSummaryChip(kind: DashboardSummaryKind) -> UUID {
        if let existingItem = items.first(where: { $0.type == .chip && $0.chipKind == .summary && $0.summaryKind == kind }) {
            return existingItem.id
        }

        let item = DashboardItemConfiguration.summaryChip(kind: kind)
        appendSelectedDashboardItem(item)
        return item.id
    }

    @discardableResult
    func addEntityChip(entityID: String) -> UUID {
        let item = DashboardItemConfiguration.entityChip(entityID: entityID)
        appendSelectedDashboardItem(item)
        return item.id
    }

    func renameHeader(id: UUID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.type == .header }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].title = normalizedHeaderTitle(title)
        updateSelectedDashboardItems(updatedItems)
    }

    func renameEntityItem(id: UUID, displayNameOverride: String?) {
        guard let entityID = items.first(where: { $0.id == id && $0.type == .entity })?.entityID else {
            return
        }

        setEntityDisplayNameOverride(displayNameOverride, for: entityID)
    }

    func renameDisplayItem(id: UUID, displayNameOverride: String?) {
        guard let index = items.firstIndex(where: { $0.id == id && ($0.type == .entity || $0.type == .chip) }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].displayNameOverride = normalizedDisplayNameOverride(displayNameOverride)
        updateSelectedDashboardItems(updatedItems)
    }

    func entityDisplayNameOverride(for entityID: String) -> String? {
        entityDisplayNameOverrides[entityID]
    }

    func setEntityDisplayNameOverride(_ displayNameOverride: String?, for entityID: String) {
        var updatedOverrides = entityDisplayNameOverrides
        updatedOverrides[entityID] = normalizedDisplayNameOverride(displayNameOverride)
        updateSelectedDashboardOverrides(updatedOverrides)
    }

    func setIconNameOverride(_ iconNameOverride: String?, forItemID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID && ($0.type == .entity || $0.type == .chip) }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].iconNameOverride = normalizedDisplayNameOverride(iconNameOverride)
        updateSelectedDashboardItems(updatedItems)
    }

    func remove(_ entityID: String) {
        updateSelectedDashboardItems(items.filter { $0.type != .entity || $0.entityID != entityID })
    }

    func removeItem(id: UUID) {
        updateSelectedDashboardItems(items.filter { $0.id != id })
    }

    func move(from source: IndexSet, to destination: Int) {
        let movingItems = source.sorted().map { items[$0] }
        var updatedItems = items

        for index in source.sorted(by: >) {
            updatedItems.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        updatedItems.insert(contentsOf: movingItems, at: adjustedDestination)
        updateSelectedDashboardItems(updatedItems)
    }

    func moveItems(in group: DashboardReorderGroup, from source: IndexSet, to destination: Int) {
        let groupIndices = items.indices.filter { group.contains(items[$0]) }
        guard source.allSatisfy({ groupIndices.indices.contains($0) }),
              destination >= 0,
              destination <= groupIndices.count else {
            return
        }

        var reorderedGroupItems = groupIndices.map { items[$0] }
        let movingItems = source.sorted().map { reorderedGroupItems[$0] }

        for index in source.sorted(by: >) {
            reorderedGroupItems.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        reorderedGroupItems.insert(contentsOf: movingItems, at: adjustedDestination)

        var updatedItems = items
        for (itemIndex, reorderedItem) in zip(groupIndices, reorderedGroupItems) {
            updatedItems[itemIndex] = reorderedItem
        }
        updateSelectedDashboardItems(updatedItems)
    }

    func moveVisibleGridItem(
        id movingItemID: UUID,
        before targetItemID: UUID?,
        visibleGridItemIDs: [UUID]
    ) {
        moveVisibleItems(
            id: movingItemID,
            before: targetItemID,
            visibleItemIDs: visibleGridItemIDs
        )
    }

    func moveVisibleChipItem(
        id movingItemID: UUID,
        before targetItemID: UUID?,
        visibleChipItemIDs: [UUID]
    ) {
        moveVisibleItems(
            id: movingItemID,
            before: targetItemID,
            visibleItemIDs: visibleChipItemIDs
        )
    }

    private func moveVisibleItems(
        id movingItemID: UUID,
        before targetItemID: UUID?,
        visibleItemIDs: [UUID]
    ) {
        let orderedVisibleItemIDs = visibleItemIDs.reduce(into: [UUID]()) { partialResult, itemID in
            if !partialResult.contains(itemID) {
                partialResult.append(itemID)
            }
        }
        guard orderedVisibleItemIDs.contains(movingItemID),
              targetItemID != movingItemID,
              targetItemID.map(orderedVisibleItemIDs.contains) ?? true else {
            return
        }

        var reorderedVisibleItemIDs = orderedVisibleItemIDs.filter { $0 != movingItemID }
        let insertionIndex = targetItemID
            .flatMap { reorderedVisibleItemIDs.firstIndex(of: $0) }
            ?? reorderedVisibleItemIDs.count
        reorderedVisibleItemIDs.insert(movingItemID, at: insertionIndex)

        guard reorderedVisibleItemIDs != orderedVisibleItemIDs else {
            return
        }

        let visibleItemIDSet = Set(orderedVisibleItemIDs)
        let originalItemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var reorderedItemIndex = reorderedVisibleItemIDs.startIndex
        var updatedItems = items

        for itemIndex in updatedItems.indices where visibleItemIDSet.contains(updatedItems[itemIndex].id) {
            let reorderedItemID = reorderedVisibleItemIDs[reorderedItemIndex]
            guard let reorderedItem = originalItemsByID[reorderedItemID] else {
                return
            }

            updatedItems[itemIndex] = reorderedItem
            reorderedItemIndex = reorderedVisibleItemIDs.index(after: reorderedItemIndex)
        }

        updateSelectedDashboardItems(updatedItems)
    }

    func reset(using entities: [HomeEntity]) {
        updateSelectedDashboardItems(Self.defaultEntityIDs(from: entities).map {
            DashboardItemConfiguration.entity(entityID: $0)
        })
    }

    func applySyncSnapshot(_ snapshot: DashboardConfigurationSyncSnapshot) {
        dashboards = Self.normalizedDashboards(snapshot.resolvedDashboards)
        ensureSelectedDashboardExists()
    }

    @discardableResult
    func selectDashboard(id: UUID) -> Bool {
        guard dashboards.contains(where: { $0.id == id }) else {
            ensureSelectedDashboardExists()
            return false
        }

        selectedDashboardID = id
        return true
    }

    @discardableResult
    func createDashboard(named name: String = "New Dashboard") -> UUID {
        let dashboard = SavedDashboardConfiguration(
            id: UUID(),
            name: uniqueDashboardName(normalizedDashboardName(name)),
            items: [],
            entityDisplayNameOverrides: [:]
        )
        dashboards.append(dashboard)
        selectedDashboardID = dashboard.id
        return dashboard.id
    }

    @discardableResult
    func duplicateSelectedDashboard() -> UUID {
        let source = selectedDashboard
        let copiedItems = source.items.map { item in
            var copy = item
            copy.id = UUID()
            return copy
        }
        let dashboard = SavedDashboardConfiguration(
            id: UUID(),
            name: uniqueDashboardName("Copy of \(source.resolvedName)"),
            items: copiedItems,
            entityDisplayNameOverrides: source.entityDisplayNameOverrides
        )
        dashboards.append(dashboard)
        selectedDashboardID = dashboard.id
        return dashboard.id
    }

    func renameDashboard(id: UUID, name: String) {
        guard let index = dashboards.firstIndex(where: { $0.id == id }) else {
            return
        }

        var updatedDashboards = dashboards
        updatedDashboards[index].name = uniqueDashboardName(normalizedDashboardName(name), excluding: id)
        dashboards = updatedDashboards
    }

    func deleteDashboard(id: UUID) {
        var updatedDashboards = dashboards.filter { $0.id != id }
        if updatedDashboards.isEmpty {
            updatedDashboards = [Self.defaultDashboard()]
        }

        dashboards = updatedDashboards
        ensureSelectedDashboardExists()
    }

    func moveDashboards(from source: IndexSet, to destination: Int) {
        let movingDashboards = source.sorted().map { dashboards[$0] }
        var updatedDashboards = dashboards

        for index in source.sorted(by: >) {
            updatedDashboards.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        updatedDashboards.insert(contentsOf: movingDashboards, at: adjustedDestination)
        dashboards = updatedDashboards
        ensureSelectedDashboardExists()
    }

    func cardSize(forItemID itemID: UUID) -> DashboardCardSize {
        items.first { $0.id == itemID }?.resolvedCardSize ?? .compact
    }

    func cardSize(for entityID: String) -> DashboardCardSize {
        items.first { $0.type == .entity && $0.entityID == entityID }?.resolvedCardSize ?? .compact
    }

    func setCardSize(_ size: DashboardCardSize, forItemID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID && $0.type == .entity }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].size = size
        updateSelectedDashboardItems(updatedItems)
    }

    func setCardSize(_ size: DashboardCardSize, for entityID: String) {
        guard let itemID = items.first(where: { $0.type == .entity && $0.entityID == entityID })?.id else {
            return
        }

        setCardSize(size, forItemID: itemID)
    }

    func featureVisibility(forItemID itemID: UUID) -> DashboardCardFeatureVisibility {
        items.first { $0.id == itemID }?.resolvedFeatureVisibility ?? .automatic
    }

    func setFeatureVisibility(_ featureVisibility: DashboardCardFeatureVisibility, forItemID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID && $0.type == .entity }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].featureVisibility = featureVisibility == .automatic ? nil : featureVisibility
        updateSelectedDashboardItems(updatedItems)
    }

    private func saveDashboards() {
        guard let data = try? JSONEncoder().encode(dashboards) else {
            return
        }

        defaults.set(data, forKey: dashboardsKey)
    }

    private func saveSelectedDashboardID() {
        defaults.set(selectedDashboardID.uuidString, forKey: selectedDashboardIDKey)
    }

    private func updateSelectedDashboardItems(_ items: [DashboardItemConfiguration]) {
        updateSelectedDashboard { dashboard in
            dashboard.items = items
        }
    }

    private func updateSelectedDashboardOverrides(_ overrides: [String: String]) {
        updateSelectedDashboard { dashboard in
            dashboard.entityDisplayNameOverrides = overrides
        }
    }

    private func appendSelectedDashboardItem(_ item: DashboardItemConfiguration) {
        updateSelectedDashboard { dashboard in
            dashboard.items.append(item)
        }
    }

    private func updateSelectedDashboard(_ update: (inout SavedDashboardConfiguration) -> Void) {
        ensureSelectedDashboardExists()
        guard let index = dashboards.firstIndex(where: { $0.id == selectedDashboardID }) else {
            return
        }

        var updatedDashboards = dashboards
        update(&updatedDashboards[index])
        dashboards = updatedDashboards
    }

    private func ensureSelectedDashboardExists() {
        if dashboards.isEmpty {
            dashboards = [Self.defaultDashboard()]
            return
        }

        if !dashboards.contains(where: { $0.id == selectedDashboardID }) {
            selectedDashboardID = dashboards[0].id
        }
    }

    private func normalizedHeaderTitle(_ title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Section" : trimmedTitle
    }

    private func normalizedDisplayNameOverride(_ title: String?) -> String? {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? nil : trimmedTitle
    }

    private func normalizedDashboardName(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Untitled Dashboard" : trimmedName
    }

    private func uniqueDashboardName(_ name: String, excluding excludedID: UUID? = nil) -> String {
        let existingNames = Set(dashboards.compactMap { dashboard -> String? in
            dashboard.id == excludedID ? nil : dashboard.resolvedName.lowercased()
        })
        guard existingNames.contains(name.lowercased()) else {
            return name
        }

        for suffix in 2... {
            let candidate = "\(name) \(suffix)"
            if !existingNames.contains(candidate.lowercased()) {
                return candidate
            }
        }

        return name
    }

    private static func loadDashboards(
        from defaults: UserDefaults,
        dashboardsKey: String,
        itemsKey: String,
        entityDisplayNameOverridesKey: String
    ) -> [SavedDashboardConfiguration] {
        if let data = defaults.data(forKey: dashboardsKey),
           let dashboards = try? JSONDecoder().decode([SavedDashboardConfiguration].self, from: data) {
            return normalizedDashboards(dashboards)
        }

        let legacyItems = loadItems(from: defaults, key: itemsKey)
        let legacyOverrides = loadEntityDisplayNameOverrides(from: defaults, key: entityDisplayNameOverridesKey)
        return [
            SavedDashboardConfiguration(
                id: UUID(),
                name: defaultDashboardName,
                items: legacyItems,
                entityDisplayNameOverrides: legacyOverrides
            )
        ]
    }

    private static func loadSelectedDashboardID(
        from defaults: UserDefaults,
        key: String,
        dashboards: [SavedDashboardConfiguration]
    ) -> UUID {
        if let rawValue = defaults.string(forKey: key),
           let selectedID = UUID(uuidString: rawValue),
           dashboards.contains(where: { $0.id == selectedID }) {
            return selectedID
        }

        return dashboards.first?.id ?? defaultDashboard().id
    }

    private static func loadItems(
        from defaults: UserDefaults,
        key: String
    ) -> [DashboardItemConfiguration] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        guard
              let items = try? JSONDecoder().decode([DashboardItemConfiguration].self, from: data) else {
            return []
        }

        return items
    }

    private static func loadEntityDisplayNameOverrides(from defaults: UserDefaults, key: String) -> [String: String] {
        guard let data = defaults.data(forKey: key),
              let overrides = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return overrides
    }

    private static func defaultEntityIDs(from entities: [HomeEntity]) -> [String] {
        let sortedEntities = entities.sorted { lhs, rhs in
            if lhs.domain.dashboardPriority != rhs.domain.dashboardPriority {
                return lhs.domain.dashboardPriority < rhs.domain.dashboardPriority
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return Array(sortedEntities.prefix(10).map(\.entityID))
    }

    private static func normalizedDashboards(_ dashboards: [SavedDashboardConfiguration]) -> [SavedDashboardConfiguration] {
        let normalized = dashboards.map { dashboard in
            SavedDashboardConfiguration(
                id: dashboard.id,
                name: dashboard.resolvedName,
                items: dashboard.items,
                entityDisplayNameOverrides: dashboard.entityDisplayNameOverrides
            )
        }

        return normalized.isEmpty ? [defaultDashboard()] : normalized
    }

    private static func defaultDashboard() -> SavedDashboardConfiguration {
        SavedDashboardConfiguration(
            id: UUID(),
            name: defaultDashboardName,
            items: [],
            entityDisplayNameOverrides: [:]
        )
    }

    private static let defaultDashboardName = "Dashboard"
}

struct DashboardConfigurationSyncSnapshot: Codable, Equatable, Sendable {
    var dashboards: [SavedDashboardConfiguration]

    var items: [DashboardItemConfiguration] {
        resolvedDashboards.first?.items ?? []
    }

    var entityDisplayNameOverrides: [String: String] {
        resolvedDashboards.first?.entityDisplayNameOverrides ?? [:]
    }

    init(dashboards: [SavedDashboardConfiguration]) {
        self.dashboards = dashboards
    }

    init(
        items: [DashboardItemConfiguration],
        entityDisplayNameOverrides: [String: String]
    ) {
        dashboards = [
            SavedDashboardConfiguration(
                id: UUID(),
                name: Self.defaultDashboardName,
                items: items,
                entityDisplayNameOverrides: entityDisplayNameOverrides
            )
        ]
    }

    var resolvedDashboards: [SavedDashboardConfiguration] {
        dashboards.isEmpty ? [
            SavedDashboardConfiguration(
                id: UUID(),
                name: Self.defaultDashboardName,
                items: [],
                entityDisplayNameOverrides: [:]
            )
        ] : dashboards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let dashboards = try container.decodeIfPresent([SavedDashboardConfiguration].self, forKey: .dashboards) {
            self.init(dashboards: dashboards)
            return
        }

        let items = try container.decodeIfPresent([DashboardItemConfiguration].self, forKey: .items) ?? []
        let overrides = try container.decodeIfPresent([String: String].self, forKey: .entityDisplayNameOverrides) ?? [:]
        self.init(items: items, entityDisplayNameOverrides: overrides)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dashboards, forKey: .dashboards)
    }

    private enum CodingKeys: String, CodingKey {
        case dashboards
        case items
        case entityDisplayNameOverrides
    }

    private static let defaultDashboardName = "Dashboard"
}

private extension DashboardReorderGroup {
    func contains(_ item: DashboardItemConfiguration) -> Bool {
        switch self {
        case .chips:
            item.type == .chip
        case .cards:
            item.type != .chip
        }
    }
}
