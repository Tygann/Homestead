import Foundation

nonisolated enum WidgetStorageContract {
    static let appGroupID = "group.com.tyler.Homestead"
    static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    enum Key {
        static let serverProfiles = "homeAssistantServerProfiles"
        static let serverSnapshots = "widgetServerSnapshotsV2"
    }
}

nonisolated struct WidgetServerSnapshot: Codable, Equatable, Sendable {
    let profileID: UUID
    let serverName: String
    let generatedAt: Date
    let lights: [WidgetLightSnapshot]
    let switches: [WidgetSwitchSnapshot]
    let covers: [WidgetCoverSnapshot]
    let fans: [WidgetFanSnapshot]
    let locks: [WidgetLockSnapshot]
    let sensors: [WidgetSensorSnapshot]
    let presence: [WidgetPresenceSnapshot]
    let actions: [WidgetActionSnapshot]
}

nonisolated enum WidgetServerSnapshotStore {
    static var snapshots: [WidgetServerSnapshot] {
        guard let data = defaults?.data(forKey: WidgetStorageContract.Key.serverSnapshots) else {
            return []
        }
        return (try? JSONDecoder().decode([WidgetServerSnapshot].self, from: data)) ?? []
    }

    static func snapshot(profileID: UUID) -> WidgetServerSnapshot? {
        snapshots.first { $0.profileID == profileID }
    }

    static func save(_ snapshot: WidgetServerSnapshot) {
        let current = merging(snapshot, into: snapshots)
        guard let data = try? JSONEncoder().encode(current) else { return }
        defaults?.set(data, forKey: WidgetStorageContract.Key.serverSnapshots)
    }

    static func merging(
        _ snapshot: WidgetServerSnapshot,
        into snapshots: [WidgetServerSnapshot]
    ) -> [WidgetServerSnapshot] {
        var result = snapshots
        result.removeAll { $0.profileID == snapshot.profileID }
        result.append(snapshot)
        result.sort {
            $0.serverName.localizedCaseInsensitiveCompare($1.serverName) == .orderedAscending
        }
        return result
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetStorageContract.appGroupID)
    }
}
