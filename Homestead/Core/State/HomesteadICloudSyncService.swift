import Foundation
import Observation

protocol HomesteadICloudKeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: HomesteadICloudKeyValueStore {}

enum HomesteadICloudSyncStatus: Equatable, Sendable {
    case disabled
    case ready
    case syncing
    case synced(Date)
    case unavailable(String)
    case quotaExceeded

    var title: String {
        switch self {
        case .disabled:
            "Off"
        case .ready:
            "Ready"
        case .syncing:
            "Syncing"
        case .synced:
            "Synced"
        case .unavailable:
            "Unavailable"
        case .quotaExceeded:
            "Storage Full"
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            return "iCloud sync is off for this device."
        case .ready:
            return "Preferences are ready to sync through iCloud."
        case .syncing:
            return "Uploading Homestead preferences to iCloud."
        case .synced(let date):
            return "Last synced \(date.formatted(date: .abbreviated, time: .shortened))."
        case .unavailable(let message):
            return message
        case .quotaExceeded:
            return "Homestead preferences exceed iCloud key-value storage limits."
        }
    }
}

struct HomesteadICloudSyncPayload: Codable, Equatable, Sendable {
    var version: Int
    var updatedAt: Date
    var connection: HAConnectionSettingsSyncSnapshot
    var dashboard: DashboardConfigurationSyncSnapshot
    var actionConfirmations: ActionConfirmationSettingsSyncSnapshot
    var appearance: HomesteadAppearanceSettingsSyncSnapshot

    static let currentVersion = 1
}

@MainActor
@Observable
final class HomesteadICloudSyncService {
    private(set) var status: HomesteadICloudSyncStatus
    private(set) var lastSyncDate: Date?
    private(set) var lastRemoteChangeDate: Date?

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            status = isEnabled ? .ready : .disabled
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let store: HomesteadICloudKeyValueStore
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var changeObserver: NSObjectProtocol?
    @ObservationIgnored private var lastAppliedRemoteUpdate: Date?
    @ObservationIgnored private let maximumPayloadBytes = 900_000

    init(
        defaults: UserDefaults = .standard,
        store: HomesteadICloudKeyValueStore = NSUbiquitousKeyValueStore.default
    ) {
        let storedIsEnabled = defaults.bool(forKey: Keys.isEnabled)
        let storedLastSyncDate = defaults.object(forKey: Keys.lastSyncDate) as? Date
        let storedLastRemoteChangeDate = defaults.object(forKey: Keys.lastRemoteChangeDate) as? Date
        self.defaults = defaults
        self.store = store
        isEnabled = storedIsEnabled
        lastSyncDate = storedLastSyncDate
        lastRemoteChangeDate = storedLastRemoteChangeDate
        status = storedIsEnabled ? storedLastSyncDate.map(HomesteadICloudSyncStatus.synced) ?? .ready : .disabled
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func startObserving(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard changeObserver == nil else {
            return
        }

        changeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { notification in
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            Task { @MainActor [weak self, weak connectionSettings, weak dashboardConfiguration, weak actionConfirmationSettings, weak appearanceSettings] in
                guard let self,
                      let connectionSettings,
                      let dashboardConfiguration,
                      let actionConfirmationSettings,
                      let appearanceSettings else {
                    return
                }

                self.handleExternalChange(
                    reason: reason,
                    changedKeys: changedKeys,
                    connectionSettings: connectionSettings,
                    dashboardConfiguration: dashboardConfiguration,
                    actionConfirmationSettings: actionConfirmationSettings,
                    appearanceSettings: appearanceSettings
                )
            }
        }

        store.synchronize()
    }

    func syncNow(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard isEnabled else {
            status = .disabled
            return
        }

        status = .syncing
        let payload = makePayload(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )

        do {
            let data = try encodedPayload(payload)
            store.set(data, forKey: Keys.payload)
            let synchronized = store.synchronize()
            guard synchronized else {
                status = .unavailable("iCloud did not accept the sync request. Check iCloud availability for this device.")
                return
            }

            lastAppliedRemoteUpdate = payload.updatedAt
            lastSyncDate = payload.updatedAt
            defaults.set(payload.updatedAt, forKey: Keys.lastSyncDate)
            status = .synced(payload.updatedAt)
        } catch HomesteadICloudSyncError.payloadTooLarge {
            status = .quotaExceeded
        } catch {
            status = .unavailable("Homestead preferences could not be prepared for iCloud sync.")
        }
    }

    func applyRemoteIfNewer(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard isEnabled,
              let payload = remotePayload(),
              payload.updatedAt > (lastAppliedRemoteUpdate ?? .distantPast) else {
            return
        }

        apply(
            payload,
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
    }

    func makePayload(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings,
        now: Date = Date()
    ) -> HomesteadICloudSyncPayload {
        HomesteadICloudSyncPayload(
            version: HomesteadICloudSyncPayload.currentVersion,
            updatedAt: now,
            connection: connectionSettings.syncSnapshot,
            dashboard: dashboardConfiguration.syncSnapshot,
            actionConfirmations: actionConfirmationSettings.syncSnapshot,
            appearance: appearanceSettings.syncSnapshot
        )
    }

    func encodedPayload(_ payload: HomesteadICloudSyncPayload) throws -> Data {
        let data = try encoder.encode(payload)
        guard data.count <= maximumPayloadBytes else {
            throw HomesteadICloudSyncError.payloadTooLarge
        }

        return data
    }

    private func handleExternalChange(
        reason: Int?,
        changedKeys: [String]?,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard isEnabled else {
            return
        }

        if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            status = .quotaExceeded
            return
        }

        if let changedKeys, !changedKeys.contains(Keys.payload) {
            return
        }

        applyRemoteIfNewer(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
    }

    private func remotePayload() -> HomesteadICloudSyncPayload? {
        guard let data = store.data(forKey: Keys.payload) else {
            return nil
        }

        return try? decoder.decode(HomesteadICloudSyncPayload.self, from: data)
    }

    private func apply(
        _ payload: HomesteadICloudSyncPayload,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard payload.version == HomesteadICloudSyncPayload.currentVersion else {
            status = .unavailable("This iCloud sync data was written by a newer version of Homestead.")
            return
        }

        connectionSettings.applySyncSnapshot(payload.connection)
        dashboardConfiguration.applySyncSnapshot(payload.dashboard)
        actionConfirmationSettings.applySyncSnapshot(payload.actionConfirmations)
        appearanceSettings.applySyncSnapshot(payload.appearance)
        lastAppliedRemoteUpdate = payload.updatedAt
        lastRemoteChangeDate = payload.updatedAt
        defaults.set(payload.updatedAt, forKey: Keys.lastRemoteChangeDate)
        status = .synced(payload.updatedAt)
    }

    private enum Keys {
        static let isEnabled = "homestead.icloudSync.isEnabled"
        static let lastSyncDate = "homestead.icloudSync.lastSyncDate"
        static let lastRemoteChangeDate = "homestead.icloudSync.lastRemoteChangeDate"
        static let payload = "homestead.preferences.v1"
    }
}

enum HomesteadICloudSyncError: Error {
    case payloadTooLarge
}
