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

    func testUnsupportedDocumentVersionResets() throws {
        let defaults = makeDefaults()
        let unsupported = DashboardConfigurationDocument(
            schemaVersion: DashboardConfigurationDocument.currentSchemaVersion + 1,
            dashboards: [makeDashboard(items: [.entityChip(entityID: "sensor.old")])]
        )
        defaults.set(try JSONEncoder().encode(unsupported), forKey: "homestead.dashboard.configuration.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertTrue(configuration.items.isEmpty)
        let stored = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
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

        let storedBeforeRestore = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
        _ = try JSONDecoder().decode(DashboardConfigurationDocument.self, from: storedBeforeRestore)
        let restored = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(restored.items.count, 2)
        XCTAssertEqual(restored.items[0].source, .entity("sensor.temperature"))
        XCTAssertEqual(restored.items[0].cardConfiguration, .graph(layout: .wide))
        XCTAssertEqual(restored.items[0].displayNameOverride, "Temperature")
        XCTAssertEqual(restored.items[1].source, .summary(.lights))
        XCTAssertEqual(restored.items[1].presentation, .chip)

        let data = try XCTUnwrap(defaults.data(forKey: "homestead.dashboard.configuration.v3"))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("chipKind"))
        XCTAssertFalse(json.contains("summaryKind"))
        XCTAssertFalse(json.contains("entityDisplayNameOverrides"))
    }

    func testInvalidDecodedPresentationIsRemovedBeforeActivation() throws {
        let defaults = makeDefaults()
        let invalid = DashboardItemConfiguration.entityCard(
            entityID: "sensor.humidity",
            configuration: .gauge(style: .circular, layout: .mini)
        )
        let document = DashboardConfigurationDocument(dashboards: [makeDashboard(items: [invalid])])
        defaults.set(try JSONEncoder().encode(document), forKey: "homestead.dashboard.configuration.v3")

        let configuration = DashboardConfiguration(defaults: defaults)

        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testCurrentDocumentRoundTripsPresentationStyles() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        _ = configuration.add(
            source: .entity("sensor.battery"),
            presentation: .card(.gauge(style: .circular, layout: .square))
        )
        let segmentedID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.battery"),
            presentation: .card(.gauge(style: .segmented, layout: .square))
        ))
        let zoneConfiguration = GaugeZoneConfiguration(
            lowerBound: 0,
            upperBound: 100,
            boundaries: [15, 30, 70, 85],
            statuses: [.critical, .warning, .nominal, .warning, .critical]
        )
        configuration.setGaugeZoneConfiguration(zoneConfiguration, forItemID: segmentedID)
        _ = configuration.add(
            source: .entity("sensor.battery"),
            presentation: .card(.gauge(style: .bar, layout: .wide))
        )

        let restored = DashboardConfiguration(defaults: defaults)

        XCTAssertEqual(
            restored.items.compactMap(\.cardConfiguration),
            [
                .gauge(style: .circular, layout: .square),
                .gauge(style: .segmented, layout: .square),
                .gauge(style: .bar, layout: .wide)
            ]
        )
        XCTAssertEqual(restored.items.first(where: { $0.id == segmentedID })?.gaugeZoneConfiguration, zoneConfiguration)
    }

    func testDuplicateIdentityIncludesStyleButNotLayout() throws {
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
        let circularGaugeID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.gauge(style: .circular, layout: .square))
        ))
        let duplicateCircularGaugeID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.gauge(style: .circular, layout: .wide))
        ))
        let barGaugeID = try XCTUnwrap(configuration.add(
            source: .entity("sensor.temperature"),
            presentation: .card(.gauge(style: .bar, layout: .wide))
        ))

        XCTAssertEqual(
            DashboardPresentationIdentity(
                source: .entity("sensor.temperature"),
                presentation: .card(.status(layout: .compact))
            ),
            DashboardPresentationIdentity(
                source: .entity("sensor.temperature"),
                presentation: .card(.status(layout: .wide))
            )
        )
        XCTAssertEqual(statusID, duplicateStatusID)
        XCTAssertNotEqual(statusID, graphID)
        XCTAssertEqual(circularGaugeID, duplicateCircularGaugeID)
        XCTAssertNotEqual(circularGaugeID, barGaugeID)
        XCTAssertEqual(configuration.items.count, 4)
    }

    func testPresentationIdentitiesMatchDashboardDuplicateRules() throws {
        let configuration = DashboardConfiguration(defaults: makeDefaults())
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
            presentation: .card(.gauge(style: .bar, layout: .wide))
        )

        XCTAssertEqual(configuration.presentationIdentities.count, 2)
        XCTAssertTrue(configuration.presentationIdentities.contains(
            DashboardPresentationIdentity(
                source: .entity("sensor.temperature"),
                presentation: .card(.status(layout: .square))
            )
        ))
        XCTAssertTrue(configuration.presentationIdentities.contains(
            DashboardPresentationIdentity(
                source: .entity("sensor.temperature"),
                presentation: .card(.gauge(style: .bar, layout: .compact))
            )
        ))
    }

    func testSummaryCardAndInvalidLayoutAreRejected() {
        let configuration = DashboardConfiguration(defaults: makeDefaults())

        XCTAssertNil(configuration.add(
            source: .summary(.lights),
            presentation: .card(.status(layout: .compact))
        ))
        XCTAssertNil(configuration.add(
            source: .entity("sensor.humidity"),
            presentation: .card(.gauge(style: .circular, layout: .mini))
        ))
        XCTAssertTrue(configuration.items.isEmpty)
    }

    func testCatalogOnlyBuildsCardPresentationsWithSupportedLayouts() {
        XCTAssertNil(DashboardPresentationCatalog.cardConfiguration(kind: .chip, layout: .compact))

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
            [.control, .status, .gauge, .graph, .camera, .weather, .media, .action]
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
                items: [.entityCard(
                    entityID: "light.phone",
                    configuration: .control(style: .slider, layout: .square, featureVisibility: .automatic)
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

    func testCatalogRejectsIncompatibleEntityPresentationDuringReconciliation() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        _ = configuration.add(
            source: .entity("light.kitchen"),
            presentation: .card(.camera(layout: .square))
        )
        _ = configuration.add(
            source: .entity("light.kitchen"),
            presentation: .card(.control(
                style: .thermostat,
                layout: .square,
                featureVisibility: .automatic
            ))
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
        XCTAssertFalse(configuration.items.contains { $0.presentation?.style == .control(.thermostat) })
        XCTAssertTrue(configuration.items.isEmpty)
        XCTAssertEqual(configuration.setupState, .manual)
    }

    func testNewDashboardWaitsForAnExplicitSetupChoice() throws {
        let defaults = makeDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        configuration.reconcile(with: store.allEntityBoxes())

        XCTAssertEqual(configuration.setupState, .notChosen)
        XCTAssertTrue(configuration.items.isEmpty)

        configuration.chooseManualSetup()
        let restored = DashboardConfiguration(defaults: defaults)
        XCTAssertEqual(restored.setupState, .manual)
        XCTAssertTrue(restored.items.isEmpty)
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
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: temperature).kind, .graph)
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: battery).kind, .status)
        XCTAssertEqual(DashboardPresentationCatalog.recommendation(for: camera).kind, .camera)
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: temperature).contains(.gauge))
        XCTAssertFalse(DashboardPresentationCatalog.compatiblePresentationKinds(for: battery).contains(.control))
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: thermostat).contains(.control))
        XCTAssertEqual(
            DashboardPresentationCatalog.recommendation(for: thermostat),
            .card(.control(style: .thermostat, layout: .square, featureVisibility: .automatic))
        )
        XCTAssertFalse(DashboardPresentationCatalog.compatiblePresentationKinds(for: readOnlyClimate).contains(.control))
        XCTAssertEqual(
            DashboardPresentationCatalog.recommendation(for: readOnlyClimate),
            .card(.status(layout: .compact))
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.defaultPresentation(kind: .gauge, for: temperature),
            .card(.gauge(style: .circular, layout: .square))
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.defaultPresentation(
                kind: .gauge,
                style: .gauge(.bar),
                for: temperature
            ),
            .card(.gauge(style: .bar, layout: .wide))
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.styleDescriptors(for: .gauge, entityBox: battery).map(\.style),
            [.gauge(.circular), .gauge(.segmented), .gauge(.bar)]
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.styleDescriptors(for: .control, entityBox: thermostat).map(\.style),
            [.control(.thermostat)]
        )
        XCTAssertEqual(
            DashboardPresentationCatalog.styleDescriptors(for: .control, entityBox: light).map(\.style),
            [.control(.slider)]
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
            DashboardPresentationCatalog.availability(of: .gauge, for: entityBox),
            .configurable("Review the suggested range and zones.")
        )
    }

    func testGaugeConfigurationAddsAndRemovesZonesFromNeutralAlkRange() throws {
        var configuration = GaugeZoneConfiguration(
            lowerBound: 0,
            upperBound: 12,
            boundaries: [],
            statuses: [.nominal]
        )

        configuration.addZone()
        XCTAssertEqual(configuration.boundaries, [6])
        XCTAssertEqual(configuration.statuses, [.nominal, .nominal])
        XCTAssertEqual(configuration.range(forZoneAt: 0), 0...6)
        XCTAssertEqual(configuration.range(forZoneAt: 1), 6...12)

        configuration.statuses[0] = .low
        configuration.statuses[1] = .high
        configuration.addZone()
        XCTAssertEqual(configuration.statuses.count, 3)
        XCTAssertTrue(configuration.isValid)

        configuration.removeZone(at: 1)
        XCTAssertEqual(configuration.statuses.count, 2)
        XCTAssertEqual(configuration.boundaries.count, 1)
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
            sections: [WidgetGaugeSection(lowerBound: 0, upperBound: 12, status: .nominal)],
            accessibilityLabel: "Alk gauge",
            accessibilityValue: "9.7 dKH"
        )

        let resolved = gauge.applyingConfiguration(
            lowerBound: 5,
            boundaries: [7, 11],
            upperBound: 13,
            statuses: [.low, .nominal, .high]
        )

        XCTAssertEqual(resolved.lowerBound, 5)
        XCTAssertEqual(resolved.upperBound, 13)
        XCTAssertEqual(resolved.sections.map(\.upperBound), [7, 11, 13])
        XCTAssertEqual(resolved.sections.map(\.status), [.low, .nominal, .high])
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
        XCTAssertFalse(DashboardPresentationCatalog.compatiblePresentationKinds(for: entityBox).contains(.gauge))
        XCTAssertTrue(DashboardPresentationCatalog.compatiblePresentationKinds(for: entityBox).contains(.graph))
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
