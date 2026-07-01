import Foundation
import Observation

// MARK: - Dashboard Item Model

nonisolated enum DashboardSourceReference: Codable, Hashable, Sendable {
    case entity(String)
    case summary(DashboardSummaryKind)
}

nonisolated enum DashboardPresentationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case chip
    case control
    case status
    case gauge
    case graph
    case camera
    case weather
    case media
    case action
}

nonisolated enum DashboardCardConfiguration: Codable, Equatable, Sendable {
    case control(layout: DashboardCardSize, featureVisibility: DashboardCardFeatureVisibility)
    case status(layout: DashboardCardSize)
    case gauge(layout: DashboardCardSize)
    case graph(layout: DashboardCardSize)
    case camera(layout: DashboardCardSize)
    case weather(layout: DashboardCardSize)
    case media(layout: DashboardCardSize, featureVisibility: DashboardCardFeatureVisibility)
    case action(layout: DashboardCardSize)

    var kind: DashboardPresentationKind {
        switch self {
        case .control: .control
        case .status: .status
        case .gauge: .gauge
        case .graph: .graph
        case .camera: .camera
        case .weather: .weather
        case .media: .media
        case .action: .action
        }
    }

    var layout: DashboardCardSize {
        switch self {
        case .control(let layout, _), .media(let layout, _): layout
        case .status(let layout), .gauge(let layout), .graph(let layout), .camera(let layout),
             .weather(let layout), .action(let layout): layout
        }
    }

    var featureVisibility: DashboardCardFeatureVisibility {
        switch self {
        case .control(_, let visibility), .media(_, let visibility): visibility
        case .gauge: .automatic
        default: .hidden
        }
    }

    func withLayout(_ layout: DashboardCardSize) -> Self {
        switch self {
        case .control(_, let visibility): .control(layout: layout, featureVisibility: visibility)
        case .status: .status(layout: layout)
        case .gauge: .gauge(layout: layout)
        case .graph: .graph(layout: layout)
        case .camera: .camera(layout: layout)
        case .weather: .weather(layout: layout)
        case .media(_, let visibility): .media(layout: layout, featureVisibility: visibility)
        case .action: .action(layout: layout)
        }
    }

    func withFeatureVisibility(_ visibility: DashboardCardFeatureVisibility) -> Self {
        switch self {
        case .control(let layout, _): .control(layout: layout, featureVisibility: visibility)
        case .media(let layout, _): .media(layout: layout, featureVisibility: visibility)
        default: self
        }
    }
}

nonisolated enum DashboardPresentationConfiguration: Codable, Equatable, Sendable {
    case chip
    case card(DashboardCardConfiguration)

    var kind: DashboardPresentationKind {
        switch self {
        case .chip: .chip
        case .card(let card): card.kind
        }
    }

    var cardConfiguration: DashboardCardConfiguration? {
        guard case .card(let configuration) = self else { return nil }
        return configuration
    }
}

nonisolated struct DashboardSourcedItem: Codable, Equatable, Sendable {
    var source: DashboardSourceReference
    var presentation: DashboardPresentationConfiguration
}

nonisolated struct DashboardHeadingConfiguration: Codable, Equatable, Sendable {
    var title: String
}

nonisolated enum DashboardItemContent: Codable, Equatable, Sendable {
    case sourced(DashboardSourcedItem)
    case heading(DashboardHeadingConfiguration)
}

nonisolated struct DashboardItemCustomization: Codable, Equatable, Sendable {
    var displayNameOverride: String?
    var iconNameOverride: String?

    static let none = DashboardItemCustomization(displayNameOverride: nil, iconNameOverride: nil)
}

nonisolated enum DashboardItemRole: Equatable, Sendable {
    case card
    case chip
    case heading
}

