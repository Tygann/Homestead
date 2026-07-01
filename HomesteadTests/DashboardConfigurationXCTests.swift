import XCTest
@testable import Homestead

@MainActor
final class DashboardConfigurationXCTests: XCTestCase {
    func testOldDashboardStorageIsDiscardedAndSelectionResets() throws {
        let defaults = makeDefaults()
        defaults.set(Data("[{\"legacy\":true}]".utf8), forKey: "homestead.dashboard.savedDashboards")
        defaults.set(UUID().uuidString, forKey: "homestead.dashboard.selectedDashboardID")
        defaults.set(Data("[]".utf8), forKey: "dashboardItems")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertTrue(configuration.items.isEmpty)
        XCTAssertEqual(configuration.selectedDashboardID, configuration.dashboards[0].id)
        XCTAssertNil(defaults.object(forKey: "homestead.dashboard.savedDashboards"))
        XCTAssertNil(defaults.object(forKey: "homestead.dashboard.selectedDashboardID"))
        XCTAssertNil(defaults.object(forKey: "dashboardItems"))
        XCTAssertNotNil(defaults.data(forKey: "homestead.dashboard.configuration.v2"))
    }

    func testCorruptCurrentDocumentResetsWithoutCrashing() {
        let defaults = makeDefaults()
        defaults.set(Data("not-json".utf8), forKey: "homestead.dashboard.configuration.v2")
        defaults.set(UUID().uuidString, forKey: "homestead.dashboard.selectedDashboardID.v2")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertTrue(configuration.items.isEmpty)
        XCTAssertEqual(configuration.selectedDashboardID, configuration.dashboards[0].id)
    }

    func testUnsupportedDocumentVersionResets() throws {
        let defaults = makeDefaults()
        let unsupported = DashboardConfigurationDocument(
            schemaVersion: DashboardConfigurationDocument.currentSchemaVersion + 1,
            dashboards: [makeDashboard(items: [.entityChip(entityID: "sensor.old")])]
        )
        defaults.set(try JSONEncoder().encode(unsupported), forKey: "homestead.dashboard.configuration.v2")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertTrue(configuration.items.isEmpty)
        let stored = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v2"))
        let decoded = try JSONDecoder().decode(DashboardConfigurationDocument.self, from: stored)
        XCTAssertEqual(decoded.schemaVersion, DashboardConfigurationDocument.currentSchemaVersion)
    }

