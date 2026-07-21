#if DEBUG
import Foundation

enum LivePreviewDashboardPersistence {
    static let backupResourceName = "PreviewDashboardLayout"
    static let appGroupSuiteName = WidgetSharedStore.appGroupID

    private static let documentKey = "homestead.dashboard.configuration.v3"
    private static let selectedDashboardIDKey = "homestead.dashboard.selectedDashboardID.v3"

    static func dashboardDefaults(fallback: UserDefaults) -> UserDefaults {
        UserDefaults(suiteName: appGroupSuiteName) ?? fallback
    }

    static func prepare(
        legacyDefaults: UserDefaults,
        dashboardDefaults: UserDefaults,
        profileIDs: [UUID?],
        backupData: Data?
    ) {
        migrateLegacyValues(
            from: legacyDefaults,
            to: dashboardDefaults,
            profileIDs: profileIDs
        )

        guard let backupData else { return }
        restoreMissingValues(from: backupData, to: dashboardDefaults)
    }

    static func bundledBackupData(bundle: Bundle = .main) -> Data? {
        guard let url = bundle.url(forResource: backupResourceName, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func persistenceKeys(profileID: UUID?) -> (document: String, selection: String) {
        guard let profileID else {
            return (documentKey, selectedDashboardIDKey)
        }
        let suffix = profileID.uuidString.lowercased()
        return ("\(documentKey).\(suffix)", "\(selectedDashboardIDKey).\(suffix)")
    }

    private static func migrateLegacyValues(
        from source: UserDefaults,
        to destination: UserDefaults,
        profileIDs: [UUID?]
    ) {
        for profileID in profileIDs {
            let keys = persistenceKeys(profileID: profileID)
            copyMissingValue(forKey: keys.document, from: source, to: destination)
            copyMissingValue(forKey: keys.selection, from: source, to: destination)
        }
    }

    private static func copyMissingValue(
        forKey key: String,
        from source: UserDefaults,
        to destination: UserDefaults
    ) {
        guard destination.object(forKey: key) == nil,
              let value = source.object(forKey: key) else {
            return
        }
        destination.set(value, forKey: key)
    }

    private static func restoreMissingValues(from data: Data, to defaults: UserDefaults) {
        guard let backup = try? JSONDecoder().decode(Backup.self, from: data),
              backup.schemaVersion == Backup.currentSchemaVersion else {
            return
        }

        for (key, encodedValue) in backup.dataValues where isDashboardPersistenceKey(key) {
            guard defaults.object(forKey: key) == nil,
                  let value = Data(base64Encoded: encodedValue) else {
                continue
            }
            defaults.set(value, forKey: key)
        }

        for (key, value) in backup.stringValues where isDashboardPersistenceKey(key) {
            guard defaults.object(forKey: key) == nil else { continue }
            defaults.set(value, forKey: key)
        }
    }

    private static func isDashboardPersistenceKey(_ key: String) -> Bool {
        key == documentKey || key.hasPrefix("\(documentKey).") ||
            key == selectedDashboardIDKey || key.hasPrefix("\(selectedDashboardIDKey).")
    }

    private struct Backup: Decodable {
        static let currentSchemaVersion = 1

        let schemaVersion: Int
        let dataValues: [String: String]
        let stringValues: [String: String]
    }
}
#endif
