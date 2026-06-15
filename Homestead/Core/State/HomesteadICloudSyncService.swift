import Foundation
import Observation

protocol HomesteadICloudKeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: HomesteadICloudKeyValueStore {}

enum HomesteadSyncSection: String, CaseIterable, Sendable {
    case connection
    case dashboard
    case actionConfirmations
    case appearance
}

enum HomesteadICloudSyncStatus: Equatable, Sendable {
    case disabled
    case checking
    case restoreAvailable
    case ready
    case syncing
    case conflict
    case synced(Date)
    case unavailable(String)
    case quotaExceeded

    var title: String {
        switch self {
        case .disabled: "Off"
        case .checking: "Checking iCloud"
        case .restoreAvailable: "Setup Available"
        case .ready: "Ready"
        case .syncing: "Syncing"
        case .conflict: "Choice Needed"
        case .synced: "Synced"
        case .unavailable: "Unavailable"
        case .quotaExceeded: "Storage Full"
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            "iCloud sync is off for this device."
        case .checking:
            "Checking iCloud for an existing Homestead setup."
        case .restoreAvailable:
            "An existing Homestead setup is available in iCloud."
        case .ready:
            "Preferences are ready to sync through iCloud."
        case .syncing:
            "Comparing this device with iCloud."
        case .conflict:
            "Choose whether to use iCloud or keep this device's preferences."
        case .synced(let date):
            "Last synced \(date.formatted(date: .abbreviated, time: .shortened))."
        case .unavailable(let message):
            message
        case .quotaExceeded:
            "Homestead preferences exceed iCloud key-value storage limits."
        }
    }
}

struct HomesteadSyncRecord<Value: Codable & Equatable>: Codable, Equatable {
    var updatedAt: Date
    var value: Value
}

struct HomesteadConnectionSyncSnapshot: Codable, Equatable {
    var baseURL: String
    var internalURL: String
    var externalURL: String
    var internalNetworkSSIDs: [String]? = nil
}

struct HomesteadICloudSyncPayload: Codable, Equatable {
    var version: Int
    var sourceDeviceID: String
    var connection: HomesteadSyncRecord<HomesteadConnectionSyncSnapshot>
    var dashboard: HomesteadSyncRecord<DashboardConfigurationSyncSnapshot>
    var actionConfirmations: HomesteadSyncRecord<ActionConfirmationSettingsSyncSnapshot>
    var appearance: HomesteadSyncRecord<HomesteadAppearanceSettingsSyncSnapshot>

    static let currentVersion = 2

    var newestUpdate: Date {
        [connection.updatedAt, dashboard.updatedAt, actionConfirmations.updatedAt, appearance.updatedAt].max() ?? .distantPast
    }
}

struct HomesteadICloudRestoreSummary: Equatable, Sendable {
    var serverDisplayName: String
    var dashboardItemCount: Int
    var updatedAt: Date
}

enum HomesteadICloudBootstrapState: Equatable, Sendable {
    case idle
    case checking
    case noRemoteSetup
    case restoreAvailable(HomesteadICloudRestoreSummary)
    case complete
    case failed(String)
}

enum HomesteadICloudEnableResult: Equatable, Sendable {
    case enabled
    case conflict(HomesteadICloudRestoreSummary)
    case unavailable(String)
}

enum HomesteadICloudConflictResolution: Sendable {
    case useICloud
    case keepThisDevice
    case cancel
}

private struct LegacyHomesteadICloudSyncPayload: Codable {
    var version: Int
    var updatedAt: Date
    var connection: LegacyConnectionSyncSnapshot
    var dashboard: DashboardConfigurationSyncSnapshot
    var actionConfirmations: ActionConfirmationSettingsSyncSnapshot
    var appearance: HomesteadAppearanceSettingsSyncSnapshot
}

private struct LegacyConnectionSyncSnapshot: Codable {
    var baseURL: String
    var internalURL: String
    var externalURL: String
    var homeNetworkName: String?
}

