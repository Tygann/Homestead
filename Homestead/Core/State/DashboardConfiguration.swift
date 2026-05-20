import Foundation
import Observation

@MainActor
@Observable
final class DashboardConfiguration {
    private(set) var entityIDs: [String] {
        didSet { saveEntityIDs() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let entityIDsKey = "dashboardEntityIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entityIDs = defaults.stringArray(forKey: entityIDsKey) ?? []
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
        let availableIDs = Set(entities.map(\.entityID))
        let currentEntityIDs = entityIDs.filter { availableIDs.contains($0) }

        if currentEntityIDs != entityIDs {
            entityIDs = currentEntityIDs
        }

        seedIfNeeded(from: entities)
    }

    func visibleEntityIDs(from entities: [HomeEntity]) -> [String] {
        let availableIDs = Set(entities.map(\.entityID))
        return entityIDs.filter { availableIDs.contains($0) }
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
    }

    private func saveEntityIDs() {
        defaults.set(entityIDs, forKey: entityIDsKey)
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
