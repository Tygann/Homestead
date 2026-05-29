import Foundation
import Observation

struct DashboardItemConfiguration: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var type: DashboardItemType
    var entityID: String?
    var title: String?
    var size: DashboardCardSize?

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
            size: size
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
            size: nil
        )
    }

    var resolvedTitle: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? "Untitled Section" : trimmedTitle
    }

    var resolvedCardSize: DashboardCardSize {
        size ?? .compact
    }

    var layoutMetadata: DashboardCardLayoutMetadata {
        switch type {
        case .entity:
            resolvedCardSize.layoutMetadata
        case .header:
            DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 1)
        }
    }
}

enum DashboardItemType: String, Codable, Equatable, Sendable {
    case entity
    case header
}

@MainActor
@Observable
final class DashboardConfiguration {
    private(set) var items: [DashboardItemConfiguration] {
        didSet { saveItems() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let itemsKey = "dashboardItems"
    @ObservationIgnored private let layoutVersionKey = "dashboardItems.layoutVersion"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = Self.loadItems(from: defaults, key: itemsKey, layoutVersionKey: layoutVersionKey)
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

    func renameHeader(id: UUID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.type == .header }) else {
            return
        }

        var updatedItems = items
        updatedItems[index].title = normalizedHeaderTitle(title)
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

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }

        defaults.set(data, forKey: itemsKey)
        defaults.set(Self.currentLayoutVersion, forKey: layoutVersionKey)
    }

    private func normalizedHeaderTitle(_ title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Section" : trimmedTitle
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