@MainActor
@Observable
final class HomesteadICloudSyncService {
    private(set) var status: HomesteadICloudSyncStatus
    private(set) var bootstrapState: HomesteadICloudBootstrapState = .idle
    private(set) var lastSyncDate: Date?
    private(set) var lastRemoteChangeDate: Date?
    private(set) var isEnabled: Bool
    private(set) var isApplyingRemote = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let store: HomesteadICloudKeyValueStore
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var changeObserver: NSObjectProtocol?
    @ObservationIgnored private var pendingRemotePayload: HomesteadICloudSyncPayload?
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    @ObservationIgnored private var localSectionUpdates: [HomesteadSyncSection: Date]
    @ObservationIgnored private let sourceDeviceID: String
    @ObservationIgnored private let maximumPayloadBytes = 900_000

    init(
        defaults: UserDefaults = .standard,
        store: HomesteadICloudKeyValueStore = NSUbiquitousKeyValueStore.default
    ) {
        self.defaults = defaults
        self.store = store
        let storedIsEnabled = defaults.bool(forKey: Keys.isEnabled)
        let storedLastSyncDate = defaults.object(forKey: Keys.lastSyncDate) as? Date
        isEnabled = storedIsEnabled
        lastSyncDate = storedLastSyncDate
        lastRemoteChangeDate = defaults.object(forKey: Keys.lastRemoteChangeDate) as? Date

        if let storedID = defaults.string(forKey: Keys.sourceDeviceID) {
            sourceDeviceID = storedID
        } else {
            let newID = UUID().uuidString
            sourceDeviceID = newID
            defaults.set(newID, forKey: Keys.sourceDeviceID)
        }

        localSectionUpdates = Dictionary(uniqueKeysWithValues: HomesteadSyncSection.allCases.map { section in
            let date = defaults.object(forKey: Keys.sectionDate(section)) as? Date ?? .distantPast
            return (section, date)
        })
        status = storedIsEnabled ? storedLastSyncDate.map(HomesteadICloudSyncStatus.synced) ?? .ready : .disabled
    }

    deinit {
        uploadTask?.cancel()
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
        guard changeObserver == nil else { return }

        changeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak connectionSettings, weak dashboardConfiguration, weak actionConfirmationSettings, weak appearanceSettings] notification in
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            MainActor.assumeIsolated {
                guard let self, let connectionSettings, let dashboardConfiguration,
                      let actionConfirmationSettings, let appearanceSettings else { return }
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
    }

    func bootstrap(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        bootstrapState = .checking
        status = .checking

        guard store.synchronize() else {
            let message = "iCloud is unavailable on this device. You can continue setup without it."
            bootstrapState = .failed(message)
            status = isEnabled ? .unavailable(message) : .disabled
            return
        }

        guard let remote = remotePayload() else {
            bootstrapState = isEnabled ? .complete : .noRemoteSetup
            status = isEnabled ? .ready : .disabled
            return
        }

        pendingRemotePayload = remote
        lastRemoteChangeDate = remote.newestUpdate
        defaults.set(remote.newestUpdate, forKey: Keys.lastRemoteChangeDate)

        if isEnabled {
            mergeRemote(
                remote,
                allowServerReplacement: connectionSettings.baseURL.trimmedForSync.isEmpty,
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings
            )
            bootstrapState = .complete
        } else if Self.isCleanDevice(connectionSettings: connectionSettings, dashboardConfiguration: dashboardConfiguration) {
            let summary = restoreSummary(for: remote)
            bootstrapState = .restoreAvailable(summary)
            status = .restoreAvailable
        } else {
            bootstrapState = .complete
            status = .disabled
        }
    }