nonisolated struct DashboardItemConfiguration: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var content: DashboardItemContent
    var customization: DashboardItemCustomization

    static func sourced(
        source: DashboardSourceReference,
        presentation: DashboardPresentationConfiguration,
        id: UUID = UUID()
    ) -> Self {
        DashboardItemConfiguration(
            id: id,
            content: .sourced(DashboardSourcedItem(source: source, presentation: presentation)),
            customization: .none
        )
    }

    static func entityCard(
        entityID: String,
        configuration: DashboardCardConfiguration,
        id: UUID = UUID()
    ) -> Self {
        sourced(source: .entity(entityID), presentation: .card(configuration), id: id)
    }

    static func header(title: String, id: UUID = UUID()) -> Self {
        DashboardItemConfiguration(
            id: id,
            content: .heading(DashboardHeadingConfiguration(title: title)),
            customization: .none
        )
    }

    static func summaryChip(kind: DashboardSummaryKind, id: UUID = UUID()) -> Self {
        sourced(source: .summary(kind), presentation: .chip, id: id)
    }

    static func entityChip(entityID: String, id: UUID = UUID()) -> Self {
        sourced(source: .entity(entityID), presentation: .chip, id: id)
    }

    var role: DashboardItemRole {
        switch content {
        case .heading: .heading
        case .sourced(let item):
            switch item.presentation {
            case .chip: .chip
            case .card: .card
            }
        }
    }

    var source: DashboardSourceReference? {
        guard case .sourced(let item) = content else { return nil }
        return item.source
    }

    var presentation: DashboardPresentationConfiguration? {
        guard case .sourced(let item) = content else { return nil }
        return item.presentation
    }

    var entityID: String? {
        guard case .entity(let entityID) = source else { return nil }
        return entityID
    }

    var summaryKind: DashboardSummaryKind? {
        guard case .summary(let kind) = source else { return nil }
        return kind
    }

    var cardConfiguration: DashboardCardConfiguration? {
        guard case .card(let configuration) = presentation else { return nil }
        return configuration
    }

    var displayNameOverride: String? {
        get { customization.displayNameOverride }
        set { customization.displayNameOverride = newValue }
    }

    var iconNameOverride: String? {
        get { customization.iconNameOverride }
        set { customization.iconNameOverride = newValue }
    }

    var resolvedTitle: String {
        guard case .heading(let heading) = content else { return "Untitled Section" }
        let trimmed = heading.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Section" : trimmed
    }

    var layoutMetadata: DashboardCardLayoutMetadata {
        switch role {
        case .card: cardConfiguration?.layout.layoutMetadata ?? DashboardCardSize.compact.layoutMetadata
        case .heading: DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 1)
        case .chip: DashboardCardLayoutMetadata(columnSpan: 2, rowSpan: 1)
        }
    }
}

nonisolated struct SavedDashboardConfiguration: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var displayTitle: String
    var items: [DashboardItemConfiguration]

    init(
        id: UUID,
        name: String,
        displayTitle: String = DashboardConfigurationDefaults.dashboardTitle,
        items: [DashboardItemConfiguration]
    ) {
        self.id = id
        self.name = name
        self.displayTitle = displayTitle
        self.items = items
    }

    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? DashboardConfigurationDefaults.untitledName : trimmed
    }

    var resolvedDisplayTitle: String {
        let trimmed = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? DashboardConfigurationDefaults.dashboardTitle : trimmed
    }
}

nonisolated struct DashboardConfigurationDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var dashboards: [SavedDashboardConfiguration]

    init(dashboards: [SavedDashboardConfiguration]) {
        schemaVersion = Self.currentSchemaVersion
        self.dashboards = dashboards
    }

    init(schemaVersion: Int, dashboards: [SavedDashboardConfiguration]) {
        self.schemaVersion = schemaVersion
        self.dashboards = dashboards
    }

    var isCurrentSchema: Bool { schemaVersion == Self.currentSchemaVersion }
}

nonisolated enum DashboardReorderGroup: Equatable, Sendable {
    case chips
    case cards
}

nonisolated struct DashboardPresentationIdentity: Hashable, Sendable {
    let source: DashboardSourceReference
    let kind: DashboardPresentationKind
}

