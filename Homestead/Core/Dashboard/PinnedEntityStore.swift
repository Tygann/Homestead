import Foundation
import Observation

@Observable
final class PinnedEntityStore {
    private(set) var entityIDs: [String] {
        didSet {
            defaults.set(entityIDs, forKey: Self.entityIDsKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entityIDs = defaults.stringArray(forKey: Self.entityIDsKey) ?? []
    }

    func isPinned(_ entityID: String) -> Bool {
        entityIDs.contains(entityID)
    }

    func toggle(_ entityID: String) {
        if isPinned(entityID) {
            entityIDs.removeAll { $0 == entityID }
        } else {
            entityIDs.append(entityID)
        }
    }

    func removeMissingEntities(validEntityIDs: Set<String>) {
        entityIDs.removeAll { !validEntityIDs.contains($0) }
    }

    private static let entityIDsKey = "dashboard.pinnedEntityIDs"
}
