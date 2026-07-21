import XCTest
@testable import Homestead

@MainActor
final class LivePreviewDashboardPersistenceXCTests: XCTestCase {
    func testPrepareMigratesProfileDashboardWithoutOverwritingAppGroupValue() throws {
        let legacyDefaults = makeDefaults(suffix: "legacy")
        let dashboardDefaults = makeDefaults(suffix: "dashboard")
        let profileID = UUID()
        let keys = LivePreviewDashboardPersistence.persistenceKeys(profileID: profileID)
        let legacyDocument = Data("legacy".utf8)
        let existingDocument = Data("existing".utf8)

        legacyDefaults.set(legacyDocument, forKey: keys.document)
        legacyDefaults.set(UUID().uuidString, forKey: keys.selection)
        dashboardDefaults.set(existingDocument, forKey: keys.document)

        LivePreviewDashboardPersistence.prepare(
            legacyDefaults: legacyDefaults,
            dashboardDefaults: dashboardDefaults,
            profileIDs: [profileID],
            backupData: nil
        )

        XCTAssertEqual(dashboardDefaults.data(forKey: keys.document), existingDocument)
        XCTAssertEqual(
            dashboardDefaults.string(forKey: keys.selection),
            legacyDefaults.string(forKey: keys.selection)
        )
    }

    func testPrepareRestoresMissingBackupValuesAndIgnoresUnrelatedKeys() throws {
        let legacyDefaults = makeDefaults(suffix: "legacy")
        let dashboardDefaults = makeDefaults(suffix: "dashboard")
        let profileID = UUID()
        let keys = LivePreviewDashboardPersistence.persistenceKeys(profileID: profileID)
        let document = Data("backup-document".utf8)
        let selection = UUID().uuidString
        let backup = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "dataValues": [
                keys.document: document.base64EncodedString(),
                "homeAssistantAccessToken": Data("secret".utf8).base64EncodedString()
            ],
            "stringValues": [
                keys.selection: selection,
                "homeAssistantBaseURL": "https://example.invalid"
            ]
        ])

        LivePreviewDashboardPersistence.prepare(
            legacyDefaults: legacyDefaults,
            dashboardDefaults: dashboardDefaults,
            profileIDs: [profileID],
            backupData: backup
        )

        XCTAssertEqual(dashboardDefaults.data(forKey: keys.document), document)
        XCTAssertEqual(dashboardDefaults.string(forKey: keys.selection), selection)
        XCTAssertNil(dashboardDefaults.object(forKey: "homeAssistantAccessToken"))
        XCTAssertNil(dashboardDefaults.object(forKey: "homeAssistantBaseURL"))
    }

    func testPrepareDoesNotReplacePersistedLayoutWithBackup() throws {
        let legacyDefaults = makeDefaults(suffix: "legacy")
        let dashboardDefaults = makeDefaults(suffix: "dashboard")
        let keys = LivePreviewDashboardPersistence.persistenceKeys(profileID: nil)
        let persistedDocument = Data("persisted".utf8)
        dashboardDefaults.set(persistedDocument, forKey: keys.document)
        let backup = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "dataValues": [keys.document: Data("backup".utf8).base64EncodedString()],
            "stringValues": [:]
        ])

        LivePreviewDashboardPersistence.prepare(
            legacyDefaults: legacyDefaults,
            dashboardDefaults: dashboardDefaults,
            profileIDs: [nil],
            backupData: backup
        )

        XCTAssertEqual(dashboardDefaults.data(forKey: keys.document), persistedDocument)
    }

    private func makeDefaults(suffix: String) -> UserDefaults {
        let suiteName = "LivePreviewDashboardPersistenceXCTests.\(suffix).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
