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

@MainActor
@Observable
final class DashboardConfiguration {
    private(set) var items: [DashboardItemConfiguration] {
        didSet { saveItems() }
    }
    private(set) var entityDisplayNameOverrides: [String: String] {
        didSet { saveEntityDisplayNameOverrides() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let itemsKey = "dashboardItems"
    @ObservationIgnored private let layoutVersionKey = "dashboardItems.layoutVersion"
    @ObservationIgnored private let entityDisplayNameOverridesKey = "entityDisplayNameOverrides"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = Self.loadItems(from: defaults, key: itemsKey, layoutVersionKey: layoutVersionKey)
        entityDisplayNameOverrides = Self.loadEntityDisplayNameOverrides(from: defaults, key: entityDisplayNameOverridesKey)
        migrateEntityItemDisplayNameOverridesIfNeeded()
    }

    var hasCustomLayout: Bool {
        !items.isEmpty
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

        items = Self.defaultEntityIDs(from: entities).map {
            DashboardItemConfiguration.entity(entityID: $0)
        }
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
            items = currentItems
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
    func add(_ entityID: String) -> UUID {
        if let existingItem = items.first(where: { $0.type == .entity && $0.entityID == entityID }) {
            return existingItem.id
        }

        let item = DashboardItemConfiguration.entity(entityID: entityID)
        items.append(item)
        return item.id
    }

    @discardableResult
    func addHeader(title: String) -> UUID {
        let item = DashboardItemConfiguration.header(title: normalizedHeaderTitle(title))
        items.append(item)
        return item.id
    }

    @discardableResult
    func addSummaryChip(kind: DashboardSummaryKind) -> UUID {
        if let existingItem = items.first(where: { $0.type == .chip && $0.chipKind == .summary && $0.summaryKind == kind }) {
            return existingItem.id
        }

        let item = DashboardItemConfiguration.summaryChip(kind: kind)
        items.append(item)
        return item.id
    }

    @discardableResult
    func addEntityChip(entityID: String) -> UUID {
        let item = DashboardItemConfiguration.entityChip(entityID: entityID)
        items.append(item)
        return item.id
    }

    func renameHeader(id: UUID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.type == .header }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].title = normalizedHeaderTitle(title)
        items = updatedItems
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
        items = updatedItems
    }

    func entityDisplayNameOverride(for entityID: String) -> String? {
        entityDisplayNameOverrides[entityID]
    }

    func setEntityDisplayNameOverride(_ displayNameOverride: String?, for entityID: String) {
        var updatedOverrides = entityDisplayNameOverrides
        updatedOverrides[entityID] = normalizedDisplayNameOverride(displayNameOverride)
        entityDisplayNameOverrides = updatedOverrides
    }

    func setIconNameOverride(_ iconNameOverride: String?, forItemID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID && ($0.type == .entity || $0.type == .chip) }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].iconNameOverride = normalizedDisplayNameOverride(iconNameOverride)
        items = updatedItems
    }

    func remove(_ entityID: String) {
        items.removeAll { $0.type == .entity && $0.entityID == entityID }
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func move(from source: IndexSet, to destination: Int) {
        let movingItems = source.sorted().map { items[$0] }
        var updatedItems = items

        for index in source.sorted(by: >) {
            updatedItems.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        updatedItems.insert(contentsOf: movingItems, at: adjustedDestination)
        items = updatedItems
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
        items = updatedItems
    }

    func reset(using entities: [HomeEntity]) {
        items = Self.defaultEntityIDs(from: entities).map {
            DashboardItemConfiguration.entity(entityID: $0)
        }
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
        items = updatedItems
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
        items = updatedItems
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }

        defaults.set(data, forKey: itemsKey)
        defaults.set(Self.currentLayoutVersion, forKey: layoutVersionKey)
    }

    private func saveEntityDisplayNameOverrides() {
        guard let data = try? JSONEncoder().encode(entityDisplayNameOverrides) else {
            return
        }

        defaults.set(data, forKey: entityDisplayNameOverridesKey)
    }

    private func normalizedHeaderTitle(_ title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Section" : trimmedTitle
    }

    private func normalizedDisplayNameOverride(_ title: String?) -> String? {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? nil : trimmedTitle
    }

    private static func loadItems(
        from defaults: UserDefaults,
        key: String,
        layoutVersionKey: String
    ) -> [DashboardItemConfiguration] {
        guard var data = defaults.data(forKey: key) else {
            return []
        }

        if defaults.integer(forKey: layoutVersionKey) < currentLayoutVersion,
           let migratedData = migrateLegacyCardSizes(in: data) {
            data = migratedData
            defaults.set(migratedData, forKey: key)
            defaults.set(currentLayoutVersion, forKey: layoutVersionKey)
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

    private func migrateEntityItemDisplayNameOverridesIfNeeded() {
        var updatedItems = items
        var updatedOverrides = entityDisplayNameOverrides
        var didMigrate = false

        for index in updatedItems.indices {
            guard updatedItems[index].type == .entity,
                  let entityID = updatedItems[index].entityID,
                  let displayNameOverride = normalizedDisplayNameOverride(updatedItems[index].displayNameOverride) else {
                continue
            }

            if updatedOverrides[entityID] == nil {
                updatedOverrides[entityID] = displayNameOverride
            }
            updatedItems[index].displayNameOverride = nil
            didMigrate = true
        }

        guard didMigrate else {
            return
        }

        items = updatedItems
        entityDisplayNameOverrides = updatedOverrides
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

    private static func migrateLegacyCardSizes(in data: Data) -> Data? {
        guard var items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        var didMigrate = false
        for index in items.indices where items[index]["size"] as? String == "large" {
            items[index]["size"] = DashboardCardSize.square.rawValue
            didMigrate = true
        }

        guard didMigrate else {
            return data
        }

        return try? JSONSerialization.data(withJSONObject: items)
    }

    private static let currentLayoutVersion = 2
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