    func testCurrentDocumentRoundTripsOnlyNewSchema() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let graphID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.graph(layout: .wide))
        ))
        configuration.renameDisplayItem(id: graphID, displayNameOverride: "Temperature")
        _ = configuration.add(source: .summary(.lights), presentation: .chip)

        let restored = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(restored.items.count, 2)
        XCTAssertEqual(restored.items[0].source, .entity("sensor.temperature"))
        XCTAssertEqual(restored.items[0].cardConfiguration, .graph(layout: .wide))
        XCTAssertEqual(restored.items[0].displayNameOverride, "Temperature")
        XCTAssertEqual(restored.items[1].source, .summary(.lights))
        XCTAssertEqual(restored.items[1].presentation, .chip)

        let data = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v2"))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("chipKind"))
        XCTAssertFalse(json.contains("summaryKind"))
        XCTAssertFalse(json.contains("entityDisplayNameOverrides"))
    }

    func testInvalidDecodedPresentationIsRemovedBeforeActivation() throws {
        let defaults = makeDefaults()
        let invalid = DashboardItemConfiguration.entityCard(
            entityID: "sensor.humidity",
            configuration: .gauge(layout: .mini)
        )
        let document = DashboardConfigurationDocument(dashboards: [makeDashboard(items: [invalid])])
        defaults.set(try JSONEncoder().encode(document), forKey: "homestead.dashboard.configuration.v2")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testDuplicateIdentityAllowsDifferentPresentationsButNotSameKind() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let statusID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .compact))
        ))
        let duplicateStatusID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .wide))
        ))
        let graphID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.graph(layout: .square))
        ))

        XCTAssertEqual(statusID, duplicateStatusID)
        XCTAssertNotEqual(statusID, graphID)
        XCTAssertEqual(configuration.items.count, 2)
    }

    func testSummaryCardAndInvalidLayoutAreRejected() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())

        XCTAssertNil(configuration.add(
            source: .summary(.lights),
            presentation: .card(.status(layout: .compact))
        ))
        XCTAssertNil(configuration.add(
            source: .entity("sensor.humidity"),
            presentation: .card(.gauge(layout: .mini))
        ))
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testOldICloudDashboardSnapshotSanitizesWithoutDecodingItems() throws {
        let oldJSON = """
        {
          "dashboards": [{
            "id": "\(UUID().uuidString)",
            "name": "Old",
            "items": [{"not":"the new item model"}],
            "entityDisplayNameOverrides": {}
          }]
        }
        """

        let snapshot = try JSONDecoder().decode(
            DashboardConfigurationSyncSnapshot.self,
            from: Data(oldJSON.utf8)
        )

        XCTAssertEqual(snapshot.schemaVersion, DashboardConfigurationDocument.currentSchemaVersion)
        XCTAssertTrue(snapshot.dashboards.isEmpty)
    }

    func testStaleDashboardSectionDoesNotDiscardOtherICloudPreferences() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = HomesteadICloudSyncPayload(
            version: HomesteadICloudSyncPayload.currentVersion,
            sourceDeviceID: "test-device",
            connection: HomesteadSyncRecord(
                updatedAt: updatedAt,
                value: HomesteadConnectionSyncSnapshot(
                    baseURL: "https://home.example",
                    internalURL: "http://home.local:8123",
                    externalURL: "https://home.example"
                )
            ),
            dashboard: HomesteadSyncRecord(
                updatedAt: updatedAt,
                value: DashboardConfigurationSyncSnapshot(dashboards: [])
            ),
            actionConfirmations: HomesteadSyncRecord(
                updatedAt: updatedAt,
                value: ActionConfirmationSettingsSyncSnapshot(
                    mode: .all,
                    confirmsLockUnlocks: true,
                    confirmsSecurityCoverOpens: true,
                    confirmsScenes: true,
                    confirmsScripts: true,
                    confirmsOtherImpactfulActions: true
                )
            ),
            appearance: HomesteadSyncRecord(
                updatedAt: updatedAt,
                value: HomesteadAppearanceSettingsSyncSnapshot(isWallpaperEnabled: true)
            )
        )
        let encoded = try JSONEncoder().encode(payload)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var dashboardRecord = try XCTUnwrap(object["dashboard"] as? [String: Any])
        dashboardRecord["value"] = ["dashboards": [["legacy": true]]]
        object["dashboard"] = dashboardRecord
        let staleData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(HomesteadICloudSyncPayload.self, from: staleData)

        XCTAssertEqual(decoded.connection.value.baseURL, "https://home.example")
        XCTAssertEqual(decoded.actionConfirmations.value.mode, .all)
        XCTAssertTrue(decoded.appearance.value.isWallpaperEnabled)
        XCTAssertTrue(decoded.dashboard.value.dashboards.isEmpty)
    }

    func testSavedDashboardDefinitionsSyncButSelectionRemainsLocal() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "iPad")
        XCTAssertEqual(configuration.selectedDashboardID, secondID)

        configuration.applySyncSnapshot(DashboardConfigurationSyncSnapshot(dashboards: [
            SavedDashboardConfiguration(
                id: firstID,
                name: "Phone",
                items: [.entityCard(entityID: "light.phone", configuration: .control(layout: .square, featureVisibility: .automatic))]
            ),
            SavedDashboardConfiguration(
                id: secondID,
                name: "Tablet",
                items: [.entityCard(entityID: "light.tablet", configuration: .status(layout: .compact))]
            )
        ]))

        XCTAssertEqual(configuration.selectedDashboardID, secondID)
        XCTAssertEqual(configuration.selectedDashboard.resolvedName, "Tablet")
        XCTAssertEqual(configuration.items.first?.entityID, "light.tablet")
    }

    func testCatalogRejectsIncompatibleEntityPresentationDuringReconciliation() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        _ = configuration.add(
            source: .entity("light.kitchen"),
            presentation: .card(.camera(layout: .square))
        )
        let store = HAStateStore()
        store.applyInitialStates([HAEntityDTO(entityID: "light.kitchen", state: "on")])

        configuration.reconcile(with: store.allEntityBoxes())

        XCTAssertFalse(configuration.items.contains { $0.presentation?.kind == .camera })
        XCTAssertFalse(configuration.items.isEmpty, "A reset dashboard should reseed from valid catalog recommendations.")
        XCTAssertEqual(configuration.items.first?.presentation?.kind, .control)
    }

    func testCatalogRecommendationsUseCapabilitiesRatherThanLiveState() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "off"),
            HAEntityDTO(
                entityID: "sensor.temperature",
                state: "70",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "85",
                attributes: [
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(entityID: "camera.driveway", state: "idle")
        ])

        let light = try XCTUnwrap(store.entityBox(for: "light.kitchen"))
        let temperature = try XCTUnwrap(store.entityBox(for: "sensor.temperature"))
        let battery = try XCTUnwrap(store.entityBox(for: "sensor.remote_battery"))
        let camera = try XCTUnwrap(store.entityBox(for: "camera.driveway"))

        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: light).kind, .control)
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: temperature).kind, .graph)
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: battery).kind, .status)
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: camera).kind, .camera)
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: temperature).contains(.gauge))

        store.applyLiveStateUpdates([HAEntityDTO(entityID: "light.kitchen", state: "on")])
        let updatedLight = try XCTUnwrap(store.entityBox(for: "light.kitchen"))
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: updatedLight).kind, .control)
    }

    private func makeDashboard(items: [DashboardItemConfiguration]) -> SavedDashboardConfiguration {
        SavedDashboardConfiguration(id: UUID(), name: "Dashboard", items: items)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.tyler.Homestead.dashboard.xctests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }
}
