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
    case circularGauge
    case segmentedGauge
    case barGauge
    case chart
    case camera
    case weather
    case media
    case action

    var supportedLayouts: [DashboardCardSize] {
        switch self {
        case .chip:
            []
        case .control, .status:
            DashboardCardSize.allCases
        case .circularGauge, .segmentedGauge, .barGauge, .chart, .camera, .weather:
            [.square, .wide, .large]
        case .media:
            [.compact, .row, .square, .wide, .large]
        case .action:
            [.mini, .compact, .row, .square]
        }
    }

    var defaultLayout: DashboardCardSize? {
        switch self {
        case .chip:
            nil
        case .control, .status, .media, .action:
            .compact
        case .chart:
            .wide
        case .circularGauge, .segmentedGauge, .barGauge, .camera, .weather:
            .square
        }
    }
}

nonisolated enum DashboardCardConfiguration: Codable, Equatable, Sendable {
    case control(layout: DashboardCardSize)
    case status(layout: DashboardCardSize)
    case circularGauge(layout: DashboardCardSize)
    case segmentedGauge(layout: DashboardCardSize)
    case barGauge(layout: DashboardCardSize)
    case chart(layout: DashboardCardSize)
    case camera(layout: DashboardCardSize)
    case weather(layout: DashboardCardSize)
    case media(layout: DashboardCardSize)
    case action(layout: DashboardCardSize)

    var kind: DashboardPresentationKind {
        switch self {
        case .control: .control
        case .status: .status
        case .circularGauge: .circularGauge
        case .segmentedGauge: .segmentedGauge
        case .barGauge: .barGauge
        case .chart: .chart
        case .camera: .camera
        case .weather: .weather
        case .media: .media
        case .action: .action
        }
    }

    var layout: DashboardCardSize {
        switch self {
        case .control(let layout), .status(let layout), .circularGauge(let layout),
             .segmentedGauge(let layout), .media(let layout),
             .barGauge(let layout), .chart(let layout), .camera(let layout),
             .weather(let layout), .action(let layout): layout
        }
    }

    func withLayout(_ layout: DashboardCardSize) -> Self {
        switch self {
        case .control:
            .control(layout: layout)
        case .status: .status(layout: layout)
        case .circularGauge: .circularGauge(layout: layout)
        case .segmentedGauge: .segmentedGauge(layout: layout)
        case .barGauge: .barGauge(layout: layout)
        case .chart: .chart(layout: layout)
        case .camera: .camera(layout: layout)
        case .weather: .weather(layout: layout)
        case .media: .media(layout: layout)
        case .action: .action(layout: layout)
        }
    }
}

nonisolated struct DashboardChartConfiguration: Codable, Equatable, Sendable {
    static let `default` = DashboardChartConfiguration(range: .sixHours)

    var range: HAHistoryRangePreset

    var isValid: Bool {
        HAHistoryRangePreset.dashboardChartPresets.contains(range)
    }
}