// MARK: - Configuration Store

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
    @ObservationIgnored private let documentKey = "homestead.dashboard.configuration.v2"
    @ObservationIgnored private let selectedDashboardIDKey = "homestead.dashboard.selectedDashboardID.v2"
    @ObservationIgnored private let obsoleteKeys = [
        "dashboardItems",
        "entityDisplayNameOverrides",
        "homestead.dashboard.savedDashboards",
        "homestead.dashboard.selectedDashboardID"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.loadDocument(from: defaults, key: documentKey)
        obsoleteKeys.forEach(defaults.removeObject(forKey:))
        let normalizedDashboards = Self.normalizedDashboards(loaded?.dashboards ?? [])
        dashboards = normalizedDashboards
        selectedDashboardID = Self.loadSelectedDashboardID(
            from: defaults,
            key: selectedDashboardIDKey,
            dashboards: normalizedDashboards
        )

        if loaded == nil {
            defaults.removeObject(forKey: documentKey)
            defaults.removeObject(forKey: selectedDashboardIDKey)
            selectedDashboardID = dashboards[0].id
            saveDashboards()
            saveSelectedDashboardID()
        }
    }

    var hasCustomLayout: Bool { !items.isEmpty }
    var syncSnapshot: DashboardConfigurationSyncSnapshot { DashboardConfigurationSyncSnapshot(dashboards: dashboards) }
    var selectedDashboard: SavedDashboardConfiguration { dashboards.first { $0.id == selectedDashboardID } ?? dashboards[0] }
    var items: [DashboardItemConfiguration] { selectedDashboard.items }
    var entityIDs: [String] { items.compactMap { $0.role == .card ? $0.entityID : nil } }

    // MARK: Lifecycle

    func seedIfNeeded(from entities: [HomeEntity]) {
        guard items.isEmpty else { return }
        let seededItems = Self.defaultEntityIDs(from: entities).map { entityID in
            DashboardItemConfiguration.entityCard(
                entityID: entityID,
                configuration: .status(layout: .compact)
            )
        }
        updateSelectedDashboardItems(seededItems)
    }

    func reconcile(with entities: [HomeEntity]) {
        reconcile(withAvailableEntityIDs: Set(entities.map(\.entityID)))
        seedIfNeeded(from: entities)
    }

    func reconcile(with entityBoxes: [HAEntityState]) {
        let boxesByID = Dictionary(uniqueKeysWithValues: entityBoxes.map { ($0.entityID, $0) })
        let compatibleItems = DashboardConfigurationValidator.normalizedItems(items).filter { item in
            guard case .entity(let entityID) = item.source,
                  case .card(let card) = item.presentation,
                  let entityBox = boxesByID[entityID] else {
                return true
            }
            return DashboardPresentationCatalog.isCompatible(card.kind, with: entityBox)
        }
        if compatibleItems != items { updateSelectedDashboardItems(compatibleItems) }

        guard self.items.isEmpty else { return }
        let seededItems = entityBoxes
            .sorted {
                if $0.domain.dashboardPriority != $1.domain.dashboardPriority {
                    return $0.domain.dashboardPriority < $1.domain.dashboardPriority
                }
                return $0.homeEntity.displayName.localizedCaseInsensitiveCompare($1.homeEntity.displayName) == .orderedAscending
            }
            .prefix(10)
            .map { entityBox in
                DashboardItemConfiguration.sourced(
                    source: .entity(entityBox.entityID),
                    presentation: DashboardPresentationCatalog.recommendation(for: entityBox)
                )
            }
        updateSelectedDashboardItems(seededItems)
    }

    func reconcile(withAvailableEntityIDs _: Set<String>) {
        let normalized = DashboardConfigurationValidator.normalizedItems(items)
        if normalized != items { updateSelectedDashboardItems(normalized) }
    }

    // MARK: Queries

    func visibleItems(from entities: [HomeEntity]) -> [DashboardItemConfiguration] {
        visibleItems(fromAvailableEntityIDs: Set(entities.map(\.entityID)))
    }

    func visibleItems(fromAvailableEntityIDs availableIDs: Set<String>) -> [DashboardItemConfiguration] {
        items.filter { item in
            switch item.content {
            case .heading:
                true
            case .sourced(let sourced):
                switch sourced.source {
                case .summary:
                    true
                case .entity(let entityID):
                    availableIDs.contains(entityID)
                }
            }
        }
    }

    func visibleEntityIDs(from entities: [HomeEntity]) -> [String] {
        visibleEntityIDs(fromAvailableEntityIDs: Set(entities.map(\.entityID)))
    }

    func visibleEntityIDs(fromAvailableEntityIDs availableIDs: Set<String>) -> [String] {
        visibleItems(fromAvailableEntityIDs: availableIDs).compactMap { $0.role == .card ? $0.entityID : nil }
    }

    func addableEntityIDs(fromAvailableEntityIDs availableIDs: Set<String>) -> Set<String> {
        availableIDs.subtracting(Set(entityIDs))
    }

    func contains(_ entityID: String) -> Bool {
        items.contains { $0.entityID == entityID && $0.role == .card }
    }

    func itemRole(for itemID: UUID) -> DashboardItemRole? {
        items.first { $0.id == itemID }?.role
    }

    func contains(source: DashboardSourceReference, presentationKind: DashboardPresentationKind) -> Bool {
        items.contains { $0.source == source && $0.presentation?.kind == presentationKind }
    }

    // MARK: Mutations

    @discardableResult
    func add(source: DashboardSourceReference, presentation: DashboardPresentationConfiguration) -> UUID? {
        guard let item = DashboardConfigurationValidator.normalizedItem(
            .sourced(source: source, presentation: presentation)
        ) else { return nil }

        if let existing = items.first(where: {
            $0.source == source && $0.presentation?.kind == presentation.kind
        }) {
            return existing.id
        }

        appendSelectedDashboardItem(item)
        return item.id
    }

    func setEntity(_ entityID: String, isVisible: Bool) {
        if isVisible {
            _ = add(source: .entity(entityID), presentation: .card(.status(layout: .compact)))
        } else {
            remove(entityID)
        }
    }

    @discardableResult
    func addHeader(title: String) -> UUID {
        let item = DashboardItemConfiguration.header(title: normalizedHeaderTitle(title))
        appendSelectedDashboardItem(item)
        return item.id
    }

    @discardableResult
    func addSummaryChip(kind: DashboardSummaryKind) -> UUID {
        add(source: .summary(kind), presentation: .chip) ?? UUID()
    }

    @discardableResult
    func addEntityChip(entityID: String) -> UUID {
        add(source: .entity(entityID), presentation: .chip) ?? UUID()
    }

    func renameHeader(id: UUID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.role == .heading }) else { return }
        var updated = items
        updated[index].content = .heading(DashboardHeadingConfiguration(title: normalizedHeaderTitle(title)))
        updateSelectedDashboardItems(updated)
    }

    func renameDisplayItem(id: UUID, displayNameOverride: String?) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.role != .heading }) else { return }
        var updated = items
        updated[index].displayNameOverride = normalizedOverride(displayNameOverride)
        updateSelectedDashboardItems(updated)
    }

    func setIconNameOverride(_ iconNameOverride: String?, forItemID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID && $0.role != .heading }) else { return }
        var updated = items
        updated[index].iconNameOverride = normalizedOverride(iconNameOverride)
        updateSelectedDashboardItems(updated)
    }

    func remove(_ entityID: String) {
        updateSelectedDashboardItems(items.filter { $0.entityID != entityID || $0.role != .card })
    }

    func removeItem(id: UUID) {
        updateSelectedDashboardItems(items.filter { $0.id != id })
    }

    func move(from source: IndexSet, to destination: Int) {
        var updated = items
        let moving = source.sorted().map { updated[$0] }
        for index in source.sorted(by: >) { updated.remove(at: index) }
        let target = destination - source.filter { $0 < destination }.count
        updated.insert(contentsOf: moving, at: target)
        updateSelectedDashboardItems(updated)
    }

    func moveItems(in group: DashboardReorderGroup, from source: IndexSet, to destination: Int) {
        let groupIndices = items.indices.filter { group.contains(items[$0]) }
        guard source.allSatisfy({ groupIndices.indices.contains($0) }), destination >= 0, destination <= groupIndices.count else { return }
        var reordered = groupIndices.map { items[$0] }
        let moving = source.sorted().map { reordered[$0] }
        for index in source.sorted(by: >) { reordered.remove(at: index) }
        let target = destination - source.filter { $0 < destination }.count
        reordered.insert(contentsOf: moving, at: target)
        var updated = items
        for (index, item) in zip(groupIndices, reordered) { updated[index] = item }
        updateSelectedDashboardItems(updated)
    }

    func moveVisibleGridItem(id: UUID, before targetID: UUID?, visibleGridItemIDs: [UUID]) {
        moveVisibleItems(id: id, before: targetID, visibleItemIDs: visibleGridItemIDs)
    }

    func moveVisibleChipItem(id: UUID, before targetID: UUID?, visibleChipItemIDs: [UUID]) {
        moveVisibleItems(id: id, before: targetID, visibleItemIDs: visibleChipItemIDs)
    }

    func reset(using entities: [HomeEntity]) {
        let resetItems = Self.defaultEntityIDs(from: entities).map {
            DashboardItemConfiguration.entityCard(entityID: $0, configuration: .status(layout: .compact))
        }
        updateSelectedDashboardItems(resetItems)
    }

    func cardConfiguration(forItemID itemID: UUID) -> DashboardCardConfiguration? {
        items.first { $0.id == itemID }?.cardConfiguration
    }

    func setCardLayout(_ layout: DashboardCardSize, forItemID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              let card = items[index].cardConfiguration else { return }
        let updatedCard = card.withLayout(layout)
        guard DashboardConfigurationValidator.isValid(updatedCard) else { return }
        var updated = items
        updated[index].content = .sourced(DashboardSourcedItem(
            source: updated[index].source!,
            presentation: .card(updatedCard)
        ))
        updateSelectedDashboardItems(updated)
    }

    func featureVisibility(forItemID itemID: UUID) -> DashboardCardFeatureVisibility {
        cardConfiguration(forItemID: itemID)?.featureVisibility ?? .hidden
    }

    func setFeatureVisibility(_ visibility: DashboardCardFeatureVisibility, forItemID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              let card = items[index].cardConfiguration else { return }
        let updatedCard = card.withFeatureVisibility(visibility)
        var updated = items
        updated[index].content = .sourced(DashboardSourcedItem(
            source: updated[index].source!,
            presentation: .card(updatedCard)
        ))
        updateSelectedDashboardItems(updated)
    }

    // MARK: Saved Dashboards

    func applySyncSnapshot(_ snapshot: DashboardConfigurationSyncSnapshot) {
        dashboards = Self.normalizedDashboards(snapshot.dashboards)
        ensureSelectedDashboardExists()
    }

    @discardableResult
    func selectDashboard(id: UUID) -> Bool {
        guard dashboards.contains(where: { $0.id == id }) else { ensureSelectedDashboardExists(); return false }
        selectedDashboardID = id
        return true
    }

    @discardableResult
    func createDashboard(named name: String = DashboardConfigurationDefaults.dashboardName) -> UUID {
        let dashboard = SavedDashboardConfiguration(
            id: UUID(),
            name: uniqueDashboardName(normalizedDashboardName(name)),
            displayTitle: DashboardConfigurationDefaults.dashboardTitle,
            items: []
        )
        dashboards.append(dashboard)
        selectedDashboardID = dashboard.id
        return dashboard.id
    }

    @discardableResult
    func duplicateSelectedDashboard() -> UUID {
        let id = duplicateDashboard(id: selectedDashboardID)
        selectedDashboardID = id
        return id
    }

    @discardableResult
    func duplicateDashboard(id: UUID) -> UUID {
        let source = dashboards.first(where: { $0.id == id }) ?? selectedDashboard
        let dashboard = SavedDashboardConfiguration(
            id: UUID(),
            name: uniqueDashboardName("Copy of \(source.resolvedName)"),
            displayTitle: source.resolvedDisplayTitle,
            items: source.items.map { item in var copy = item; copy.id = UUID(); return copy }
        )
        dashboards.append(dashboard)
        return dashboard.id
    }

    @discardableResult
    func duplicateDashboard(id: UUID, named name: String) -> UUID {
        let duplicateID = duplicateDashboard(id: id)
        renameDashboard(id: duplicateID, name: name)
        return duplicateID
    }

    func renameDashboard(id: UUID, name: String) {
        guard let index = dashboards.firstIndex(where: { $0.id == id }) else { return }
        var updated = dashboards
        updated[index].name = uniqueDashboardName(normalizedDashboardName(name), excluding: id)
        dashboards = updated
    }

    func setDashboardDisplayTitle(id: UUID, title: String) {
        guard let index = dashboards.firstIndex(where: { $0.id == id }) else { return }
        var updated = dashboards
        updated[index].displayTitle = normalizedDashboardDisplayTitle(title)
        dashboards = updated
    }

    func deleteDashboard(id: UUID) {
        dashboards = Self.normalizedDashboards(dashboards.filter { $0.id != id })
        ensureSelectedDashboardExists()
    }

    func moveDashboards(from source: IndexSet, to destination: Int) {
        var updated = dashboards
        let moving = source.sorted().map { updated[$0] }
        for index in source.sorted(by: >) { updated.remove(at: index) }
        let target = destination - source.filter { $0 < destination }.count
        updated.insert(contentsOf: moving, at: target)
        dashboards = updated
        ensureSelectedDashboardExists()
    }

    // MARK: Private Helpers

    private func moveVisibleItems(id movingID: UUID, before targetID: UUID?, visibleItemIDs: [UUID]) {
        let ordered = visibleItemIDs.reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }
        guard ordered.contains(movingID), targetID != movingID, targetID.map(ordered.contains) ?? true else { return }
        var reordered = ordered.filter { $0 != movingID }
        reordered.insert(movingID, at: targetID.flatMap(reordered.firstIndex(of:)) ?? reordered.count)
        guard reordered != ordered else { return }
        let visibleSet = Set(ordered)
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var iterator = reordered.makeIterator()
        var updated = items
        for index in updated.indices where visibleSet.contains(updated[index].id) {
            guard let id = iterator.next(), let item = byID[id] else { return }
            updated[index] = item
        }
        updateSelectedDashboardItems(updated)
    }

    private func saveDashboards() {
        guard let data = try? JSONEncoder().encode(DashboardConfigurationDocument(dashboards: dashboards)) else { return }
        defaults.set(data, forKey: documentKey)
    }

    private func saveSelectedDashboardID() {
        defaults.set(selectedDashboardID.uuidString, forKey: selectedDashboardIDKey)
    }

    private func updateSelectedDashboardItems(_ items: [DashboardItemConfiguration]) {
        updateSelectedDashboard { $0.items = DashboardConfigurationValidator.normalizedItems(items) }
    }

    private func appendSelectedDashboardItem(_ item: DashboardItemConfiguration) {
        updateSelectedDashboard { $0.items.append(item) }
    }

    private func updateSelectedDashboard(_ update: (inout SavedDashboardConfiguration) -> Void) {
        ensureSelectedDashboardExists()
        guard let index = dashboards.firstIndex(where: { $0.id == selectedDashboardID }) else { return }
        var updated = dashboards
        update(&updated[index])
        dashboards = updated
    }

    private func ensureSelectedDashboardExists() {
        if dashboards.isEmpty { dashboards = [Self.defaultDashboard()] }
        if !dashboards.contains(where: { $0.id == selectedDashboardID }) { selectedDashboardID = dashboards[0].id }
    }

    private func normalizedHeaderTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Section" : trimmed
    }

    private func normalizedOverride(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedDashboardName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? DashboardConfigurationDefaults.untitledName : trimmed
    }

    private func normalizedDashboardDisplayTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? DashboardConfigurationDefaults.dashboardTitle : trimmed
    }

    private func uniqueDashboardName(_ name: String, excluding excludedID: UUID? = nil) -> String {
        let names = Set(dashboards.compactMap { $0.id == excludedID ? nil : $0.resolvedName.lowercased() })
        guard names.contains(name.lowercased()) else { return name }
        for suffix in 2... where !names.contains("\(name) \(suffix)".lowercased()) { return "\(name) \(suffix)" }
        return name
    }

    private static func loadDocument(from defaults: UserDefaults, key: String) -> DashboardConfigurationDocument? {
        guard let data = defaults.data(forKey: key),
              let document = try? JSONDecoder().decode(DashboardConfigurationDocument.self, from: data),
              document.isCurrentSchema else { return nil }
        return DashboardConfigurationDocument(dashboards: normalizedDashboards(document.dashboards))
    }

    private static func loadSelectedDashboardID(from defaults: UserDefaults, key: String, dashboards: [SavedDashboardConfiguration]) -> UUID {
        if let value = defaults.string(forKey: key), let id = UUID(uuidString: value), dashboards.contains(where: { $0.id == id }) { return id }
        return dashboards[0].id
    }

    private static func defaultEntityIDs(from entities: [HomeEntity]) -> [String] {
        let sorted = entities.sorted {
            if $0.domain.dashboardPriority != $1.domain.dashboardPriority { return $0.domain.dashboardPriority < $1.domain.dashboardPriority }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        return Array(sorted.prefix(10).map(\.entityID))
    }

    private static func normalizedDashboards(_ dashboards: [SavedDashboardConfiguration]) -> [SavedDashboardConfiguration] {
        let normalized = dashboards.map {
            SavedDashboardConfiguration(
                id: $0.id,
                name: $0.resolvedName,
                displayTitle: $0.resolvedDisplayTitle,
                items: DashboardConfigurationValidator.normalizedItems($0.items)
            )
        }
        return normalized.isEmpty ? [defaultDashboard()] : normalized
    }

    private static func defaultDashboard() -> SavedDashboardConfiguration {
        SavedDashboardConfiguration(
            id: UUID(),
            name: DashboardConfigurationDefaults.dashboardName,
            displayTitle: DashboardConfigurationDefaults.dashboardTitle,
            items: []
        )
    }
}

