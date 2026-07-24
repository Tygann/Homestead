import XCTest
@testable import Homestead

@MainActor
final class DashboardConfigurationXCTests: XCTestCase {
    func testOldDashboardStorageIsDiscardedAndSelectionResets() throws {
        let defaults = makeDefaults()
        defaults.set(Data("[{\"legacy\":true}]".utf8), forKey: "homestead.dashboard.savedDashboards")
        defaults.set(UUID().uuidString, forKey: "homestead.dashboard.selectedDashboardID")
        defaults.set(Data("[]".utf8), forKey: "dashboardItems")
        defaults.set(Data("{\"schemaVersion\":2,\"dashboards\":[]}".utf8), forKey: "homestead.dashboard.configuration.v2")
        defaults.set(UUID().uuidString, forKey: "homestead.dashboard.selectedDashboardID.v2")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertTrue(configuration.items.isEmpty)
        XCTAssertEqual(configuration.selectedDashboardID, configuration.dashboards[0].id)
        XCTAssertNil(defaults.object(forKey: "homestead.dashboard.savedDashboards"))
        XCTAssertNil(defaults.object(forKey: "homestead.dashboard.selectedDashboardID"))
        XCTAssertNil(defaults.object(forKey: "dashboardItems"))
        XCTAssertNil(defaults.object(forKey: "homestead.dashboard.configuration.v2"))
        XCTAssertNil(defaults.object(forKey: "homestead.dashboard.selectedDashboardID.v2"))
        XCTAssertNotNil(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
    }

    func testCorruptCurrentDocumentResetsWithoutCrashing() {
        let defaults = makeDefaults()
        defaults.set(Data("not-json".utf8), forKey: "homestead.dashboard.configuration.v3")
        defaults.set(UUID().uuidString, forKey: "homestead.dashboard.selectedDashboardID.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertTrue(configuration.items.isEmpty)
        XCTAssertEqual(configuration.selectedDashboardID, configuration.dashboards[0].id)
    }

    func testNewerDocumentVersionIsPreservedWithoutBeingOverwritten() throws {
        let defaults = makeDefaults()
        let selectedID = UUID()
        let unsupported = DashboardConfigurationDocument(
            schemaVersion: DashboardConfigurationDocument.currentSchemaVersion + 1,
            dashboards: [makeDashboard(items: [.entityChip(entityID: "sensor.old")])]
        )
        let originalData = try JSONEncoder().encode(unsupported)
        defaults.set(originalData, forKey: "homestead.dashboard.configuration.v3")
        defaults.set(selectedID.uuidString, forKey: "homestead.dashboard.selectedDashboardID.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertTrue(configuration.items.isEmpty)
        let stored = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
        XCTAssertEqual(stored, originalData)
        XCTAssertEqual(defaults.string(forKey: "homestead.dashboard.selectedDashboardID.v3"), selectedID.uuidString)
    }

    func testVersionFiveDocumentMigratesToChartAndPreservesDashboardsAndSelection() throws {
        let defaults = makeDefaults()
        let first = SavedDashboardConfiguration(
            id: UUID(),
            name: "Upstairs",
            displayTitle: "Second Floor",
            items: [.entityChip(entityID: "light.hall")]
        )
        let second = SavedDashboardConfiguration(
            id: UUID(),
            name: "Climate",
            displayTitle: "Indoor Climate",
            items: [.entityCard(entityID: "sensor.temperature", configuration: .chart(layout: .wide))]
        )
        let currentData = try JSONEncoder().encode(DashboardConfigurationDocument(dashboards: [first, second]))
        let currentJSON = try XCTUnwrap(String(data: currentData, encoding: .utf8))
        let versionFiveJSON = currentJSON
            .replacingOccurrences(of: "\"schemaVersion\":6", with: "\"schemaVersion\":5")
            .replacingOccurrences(of: "\"chart\"", with: "\"graph\"")
        XCTAssertNotEqual(versionFiveJSON, currentJSON)
        let versionFiveData = Data(versionFiveJSON.utf8)
        defaults.set(versionFiveData, forKey: "homestead.dashboard.configuration.v3")
        defaults.set(second.id.uuidString, forKey: "homestead.dashboard.selectedDashboardID.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.map(\.name), ["Upstairs", "Climate"])
        XCTAssertEqual(configuration.dashboards.map(\.displayTitle), ["Second Floor", "Indoor Climate"])
        XCTAssertEqual(configuration.selectedDashboardID, second.id)
        XCTAssertEqual(configuration.items.first?.cardConfiguration, .chart(layout: .wide))

        let migratedData = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
        let migratedJSON = try XCTUnwrap(String(data: migratedData, encoding: .utf8))
        XCTAssertTrue(migratedJSON.contains("\"schemaVersion\":6"))
        XCTAssertTrue(migratedJSON.contains("\"chart\""))
        XCTAssertFalse(migratedJSON.contains("\"graph\""))
        XCTAssertEqual(defaults.data(forKey: "homestead.dashboard.configuration.v3.backup"), versionFiveData)
    }

    func testMalformedCardIsDroppedWithoutDiscardingDashboardOrSiblingCards() throws {
        let defaults = makeDefaults()
        let dashboard = makeDashboard(items: [
            .entityChip(entityID: "light.kitchen"),
            .entityCard(entityID: "sensor.temperature", configuration: .chart(layout: .wide))
        ])
        let data = try JSONEncoder().encode(DashboardConfigurationDocument(dashboards: [dashboard]))
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var dashboards = try XCTUnwrap(root["dashboards"] as? [[String: Any]])
        var items = try XCTUnwrap(dashboards[0]["items"] as? [[String: Any]])
        items.insert(["malformed": true], at: 1)
        dashboards[0]["items"] = items
        root["dashboards"] = dashboards
        defaults.set(try JSONSerialization.data(withJSONObject: root), forKey: "homestead.dashboard.configuration.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.count, 1)
        XCTAssertEqual(configuration.dashboards[0].id, dashboard.id)
        XCTAssertEqual(configuration.items.map(\.source), [.entity("light.kitchen"), .entity("sensor.temperature")])
    }

    func testMalformedDashboardIsDroppedWithoutDiscardingValidDashboard() throws {
        let defaults = makeDefaults()
        let dashboard = makeDashboard(items: [.entityChip(entityID: "light.kitchen")])
        let data = try JSONEncoder().encode(DashboardConfigurationDocument(dashboards: [dashboard]))
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var dashboards = try XCTUnwrap(root["dashboards"] as? [[String: Any]])
        dashboards.insert(["id": 42, "name": "Broken"], at: 0)
        root["dashboards"] = dashboards
        defaults.set(try JSONSerialization.data(withJSONObject: root), forKey: "homestead.dashboard.configuration.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.map(\.id), [dashboard.id])
        XCTAssertEqual(configuration.items.first?.source, .entity("light.kitchen"))
    }

    func testCorruptDocumentRecoversLastKnownGoodBackup() throws {
        let defaults = makeDefaults()
        let dashboard = makeDashboard(items: [.entityChip(entityID: "light.kitchen")])
        let backup = try JSONEncoder().encode(DashboardConfigurationDocument(dashboards: [dashboard]))
        defaults.set(backup, forKey: "homestead.dashboard.configuration.v3.backup")
        defaults.set(Data("not-json".utf8), forKey: "homestead.dashboard.configuration.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.dashboards.map(\.id), [dashboard.id])
        XCTAssertEqual(configuration.items.first?.source, .entity("light.kitchen"))
        XCTAssertEqual(defaults.data(forKey: "homestead.dashboard.configuration.v3.rejected"), Data("not-json".utf8))
    }

    func testCurrentDocumentRoundTripsOnlyNewSchema() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let chartID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.chart(layout: .wide))
        ))
        configuration.renameDisplayItem(id: chartID, displayNameOverride: "Temperature")
        _ = configuration.add(source: .summary(.lights), presentation: .chip)

        let storedBeforeRestore = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
        _ = try JSONDecoder().decode(DashboardConfigurationDocument.self, from: storedBeforeRestore)
        let restored = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(restored.items.count, 2)
        XCTAssertEqual(restored.items[0].source, .entity("sensor.temperature"))
        XCTAssertEqual(restored.items[0].cardConfiguration, .chart(layout: .wide))
        XCTAssertEqual(restored.items[0].displayNameOverride, "Temperature")
        XCTAssertEqual(restored.items[1].source, .summary(.lights))
        XCTAssertEqual(restored.items[1].presentation, .chip)

        let data = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(DashboardConfigurationDocument.currentSchemaVersion, 6)
        XCTAssertTrue(json.contains("\"chart\""))
        XCTAssertFalse(json.contains("\"graph\""))
        XCTAssertFalse(json.contains("chipKind"))
        XCTAssertFalse(json.contains("summaryKind"))
        XCTAssertFalse(json.contains("entityDisplayNameOverrides"))
    }

    func testChartRangePersistsOnlyForChartCards() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let chartID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.chart(layout: .wide))
        ))
        let statusID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .square))
        ))

        configuration.setChartConfiguration(.init(range: .day), forItemID: chartID)
        configuration.setChartConfiguration(.init(range: .week), forItemID: statusID)

        XCTAssertEqual(configuration.items.first(where: { $0.id == chartID })?.chartConfiguration?.range, .day)
        XCTAssertNil(configuration.items.first(where: { $0.id == statusID })?.chartConfiguration)

        let restored = DashboardConfiguration(defaults: defaults)
        let layoutItems = DashboardLayoutItemBuilder.makeItems(from: restored.items)
        guard case .card(let restoredChart)? = layoutItems.first(where: { $0.configurationItemID == chartID })?.kind else {
            return XCTFail("Expected restored chart card")
        }
        XCTAssertEqual(restoredChart.chartConfiguration.range, HAHistoryRangePreset.day)

        restored.setChartConfiguration(.default, forItemID: chartID)
        XCTAssertNil(restored.items.first(where: { $0.id == chartID })?.chartConfiguration)
    }

    func testInvalidDecodedPresentationIsRemovedBeforeActivation() throws {
        let defaults = makeDefaults()
        let invalid = DashboardItemConfiguration.entityCard(
            entityID: "sensor.humidity",
            configuration: .circularGauge(layout: .mini)
        )
        let document = DashboardConfigurationDocument(dashboards: [makeDashboard(items: [invalid])])
        defaults.set(try JSONEncoder().encode(document), forKey: "homestead.dashboard.configuration.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testCurrentDocumentRoundTripsAtomicGaugeCards() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        _ = configuration.add(
            source: .entity("sensor.battery"),
            presentation: .card(.circularGauge(layout: .square))
        )
        let segmentedID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.battery"),
            presentation: .card(.segmentedGauge(layout: .square))
        ))
        let zoneConfiguration = GaugeZoneConfiguration(
            lowerBound: 0,
            upperBound: 100,
            boundaries: [15, 30, 70, 85],
            colors: [
                .standard(for: .critical), .standard(for: .warning), .standard(for: .nominal),
                .standard(for: .warning), .standard(for: .critical)
            ]
        )
        configuration.setGaugeZoneConfiguration(zoneConfiguration, forItemID: segmentedID)
        _ = configuration.add(
            source: .entity("sensor.battery"),
            presentation: .card(.barGauge(layout: .wide))
        )

        let restored = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(
            restored.items.compactMap(\.cardConfiguration),
            [
                .circularGauge(layout: .square),
                .segmentedGauge(layout: .square),
                .barGauge(layout: .wide)
            ]
        )
        XCTAssertEqual(restored.items.first(where: { $0.id == segmentedID })?.gaugeZoneConfiguration, zoneConfiguration)
    }

    func testEntityPresentationsCanRepeatAcrossCardTypesAndLayouts() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let statusID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .compact))
        ))
        let wideStatusID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .wide))
        ))
        let secondCompactStatusID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .compact))
        ))
        let chartID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.chart(layout: .square))
        ))
        let circularGaugeID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.circularGauge(layout: .square))
        ))
        let wideCircularGaugeID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.circularGauge(layout: .wide))
        ))
        let barGaugeID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.barGauge(layout: .wide))
        ))

        XCTAssertNotEqual(statusID, wideStatusID)
        XCTAssertNotEqual(statusID, secondCompactStatusID)
        XCTAssertNotEqual(statusID, chartID)
        XCTAssertNotEqual(circularGaugeID, wideCircularGaugeID)
        XCTAssertNotEqual(circularGaugeID, barGaugeID)
        XCTAssertEqual(configuration.items.count, 7)
        XCTAssertEqual(
            configuration.presentationCount(
                source: .entity("sensor.temperature"),
                presentation: .card(.status(layout: .square))
            ),
            3
        )
    }

    func testRepeatedEntityPresentationsSurvivePersistenceNormalization() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        _ = configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .compact))
        )
        _ = configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .wide))
        )
        _ = configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.barGauge(layout: .wide))
        )

        let restored = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(restored.items.count, 3)
        XCTAssertEqual(
            restored.presentationCount(
                source: .entity("sensor.temperature"),
                presentation: .card(.status(layout: .square))
            ),
            2
        )
    }

    func testReplacingCardEntityPreservesIdentityPresentationAndCustomizations() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        _ = configuration.addHeader(title: "Climate")
        let cardID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.hall_temperature"),
            presentation: .card(.segmentedGauge(layout: .wide))
        ))
        _ = configuration.add(
            source: .entity("light.kitchen"),
            presentation: .card(.status(layout: .compact))
        )
        configuration.renameDisplayItem(id: cardID, displayNameOverride: "Hallway")
        configuration.setIconNameOverride("thermometer.medium", forItemID: cardID)
        let zoneConfiguration = GaugeZoneConfiguration(
            lowerBound: 50,
            upperBound: 90,
            boundaries: [68, 76],
            colors: [
                .standard(for: .low),
                .standard(for: .nominal),
                .standard(for: .high)
            ],
            names: ["Cool", "Comfortable", "Warm"]
        )
        configuration.setGaugeZoneConfiguration(zoneConfiguration, forItemID: cardID)
        let originalIDs = configuration.items.map(\.id)

        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.bedroom_temperature",
                state: "72",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            )
        ])
        let replacement = try XCTUnwrap(store.entityBox(for: "sensor.bedroom_temperature"))

        XCTAssertTrue(configuration.replaceEntity(
            forItemID: cardID,
            with: replacement,
            preserveGaugeZoneConfiguration: true
        ))
        XCTAssertEqual(configuration.items.map(\.id), originalIDs)
        let updatedCard = try XCTUnwrap(configuration.items.first { $0.id == cardID })
        XCTAssertEqual(updatedCard.source, .entity("sensor.bedroom_temperature"))
        XCTAssertEqual(updatedCard.cardConfiguration, .segmentedGauge(layout: .wide))
        XCTAssertEqual(updatedCard.displayNameOverride, "Hallway")
        XCTAssertEqual(updatedCard.iconNameOverride, "thermometer.medium")
        XCTAssertEqual(updatedCard.gaugeZoneConfiguration, zoneConfiguration)
    }

    func testReplacingGaugeEntityResetsOnlyIncompatibleGaugeCustomization() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let cardID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.hall_temperature"),
            presentation: .card(.circularGauge(layout: .square))
        ))
        configuration.renameDisplayItem(id: cardID, displayNameOverride: "Comfort")
        configuration.setIconNameOverride("house", forItemID: cardID)
        configuration.setGaugeZoneConfiguration(
            GaugeZoneConfiguration(
                lowerBound: 50,
                upperBound: 90,
                boundaries: [70],
                colors: [.standard(for: .low), .standard(for: .critical)]
            ),
            forItemID: cardID
        )

        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.humidity",
                state: "45",
                attributes: [
                    "device_class": .string("humidity"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])
        let humidity = try XCTUnwrap(store.entityBox(for: "sensor.humidity"))
        let light = try XCTUnwrap(store.entityBox(for: "light.kitchen"))

        XCTAssertFalse(configuration.replaceEntity(
            forItemID: cardID,
            with: light,
            preserveGaugeZoneConfiguration: false
        ))
        XCTAssertTrue(configuration.replaceEntity(
            forItemID: cardID,
            with: humidity,
            preserveGaugeZoneConfiguration: false
        ))
        let updatedCard = try XCTUnwrap(configuration.items.first { $0.id == cardID })
        XCTAssertEqual(updatedCard.source, .entity("sensor.humidity"))
        XCTAssertEqual(updatedCard.displayNameOverride, "Comfort")
        XCTAssertEqual(updatedCard.iconNameOverride, "house")
        XCTAssertNil(updatedCard.gaugeZoneConfiguration)
    }

    func testContextualCardEditingTargetsNonSelectedDashboard() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let sourceDashboardID = configuration.selectedDashboardID
        let cardID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.chart(layout: .wide))
        ))
        let reference = DashboardItemReference(dashboardID: sourceDashboardID, itemID: cardID)

        let selectedDashboardID = configuration.createDashboard(named: "Other")
        XCTAssertTrue(configuration.selectDashboard(id: selectedDashboardID))
        XCTAssertEqual(configuration.selectedDashboardID, selectedDashboardID)
        XCTAssertTrue(configuration.items.isEmpty)

        XCTAssertTrue(configuration.renameDisplayItem(reference, displayNameOverride: "Outside"))
        XCTAssertTrue(configuration.setIconNameOverride("thermometer.medium", for: reference))
        XCTAssertTrue(configuration.setCardLayout(.large, for: reference))
        XCTAssertTrue(configuration.setChartConfiguration(.init(range: .week), for: reference))

        let edited = try XCTUnwrap(configuration.item(for: reference))
        XCTAssertEqual(edited.displayNameOverride, "Outside")
        XCTAssertEqual(edited.iconNameOverride, "thermometer.medium")
        XCTAssertEqual(edited.cardConfiguration, .chart(layout: .large))
        XCTAssertEqual(edited.chartConfiguration, .init(range: .week))
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testTransactionalCardUpdateAppliesAllDraftFieldsToExactCard() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let sourceDashboardID = configuration.selectedDashboardID
        let cardID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.hall_temperature"),
            presentation: .card(.segmentedGauge(layout: .wide))
        ))
        let reference = DashboardItemReference(dashboardID: sourceDashboardID, itemID: cardID)
        let zones = GaugeZoneConfiguration(
            lowerBound: 50,
            upperBound: 90,
            boundaries: [68, 76],
            colors: [
                .standard(for: .low),
                .standard(for: .nominal),
                .standard(for: .high)
            ]
        )

        let otherDashboardID = configuration.createDashboard(named: "Other")
        XCTAssertTrue(configuration.selectDashboard(id: otherDashboardID))
        XCTAssertTrue(configuration.applyCardUpdate(
            DashboardCardUpdate(
                entityID: "sensor.bedroom_temperature",
                configuration: .segmentedGauge(layout: .large),
                displayNameOverride: "Comfort",
                iconNameOverride: "thermometer.medium",
                gaugeZoneConfiguration: zones,
                chartConfiguration: .default
            ),
            for: reference
        ))

        let updated = try XCTUnwrap(configuration.item(for: reference))
        XCTAssertEqual(updated.source, .entity("sensor.bedroom_temperature"))
        XCTAssertEqual(updated.cardConfiguration, .segmentedGauge(layout: .large))
        XCTAssertEqual(updated.displayNameOverride, "Comfort")
        XCTAssertEqual(updated.iconNameOverride, "thermometer.medium")
        XCTAssertEqual(updated.gaugeZoneConfiguration, zones)
        XCTAssertNil(updated.chartConfiguration)
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testTransactionalCardUpdateRejectsInvalidDraftWithoutPartialMutation() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let cardID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.status(layout: .compact))
        ))
        let reference = DashboardItemReference(
            dashboardID: configuration.selectedDashboardID,
            itemID: cardID
        )
        let original = try XCTUnwrap(configuration.item(for: reference))

        XCTAssertFalse(configuration.applyCardUpdate(
            DashboardCardUpdate(
                entityID: "sensor.changed",
                configuration: .status(layout: .compact),
                displayNameOverride: "Changed",
                iconNameOverride: "house",
                gaugeZoneConfiguration: nil,
                chartConfiguration: .init(range: .week)
            ),
            for: reference
        ))
        XCTAssertEqual(configuration.item(for: reference), original)
    }

    func testCompositeCardReferenceDisambiguatesMatchingItemIDs() throws {
        let sharedItemID = UUID()
        let firstDashboardID = UUID()
        let secondDashboardID = UUID()
        let firstItem = DashboardItemConfiguration.entityCard(
            entityID: "sensor.first",
            configuration: .status(layout: .compact),
            id: sharedItemID
        )
        let secondItem = DashboardItemConfiguration.entityCard(
            entityID: "sensor.second",
            configuration: .status(layout: .compact),
            id: sharedItemID
        )
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        XCTAssertTrue(configuration.applySyncSnapshot(DashboardConfigurationSyncSnapshot(dashboards: [
            SavedDashboardConfiguration(id: firstDashboardID, name: "First", items: [firstItem]),
            SavedDashboardConfiguration(id: secondDashboardID, name: "Second", items: [secondItem])
        ])))

        let secondReference = DashboardItemReference(
            dashboardID: secondDashboardID,
            itemID: sharedItemID
        )
        XCTAssertTrue(configuration.renameDisplayItem(secondReference, displayNameOverride: "Second Card"))

        let firstReference = DashboardItemReference(
            dashboardID: firstDashboardID,
            itemID: sharedItemID
        )
        XCTAssertNil(configuration.item(for: firstReference)?.displayNameOverride)
        XCTAssertEqual(configuration.item(for: secondReference)?.displayNameOverride, "Second Card")
    }

    func testContextualGaugeReplacementAndRemovalTargetNonSelectedDashboard() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let sourceDashboardID = configuration.selectedDashboardID
        let cardID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.hall_temperature"),
            presentation: .card(.segmentedGauge(layout: .wide))
        ))
        let reference = DashboardItemReference(dashboardID: sourceDashboardID, itemID: cardID)
        let zones = GaugeZoneConfiguration(
            lowerBound: 50,
            upperBound: 90,
            boundaries: [68, 76],
            colors: [
                .standard(for: .low),
                .standard(for: .nominal),
                .standard(for: .high)
            ]
        )

        let otherDashboardID = configuration.createDashboard(named: "Other")
        XCTAssertTrue(configuration.selectDashboard(id: otherDashboardID))
        XCTAssertTrue(configuration.setGaugeZoneConfiguration(zones, for: reference))

        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.bedroom_temperature",
                state: "72",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            )
        ])
        let replacement = try XCTUnwrap(store.entityBox(for: "sensor.bedroom_temperature"))

        XCTAssertTrue(configuration.replaceEntity(
            for: reference,
            with: replacement,
            preserveGaugeZoneConfiguration: true
        ))
        XCTAssertEqual(configuration.item(for: reference)?.source, .entity("sensor.bedroom_temperature"))
        XCTAssertEqual(configuration.item(for: reference)?.gaugeZoneConfiguration, zones)
        XCTAssertTrue(configuration.items.isEmpty)

        XCTAssertTrue(configuration.removeItem(for: reference))
        XCTAssertNil(configuration.item(for: reference))
        XCTAssertEqual(
            configuration.dashboards.first(where: { $0.id == sourceDashboardID })?.setupState,
            .intentionallyEmpty
        )
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testStaleContextualCardReferenceFailsWithoutChangingDashboards() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let originalDashboards = configuration.dashboards
        let staleReference = DashboardItemReference(dashboardID: UUID(), itemID: UUID())
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "sensor.replacement", state: "1", attributes: [:])
        ])
        let replacement = try XCTUnwrap(store.entityBox(for: "sensor.replacement"))

        XCTAssertFalse(configuration.renameDisplayItem(staleReference, displayNameOverride: "Missing"))
        XCTAssertFalse(configuration.setIconNameOverride("house", for: staleReference))
        XCTAssertFalse(configuration.setCardLayout(.wide, for: staleReference))
        XCTAssertFalse(configuration.setGaugeZoneConfiguration(nil, for: staleReference))
        XCTAssertFalse(configuration.setChartConfiguration(.init(range: .week), for: staleReference))
        XCTAssertFalse(configuration.replaceEntity(
            for: staleReference,
            with: replacement,
            preserveGaugeZoneConfiguration: true
        ))
        XCTAssertFalse(configuration.removeItem(for: staleReference))
        XCTAssertEqual(configuration.dashboards, originalDashboards)
    }

    func testGaugeReplacementPolicyRequiresMatchingDeviceClassAndUnit() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.hall_temperature",
                state: "71",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.bedroom_temperature",
                state: "72",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.outdoor_temperature",
                state: "20",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°C")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.humidity",
                state: "45",
                attributes: [
                    "device_class": .string("humidity"),
                    "unit_of_measurement": .string("%")
                ]
            )
        ])
        let current = try XCTUnwrap(store.entityBox(for: "sensor.hall_temperature"))
        let matching = try XCTUnwrap(store.entityBox(for: "sensor.bedroom_temperature"))
        let differentUnit = try XCTUnwrap(store.entityBox(for: "sensor.outdoor_temperature"))
        let differentDeviceClass = try XCTUnwrap(store.entityBox(for: "sensor.humidity"))

        XCTAssertTrue(DashboardEntityReplacementPolicy.preservesGaugeCustomization(
            from: current,
            to: matching
        ))
        XCTAssertFalse(DashboardEntityReplacementPolicy.preservesGaugeCustomization(
            from: current,
            to: differentUnit
        ))
        XCTAssertFalse(DashboardEntityReplacementPolicy.preservesGaugeCustomization(
            from: current,
            to: differentDeviceClass
        ))
    }

    func testSummaryChipsRemainSingleInstance() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let firstID = try XCTUnwrap(configuration.add(source: .summary(.lights), presentation: .chip))
        let secondID = try XCTUnwrap(configuration.add(source: .summary(.lights), presentation: .chip))

        XCTAssertEqual(firstID, secondID)
        XCTAssertEqual(configuration.items.count, 1)
        XCTAssertEqual(
            configuration.presentationCount(source: .summary(.lights), presentation: .chip),
            1
        )
    }

    func testSummaryCardAndInvalidLayoutAreRejected() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())

        XCTAssertNil(configuration.add(
            source: .summary(.lights),
            presentation: .card(.status(layout: .compact))
        ))
        XCTAssertNil(configuration.add(
            source: .entity("sensor.humidity"),
            presentation: .card(.circularGauge(layout: .mini))
        ))
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testCatalogOnlyBuildsCardPresentationsWithSupportedLayouts() {
        XCTAssertNil(DashboardPresentationCatalog.cardConfiguration(kind: .chip, layout: .compact))
        XCTAssertEqual(DashboardPresentationCatalog.descriptor(for: .chart).title, "Chart")
        XCTAssertEqual(DashboardPresentationKind.chart.defaultLayout, .wide)

        for kind in DashboardPresentationKind.allCases {
            if let defaultLayout = kind.defaultLayout {
                XCTAssertTrue(kind.supportedLayouts.contains(defaultLayout))
            } else {
                XCTAssertEqual(kind, .chip)
            }

            guard kind != .chip else { continue }
            for layout in DashboardCardSize.allCases {
                let configuration = DashboardPresentationCatalog.cardConfiguration(kind: kind, layout: layout)

                XCTAssertEqual(
                    configuration != nil,
                    kind.supportedLayouts.contains(layout),
                    "\(kind.rawValue) and \(layout.rawValue) should agree with the catalog."
                )
            }
        }
    }

    func testCatalogDeclaresCardEditorSettingsByCapability() {
        XCTAssertEqual(
            DashboardPresentationCatalog.descriptor(for: .chart).editorSettings,
            [.historyRange]
        )

        for kind in [
            DashboardPresentationKind.circularGauge,
            .segmentedGauge,
            .barGauge
        ] {
            XCTAssertEqual(
                DashboardPresentationCatalog.descriptor(for: kind).editorSettings,
                [.gaugeZones]
            )
        }

        for kind in [
            DashboardPresentationKind.control,
            .status,
            .camera,
            .weather,
            .media,
            .action
        ] {
            XCTAssertTrue(DashboardPresentationCatalog.descriptor(for: kind).editorSettings.isEmpty)
        }
    }

    func testCardEditorPreviewLayoutPreservesFourColumnProportions() {
        let mini = DashboardCardEditorPreviewLayout(availableWidth: 320, size: .mini)
        let compact = DashboardCardEditorPreviewLayout(availableWidth: 320, size: .compact)
        let row = DashboardCardEditorPreviewLayout(availableWidth: 320, size: .row)
        let square = DashboardCardEditorPreviewLayout(availableWidth: 320, size: .square)
        let large = DashboardCardEditorPreviewLayout(availableWidth: 320, size: .large)

        XCTAssertEqual(
            compact.unscaledCardSize.width,
            (mini.unscaledCardSize.width * 2) + DashboardCardEditorPreviewLayout.spacing,
            accuracy: 0.001
        )
        XCTAssertEqual(
            row.unscaledCardSize.width,
            (mini.unscaledCardSize.width * 4) + (DashboardCardEditorPreviewLayout.spacing * 3),
            accuracy: 0.001
        )
        XCTAssertEqual(square.unscaledCardSize.width, compact.unscaledCardSize.width, accuracy: 0.001)
        XCTAssertEqual(
            square.unscaledCardSize.height,
            DashboardCardSize.square.renderedHeight(
                rowSpacing: DashboardCardEditorPreviewLayout.spacing,
                cardPadding: DashboardCardEditorPreviewLayout.cardPadding
            ),
            accuracy: 0.001
        )
        XCTAssertEqual(
            DashboardCardEditorPreviewLayout.stageHeight(for: .large),
            large.unscaledCardSize.height + (DashboardCardEditorPreviewLayout.stagePadding * 2),
            accuracy: 0.001
        )
        XCTAssertEqual(
            DashboardCardEditorPreviewLayout.stageHeight(for: .compact),
            compact.unscaledCardSize.height + (AppSpacing.xSmall * 2),
            accuracy: 0.001
        )
        XCTAssertEqual(large.scale, 1, accuracy: 0.001)
        XCTAssertEqual(
            large.unscaledCardSize.width * large.scale,
            row.unscaledCardSize.width,
            accuracy: 0.001
        )
    }

    func testGalleryCatalogSeparatesImplementedAndPlannedMetadata() {
        XCTAssertEqual(
            DashboardAddGallerySection.elements.items.map(\.title),
            ["Header", "Chip"]
        )

        let implementedKinds: [DashboardPresentationKind] = DashboardAddGallerySection.cards.items.compactMap { item in
            guard case .presentation(let descriptor) = item else { return nil }
            return descriptor.kind
        }
        XCTAssertEqual(
            implementedKinds,
            [.control, .status, .circularGauge, .segmentedGauge, .barGauge, .chart, .camera, .weather, .media, .action]
        )
        XCTAssertEqual(implementedKinds.count, DashboardAddGallerySection.cards.items.count)

        let plannedItems = DashboardAddGallerySection.planned.items
        XCTAssertEqual(
            plannedItems.map(\.title),
            ["Calendar", "Map", "Picture", "Area", "Person", "Energy", "Text", "Spacer"]
        )
        XCTAssertTrue(plannedItems.allSatisfy(\.isPlanned))
        XCTAssertEqual(
            DashboardAddGalleryCatalog.sections.contains(.planned),
            DashboardAddGalleryCatalog.showsPlannedCards
        )
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
        XCTAssertFalse(snapshot.isCompatible)
    }

    func testVersionFiveICloudDashboardSnapshotMigratesToChart() throws {
        let dashboard = makeDashboard(items: [
            .entityCard(entityID: "sensor.temperature", configuration: .chart(layout: .square))
        ])
        let currentData = try JSONEncoder().encode(DashboardConfigurationSyncSnapshot(dashboards: [dashboard]))
        let currentJSON = try XCTUnwrap(String(data: currentData, encoding: .utf8))
        let oldJSON = currentJSON
            .replacingOccurrences(of: "\"schemaVersion\":6", with: "\"schemaVersion\":5")
            .replacingOccurrences(of: "\"chart\"", with: "\"graph\"")

        let snapshot = try JSONDecoder().decode(
            DashboardConfigurationSyncSnapshot.self,
            from: Data(oldJSON.utf8)
        )

        XCTAssertTrue(snapshot.isCompatible)
        XCTAssertEqual(snapshot.dashboards.first?.items.first?.cardConfiguration, .chart(layout: .square))
    }

    func testIncompatibleICloudDashboardSnapshotDoesNotReplaceLocalDashboards() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        _ = configuration.add(source: .entity("light.kitchen"), presentation: .chip)
        let originalDashboards = configuration.dashboards
        let newerJSON = """
        {"schemaVersion":7,"dashboards":[]}
        """
        let snapshot = try JSONDecoder().decode(
            DashboardConfigurationSyncSnapshot.self,
            from: Data(newerJSON.utf8)
        )

        XCTAssertFalse(configuration.applySyncSnapshot(snapshot))
        XCTAssertEqual(configuration.dashboards, originalDashboards)
    }

    func testProfileSyncBundleDoesNotOverwriteNewerStoredProfileSchema() throws {
        let defaults = makeDefaults()
        let activeProfileID = UUID()
        let protectedProfileID = UUID()
        let protectedKey = "homestead.dashboard.configuration.v3.\(protectedProfileID.uuidString.lowercased())"
        let newerData = Data("{\"schemaVersion\":7,\"dashboards\":[]}".utf8)
        defaults.set(newerData, forKey: protectedKey)
        let configuration = DashboardConfiguration(defaults: defaults, profileID: activeProfileID)
        let snapshot = DashboardConfigurationSyncSnapshot(dashboards: [
            makeDashboard(items: [.entityChip(entityID: "light.kitchen")])
        ])

        let didApply = configuration.applyProfileSyncSnapshots([
            activeProfileID: snapshot,
            protectedProfileID: snapshot
        ])

        XCTAssertFalse(didApply)
        XCTAssertEqual(defaults.data(forKey: protectedKey), newerData)
        XCTAssertTrue(configuration.items.isEmpty)
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
                value: HomesteadAppearanceSettingsSyncSnapshot(
                    wallpaperEnabledProfileIDs: [UUID(uuidString: "11111111-1111-1111-1111-111111111111")!]
                )
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
        XCTAssertEqual(decoded.appearance.value.wallpaperEnabledProfileIDs.count, 1)
        XCTAssertTrue(decoded.dashboard.value.dashboards.isEmpty)
    }

    func testSavedDashboardDefinitionsSyncButSelectionRemainsLocal() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "iPad")
        XCTAssertEqual(configuration.selectedDashboardID, firstID)
        XCTAssertTrue(configuration.selectDashboard(id: secondID))

        configuration.applySyncSnapshot(DashboardConfigurationSyncSnapshot(dashboards: [
            SavedDashboardConfiguration(
                id: firstID,
                name: "Phone",
                items: [.entityCard(
                    entityID: "light.phone",
                    configuration: .control(layout: .square)
                )]
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

    func testLegacyVisibilityDefaultsToPreviouslySelectedDashboardOnly() throws {
        let defaults = makeDefaults()
        let first = makeDashboard(items: [])
        let second = makeDashboard(items: [])
        let third = makeDashboard(items: [])
        defaults.set(
            try JSONEncoder().encode(DashboardConfigurationDocument(dashboards: [first, second, third])),
            forKey: "homestead.dashboard.configuration.v3"
        )
        defaults.set(second.id.uuidString, forKey: "homestead.dashboard.selectedDashboardID.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(configuration.selectedDashboardID, second.id)
        XCTAssertEqual(configuration.enabledDashboardIDs, [second.id])
        XCTAssertEqual(configuration.enabledDashboards.map(\.id), [second.id])
    }

    func testEnabledDashboardsAreLocalAndExcludedFromSyncSnapshot() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "Second")

        XCTAssertEqual(configuration.enabledDashboardIDs, [firstID, secondID])

        let encoded = try JSONEncoder().encode(configuration.syncSnapshot)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(json.contains("enabledDashboard"))
        XCTAssertFalse(json.contains("selectedDashboard"))
    }

    func testAtLeastOneDashboardAlwaysRemainsEnabled() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let onlyID = configuration.selectedDashboardID

        XCTAssertFalse(configuration.setDashboardEnabled(false, id: onlyID))
        XCTAssertEqual(configuration.enabledDashboardIDs, [onlyID])

        let secondID = configuration.createDashboard(named: "Second")
        XCTAssertTrue(configuration.setDashboardEnabled(false, id: secondID))
        XCTAssertFalse(configuration.setDashboardEnabled(false, id: onlyID))
        XCTAssertEqual(configuration.enabledDashboardIDs, [onlyID])
    }

    func testSettledSelectionAndDisablingSelectedDashboardPreferPrecedingEnabledPage() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "Second")
        let thirdID = configuration.createDashboard(named: "Third")

        XCTAssertTrue(configuration.selectDashboard(id: secondID))
        XCTAssertEqual(configuration.selectedDashboardID, secondID)
        XCTAssertTrue(configuration.setDashboardEnabled(false, id: secondID))
        XCTAssertEqual(configuration.selectedDashboardID, firstID)
        XCTAssertEqual(configuration.enabledDashboards.map(\.id), [firstID, thirdID])
    }

    func testDeletingSelectedDashboardPrefersPrecedingEnabledPage() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "Second")
        let thirdID = configuration.createDashboard(named: "Third")
        XCTAssertTrue(configuration.selectDashboard(id: secondID))

        configuration.deleteDashboard(id: secondID)

        XCTAssertEqual(configuration.selectedDashboardID, firstID)
        XCTAssertEqual(configuration.enabledDashboards.map(\.id), [firstID, thirdID])
    }

    func testCreationAndDuplicationEnableNewDashboardWithoutChangingCurrentPage() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let selectedID = configuration.selectedDashboardID
        _ = configuration.add(source: .entity("light.kitchen"), presentation: .chip)

        let createdID = configuration.createDashboard(named: "Created")
        let duplicateID = configuration.duplicateDashboard(id: selectedID, named: "Duplicate")

        XCTAssertEqual(configuration.selectedDashboardID, selectedID)
        XCTAssertTrue(configuration.enabledDashboardIDs.contains(createdID))
        XCTAssertTrue(configuration.enabledDashboardIDs.contains(duplicateID))
        XCTAssertEqual(
            try XCTUnwrap(configuration.dashboard(id: duplicateID)).items.first?.entityID,
            "light.kitchen"
        )
    }

    func testReorderingChangesEnabledPageOrderWithoutChangingSelection() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "Second")
        let thirdID = configuration.createDashboard(named: "Third")
        XCTAssertTrue(configuration.selectDashboard(id: secondID))

        configuration.moveDashboards(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(configuration.enabledDashboards.map(\.id), [thirdID, firstID, secondID])
        XCTAssertEqual(configuration.selectedDashboardID, secondID)
    }

    func testSyncReconciliationPreservesValidLocalVisibilityAndRemovesMissingIDs() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "Second")
        let thirdID = configuration.createDashboard(named: "Third")
        XCTAssertTrue(configuration.setDashboardEnabled(false, id: firstID))
        XCTAssertTrue(configuration.selectDashboard(id: secondID))
        let replacementID = UUID()

        XCTAssertTrue(configuration.applySyncSnapshot(DashboardConfigurationSyncSnapshot(dashboards: [
            SavedDashboardConfiguration(id: secondID, name: "Second Synced", items: []),
            SavedDashboardConfiguration(id: replacementID, name: "Replacement", items: [])
        ])))

        XCTAssertEqual(configuration.enabledDashboardIDs, [secondID])
        XCTAssertEqual(configuration.selectedDashboardID, secondID)
        XCTAssertFalse(configuration.enabledDashboardIDs.contains(thirdID))
    }

    func testProfileSwitchingIsolatesEnabledPagesAndSelection() {
        let defaults = makeDefaults()
        let firstProfileID = UUID()
        let secondProfileID = UUID()
        let configuration = DashboardConfiguration(defaults: defaults, profileID: firstProfileID)
        let firstSelectedID = configuration.selectedDashboardID
        let firstAdditionalID = configuration.createDashboard(named: "First Additional")

        configuration.activateProfile(secondProfileID)
        let secondSelectedID = configuration.selectedDashboardID
        XCTAssertNotEqual(secondSelectedID, firstSelectedID)
        XCTAssertEqual(configuration.enabledDashboardIDs, [secondSelectedID])
        _ = configuration.createDashboard(named: "Second Additional")

        configuration.activateProfile(firstProfileID)
        XCTAssertEqual(configuration.selectedDashboardID, firstSelectedID)
        XCTAssertEqual(configuration.enabledDashboardIDs, [firstSelectedID, firstAdditionalID])
    }

    func testDashboardActionsRemainScopedToExplicitDashboardID() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
        let firstID = configuration.selectedDashboardID
        let secondID = configuration.createDashboard(named: "Second")
        let addedID = try XCTUnwrap(configuration.add(
            source: .entity("light.second"),
            presentation: .card(.control(layout: .square)),
            to: secondID
        ))
        _ = configuration.addHeader(title: "Second Header", to: secondID)

        XCTAssertTrue(configuration.items(for: firstID).isEmpty)
        XCTAssertEqual(configuration.items(for: secondID).count, 2)

        configuration.renameHeader(
            DashboardItemReference(
                dashboardID: secondID,
                itemID: try XCTUnwrap(configuration.items(for: secondID).last?.id)
            ),
            title: "Renamed"
        )
        XCTAssertTrue(configuration.removeItem(
            for: DashboardItemReference(dashboardID: secondID, itemID: addedID)
        ))
        XCTAssertTrue(configuration.items(for: firstID).isEmpty)
        XCTAssertEqual(configuration.items(for: secondID).first?.resolvedTitle, "Renamed")
    }

    func testPhonePreviewMetricsPreserveAspectRatioAtRepresentativeWidths() {
        for width: CGFloat in [140, 162, 178, 240, 320] {
            let size = SettingsDashboardPhonePreviewMetrics.size(forWidth: width)
            XCTAssertEqual(size.width, width, accuracy: 0.001)
            XCTAssertEqual(
                size.width / size.height,
                SettingsDashboardPhonePreviewMetrics.aspectRatio,
                accuracy: 0.001
            )
        }
    }

    func testPageIndicatorUsesAStableFourDotWindow() {
        let firstPage = DashboardPageIndicatorLayout(pageCount: 5, selectedIndex: 0)
        XCTAssertEqual(firstPage.dots.map(\.pageIndex), [0, 1, 2, 3])
        XCTAssertEqual(firstPage.dots.map(\.scale), [1, 1, 1, 0.62])

        let middlePage = DashboardPageIndicatorLayout(pageCount: 6, selectedIndex: 3)
        XCTAssertEqual(middlePage.dots.map(\.pageIndex), [1, 2, 3, 4])
        XCTAssertEqual(middlePage.dots.map(\.scale), [0.62, 1, 1, 0.62])

        let lastPage = DashboardPageIndicatorLayout(pageCount: 5, selectedIndex: 4)
        XCTAssertEqual(lastPage.dots.map(\.pageIndex), [1, 2, 3, 4])
        XCTAssertEqual(lastPage.dots.map(\.scale), [0.62, 1, 1, 1])
    }

    func testPageIndicatorKeepsAFixedCapsuleSize() {
        XCTAssertEqual(DashboardPageIndicatorMetrics.capsuleSize.width, 52, accuracy: 0.001)
        XCTAssertEqual(DashboardPageIndicatorMetrics.capsuleSize.height, 20, accuracy: 0.001)
    }

    func testCatalogRejectsIncompatibleEntityPresentationDuringReconciliation() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        _ = configuration.add(
            source: .entity("light.kitchen"),
            presentation: .card(.camera(layout: .square))
        )
        _ = configuration.add(
            source: .entity("light.kitchen"),
            presentation: .card(.control(layout: .square))
        )
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["brightness": .number(128)]
            )
        ])

        configuration.reconcile(with: store.allEntityBoxes())

        XCTAssertFalse(configuration.items.contains { $0.presentation?.kind == .camera })
        XCTAssertTrue(configuration.items.contains { $0.presentation?.kind == .control })
        XCTAssertEqual(configuration.items.count, 1)
        XCTAssertEqual(configuration.setupState, .manual)
    }

    func testNewDashboardWaitsForFirstAddedItemBeforeRecordingManualSetup() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        configuration.reconcile(with: store.allEntityBoxes())

        XCTAssertEqual(configuration.setupState, .notChosen)
        XCTAssertTrue(configuration.items.isEmpty)

        let restoredBeforeAdding = DashboardConfiguration(defaults: defaults)
        XCTAssertEqual(restoredBeforeAdding.setupState, .notChosen)
        XCTAssertTrue(restoredBeforeAdding.items.isEmpty)

        _ = restoredBeforeAdding.add(source: .entity("light.kitchen"), presentation: .chip)
        let restored = DashboardConfiguration(defaults: defaults)
        XCTAssertEqual(restored.setupState, .manual)
        XCTAssertEqual(restored.items.count, 1)
    }

    func testRemovingLastSuggestedItemPersistsIntentionalEmptyStateWithoutReseeding() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let candidates = [suggestionCandidate(
            entityID: "light.kitchen",
            domain: .light,
            displayName: "Kitchen"
        )]

        XCTAssertTrue(configuration.applySuggestedSetup(using: candidates))
        XCTAssertEqual(configuration.setupState, .suggested)
        let acceptedSetup = DashboardConfiguration(defaults: defaults)
        XCTAssertEqual(acceptedSetup.setupState, .suggested)
        let itemID = try XCTUnwrap(acceptedSetup.items.first?.id)

        acceptedSetup.removeItem(id: itemID)
        let restored = DashboardConfiguration(defaults: defaults)
        XCTAssertEqual(restored.setupState, .intentionallyEmpty)
        XCTAssertTrue(restored.items.isEmpty)

        let store = HAStateStore()
        store.applyInitialStates([HAEntityDTO(entityID: "light.kitchen", state: "on")])
        restored.reconcile(with: store.allEntityBoxes())
        XCTAssertTrue(restored.items.isEmpty)
        XCTAssertEqual(restored.setupState, .intentionallyEmpty)
    }

    func testSuggestedSetupIsDeterministicAndFiltersLowQualityEntities() {
        let candidates = [
            suggestionCandidate(entityID: "sensor.temperature", domain: .sensor, displayName: "Temperature", deviceClass: "temperature"),
            suggestionCandidate(entityID: "scene.good_night", domain: .scene, displayName: "Good Night"),
            suggestionCandidate(entityID: "light.kitchen", domain: .light, displayName: "Kitchen"),
            suggestionCandidate(entityID: "cover.garage", domain: .cover, displayName: "Garage Door", deviceClass: "garage"),
            suggestionCandidate(entityID: "climate.hall", domain: .climate, displayName: "Hall Thermostat"),
            suggestionCandidate(entityID: "switch.random_plug", domain: .switch, displayName: "Random Plug"),
            suggestionCandidate(entityID: "sensor.router", domain: .sensor, displayName: "Router", entityCategory: "diagnostic", deviceClass: "temperature"),
            suggestionCandidate(entityID: "light.hidden", domain: .light, displayName: "Hidden Light", isHidden: true),
            suggestionCandidate(entityID: "lock.front_door", domain: .lock, displayName: "Front Door", isAvailable: false),
            suggestionCandidate(entityID: "scene.restart_server", domain: .scene, displayName: "Restart Server")
        ]

        let first = DashboardSuggestedSetup.items(from: candidates)
        let second = DashboardSuggestedSetup.items(from: Array(candidates.reversed()))

        XCTAssertEqual(first.map(\.entityID), second.map(\.entityID))
        XCTAssertEqual(
            first.compactMap(\.entityID),
            ["light.kitchen", "climate.hall", "cover.garage", "scene.good_night", "sensor.temperature"]
        )
    }

    func testCatalogRecommendationsUseCapabilitiesRatherThanLiveState() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                attributes: [
                    "brightness": .number(128),
                    "supported_color_modes": .array([.string("brightness")])
                ]
            ),
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
            HAEntityDTO(entityID: "camera.driveway", state: "idle"),
            HAEntityDTO(
                entityID: "climate.thermostat",
                state: "heat",
                attributes: [
                    "current_temperature": .number(70),
                    "temperature": .number(72),
                    "temperature_unit": .string("°F"),
                    "min_temp": .number(50),
                    "max_temp": .number(90),
                    "target_temp_step": .number(1)
                ]
            ),
            HAEntityDTO(
                entityID: "climate.read_only",
                state: "heat",
                attributes: [
                    "current_temperature": .number(70),
                    "temperature_unit": .string("°F")
                ]
            )
        ])

        let light = try XCTUnwrap(store.entityBox(for: "light.kitchen"))
        let temperature = try XCTUnwrap(store.entityBox(for: "sensor.temperature"))
        let battery = try XCTUnwrap(store.entityBox(for: "sensor.remote_battery"))
        let camera = try XCTUnwrap(store.entityBox(for: "camera.driveway"))
        let thermostat = try XCTUnwrap(store.entityBox(for: "climate.thermostat"))
        let readOnlyClimate = try XCTUnwrap(store.entityBox(for: "climate.read_only"))

        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: light).kind, .control)
        XCTAssertEqual(
            DashboardPresentationCatalog.recommendation(for: temperature),
            .card(.chart(layout: .wide))
        )
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: battery).kind, .status)
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: camera).kind, .camera)
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: temperature).contains(.circularGauge))
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: temperature).contains(.segmentedGauge))
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: temperature).contains(.barGauge))
        XCTAssertFalse(DashboardPresentationCatalog.compatiblePresentationKinds(for: battery).contains(.control))
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: thermostat).contains(.control))
        XCTAssertEqual(
            DashboardPresentationCatalog.recommendation(for: thermostat),
            .card(.control(layout: .square))
        )
        XCTAssertFalse(DashboardPresentationCatalog.compatiblePresentationKinds(for: readOnlyClimate).contains(.control))
        XCTAssertEqual(
            DashboardPresentationCatalog.recommendation(for: readOnlyClimate),
            .card(.status(layout: .compact))
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.defaultPresentation(kind: .circularGauge, for: temperature),
            .card(.circularGauge(layout: .square))
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.defaultPresentation(
                kind: .barGauge,
                for: temperature
            ),
            .card(.barGauge(layout: .square))
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.defaultPresentation(kind: .status, for: temperature),
            .card(.status(layout: .compact))
        )

        store.applyLiveStateUpdates([HAEntityDTO(entityID: "light.kitchen", state: "on")])
        let updatedLight = try XCTUnwrap(store.entityBox(for: "light.kitchen"))
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: updatedLight).kind, .control)
    }

    func testGenericNumericMeasurementOffersConfigurableGauge() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.apex_alk",
                state: "9.68",
                attributes: [
                    "unit_of_measurement": .string("dKH"),
                    "state_class": .string("measurement")
                ]
            )
        ])

        let entityBox = try XCTUnwrap(store.entityBox(for: "sensor.apex_alk"))
        let gauge = try XCTUnwrap(entityBox.sensorEntity?.gaugePresentation)
        XCTAssertEqual(gauge.range, 0...12)
        XCTAssertEqual(gauge.rangeSource, .valueSuggested)
        XCTAssertEqual(gauge.sections.map(\.status), [.nominal])
        XCTAssertEqual(
            DashboardPresentationCatalog.availability(of: .circularGauge, for: entityBox),
            .configurable("Review the suggested range and zones.")
        )
    }

    func testGaugeConfigurationAddsAndRemovesZonesFromNeutralAlkRange() throws {
        var configuration = GaugeZoneConfiguration(
            lowerBound: 0,
            upperBound: 12,
            boundaries: [],
            colors: [.standard(for: .nominal)]
        )

        configuration.addZone()
        XCTAssertEqual(configuration.boundaries, [6])
        XCTAssertEqual(configuration.colors, [.standard(for: .nominal), .standard(for: .nominal)])
        XCTAssertEqual(configuration.names, ["Zone 1", "Zone 2"])
        XCTAssertEqual(configuration.range(forZoneAt: 0), 0...6)
        XCTAssertEqual(configuration.range(forZoneAt: 1), 6...12)

        configuration.colors[0] = .standard(for: .low)
        configuration.colors[1] = .standard(for: .high)
        configuration.addZone()
        XCTAssertEqual(configuration.colors.count, 3)
        XCTAssertTrue(configuration.isValid)

        configuration.removeZone(at: 1)
        XCTAssertEqual(configuration.colors.count, 2)
        XCTAssertEqual(configuration.boundaries.count, 1)
        XCTAssertEqual(configuration.names, ["Zone 1", "Zone 2"])
        XCTAssertTrue(configuration.isValid)
    }

    func testGaugeConfigurationPreservesCustomZoneNamesWhenEditingZones() {
        var configuration = GaugeZoneConfiguration(
            lowerBound: 0,
            upperBound: 100,
            boundaries: [50],
            colors: [.standard(for: .low), .standard(for: .high)],
            names: ["Too Low", "Too High"]
        )

        configuration.addZone()

        XCTAssertEqual(configuration.names, ["Too Low", "Zone 3", "Too High"])
        XCTAssertEqual(configuration.name(forZoneAt: 1), "Zone 3")

        configuration.names[1] = "Preferred"
        configuration.removeZone(at: 0)

        XCTAssertEqual(configuration.names, ["Preferred", "Too High"])
        XCTAssertTrue(configuration.isValid)
    }

    func testWidgetGaugeAppliesIndependentThreeZoneConfiguration() {
        let gauge = WidgetGaugePresentation(
            value: 9.7,
            lowerBound: 0,
            upperBound: 12,
            valueText: "9.7",
            unitText: "dKH",
            status: .nominal,
            statusDisplayText: "Normal",
            sections: [WidgetGaugeSection(lowerBound: 0, upperBound: 12, color: .green)],
            accessibilityLabel: "Alk gauge",
            accessibilityValue: "9.7 dKH"
        )

        let resolved = gauge.applyingConfiguration(
            lowerBound: 5,
            boundaries: [7, 11],
            upperBound: 13,
            colors: [.blue, .green, .orange]
        )

        XCTAssertEqual(resolved.lowerBound, 5)
        XCTAssertEqual(resolved.upperBound, 13)
        XCTAssertEqual(resolved.sections.map(\.upperBound), [7, 11, 13])
        XCTAssertEqual(resolved.sections.map(\.color), [.blue, .green, .orange])
        XCTAssertEqual(resolved.currentColor, .green)
        XCTAssertEqual(resolved.status, .nominal)
    }

    func testTotalIncreasingSensorDoesNotOfferGauge() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.lifetime_energy",
                state: "12345",
                attributes: [
                    "device_class": .string("energy"),
                    "state_class": .string("total_increasing"),
                    "unit_of_measurement": .string("kWh")
                ]
            )
        ])

        let entityBox = try XCTUnwrap(store.entityBox(for: "sensor.lifetime_energy"))
        XCTAssertNil(entityBox.sensorEntity?.gaugePresentation)
        XCTAssertFalse(DashboardPresentationCatalog.compatiblePresentationKinds(for: entityBox).contains(.circularGauge))
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: entityBox).contains(.chart))
    }

    func testTargetActionMetadataBuildsSchemaDrivenFields() throws {
        let registry = HAServiceRegistry(domains: [
            "valve": [
                "set_position": HAServiceDescription(
                    name: "Set position",
                    fields: [
                        "position": .object([
                            "name": .string("Position"),
                            "required": .bool(true),
                            "selector": .object(["number": .object([:])])
                        ])
                    ]
                )
            ]
        ])

        let action = try XCTUnwrap(registry.actions(with: ["valve.set_position"]).first)
        XCTAssertEqual(action.displayName, "Set position")
        XCTAssertEqual(action.fields.first?.displayName, "Position")
        XCTAssertEqual(action.fields.first?.kind, .number)
        XCTAssertTrue(action.requiresFields)
    }

    func testMediaEntityChipUsesConcisePlaybackState() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "media_player.living_room",
                state: "playing",
                attributes: [
                    "friendly_name": .string("Living Room"),
                    "media_title": .string("A Very Long Episode Title"),
                    "media_artist": .string("A Very Long Podcast Name")
                ]
            )
        ])

        let entityBox = try XCTUnwrap(store.entityBox(for: "media_player.living_room"))
        let chip = DashboardSummaryProvider.makeEntityChip(entityBox: entityBox)

        XCTAssertEqual(chip.title, "Living Room")
        XCTAssertEqual(chip.value, "Playing")
    }

    private func makeDashboard(items: [DashboardItemConfiguration]) -> SavedDashboardConfiguration {
        SavedDashboardConfiguration(id: UUID(), name: "Dashboard", items: items)
    }

    private func suggestionCandidate(
        entityID: String,
        domain: EntityDomain,
        displayName: String,
        isAvailable: Bool = true,
        isHidden: Bool = false,
        entityCategory: String? = nil,
        deviceClass: String? = nil
    ) -> DashboardSuggestionCandidate {
        DashboardSuggestionCandidate(
            entityID: entityID,
            domain: domain,
            displayName: displayName,
            isAvailable: isAvailable,
            isHidden: isHidden,
            entityCategory: entityCategory,
            deviceClass: deviceClass,
            presentation: .card(.status(layout: .compact))
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.tyler.Homestead.dashboard.xctests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }
}