nonisolated struct DashboardCardUpdate: Equatable, Sendable {
    let entityID: String
    let configuration: DashboardCardConfiguration
    let displayNameOverride: String?
    let iconNameOverride: String?
    let gaugeZoneConfiguration: GaugeZoneConfiguration?
    let chartConfiguration: DashboardChartConfiguration
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
    var gaugeZoneConfiguration: GaugeZoneConfiguration?
    var chartConfiguration: DashboardChartConfiguration?

    static let none = DashboardItemCustomization(
        displayNameOverride: nil,
        iconNameOverride: nil,
        gaugeZoneConfiguration: nil,
        chartConfiguration: nil
    )
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

    var gaugeZoneConfiguration: GaugeZoneConfiguration? {
        get { customization.gaugeZoneConfiguration }
        set { customization.gaugeZoneConfiguration = newValue }
    }

    var chartConfiguration: DashboardChartConfiguration? {
        get { customization.chartConfiguration }
        set { customization.chartConfiguration = newValue }
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

nonisolated enum DashboardSetupState: String, Codable, Equatable, Sendable {
    case notChosen
    case suggested
    case manual
    case intentionallyEmpty
}

nonisolated struct SavedDashboardConfiguration: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var displayTitle: String
    var items: [DashboardItemConfiguration]
    var setupState: DashboardSetupState

    init(
        id: UUID,
        name: String,
        displayTitle: String = DashboardConfigurationDefaults.dashboardTitle,
        items: [DashboardItemConfiguration],
        setupState: DashboardSetupState? = nil
    ) {
        self.id = id
        self.name = name
        self.displayTitle = displayTitle
        self.items = items
        self.setupState = setupState ?? (items.isEmpty ? .notChosen : .manual)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayTitle
        case items
        case setupState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayTitle = try container.decodeIfPresent(String.self, forKey: .displayTitle)
            ?? DashboardConfigurationDefaults.dashboardTitle
        items = try container.decodeIfPresent(
            LossyDecodableArray<DashboardItemConfiguration>.self,
            forKey: .items
        )?.elements ?? []
        setupState = try container.decodeIfPresent(DashboardSetupState.self, forKey: .setupState)
            ?? (items.isEmpty ? .intentionallyEmpty : .manual)
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

// MARK: - Suggested Setup

nonisolated struct DashboardSuggestionCandidate: Equatable, Sendable {
    let entityID: String
    let domain: EntityDomain
    let displayName: String
    let isAvailable: Bool
    let isHidden: Bool
    let entityCategory: String?
    let deviceClass: String?
    let presentation: DashboardPresentationConfiguration
}

nonisolated enum DashboardSuggestedSetup {
    static let maximumItemCount = 8

    static func items(from candidates: [DashboardSuggestionCandidate]) -> [DashboardItemConfiguration] {
        var domainCounts: [EntityDomain: Int] = [:]
        var seenEntityIDs = Set<String>()

        return candidates
            .filter(isEligible)
            .sorted(by: isHigherQuality)
            .compactMap { candidate in
                guard seenEntityIDs.insert(candidate.entityID).inserted else { return nil }
                let count = domainCounts[candidate.domain, default: 0]
                guard count < domainLimit(candidate.domain) else { return nil }
                domainCounts[candidate.domain] = count + 1
                return DashboardItemConfiguration.sourced(
                    source: .entity(candidate.entityID),
                    presentation: candidate.presentation
                )
            }
            .prefix(maximumItemCount)
            .map { $0 }
    }

    private static func isEligible(_ candidate: DashboardSuggestionCandidate) -> Bool {
        guard candidate.isAvailable,
              !candidate.isHidden,
              candidate.entityCategory == nil else {
            return false
        }

        switch candidate.domain {
        case .light, .climate, .lock, .cover, .fan, .weather:
            return true
        case .scene, .script:
            return !containsTechnicalName(candidate)
        case .sensor:
            return usefulSensorDeviceClasses.contains(candidate.deviceClass ?? "")
        default:
            return false
        }
    }

    private static func isHigherQuality(
        _ lhs: DashboardSuggestionCandidate,
        _ rhs: DashboardSuggestionCandidate
    ) -> Bool {
        let lhsRank = domainRank(lhs.domain)
        let rhsRank = domainRank(rhs.domain)
        if lhsRank != rhsRank { return lhsRank < rhsRank }

        let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.entityID.localizedCaseInsensitiveCompare(rhs.entityID) == .orderedAscending
    }

    private static func domainRank(_ domain: EntityDomain) -> Int {
        switch domain {
        case .light: 0
        case .climate: 1
        case .lock: 2
        case .cover: 3
        case .fan: 4
        case .weather: 5
        case .scene: 6
        case .script: 7
        case .sensor: 8
        default: 100
        }
    }

    private static func domainLimit(_ domain: EntityDomain) -> Int {
        switch domain {
        case .light: 3
        case .cover: 2
        case .sensor: 2
        default: 1
        }
    }

    private static func containsTechnicalName(_ candidate: DashboardSuggestionCandidate) -> Bool {
        let searchableText = "\(candidate.displayName) \(candidate.entityID)".lowercased()
        return ["debug", "notification", "reload", "restart", "test"].contains {
            searchableText.contains($0)
        }
    }

    private static let usefulSensorDeviceClasses: Set<String> = [
        "air_quality",
        "carbon_dioxide",
        "humidity",
        "pm1",
        "pm10",
        "pm25",
        "temperature"
    ]
}

nonisolated struct DashboardConfigurationDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 6

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

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case dashboards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        dashboards = try container.decodeIfPresent(
            LossyDecodableArray<SavedDashboardConfiguration>.self,
            forKey: .dashboards
        )?.elements ?? []
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

    init(source: DashboardSourceReference, presentation: DashboardPresentationConfiguration) {
        self.source = source
        kind = presentation.kind
    }
}

nonisolated private enum StoredDashboardDocumentState {
    case missing
    case loaded(DashboardConfigurationDocument)
    case newerSchema(version: Int)
    case unrecoverable

    var document: DashboardConfigurationDocument? {
        guard case .loaded(let document) = self else { return nil }
        return document
    }

    var isNewerSchema: Bool {
        guard case .newerSchema = self else { return false }
        return true
    }

    var canUseLegacyFallback: Bool {
        switch self {
        case .missing, .unrecoverable: true
        case .loaded, .newerSchema: false
        }
    }

    var shouldCreateFreshDocument: Bool {
        switch self {
        case .missing, .unrecoverable: true
        case .loaded, .newerSchema: false
        }
    }
}

// MARK: - Configuration Store

@MainActor
@Observable
final class DashboardConfiguration {
    private(set) var dashboards: [SavedDashboardConfiguration] {
        didSet {
            if !isSwitchingProfile { saveDashboards() }
        }
    }

    private(set) var selectedDashboardID: UUID {
        didSet {
            if !isSwitchingProfile { saveSelectedDashboardID() }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var activeProfileID: UUID?
    @ObservationIgnored private var isSwitchingProfile = false
    @ObservationIgnored private var protectsNewerDashboardSchema = false
    @ObservationIgnored private var documentKey: String {
        Self.documentKey(profileID: activeProfileID)
    }
    @ObservationIgnored private var selectedDashboardIDKey: String {
        Self.selectedDashboardIDKey(profileID: activeProfileID)
    }
    @ObservationIgnored private let obsoleteKeys = [
        "dashboardItems",
        "entityDisplayNameOverrides",
        "homestead.dashboard.savedDashboards",
        "homestead.dashboard.selectedDashboardID",
        "homestead.dashboard.configuration.v2",
        "homestead.dashboard.selectedDashboardID.v2"
    ]

    init(defaults: UserDefaults = .standard, profileID: UUID? = nil) {
        self.defaults = defaults
        activeProfileID = profileID
        let profileDocumentKey = Self.documentKey(profileID: profileID)
        let profileSelectedKey = Self.selectedDashboardIDKey(profileID: profileID)
        let primaryState = Self.loadDocumentState(from: defaults, key: profileDocumentKey)
        let state: StoredDashboardDocumentState
        let selectedKey: String
        if profileID != nil, primaryState.canUseLegacyFallback {
            let legacyState = Self.loadDocumentState(from: defaults, key: Self.legacyDocumentKey)
            if legacyState.document != nil || legacyState.isNewerSchema {
                state = legacyState
                selectedKey = Self.legacySelectedDashboardIDKey
            } else {
                state = primaryState
                selectedKey = profileSelectedKey
            }
        } else {
            state = primaryState
            selectedKey = profileSelectedKey
        }
        obsoleteKeys.forEach(defaults.removeObject(forKey:))
        protectsNewerDashboardSchema = state.isNewerSchema
        let normalizedDashboards = Self.normalizedDashboards(state.document?.dashboards ?? [])
        dashboards = normalizedDashboards
        selectedDashboardID = Self.loadSelectedDashboardID(
            from: defaults,
            key: selectedKey,
            dashboards: normalizedDashboards
        )

        if state.shouldCreateFreshDocument {
            selectedDashboardID = dashboards[0].id
        }
        saveDashboards()
        saveSelectedDashboardID()
    }

    var hasCustomLayout: Bool { !items.isEmpty }
    var syncSnapshot: DashboardConfigurationSyncSnapshot { DashboardConfigurationSyncSnapshot(dashboards: dashboards) }

    func syncSnapshots(profileIDs: [UUID]) -> [UUID: DashboardConfigurationSyncSnapshot] {
        Dictionary(uniqueKeysWithValues: profileIDs.compactMap { profileID in
            let state = Self.loadDocumentState(from: defaults, key: Self.documentKey(profileID: profileID))
            guard !state.isNewerSchema else { return nil }
            let dashboards = Self.normalizedDashboards(state.document?.dashboards ?? [])
            return (profileID, DashboardConfigurationSyncSnapshot(dashboards: dashboards))
        })
    }

    @discardableResult
    func applyProfileSyncSnapshots(_ snapshots: [UUID: DashboardConfigurationSyncSnapshot]) -> Bool {
        guard snapshots.values.allSatisfy(\.isCompatible) else { return false }
        let targetKeys = snapshots.keys.map { Self.documentKey(profileID: $0) }
        guard targetKeys.allSatisfy({
            !Self.loadDocumentState(from: defaults, key: $0).isNewerSchema
        }) else { return false }
        let encodedDocuments = snapshots.compactMap { profileID, snapshot -> (UUID, Data)? in
            let document = DashboardConfigurationDocument(dashboards: Self.normalizedDashboards(snapshot.dashboards))
            guard let data = try? JSONEncoder().encode(document) else { return nil }
            return (profileID, data)
        }
        guard encodedDocuments.count == snapshots.count else { return false }
        for (profileID, data) in encodedDocuments {
            Self.storeDocument(data, in: defaults, key: Self.documentKey(profileID: profileID))
        }
        if let activeProfileID, let active = snapshots[activeProfileID] {
            applySyncSnapshot(active)
        }
        return true
    }
    var selectedDashboard: SavedDashboardConfiguration { dashboards.first { $0.id == selectedDashboardID } ?? dashboards[0] }
    var items: [DashboardItemConfiguration] { selectedDashboard.items }
    var setupState: DashboardSetupState { selectedDashboard.setupState }
    var presentationCounts: [DashboardPresentationIdentity: Int] {
        items.reduce(into: [:]) { counts, item in
            guard let source = item.source,
                  let presentation = item.presentation else {
                return
            }
            counts[DashboardPresentationIdentity(source: source, presentation: presentation), default: 0] += 1
        }
    }

    var sourceCounts: [DashboardSourceReference: Int] {
        items.reduce(into: [:]) { counts, item in
            guard let source = item.source else { return }
            counts[source, default: 0] += 1
        }
    }

    // MARK: Lifecycle

    func activateProfile(_ profileID: UUID) {
        guard activeProfileID != profileID else { return }
        isSwitchingProfile = true
        activeProfileID = profileID
        let state = Self.loadDocumentState(from: defaults, key: documentKey)
        protectsNewerDashboardSchema = state.isNewerSchema
        let normalized = Self.normalizedDashboards(state.document?.dashboards ?? [])
        dashboards = normalized
        selectedDashboardID = Self.loadSelectedDashboardID(
            from: defaults,
            key: selectedDashboardIDKey,
            dashboards: normalized
        )
        isSwitchingProfile = false
        saveDashboards()
        saveSelectedDashboardID()
    }

    func removeProfileData(_ profileID: UUID) {
        let key = Self.documentKey(profileID: profileID)
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: Self.backupDocumentKey(for: key))
        defaults.removeObject(forKey: Self.rejectedDocumentKey(for: key))
        defaults.removeObject(forKey: Self.selectedDashboardIDKey(profileID: profileID))
    }

    func reconcile(with entityBoxes: [HAEntityState]) {
        let boxesByID = Dictionary(uniqueKeysWithValues: entityBoxes.map { ($0.entityID, $0) })
        let compatibleItems = DashboardConfigurationValidator.normalizedItems(items).filter { item in
            guard case .entity(let entityID) = item.source,
                  case .card(let card) = item.presentation,
                  let entityBox = boxesByID[entityID] else {
                return true
            }
            return DashboardPresentationCatalog.isCompatible(card, with: entityBox)
        }
        if compatibleItems != items { updateSelectedDashboardItems(compatibleItems) }

    }

    // MARK: Queries

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

    func itemRole(for itemID: UUID) -> DashboardItemRole? {
        items.first { $0.id == itemID }?.role
    }

    func item(for reference: DashboardItemReference) -> DashboardItemConfiguration? {
        dashboards
            .first(where: { $0.id == reference.dashboardID })?
            .items
            .first(where: { $0.id == reference.itemID })
    }

    func dashboardName(for reference: DashboardItemReference) -> String? {
        dashboards.first(where: { $0.id == reference.dashboardID })?.resolvedName
    }

    @discardableResult
    func updateItem(
        for reference: DashboardItemReference,
        _ update: (inout DashboardItemConfiguration) -> Void
    ) -> Bool {
        guard let dashboardIndex = dashboards.firstIndex(where: { $0.id == reference.dashboardID }),
              let itemIndex = dashboards[dashboardIndex].items.firstIndex(where: { $0.id == reference.itemID }) else {
            return false
        }

        var updatedDashboards = dashboards
        update(&updatedDashboards[dashboardIndex].items[itemIndex])
        updatedDashboards[dashboardIndex].items = DashboardConfigurationValidator.normalizedItems(
            updatedDashboards[dashboardIndex].items
        )
        updatedDashboards[dashboardIndex].setupState = .manual
        dashboards = updatedDashboards
        return true
    }

    @discardableResult
    func applyCardUpdate(
        _ update: DashboardCardUpdate,
        for reference: DashboardItemReference
    ) -> Bool {
        let entityID = update.entityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entityID.isEmpty,
              item(for: reference)?.role == .card,
              DashboardConfigurationValidator.isValid(update.configuration),
              update.gaugeZoneConfiguration?.isValid != false,
              update.chartConfiguration.isValid else {
            return false
        }

        let gaugeKinds: Set<DashboardPresentationKind> = [
            .circularGauge,
            .segmentedGauge,
            .barGauge
        ]
        guard update.gaugeZoneConfiguration == nil || gaugeKinds.contains(update.configuration.kind),
              update.configuration.kind == .chart || update.chartConfiguration == .default else {
            return false
        }

        return updateItem(for: reference) { item in
            item.content = .sourced(DashboardSourcedItem(
                source: .entity(entityID),
                presentation: .card(update.configuration)
            ))
            item.displayNameOverride = normalizedOverride(update.displayNameOverride)
            item.iconNameOverride = normalizedOverride(update.iconNameOverride)
            item.gaugeZoneConfiguration = update.gaugeZoneConfiguration
            item.chartConfiguration = update.configuration.kind == .chart && update.chartConfiguration != .default
                ? update.chartConfiguration
                : nil
        }
    }

    @discardableResult
    func removeItem(for reference: DashboardItemReference) -> Bool {
        guard let dashboardIndex = dashboards.firstIndex(where: { $0.id == reference.dashboardID }),
              dashboards[dashboardIndex].items.contains(where: { $0.id == reference.itemID }) else {
            return false
        }

        var updatedDashboards = dashboards
        updatedDashboards[dashboardIndex].items.removeAll { $0.id == reference.itemID }
        updatedDashboards[dashboardIndex].setupState = updatedDashboards[dashboardIndex].items.isEmpty
            ? .intentionallyEmpty
            : .manual
        dashboards = updatedDashboards
        return true
    }

    func presentationCount(
        source: DashboardSourceReference,
        presentation: DashboardPresentationConfiguration
    ) -> Int {
        presentationCounts[DashboardPresentationIdentity(source: source, presentation: presentation), default: 0]
    }

    // MARK: Mutations

    @discardableResult
    func add(source: DashboardSourceReference, presentation: DashboardPresentationConfiguration) -> UUID? {
        guard let item = DashboardConfigurationValidator.normalizedItem(
            .sourced(source: source, presentation: presentation)
        ) else { return nil }

        // Summary chips are dashboard-wide aggregates. Entity-backed items are
        // independent presentations and may intentionally repeat.
        if case .summary = source,
           let existing = items.first(where: {
               guard let itemSource = $0.source, let itemPresentation = $0.presentation else { return false }
               return DashboardPresentationIdentity(source: itemSource, presentation: itemPresentation)
                   == DashboardPresentationIdentity(source: source, presentation: presentation)
           }) {
            return existing.id
        }

        appendSelectedDashboardItem(item, setupState: .manual)
        return item.id
    }

    @discardableResult
    func addHeader(title: String) -> UUID {
        let item = DashboardItemConfiguration.header(title: normalizedHeaderTitle(title))
        appendSelectedDashboardItem(item, setupState: .manual)
        return item.id
    }

    func renameHeader(id: UUID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.role == .heading }) else { return }
        var updated = items
        updated[index].content = .heading(DashboardHeadingConfiguration(title: normalizedHeaderTitle(title)))
        updateSelectedDashboardItems(updated, setupState: .manual)
    }

    func renameDisplayItem(id: UUID, displayNameOverride: String?) {
        _ = renameDisplayItem(
            DashboardItemReference(dashboardID: selectedDashboardID, itemID: id),
            displayNameOverride: displayNameOverride
        )
    }

    @discardableResult
    func renameDisplayItem(
        _ reference: DashboardItemReference,
        displayNameOverride: String?
    ) -> Bool {
        guard let item = item(for: reference), item.role != .heading else { return false }
        return updateItem(for: reference) { item in
            item.displayNameOverride = normalizedOverride(displayNameOverride)
        }
    }

    func setIconNameOverride(_ iconNameOverride: String?, forItemID itemID: UUID) {
        _ = setIconNameOverride(
            iconNameOverride,
            for: DashboardItemReference(dashboardID: selectedDashboardID, itemID: itemID)
        )
    }

    @discardableResult
    func setIconNameOverride(_ iconNameOverride: String?, for reference: DashboardItemReference) -> Bool {
        guard let item = item(for: reference), item.role != .heading else { return false }
        return updateItem(for: reference) { item in
            item.iconNameOverride = normalizedOverride(iconNameOverride)
        }
    }

    func setGaugeZoneConfiguration(_ configuration: GaugeZoneConfiguration?, forItemID itemID: UUID) {
        _ = setGaugeZoneConfiguration(
            configuration,
            for: DashboardItemReference(dashboardID: selectedDashboardID, itemID: itemID)
        )
    }

    @discardableResult
    func setGaugeZoneConfiguration(
        _ configuration: GaugeZoneConfiguration?,
        for reference: DashboardItemReference
    ) -> Bool {
        guard configuration?.isValid != false,
              item(for: reference)?.role == .card else { return false }
        return updateItem(for: reference) { item in
            item.gaugeZoneConfiguration = configuration
        }
    }

    func setChartConfiguration(_ configuration: DashboardChartConfiguration, forItemID itemID: UUID) {
        _ = setChartConfiguration(
            configuration,
            for: DashboardItemReference(dashboardID: selectedDashboardID, itemID: itemID)
        )
    }

    @discardableResult
    func setChartConfiguration(
        _ configuration: DashboardChartConfiguration,
        for reference: DashboardItemReference
    ) -> Bool {
        guard configuration.isValid,
              item(for: reference)?.cardConfiguration?.kind == .chart else { return false }
        return updateItem(for: reference) { item in
            item.chartConfiguration = configuration == .default ? nil : configuration
        }
    }

    @discardableResult
    func replaceEntity(
        forItemID itemID: UUID,
        with replacementEntity: HAEntityState,
        preserveGaugeZoneConfiguration: Bool
    ) -> Bool {
        replaceEntity(
            for: DashboardItemReference(dashboardID: selectedDashboardID, itemID: itemID),
            with: replacementEntity,
            preserveGaugeZoneConfiguration: preserveGaugeZoneConfiguration
        )
    }

    @discardableResult
    func replaceEntity(
        for reference: DashboardItemReference,
        with replacementEntity: HAEntityState,
        preserveGaugeZoneConfiguration: Bool
    ) -> Bool {
        guard let currentItem = item(for: reference),
              case .entity(let currentEntityID) = currentItem.source,
              let card = currentItem.cardConfiguration,
              currentEntityID != replacementEntity.entityID,
              DashboardPresentationCatalog.isCompatible(card, with: replacementEntity) else {
            return false
        }

        return updateItem(for: reference) { item in
            item.content = .sourced(DashboardSourcedItem(
                source: .entity(replacementEntity.entityID),
                presentation: .card(card)
            ))
            if !preserveGaugeZoneConfiguration {
                item.gaugeZoneConfiguration = nil
            }
        }
    }

    func removeItem(id: UUID) {
        let updated = items.filter { $0.id != id }
        updateSelectedDashboardItems(updated, setupState: updated.isEmpty ? .intentionallyEmpty : .manual)
    }

    func move(from source: IndexSet, to destination: Int) {
        var updated = items
        let moving = source.sorted().map { updated[$0] }
        for index in source.sorted(by: >) { updated.remove(at: index) }
        let target = destination - source.filter { $0 < destination }.count
        updated.insert(contentsOf: moving, at: target)
        updateSelectedDashboardItems(updated, setupState: .manual)
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
        updateSelectedDashboardItems(updated, setupState: .manual)
    }

    func moveVisibleGridItem(id: UUID, before targetID: UUID?, visibleGridItemIDs: [UUID]) {
        moveVisibleItems(id: id, before: targetID, visibleItemIDs: visibleGridItemIDs)
    }

    func moveVisibleChipItem(id: UUID, before targetID: UUID?, visibleChipItemIDs: [UUID]) {
        moveVisibleItems(id: id, before: targetID, visibleItemIDs: visibleChipItemIDs)
    }

    @discardableResult
    func applySuggestedSetup(using candidates: [DashboardSuggestionCandidate]) -> Bool {
        let suggestedItems = DashboardSuggestedSetup.items(from: candidates)
        guard !suggestedItems.isEmpty else { return false }
        updateSelectedDashboardItems(suggestedItems, setupState: .suggested)
        return true
    }

    func cardConfiguration(forItemID itemID: UUID) -> DashboardCardConfiguration? {
        items.first { $0.id == itemID }?.cardConfiguration
    }

    func setCardLayout(_ layout: DashboardCardSize, forItemID itemID: UUID) {
        _ = setCardLayout(
            layout,
            for: DashboardItemReference(dashboardID: selectedDashboardID, itemID: itemID)
        )
    }

    @discardableResult
    func setCardLayout(_ layout: DashboardCardSize, for reference: DashboardItemReference) -> Bool {
        guard let item = item(for: reference),
              let card = item.cardConfiguration else { return false }
        let updatedCard = card.withLayout(layout)
        guard DashboardConfigurationValidator.isValid(updatedCard) else { return false }

        return updateItem(for: reference) { item in
            guard let source = item.source else { return }
            item.content = .sourced(DashboardSourcedItem(source: source, presentation: .card(updatedCard)))
        }
    }

    // MARK: Saved Dashboards

    @discardableResult
    func applySyncSnapshot(_ snapshot: DashboardConfigurationSyncSnapshot) -> Bool {
        guard snapshot.isCompatible, !protectsNewerDashboardSchema else { return false }
        dashboards = Self.normalizedDashboards(snapshot.dashboards)
        ensureSelectedDashboardExists()
        return true
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
            items: [],
            setupState: .notChosen
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
            items: source.items.map { item in var copy = item; copy.id = UUID(); return copy },
            setupState: source.items.isEmpty ? .intentionallyEmpty : .manual
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
        updateSelectedDashboardItems(updated, setupState: .manual)
    }

    private func saveDashboards() {
        guard !protectsNewerDashboardSchema else { return }
        guard let data = try? JSONEncoder().encode(DashboardConfigurationDocument(dashboards: dashboards)) else { return }
        Self.storeDocument(data, in: defaults, key: documentKey)
    }

    private func saveSelectedDashboardID() {
        guard !protectsNewerDashboardSchema else { return }
        defaults.set(selectedDashboardID.uuidString, forKey: selectedDashboardIDKey)
    }

    private func updateSelectedDashboardItems(
        _ items: [DashboardItemConfiguration],
        setupState: DashboardSetupState? = nil
    ) {
        updateSelectedDashboard {
            $0.items = DashboardConfigurationValidator.normalizedItems(items)
            if let setupState { $0.setupState = setupState }
        }
    }

    private func appendSelectedDashboardItem(_ item: DashboardItemConfiguration, setupState: DashboardSetupState) {
        updateSelectedDashboard {
            $0.items.append(item)
            $0.setupState = setupState
        }
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

    private static func loadDocumentState(from defaults: UserDefaults, key: String) -> StoredDashboardDocumentState {
        guard let data = defaults.data(forKey: key) else { return .missing }

        switch DashboardConfigurationMigrator.migrate(data) {
        case .loaded(let document, _, let didMigrate):
            if didMigrate {
                defaults.set(data, forKey: backupDocumentKey(for: key))
            }
            return .loaded(DashboardConfigurationDocument(dashboards: normalizedDashboards(document.dashboards)))
        case .newerSchema(let version):
            return .newerSchema(version: version)
        case .unsupportedSchema, .invalid:
            defaults.set(data, forKey: rejectedDocumentKey(for: key))
            guard let backup = defaults.data(forKey: backupDocumentKey(for: key)),
                  case .loaded(let document, _, _) = DashboardConfigurationMigrator.migrate(backup) else {
                return .unrecoverable
            }
            return .loaded(DashboardConfigurationDocument(dashboards: normalizedDashboards(document.dashboards)))
        }
    }

    @discardableResult
    private static func storeDocument(_ data: Data, in defaults: UserDefaults, key: String) -> Bool {
        if let existing = defaults.data(forKey: key), existing != data {
            switch DashboardConfigurationMigrator.migrate(existing) {
            case .newerSchema:
                return false
            case .loaded:
                defaults.set(existing, forKey: backupDocumentKey(for: key))
            case .unsupportedSchema, .invalid:
                break
            }
        }
        defaults.set(data, forKey: key)
        return true
    }

    private static let legacyDocumentKey = "homestead.dashboard.configuration.v3"
    private static let legacySelectedDashboardIDKey = "homestead.dashboard.selectedDashboardID.v3"

    private static func documentKey(profileID: UUID?) -> String {
        guard let profileID else { return legacyDocumentKey }
        return "\(legacyDocumentKey).\(profileID.uuidString.lowercased())"
    }

    private static func selectedDashboardIDKey(profileID: UUID?) -> String {
        guard let profileID else { return legacySelectedDashboardIDKey }
        return "\(legacySelectedDashboardIDKey).\(profileID.uuidString.lowercased())"
    }

    private static func backupDocumentKey(for documentKey: String) -> String { "\(documentKey).backup" }
    private static func rejectedDocumentKey(for documentKey: String) -> String { "\(documentKey).rejected" }

    private static func loadSelectedDashboardID(from defaults: UserDefaults, key: String, dashboards: [SavedDashboardConfiguration]) -> UUID {
        if let value = defaults.string(forKey: key), let id = UUID(uuidString: value), dashboards.contains(where: { $0.id == id }) { return id }
        return dashboards[0].id
    }

    private static func normalizedDashboards(_ dashboards: [SavedDashboardConfiguration]) -> [SavedDashboardConfiguration] {
        let normalized = dashboards.map {
            SavedDashboardConfiguration(
                id: $0.id,
                name: $0.resolvedName,
                displayTitle: $0.resolvedDisplayTitle,
                items: DashboardConfigurationValidator.normalizedItems($0.items),
                setupState: $0.setupState
            )
        }
        return normalized.isEmpty ? [defaultDashboard()] : normalized
    }

    private static func defaultDashboard() -> SavedDashboardConfiguration {
        SavedDashboardConfiguration(
            id: UUID(),
            name: DashboardConfigurationDefaults.dashboardName,
            displayTitle: DashboardConfigurationDefaults.dashboardTitle,
            items: [],
            setupState: .notChosen
        )
    }
}

// MARK: - Validation

nonisolated enum DashboardConfigurationValidator {
    static func normalizedItems(_ items: [DashboardItemConfiguration]) -> [DashboardItemConfiguration] {
        var summaryIdentities = Set<DashboardPresentationIdentity>()
        return items.compactMap { item in
            guard let normalized = normalizedItem(item) else { return nil }
            guard let source = normalized.source, let presentation = normalized.presentation else { return normalized }
            guard case .summary = source else { return normalized }
            return summaryIdentities.insert(
                DashboardPresentationIdentity(source: source, presentation: presentation)
            ).inserted ? normalized : nil
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
        card.kind.supportedLayouts.contains(card.layout)
    }

}

// MARK: - iCloud Snapshot

nonisolated struct DashboardConfigurationSyncSnapshot: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var dashboards: [SavedDashboardConfiguration]
    private(set) var isCompatible: Bool

    init(dashboards: [SavedDashboardConfiguration]) {
        schemaVersion = DashboardConfigurationDocument.currentSchemaVersion
        self.dashboards = dashboards
        isCompatible = true
    }

    init(from decoder: Decoder) throws {
        let value = try JSONValue(from: decoder)
        let data = try JSONEncoder().encode(value)

        switch DashboardConfigurationMigrator.migrate(data) {
        case .loaded(let document, _, _):
            schemaVersion = DashboardConfigurationDocument.currentSchemaVersion
            dashboards = document.dashboards
            isCompatible = true
        case .newerSchema(let version):
            schemaVersion = version
            dashboards = []
            isCompatible = false
        case .unsupportedSchema(let version):
            schemaVersion = version ?? DashboardConfigurationDocument.currentSchemaVersion
            dashboards = []
            isCompatible = false
        case .invalid:
            schemaVersion = DashboardConfigurationDocument.currentSchemaVersion
            dashboards = []
            isCompatible = false
        }
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