    func acceptBootstrapRestore(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard let remote = pendingRemotePayload else {
            bootstrapState = .complete
            return
        }

        applyAll(
            remote,
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
        setEnabled(true)
        bootstrapState = .complete
    }

    func declineBootstrapRestore() {
        pendingRemotePayload = nil
        bootstrapState = .complete
        status = .disabled
    }

    func requestEnable(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) -> HomesteadICloudEnableResult {
        status = .syncing
        guard store.synchronize() else {
            let message = "iCloud did not respond. Check iCloud availability for this device."
            status = .unavailable(message)
            return .unavailable(message)
        }

        guard let remote = remotePayload() else {
            setEnabled(true)
            markAllSectionsChanged()
            uploadNow(
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings
            )
            return .enabled
        }

        pendingRemotePayload = remote
        let local = makePayload(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
        guard !sameValues(local, remote) else {
            setEnabled(true)
            mergeRemote(
                remote,
                allowServerReplacement: true,
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings
            )
            return .enabled
        }

        status = .conflict
        return .conflict(restoreSummary(for: remote))
    }

    func resolveEnableConflict(
        _ resolution: HomesteadICloudConflictResolution,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        switch resolution {
        case .useICloud:
            if let remote = pendingRemotePayload {
                applyAll(
                    remote,
                    connectionSettings: connectionSettings,
                    dashboardConfiguration: dashboardConfiguration,
                    actionConfirmationSettings: actionConfirmationSettings,
                    appearanceSettings: appearanceSettings
                )
            }
            setEnabled(true)
        case .keepThisDevice:
            setEnabled(true)
            markAllSectionsChanged()
            uploadNow(
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings
            )
        case .cancel:
            status = .disabled
        }
        pendingRemotePayload = nil
    }

    func disable() {
        uploadTask?.cancel()
        uploadTask = nil
        setEnabled(false)
    }

    func noteLocalChange(
        _ section: HomesteadSyncSection,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard isEnabled, bootstrapState == .complete, !isApplyingRemote else { return }
        let now = Date()
        localSectionUpdates[section] = now
        defaults.set(now, forKey: Keys.sectionDate(section))

        uploadTask?.cancel()
        uploadTask = Task { @MainActor [weak self, weak connectionSettings, weak dashboardConfiguration, weak actionConfirmationSettings, weak appearanceSettings] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self, let connectionSettings, let dashboardConfiguration,
                  let actionConfirmationSettings, let appearanceSettings else { return }
            self.uploadNow(
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings
            )
        }
    }

    func syncNow(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard isEnabled else { return }
        status = .syncing
        _ = store.synchronize()
        if let remote = remotePayload() {
            pendingRemotePayload = remote
            mergeRemote(
                remote,
                allowServerReplacement: false,
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings
            )
        }
        uploadNow(
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
        now: Date? = nil
    ) -> HomesteadICloudSyncPayload {
        let dates = Dictionary(uniqueKeysWithValues: HomesteadSyncSection.allCases.map { section in
            (section, now ?? localSectionUpdates[section] ?? .distantPast)
        })
        return HomesteadICloudSyncPayload(
            version: HomesteadICloudSyncPayload.currentVersion,
            sourceDeviceID: sourceDeviceID,
            connection: HomesteadSyncRecord(
                updatedAt: dates[.connection] ?? .distantPast,
                value: HomesteadConnectionSyncSnapshot(
                    baseURL: Self.preferredIdentityBaseURL(
                        baseURL: connectionSettings.baseURL,
                        internalURL: connectionSettings.internalURL,
                        externalURL: connectionSettings.externalURL
                    ),
                    internalURL: connectionSettings.internalURL,
                    externalURL: connectionSettings.externalURL,
                    internalNetworkSSIDs: connectionSettings.internalNetworkSSIDs
                )
            ),
            dashboard: HomesteadSyncRecord(updatedAt: dates[.dashboard] ?? .distantPast, value: dashboardConfiguration.syncSnapshot),
            actionConfirmations: HomesteadSyncRecord(updatedAt: dates[.actionConfirmations] ?? .distantPast, value: actionConfirmationSettings.syncSnapshot),
            appearance: HomesteadSyncRecord(updatedAt: dates[.appearance] ?? .distantPast, value: appearanceSettings.syncSnapshot)
        )
    }

    func encodedPayload(_ payload: HomesteadICloudSyncPayload) throws -> Data {
        let data = try encoder.encode(payload)
        guard data.count <= maximumPayloadBytes else { throw HomesteadICloudSyncError.payloadTooLarge }
        return data
    }

    private func uploadNow(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        guard isEnabled, bootstrapState == .complete else { return }
        status = .syncing
        var payload = makePayload(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
        if let remote = pendingRemotePayload {
            if remote.connection.updatedAt > payload.connection.updatedAt { payload.connection = remote.connection }
            if remote.dashboard.updatedAt > payload.dashboard.updatedAt { payload.dashboard = remote.dashboard }
            if remote.actionConfirmations.updatedAt > payload.actionConfirmations.updatedAt {
                payload.actionConfirmations = remote.actionConfirmations
            }
            if remote.appearance.updatedAt > payload.appearance.updatedAt { payload.appearance = remote.appearance }
        }
        do {
            store.set(try encodedPayload(payload), forKey: Keys.payloadV2)
            guard store.synchronize() else {
                status = .unavailable("iCloud did not accept the sync request. Check iCloud availability for this device.")
                return
            }
            lastSyncDate = payload.newestUpdate
            pendingRemotePayload = payload
            defaults.set(payload.newestUpdate, forKey: Keys.lastSyncDate)
            status = .synced(payload.newestUpdate)
        } catch HomesteadICloudSyncError.payloadTooLarge {
            status = .quotaExceeded
        } catch {
            status = .unavailable("Homestead preferences could not be prepared for iCloud sync.")
        }
    }

    private func handleExternalChange(
        reason: Int?,
        changedKeys: [String]?,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            status = .quotaExceeded
            return
        }
        if let changedKeys, !changedKeys.contains(Keys.payloadV2), !changedKeys.contains(Keys.payloadV1) { return }
        guard let remote = remotePayload() else { return }

        pendingRemotePayload = remote
        if bootstrapState == .checking || bootstrapState == .idle || bootstrapState == .noRemoteSetup,
           !isEnabled,
           Self.isCleanDevice(connectionSettings: connectionSettings, dashboardConfiguration: dashboardConfiguration) {
            bootstrapState = .restoreAvailable(restoreSummary(for: remote))
            status = .restoreAvailable
        } else if isEnabled {
            mergeRemote(
                remote,
                allowServerReplacement: false,
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings
            )
        }
    }

    private func remotePayload() -> HomesteadICloudSyncPayload? {
        if let data = store.data(forKey: Keys.payloadV2),
           let payload = try? decoder.decode(HomesteadICloudSyncPayload.self, from: data),
           payload.version == HomesteadICloudSyncPayload.currentVersion {
            return payload
        }
        guard let data = store.data(forKey: Keys.payloadV1),
              let legacy = try? decoder.decode(LegacyHomesteadICloudSyncPayload.self, from: data) else { return nil }
        return HomesteadICloudSyncPayload(
            version: HomesteadICloudSyncPayload.currentVersion,
            sourceDeviceID: "legacy",
            connection: HomesteadSyncRecord(
                updatedAt: legacy.updatedAt,
                value: HomesteadConnectionSyncSnapshot(
                    baseURL: legacy.connection.baseURL,
                    internalURL: legacy.connection.internalURL,
                    externalURL: legacy.connection.externalURL,
                    internalNetworkSSIDs: legacy.connection.homeNetworkName.map { [$0] }
                )
            ),
            dashboard: HomesteadSyncRecord(updatedAt: legacy.updatedAt, value: legacy.dashboard),
            actionConfirmations: HomesteadSyncRecord(updatedAt: legacy.updatedAt, value: legacy.actionConfirmations),
            appearance: HomesteadSyncRecord(updatedAt: legacy.updatedAt, value: legacy.appearance)
        )
    }

    private func mergeRemote(
        _ remote: HomesteadICloudSyncPayload,
        allowServerReplacement: Bool,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        if remote.connection.updatedAt > localDate(.connection) {
            let localServer = connectionSettings.baseURL.trimmedForSync
            let remoteServer = Self.preferredIdentityBaseURL(
                baseURL: remote.connection.value.baseURL,
                internalURL: remote.connection.value.internalURL,
                externalURL: remote.connection.value.externalURL
            )
            if allowServerReplacement || localServer.isEmpty || normalized(localServer) == normalized(remoteServer) {
                connectionSettings.applySyncSnapshot(remote.connection.value)
                recordRemoteDate(remote.connection.updatedAt, section: .connection)
            } else {
                connectionSettings.applyRoutingSyncSnapshot(remote.connection.value)
            }
        }
        if remote.dashboard.updatedAt > localDate(.dashboard) {
            dashboardConfiguration.applySyncSnapshot(remote.dashboard.value)
            recordRemoteDate(remote.dashboard.updatedAt, section: .dashboard)
        }
        if remote.actionConfirmations.updatedAt > localDate(.actionConfirmations) {
            actionConfirmationSettings.applySyncSnapshot(remote.actionConfirmations.value)
            recordRemoteDate(remote.actionConfirmations.updatedAt, section: .actionConfirmations)
        }
        if remote.appearance.updatedAt > localDate(.appearance) {
            appearanceSettings.applySyncSnapshot(remote.appearance.value)
            recordRemoteDate(remote.appearance.updatedAt, section: .appearance)
        }
        lastRemoteChangeDate = remote.newestUpdate
        defaults.set(remote.newestUpdate, forKey: Keys.lastRemoteChangeDate)
        status = .synced(remote.newestUpdate)
    }

    private func applyAll(
        _ remote: HomesteadICloudSyncPayload,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings
    ) {
        isApplyingRemote = true
        connectionSettings.applySyncSnapshot(remote.connection.value)
        dashboardConfiguration.applySyncSnapshot(remote.dashboard.value)
        actionConfirmationSettings.applySyncSnapshot(remote.actionConfirmations.value)
        appearanceSettings.applySyncSnapshot(remote.appearance.value)
        isApplyingRemote = false
        for section in HomesteadSyncSection.allCases {
            recordRemoteDate(recordDate(for: section, payload: remote), section: section)
        }
        lastRemoteChangeDate = remote.newestUpdate
        defaults.set(remote.newestUpdate, forKey: Keys.lastRemoteChangeDate)
        status = .synced(remote.newestUpdate)
    }

    private func restoreSummary(for payload: HomesteadICloudSyncPayload) -> HomesteadICloudRestoreSummary {
        HomesteadICloudRestoreSummary(
            serverDisplayName: payload.connection.value.baseURL.trimmedForSync,
            dashboardItemCount: payload.dashboard.value.items.count,
            updatedAt: payload.newestUpdate
        )
    }

    private func sameValues(_ lhs: HomesteadICloudSyncPayload, _ rhs: HomesteadICloudSyncPayload) -> Bool {
        lhs.connection.value == rhs.connection.value &&
            lhs.dashboard.value == rhs.dashboard.value &&
            lhs.actionConfirmations.value == rhs.actionConfirmations.value &&
            lhs.appearance.value == rhs.appearance.value
    }

    private func markAllSectionsChanged() {
        let now = Date()
        for section in HomesteadSyncSection.allCases {
            localSectionUpdates[section] = now
            defaults.set(now, forKey: Keys.sectionDate(section))
        }
    }

    private func recordRemoteDate(_ date: Date, section: HomesteadSyncSection) {
        localSectionUpdates[section] = date
        defaults.set(date, forKey: Keys.sectionDate(section))
    }

    private func localDate(_ section: HomesteadSyncSection) -> Date {
        localSectionUpdates[section] ?? .distantPast
    }

    private func recordDate(for section: HomesteadSyncSection, payload: HomesteadICloudSyncPayload) -> Date {
        switch section {
        case .connection: payload.connection.updatedAt
        case .dashboard: payload.dashboard.updatedAt
        case .actionConfirmations: payload.actionConfirmations.updatedAt
        case .appearance: payload.appearance.updatedAt
        }
    }

    private func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Keys.isEnabled)
        if enabled, bootstrapState == .noRemoteSetup {
            bootstrapState = .complete
        }
        status = enabled ? .ready : .disabled
    }

    private static func isCleanDevice(
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration
    ) -> Bool {
        connectionSettings.baseURL.trimmedForSync.isEmpty && !dashboardConfiguration.hasCustomLayout
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    private static func preferredIdentityBaseURL(
        baseURL: String,
        internalURL: String,
        externalURL: String
    ) -> String {
        let externalURL = externalURL.trimmedForSync
        if !externalURL.isEmpty { return externalURL }

        let baseURL = baseURL.trimmedForSync
        if !baseURL.isEmpty { return baseURL }

        return internalURL.trimmedForSync
    }

    private enum Keys {
        static let isEnabled = "homestead.icloudSync.isEnabled"
        static let lastSyncDate = "homestead.icloudSync.lastSyncDate"
        static let lastRemoteChangeDate = "homestead.icloudSync.lastRemoteChangeDate"
        static let sourceDeviceID = "homestead.icloudSync.sourceDeviceID"
        static let payloadV1 = "homestead.preferences.v1"
        static let payloadV2 = "homestead.preferences.v2"

        static func sectionDate(_ section: HomesteadSyncSection) -> String {
            "homestead.icloudSync.section.\(section.rawValue).updatedAt"
        }
    }
}

enum HomesteadICloudSyncError: Error {
    case payloadTooLarge
}

private extension String {
    var trimmedForSync: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
