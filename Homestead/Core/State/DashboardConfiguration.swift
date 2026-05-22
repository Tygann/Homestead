import Foundation
import Observation

@MainActor
@Observable
final class DashboardConfiguration {
    private(set) var entityIDs: [String] {
        didSet { saveEntityIDs() }
    }
    private(set) var cardSizes: [String: DashboardCardSize] {
        didSet { saveCardSizes() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let entityIDsKey = "dashboardEntityIDs"
    @ObservationIgnored private let cardSizesKey = "dashboardCardSizes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entityIDs = defaults.stringArray(forKey: entityIDsKey) ?? []
        cardSizes = Self.loadCardSizes(from: defaults, key: cardSizesKey)
    }

    var hasCustomLayout: Bool {
        !entityIDs.isEmpty
    }

    func seedIfNeeded(from entities: [HomeEntity]) {
        guard entityIDs.isEmpty else {
            return
        }

        entityIDs = Self.defaultEntityIDs(from: entities)
    }

    func reconcile(with entities: [HomeEntity]) {
        reconcile(withAvailableEntityIDs: Set(entities.map(\.entityID)))
        seedIfNeeded(from: entities)
    }

    func reconcile(withAvailableEntityIDs availableIDs: Set<String>) {
        let currentEntityIDs = entityIDs.filter { availableIDs.contains($0) }

        if currentEntityIDs != entityIDs {
            entityIDs = currentEntityIDs
        }

        let currentSizes = cardSizes.filter { availableIDs.contains($0.key) }
        if currentSizes != cardSizes {
            cardSizes = currentSizes
        }
    }

    func visibleEntityIDs(from entities: [HomeEntity]) -> [String] {
        visibleEntityIDs(fromAvailableEntityIDs: Set(entities.map(\.entityID)))
    }

    func visibleEntityIDs(fromAvailableEntityIDs availableIDs: Set<String>) -> [String] {
        return entityIDs.filter { availableIDs.contains($0) }
    }

    func addableEntityIDs(fromAvailableEntityIDs availableIDs: Set<String>) -> Set<String> {
        availableIDs.subtracting(Set(visibleEntityIDs(fromAvailableEntityIDs: availableIDs)))
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

    func add(_ entityID: String) {
        guard !entityIDs.contains(entityID) else {
            return
        }

        entityIDs.append(entityID)
    }

    func remove(_ entityID: String) {
        entityIDs.removeAll { $0 == entityID }
        cardSizes.removeValue(forKey: entityID)
    }

    func move(from source: IndexSet, to destination: Int) {
        let movingIDs = source.sorted().map { entityIDs[$0] }
        var updatedIDs = entityIDs

        for index in source.sorted(by: >) {
            updatedIDs.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        updatedIDs.insert(contentsOf: movingIDs, at: adjustedDestination)
        entityIDs = updatedIDs
    }

    func reset(using entities: [HomeEntity]) {
        entityIDs = Self.defaultEntityIDs(from: entities)
        cardSizes = [:]
    }

    func cardSize(for entityID: String) -> DashboardCardSize {
        cardSizes[entityID] ?? .compact
    }

    func setCardSize(_ size: DashboardCardSize, for entityID: String) {
        if size == .compact {
            cardSizes.removeValue(forKey: entityID)
        } else {
            cardSizes[entityID] = size
        }
    }

    private func saveEntityIDs() {
        defaults.set(entityIDs, forKey: entityIDsKey)
    }

    private func saveCardSizes() {
        let rawSizes = cardSizes.mapValues(\.rawValue)
        defaults.set(rawSizes, forKey: cardSizesKey)
    }

    private static func loadCardSizes(from defaults: UserDefaults, key: String) -> [String: DashboardCardSize] {
        guard let rawSizes = defaults.dictionary(forKey: key) as? [String: String] else {
            return [:]
        }

        return rawSizes.compactMapValues(DashboardCardSize.init(rawValue:))
    }

    private static func defaultEntityIDs(from entities: [HomeEntity]) -> [String] {
        let sortedEntities = entities.sorted { lhs, rhs in
            if lhs.domain.dashboardPriority != rhs.domain.dashboardPriority {
                return lhs.domain.dashboardPriority < rhs.domain.dashboardPriority
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return Array(sortedEntities.prefix(12).map(\.entityID))
    }
}