// MARK: - Validation

nonisolated enum DashboardConfigurationValidator {
    static func normalizedItems(_ items: [DashboardItemConfiguration]) -> [DashboardItemConfiguration] {
        var identities = Set<DashboardPresentationIdentity>()
        return items.compactMap { item in
            guard let normalized = normalizedItem(item) else { return nil }
            guard let source = normalized.source, let kind = normalized.presentation?.kind else { return normalized }
            return identities.insert(DashboardPresentationIdentity(source: source, kind: kind)).inserted ? normalized : nil
        }
    }

    static func normalizedItem(_ item: DashboardItemConfiguration) -> DashboardItemConfiguration? {
        switch item.content {
        case .heading:
            return item
        case .sourced(let sourced):
            switch (sourced.source, sourced.presentation) {
            case (.summary, .chip):
                return item
            case (.summary, .card):
                return nil
            case (.entity, .chip):
                return item
            case (.entity, .card(let card)):
                return isValid(card) ? item : nil
            }
        }
    }

    static func isValid(_ card: DashboardCardConfiguration) -> Bool {
        switch card.kind {
        case .control, .status:
            return true
        case .gauge, .graph, .camera, .weather:
            return [.square, .wide, .large].contains(card.layout)
        case .media:
            return [.compact, .row, .square, .wide, .large].contains(card.layout)
        case .action:
            return [.mini, .compact, .row, .square].contains(card.layout)
        case .chip:
            return false
        }
    }

}

// MARK: - iCloud Snapshot

nonisolated struct DashboardConfigurationSyncSnapshot: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var dashboards: [SavedDashboardConfiguration]

    init(dashboards: [SavedDashboardConfiguration]) {
        schemaVersion = DashboardConfigurationDocument.currentSchemaVersion
        self.dashboards = dashboards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        schemaVersion = DashboardConfigurationDocument.currentSchemaVersion
        guard decodedVersion == DashboardConfigurationDocument.currentSchemaVersion else {
            dashboards = []
            return
        }
        dashboards = (try? container.decode([SavedDashboardConfiguration].self, forKey: .dashboards)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(DashboardConfigurationDocument.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(dashboards, forKey: .dashboards)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case dashboards
    }
}

nonisolated private enum DashboardConfigurationDefaults {
    static let dashboardName = "Dashboard"
    static let dashboardTitle = "Dashboard"
    static let untitledName = "Untitled Dashboard"
}

private extension DashboardReorderGroup {
    func contains(_ item: DashboardItemConfiguration) -> Bool {
        switch self {
        case .chips: item.role == .chip
        case .cards: item.role != .chip
        }
    }
}
