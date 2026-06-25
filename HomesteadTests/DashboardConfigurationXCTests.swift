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
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Dashboard")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
        XCTAssertEqual(configuration.items.map(\.entityID), ["light.kitchen", nil])
        XCTAssertEqual(configuration.items.first?.resolvedCardSize, .square)
        XCTAssertEqual(configuration.entityDisplayNameOverride(for: "light.kitchen"), "Kitchen")
    }

    func testSavedDashboardWithoutDisplayTitleDefaultsDashboardTitle() throws {
        let defaults = makeDefaults()
        let dashboardID = UUID()
        let json = """
        [
          {
            "id": "\(dashboardID.uuidString)",
            "name": "iPhone",
            "items": [],
            "entityDisplayNameOverrides": {}
          }
        ]
        """
        defaults.set(Data(json.utf8), forKey: "homestead.dashboard.savedDashboards")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "iPhone")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
    }

    func testDefaultDashboardUsesDefaultNameAndDisplayTitle() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Dashboard")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
    }

    func testCreatingDashboardUsesProvidedNameAndDefaultDisplayTitle() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)

        let dashboardID = configuration.createDashboard(named: "iPad")
        let dashboard = configuration.dashboards.first { $0.id == dashboardID }

        XCTAssertEqual(dashboard?.resolvedName, "iPad")
        XCTAssertEqual(dashboard?.resolvedDisplayTitle, "Dashboard")
        XCTAssertEqual(configuration.selectedDashboardID, dashboardID)
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
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
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
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
    }

    func testDuplicateRenameAndDeleteCurrentDashboard() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen", size: .square)
        configuration.setEntityDisplayNameOverride("Kitchen", for: "light.kitchen")
        configuration.setDashboardDisplayTitle(id: configuration.selectedDashboardID, title: "Kitchen")

        let duplicateID = configuration.duplicateSelectedDashboard()
        configuration.renameDashboard(id: duplicateID, name: "Wall Tablet")

        XCTAssertEqual(configuration.selectedDashboardID, duplicateID)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Wall Tablet")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Kitchen")
        XCTAssertEqual(configuration.items.first?.entityID, "light.kitchen")
        XCTAssertEqual(configuration.items.first?.resolvedCardSize, .square)
        XCTAssertEqual(configuration.entityDisplayNameOverride(for: "light.kitchen"), "Kitchen")

        configuration.deleteDashboard(id: duplicateID)

        XCTAssertNotEqual(configuration.selectedDashboardID, duplicateID)
        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.items.first?.entityID, "light.kitchen")
    }

    func testDuplicatingSpecificDashboardDoesNotChangeLocalSelection() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let originalID = configuration.selectedDashboardID
        configuration.add("light.kitchen", size: .square)
        configuration.setDashboardDisplayTitle(id: originalID, title: "Home")
        let officeID = configuration.createDashboard(named: "Office")

        XCTAssertEqual(configuration.selectedDashboardID, officeID)

        let duplicateID = configuration.duplicateDashboard(id: originalID, named: "Phone Copy")

        XCTAssertEqual(configuration.selectedDashboardID, officeID)
        XCTAssertEqual(configuration.dashboards.first(where: { $0.id == duplicateID })?.resolvedName, "Phone Copy")
        XCTAssertEqual(configuration.dashboards.first(where: { $0.id == duplicateID })?.resolvedDisplayTitle, "Home")
        XCTAssertEqual(configuration.dashboards.first(where: { $0.id == duplicateID })?.items.first?.entityID, "light.kitchen")
    }

    func testDashboardNameAndDisplayTitleCanChangeIndependently() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let dashboardID = configuration.selectedDashboardID

        configuration.renameDashboard(id: dashboardID, name: "iPhone")

        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "iPhone")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")

        configuration.setDashboardDisplayTitle(id: dashboardID, title: "Living Room")

        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "iPhone")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Living Room")
    }

    func testMainDashboardTitleSourceUsesDisplayTitleNotName() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let dashboardID = configuration.selectedDashboardID

        configuration.renameDashboard(id: dashboardID, name: "iPhone")
        configuration.setDashboardDisplayTitle(id: dashboardID, title: "Dashboard")

        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "iPhone")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
    }

    func testDeletingLastDashboardRestoresEmptyDefault() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let onlyDashboardID = configuration.selectedDashboardID

        configuration.deleteDashboard(id: onlyDashboardID)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Dashboard")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testEmptySyncedDashboardListRestoresDefaultDashboard() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.createDashboard(named: "Office")

        configuration.applySyncSnapshot(DashboardConfigurationSyncSnapshot(dashboards: []))

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Dashboard")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Dashboard")
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testActiveDashboardDeletionFallsBackToRemainingDisplayTitle() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let phoneID = configuration.selectedDashboardID
        configuration.renameDashboard(id: phoneID, name: "Phone")
        configuration.setDashboardDisplayTitle(id: phoneID, title: "Phone Home")
        let officeID = configuration.createDashboard(named: "Office")
        configuration.setDashboardDisplayTitle(id: officeID, title: "Office")

        configuration.deleteDashboard(id: officeID)

        XCTAssertEqual(configuration.selectedDashboardID, phoneID)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Phone")
        XCTAssertEqual(configuration.selectedDashboard.resolvedDisplayTitle, "Phone Home")
    }

    func testDashboardReorderingSyncsDefinitionOrderWithoutChangingLocalSelection() {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let phoneID = configuration.selectedDashboardID
        configuration.renameDashboard(id: phoneID, name: "Phone")
        let officeID = configuration.createDashboard(named: "Office")
        let iPadID = configuration.createDashboard(named: "iPad")

        XCTAssertEqual(configuration.selectedDashboardID, iPadID)

        configuration.moveDashboards(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(configuration.dashboards.map(\.resolvedName), ["iPad", "Phone", "Office"])
        XCTAssertEqual(configuration.syncSnapshot.dashboards.map(\.id), [iPadID, phoneID, officeID])
        XCTAssertEqual(configuration.selectedDashboardID, iPadID)
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
