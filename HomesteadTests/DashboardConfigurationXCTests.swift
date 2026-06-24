import XCTest
@testable import Homestead

@MainActor
final class DashboardConfigurationXCTests: XCTestCase {
    func testMigratesSingleDashboardStorageIntoSavedDashboard() throws {
        let defaults = makeDefaults()
        let legacyItems = [
            DashboardItemConfiguration.entity(entityID: "light.kitchen", size: .square),
            DashboardItemConfiguration.header(title: "Downstairs")
        ]
        let legacyOverrides = ["light.kitchen": "Kitchen"]
        defaults.set(try JSONEncoder().encode(legacyItems), forKey: "dashboardItems")
        defaults.set(try JSONEncoder().encode(legacyOverrides), forKey: "entityDisplayNameOverrides")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "My Dashboard")
        XCTAssertEqual(configuration.items.map(\.entityID), ["light.kitchen", nil])
        XCTAssertEqual(configuration.items.first?.resolvedCardSize, .square)
        XCTAssertEqual(configuration.entityDisplayNameOverride(for: "light.kitchen"), "Kitchen")
    }

    func testSelectedDashboardIDIsLocalAndNotAppliedFromSyncSnapshot() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let firstDashboardID = configuration.selectedDashboardID
        let secondDashboardID = configuration.createDashboard(named: "iPad")
        XCTAssertEqual(configuration.selectedDashboardID, secondDashboardID)

        let remoteSnapshot = DashboardConfigurationSyncSnapshot(dashboards: [
            SavedDashboardConfiguration(
                id: firstDashboardID,
                name: "Phone",
                items: [.entity(entityID: "light.phone", size: .compact)],
                entityDisplayNameOverrides: [:]
            ),
            SavedDashboardConfiguration(
                id: secondDashboardID,
                name: "Tablet",
                items: [.entity(entityID: "light.tablet", size: .wide)],
                entityDisplayNameOverrides: [:]
            )
        ])

        configuration.applySyncSnapshot(remoteSnapshot)

        XCTAssertEqual(configuration.selectedDashboardID, secondDashboardID)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Tablet")
        XCTAssertEqual(configuration.items.first?.entityID, "light.tablet")
        XCTAssertEqual(configuration.syncSnapshot.dashboards.count, 2)
    }

    func testSelectedDashboardFallsBackWhenMissing() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let removedDashboardID = configuration.selectedDashboardID
        let keptDashboardID = configuration.createDashboard(named: "Office")

        XCTAssertEqual(configuration.selectedDashboardID, keptDashboardID)

        configuration.applySyncSnapshot(DashboardConfigurationSyncSnapshot(dashboards: [
            SavedDashboardConfiguration(
                id: removedDashboardID,
                name: "Phone",
                items: [.entity(entityID: "light.phone", size: .compact)],
                entityDisplayNameOverrides: [:]
            )
        ]))

        XCTAssertEqual(configuration.selectedDashboardID, removedDashboardID)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Phone")
    }

    func testDuplicateRenameAndDeleteCurrentDashboard() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen", size: .square)
        configuration.setEntityDisplayNameOverride("Kitchen", for: "light.kitchen")

        let duplicateID = configuration.duplicateSelectedDashboard()
        configuration.renameDashboard(id: duplicateID, name: "Wall Tablet")

        XCTAssertEqual(configuration.selectedDashboardID, duplicateID)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Wall Tablet")
        XCTAssertEqual(configuration.items.first?.entityID, "light.kitchen")
        XCTAssertEqual(configuration.items.first?.resolvedCardSize, .square)
        XCTAssertEqual(configuration.entityDisplayNameOverride(for: "light.kitchen"), "Kitchen")

        configuration.deleteDashboard(id: duplicateID)

        XCTAssertNotEqual(configuration.selectedDashboardID, duplicateID)
        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.items.first?.entityID, "light.kitchen")
    }

    func testDeletingLastDashboardRestoresEmptyDefault() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let onlyDashboardID = configuration.selectedDashboardID

        configuration.deleteDashboard(id: onlyDashboardID)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "My Dashboard")
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testEmptySyncedDashboardListRestoresDefaultDashboard() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.createDashboard(named: "Office")

        configuration.applySyncSnapshot(DashboardConfigurationSyncSnapshot(dashboards: []))

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "My Dashboard")
        XCTAssertTrue(configuration.items.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.tyler.Homestead.dashboard.xctests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
