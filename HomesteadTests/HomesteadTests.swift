import Foundation
import Testing
@testable import Homestead

struct HomesteadTests {
    @Test func webSocketEndpointUsesExpectedSchemeAndPath() throws {
        let localURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "http://homeassistant.local:8123")
        #expect(localURL.absoluteString == "ws://homeassistant.local:8123/api/websocket")

        let secureURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "https://example.com/ha")
        #expect(secureURL.absoluteString == "wss://example.com/ha/api/websocket")

        let hostOnlyURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "homeassistant.local:8123")
        #expect(hostOnlyURL.absoluteString == "ws://homeassistant.local:8123/api/websocket")
    }

    @Test func callServiceRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.callService(
            id: 42,
            domain: "light",
            service: "turn_on",
            target: ["entity_id": .string("light.kitchen")],
            serviceData: ["brightness": .number(200)]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let target = try #require(object["target"] as? [String: Any])
        let serviceData = try #require(object["service_data"] as? [String: Any])

        #expect(object["id"] as? Int == 42)
        #expect(object["type"] as? String == "call_service")
        #expect(object["domain"] as? String == "light")
        #expect(object["service"] as? String == "turn_on")
        #expect(target["entity_id"] as? String == "light.kitchen")
        #expect(serviceData["brightness"] as? Double == 200)
    }

    @Test func coverPositionServiceRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.callService(
            id: 43,
            domain: "cover",
            service: "set_cover_position",
            target: ["entity_id": .string("cover.primary_shades")],
            serviceData: ["position": .number(72)]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let target = try #require(object["target"] as? [String: Any])
        let serviceData = try #require(object["service_data"] as? [String: Any])

        #expect(object["id"] as? Int == 43)
        #expect(object["type"] as? String == "call_service")
        #expect(object["domain"] as? String == "cover")
        #expect(object["service"] as? String == "set_cover_position")
        #expect(target["entity_id"] as? String == "cover.primary_shades")
        #expect(serviceData["position"] as? Double == 72)
    }

    @Test func climateTemperatureServiceRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.callService(
            id: 44,
            domain: "climate",
            service: "set_temperature",
            target: ["entity_id": .string("climate.downstairs")],
            serviceData: ["temperature": .number(70)]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let target = try #require(object["target"] as? [String: Any])
        let serviceData = try #require(object["service_data"] as? [String: Any])

        #expect(object["id"] as? Int == 44)
        #expect(object["type"] as? String == "call_service")
        #expect(object["domain"] as? String == "climate")
        #expect(object["service"] as? String == "set_temperature")
        #expect(target["entity_id"] as? String == "climate.downstairs")
        #expect(serviceData["temperature"] as? Double == 70)
    }

    @Test func registryCommandEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.registryCommand(
            id: 7,
            type: HAWebSocketMessageType.entityRegistryListForDisplay
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 7)
        #expect(object["type"] as? String == "config/entity_registry/list_for_display")
    }

    @Test func entityRegistryDisplayResponseDecodesCompactHomeAssistantPayload() throws {
        let payload = """
        {
            "entities": [
                {
                    "ei": "sensor.ashtons_ipad_location_permission",
                    "di": "ipad",
                    "en": "Location permission",
                    "hb": true
                }
            ]
        }
        """

        let response = try JSONDecoder().decode(
            HAEntityRegistryDisplayResponseDTO.self,
            from: Data(payload.utf8)
        )

        #expect(response.entities.first?.entityID == "sensor.ashtons_ipad_location_permission")
        #expect(response.entities.first?.deviceID == "ipad")
        #expect(response.entities.first?.originalName == "Location permission")
        #expect(response.entities.first?.hiddenBy == true)
    }

    @Test func entityRegistryDisplayResponseDecodesRawEntityArray() throws {
        let payload = """
        [
            {
                "ei": "light.kitchen",
                "di": "kitchen",
                "en": "Kitchen"
            }
        ]
        """

        let response = try JSONDecoder().decode(
            HAEntityRegistryDisplayResponseDTO.self,
            from: Data(payload.utf8)
        )

        #expect(response.entities.map(\.entityID) == ["light.kitchen"])
        #expect(response.entities.first?.deviceID == "kitchen")
    }

    @Test func entityMapperMapsLightAndSensorDomainModels() {
        let lightDTO = HAEntityDTO(
            entityID: "light.kitchen_pendants",
            state: "on",
            attributes: [
                "friendly_name": .string("Kitchen Pendants"),
                "brightness": .number(128)
            ]
        )

        let sensorDTO = HAEntityDTO(
            entityID: "sensor.hallway_temperature",
            state: "72",
            attributes: [
                "friendly_name": .string("Hallway"),
                "device_class": .string("temperature"),
                "unit_of_measurement": .string("F")
            ]
        )

        let light = EntityMapper.lightEntity(from: lightDTO)
        let sensor = EntityMapper.sensorEntity(from: sensorDTO)

        #expect(light?.displayName == "Kitchen Pendants")
        #expect(light?.isOn == true)
        #expect(light?.brightness == 128)
        #expect(light?.brightnessPercentage == 50)
        #expect(sensor?.displayName == "Hallway")
        #expect(sensor?.formattedValue == "72°F")
        #expect(sensor?.unit == "F")
        #expect(sensor?.iconName == "thermometer.medium")
    }

    @Test func entityMapperMapsSceneAndScriptActionEntities() {
        let sceneDTO = HAEntityDTO(
            entityID: "scene.movie_night",
            state: "scening",
            attributes: [
                "friendly_name": .string("Movie Night")
            ]
        )
        let scriptDTO = HAEntityDTO(
            entityID: "script.good_morning",
            state: "off",
            attributes: [
                "friendly_name": .string("Good Morning")
            ]
        )

        let scene = EntityMapper.homeEntity(from: sceneDTO)
        let script = EntityMapper.homeEntity(from: scriptDTO)

        #expect(scene.domain == .scene)
        #expect(scene.displayName == "Movie Night")
        #expect(scene.iconName == "sparkles")
        #expect(script.domain == .script)
        #expect(script.displayName == "Good Morning")
        #expect(script.iconName == "play.circle")
    }

    @Test func entityMapperMapsCoverPositionState() throws {
        let coverDTO = HAEntityDTO(
            entityID: "cover.primary_shades",
            state: "open",
            attributes: [
                "friendly_name": .string("Primary Shades"),
                "current_position": .number(72)
            ]
        )

        let cover = try #require(EntityMapper.coverEntity(from: coverDTO))

        #expect(cover.displayName == "Primary Shades")
        #expect(cover.state == "open")
        #expect(cover.position == 72)
        #expect(cover.positionPercentage == 72)
        #expect(cover.isOpen == true)
        #expect(cover.isClosed == false)
        #expect(cover.displayState == "Open")
        #expect(cover.displaySubtitle == "Open, 72%")
    }

    @Test func entityMapperMapsClimateControls() throws {
        let climateDTO = HAEntityDTO(
            entityID: "climate.downstairs",
            state: "heat",
            attributes: [
                "friendly_name": .string("Downstairs"),
                "current_temperature": .number(68),
                "temperature": .number(70),
                "temperature_unit": .string("°F"),
                "min_temp": .number(50),
                "max_temp": .number(90),
                "target_temp_step": .number(1),
                "hvac_modes": .array([
                    .string("off"),
                    .string("heat"),
                    .string("cool"),
                    .string("heat_cool")
                ])
            ]
        )

        let climate = try #require(EntityMapper.climateEntity(from: climateDTO))

        #expect(climate.displayName == "Downstairs")
        #expect(climate.state == "heat")
        #expect(climate.currentTemperature == 68)
        #expect(climate.targetTemperature == 70)
        #expect(climate.temperatureUnit == "°F")
        #expect(climate.hvacModes == ["off", "heat", "cool", "heat_cool"])
        #expect(climate.isActive == true)
        #expect(climate.displayState == "Heat")
        #expect(climate.targetTemperatureText == "70°F")
        #expect(climate.currentTemperatureText == "68°F")
        #expect(climate.displaySubtitle == "Heat, set to 70°F")
    }

    @Test func sensorFormattingHandlesUnitsAndUnavailableStates() {
        let humidity = SensorEntity(
            entityID: "sensor.humidity",
            displayName: "Humidity",
            value: "44.2",
            unit: "%",
            deviceClass: "humidity",
            iconName: "humidity",
            lastUpdated: nil
        )
        let energy = SensorEntity(
            entityID: "sensor.energy",
            displayName: "Energy",
            value: "12.3456",
            unit: "kWh",
            deviceClass: "energy",
            iconName: "bolt.fill",
            lastUpdated: nil
        )
        let unavailable = SensorEntity(
            entityID: "sensor.unavailable",
            displayName: "Unavailable",
            value: "unavailable",
            unit: nil,
            deviceClass: nil,
            iconName: "gauge.medium",
            lastUpdated: nil
        )
        let textState = SensorEntity(
            entityID: "sensor.location_permission",
            displayName: "Location Permission",
            value: "authorized_always",
            unit: nil,
            deviceClass: nil,
            iconName: "gauge.medium",
            lastUpdated: nil
        )
        let lowBattery = SensorEntity(
            entityID: "sensor.front_door_battery",
            displayName: "Front Door Battery",
            value: "18",
            unit: "%",
            deviceClass: "battery",
            iconName: "battery.75percent",
            lastUpdated: nil
        )
        let waterClear = SensorEntity(
            entityID: "sensor.laundry_leak",
            displayName: "Laundry Leak",
            value: "off",
            unit: nil,
            deviceClass: "water",
            iconName: "drop.fill",
            lastUpdated: nil
        )
        let waterDetected = SensorEntity(
            entityID: "sensor.laundry_leak",
            displayName: "Laundry Leak",
            value: "on",
            unit: nil,
            deviceClass: "water",
            iconName: "drop.fill",
            lastUpdated: nil
        )

        #expect(humidity.formattedValue == "44%")
        #expect(humidity.valueText == "44")
        #expect(humidity.unitText == "%")
        #expect(humidity.displayKind == .humidity)
        #expect(humidity.isAlerting == false)
        #expect(humidity.displaySubtitle == "Humidity")
        #expect(energy.formattedValue == "12.35 kWh")
        #expect(energy.valueText == "12.35")
        #expect(energy.unitText == "kWh")
        #expect(energy.displayKind == .energy)
        #expect(energy.formattedDeviceClass == "Energy")
        #expect(unavailable.formattedValue == "Unavailable")
        #expect(unavailable.valueText == "Unavailable")
        #expect(unavailable.unitText == nil)
        #expect(unavailable.isAvailable == false)
        #expect(unavailable.displaySubtitle == "Sensor unavailable")
        #expect(textState.formattedValue == "Authorized Always")
        #expect(lowBattery.isAlerting == true)
        #expect(lowBattery.displaySubtitle == "Low Battery")
        #expect(waterClear.isAlerting == false)
        #expect(waterClear.displaySubtitle == "Clear")
        #expect(waterDetected.isAlerting == true)
        #expect(waterDetected.displaySubtitle == "Water Detected")
    }

    @MainActor
    @Test func stateStoreAppliesInitialStatesAndStateChangedEvents() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                attributes: ["friendly_name": .string("Kitchen")]
            )
        ])

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)

        let event = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .null,
                "new_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("on"),
                    "attributes": .object(["friendly_name": .string("Kitchen")]),
                    "last_changed": .string("2026-05-20T10:00:00.000000+00:00"),
                    "last_updated": .string("2026-05-20T10:00:00.000000+00:00")
                ])
            ])
        )

        store.apply(event: event)

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
        #expect(store.entity(for: "light.kitchen")?.state == "on")

        let offEvent = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .null,
                "new_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("off"),
                    "attributes": .object(["friendly_name": .string("Kitchen")]),
                    "last_changed": .string("2026-05-20T10:01:00.000000+00:00"),
                    "last_updated": .string("2026-05-20T10:01:00.000000+00:00")
                ])
            ])
        )

        store.apply(event: offEvent)

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)
        #expect(store.entity(for: "light.kitchen")?.state == "off")

        let pendingCommand = HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on")
        store.setPendingCommand(pendingCommand)

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)
        #expect(store.pendingCommand(for: "light.kitchen") == pendingCommand)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == pendingCommand)
    }

    @MainActor
    @Test func stateStoreTracksInitialSnapshotLoadSeparatelyFromEntityCount() {
        let store = HAStateStore()

        #expect(store.hasLoadedInitialSnapshot == false)
        #expect(store.hasEntities == false)

        store.applySnapshot([])

        #expect(store.hasLoadedInitialSnapshot == true)
        #expect(store.hasEntities == false)
    }

    @MainActor
    @Test func stateStoreDoesNotLetOlderUpdatesOverwriteNewerState() throws {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:02:00.000000+00:00"))
            )
        ])

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:01:00.000000+00:00"))
            )
        ])

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
        #expect(store.rawEntity(for: "light.kitchen")?.state == "on")
    }

    @MainActor
    @Test func stateStoreSnapshotPreservesEntityBoxIdentity() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])
        let firstBox = store.entityBox(for: "light.kitchen")

        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        #expect(store.entityBox(for: "light.kitchen") === firstBox)
        #expect(firstBox?.lightEntity?.isOn == true)
    }

    @MainActor
    @Test func stateStoreRemovesEntityWhenStateChangedNewStateIsNull() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        let removalEvent = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("on")
                ]),
                "new_state": .null
            ])
        )

        store.apply(event: removalEvent)

        #expect(store.entity(for: "light.kitchen") == nil)
        #expect(store.entityBox(for: "light.kitchen") == nil)
        #expect(store.availableEntityIDs.contains("light.kitchen") == false)
    }

    @MainActor
    @Test func confirmedStateChangeClearsPendingCommand() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])
        store.setPendingCommand(HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on"))

        let event = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .null,
                "new_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("on")
                ])
            ])
        )

        store.apply(event: event)

        #expect(store.pendingCommand(for: "light.kitchen") == nil)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == nil)
        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
    }

    @MainActor
    @Test func staleSnapshotDoesNotClearPendingCommandUntilExpectedStateIsConfirmed() throws {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:00:00.000000+00:00"))
            )
        ])
        let pendingCommand = HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on")
        store.setPendingCommand(pendingCommand)

        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:01:00.000000+00:00"))
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == pendingCommand)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == pendingCommand)
        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)

        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:02:00.000000+00:00"))
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == nil)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == nil)
        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
    }

    @MainActor
    @Test func pendingCommandWaitsForExpectedAttributes() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])
        let pendingCommand = HAEntityPendingCommand(
            entityID: "light.kitchen",
            expectedState: "on",
            expectedAttributes: ["brightness": .number(128)]
        )
        store.setPendingCommand(pendingCommand)

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["brightness": .number(64)]
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == pendingCommand)

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["brightness": .number(128)]
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == nil)
    }

    @MainActor
    @Test func liveStateUpdateKeepsAllEntitiesProjectionFresh() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])

        store.applyLiveStateUpdates([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        #expect(store.allEntities.first { $0.entityID == "light.kitchen" }?.state == "on")
        #expect(store.entitiesByDomain.first?.entities.first { $0.entityID == "light.kitchen" }?.state == "on")
    }

    @MainActor
    @Test func connectionSettingsStoresTokenInCredentialStore() throws {
        let suiteName = "com.tyler.Homestead.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let credentialStore = InMemoryHACredentialStore()
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: defaults,
            credentialStore: credentialStore
        )

        settings.accessToken = "abc123"
        #expect(try credentialStore.readAccessToken() == "abc123")

        settings.accessToken = ""
        #expect(try credentialStore.readAccessToken() == nil)
    }

    @MainActor
    @Test func dashboardConfigurationResetSeedsEntityItems() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.reset(using: dashboardTestEntities)

        #expect(configuration.items.map(\.type) == [.entity, .entity])
        #expect(configuration.items.map(\.entityID) == ["light.kitchen", "sensor.hallway_temperature"])
        #expect(configuration.items.map(\.resolvedCardSize) == [.compact, .compact])
    }

    @MainActor
    @Test func dashboardConfigurationAddEntityItemPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.entity])
        #expect(restoredConfiguration.items.map(\.entityID) == ["light.kitchen"])
    }

    @MainActor
    @Test func dashboardConfigurationRemoveEntityItemPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")
        configuration.remove("light.kitchen")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.isEmpty)
    }

    @MainActor
    @Test func dashboardConfigurationCardSizeChangesPersistOnEntityItem() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let itemID = configuration.add("sensor.hallway_temperature")
        configuration.setCardSize(.wide, forItemID: itemID)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.entityID == "sensor.hallway_temperature")
        #expect(restoredConfiguration.items.first?.resolvedCardSize == .wide)
    }

    @MainActor
    @Test func dashboardConfigurationAddHeaderPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.addHeader(title: "Downstairs")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.header])
        #expect(restoredConfiguration.items.first?.resolvedTitle == "Downstairs")
    }

    @MainActor
    @Test func dashboardConfigurationRenameHeaderPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let headerID = configuration.addHeader(title: "Downstairs")
        configuration.renameHeader(id: headerID, title: "Main Floor")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.resolvedTitle == "Main Floor")
    }

    @MainActor
    @Test func dashboardConfigurationRemoveHeaderPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let headerID = configuration.addHeader(title: "Downstairs")
        configuration.removeItem(id: headerID)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.isEmpty)
    }

    @MainActor
    @Test func dashboardConfigurationReconcileRemovesStaleEntitiesAndPreservesHeaders() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")
        configuration.addHeader(title: "Sensors")
        configuration.add("sensor.removed")

        configuration.reconcile(with: dashboardTestEntities)

        #expect(configuration.items.map(\.type) == [.entity, .header])
        #expect(configuration.items.first?.entityID == "light.kitchen")
        #expect(configuration.items.last?.resolvedTitle == "Sensors")
    }

    @MainActor
    @Test func dashboardConfigurationAddableEntityIDsExcludeAddedAndIncludeRemoved() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let availableEntityIDs = Set(dashboardTestEntities.map(\.entityID))
        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")

        #expect(configuration.addableEntityIDs(fromAvailableEntityIDs: availableEntityIDs) == ["sensor.hallway_temperature"])

        configuration.remove("light.kitchen")
        #expect(configuration.addableEntityIDs(fromAvailableEntityIDs: availableEntityIDs) == availableEntityIDs)
    }

    @MainActor
    @Test func dashboardConfigurationMovesMixedItemsAndPersistsOrder() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.addHeader(title: "Downstairs")
        configuration.add("light.kitchen")
        configuration.add("sensor.hallway_temperature")

        configuration.move(from: IndexSet(integer: 0), to: 3)

        #expect(configuration.items.map(\.type) == [.entity, .entity, .header])
        #expect(configuration.items.map(\.entityID) == ["light.kitchen", "sensor.hallway_temperature", nil])
        #expect(configuration.items.last?.resolvedTitle == "Downstairs")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.entity, .entity, .header])
        #expect(restoredConfiguration.items.map(\.entityID) == ["light.kitchen", "sensor.hallway_temperature", nil])
        #expect(restoredConfiguration.items.last?.resolvedTitle == "Downstairs")
    }

    @Test func stateCacheRoundTripsEntitySnapshotsAndScopesByConnection() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadStateCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = HAStateCache(directoryURL: cacheDirectory)
        let primaryConfiguration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let otherConfiguration = HAConnectionConfiguration(
            baseURLString: "http://other-home.local:8123",
            accessToken: "token-a"
        )
        let entities = [
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:00:00.000000+00:00"))
            )
        ]

        await cache.save(entities, for: primaryConfiguration)

        let restoredSnapshot = try #require(await cache.load(for: primaryConfiguration))
        #expect(restoredSnapshot.entities == entities)
        #expect(await cache.load(for: otherConfiguration) == nil)
        #expect(HAStateCache.cacheFileName(for: primaryConfiguration) != HAStateCache.cacheFileName(for: otherConfiguration))
    }

    @Test func stateCacheKeyNormalizesEquivalentHomeAssistantURLs() {
        let hostOnlyConfiguration = HAConnectionConfiguration(
            baseURLString: "homeassistant.local:8123",
            accessToken: "token-a"
        )
        let httpConfiguration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123/",
            accessToken: "token-a"
        )
        let webSocketConfiguration = HAConnectionConfiguration(
            baseURLString: "ws://homeassistant.local:8123/api/websocket",
            accessToken: "token-a"
        )

        #expect(HAStateCache.cacheFileName(for: hostOnlyConfiguration) == HAStateCache.cacheFileName(for: httpConfiguration))
        #expect(HAStateCache.cacheFileName(for: httpConfiguration) == HAStateCache.cacheFileName(for: webSocketConfiguration))
    }

    @MainActor
    @Test func homeAssistantServiceCanApplyCachedStatesBeforeConnecting() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadServiceCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = HAStateCache(directoryURL: cacheDirectory)
        let configuration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let entities = [
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:00:00.000000+00:00"))
            )
        ]

        await cache.save(entities, for: configuration)

        let store = HAStateStore()
        let service = HomeAssistantService(stateStore: store, stateCache: cache)
        let settings = HAConnectionSettings(
            baseURL: "homeassistant.local:8123",
            accessToken: "token-a",
            credentialStore: InMemoryHACredentialStore()
        )

        await service.loadCachedStatesIfPossible(settings: settings)

        #expect(store.hasLoadedInitialSnapshot == true)
        #expect(store.entity(for: "light.kitchen")?.state == "on")
        if case .cached = service.dataFreshness {
            // Expected cached-first launch state.
        } else {
            Issue.record("Expected cached data freshness after applying the saved snapshot.")
        }
    }

    @MainActor
    @Test func pinnedEntityStorePersistsAndPreservesMissingEntitiesByDefault() throws {
        let suiteName = "com.tyler.Homestead.pinned.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PinnedEntityStore(defaults: defaults)
        store.toggle("light.kitchen")
        store.toggle("sensor.missing")

        let restoredStore = PinnedEntityStore(defaults: defaults)
        #expect(restoredStore.entityIDs == ["light.kitchen", "sensor.missing"])
    }

    @MainActor
    @Test func dashboardPreferencesPersistDensityAndActiveFilter() throws {
        let suiteName = "com.tyler.Homestead.preferences.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = DashboardPreferences(defaults: defaults)
        preferences.density = .compact
        preferences.showsOnlyActiveDevices = true

        let restoredPreferences = DashboardPreferences(defaults: defaults)
        #expect(restoredPreferences.density == .compact)
        #expect(restoredPreferences.showsOnlyActiveDevices == true)
    }

    @MainActor
    @Test func roomBuilderGroupsEntitiesAndCountsActivePresentations() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen Pendants")]
            ),
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "72",
                attributes: ["friendly_name": .string("Kitchen Temperature")]
            ),
            HAEntityDTO(
                entityID: "light.office_lamp",
                state: "unavailable",
                attributes: ["friendly_name": .string("Office Lamp")]
            )
        ])

        let rooms = DashboardRoomBuilder.buildRooms(from: store.allEntityBoxes())
        let kitchen = rooms.first { $0.name == "Kitchen" }
        let office = rooms.first { $0.name == "Office" }

        #expect(kitchen?.entityIDs == ["light.kitchen", "sensor.kitchen_temperature"])
        #expect(kitchen?.activeCount == 1)
        #expect(office?.unavailableCount == 1)
    }

    @MainActor
    @Test func entityPresentationCentralizesDomainActionsAndDetails() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on"),
            HAEntityDTO(entityID: "cover.shades", state: "open"),
            HAEntityDTO(entityID: "scene.movie_night", state: "scening"),
            HAEntityDTO(entityID: "sensor.temperature", state: "72")
        ])

        let lightPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "light.kitchen"))
        )
        let coverPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "cover.shades"))
        )
        let scenePresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "scene.movie_night"))
        )
        let sensorPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "sensor.temperature"))
        )

        #expect(lightPresentation.primaryAction == .toggleLight)
        #expect(lightPresentation.detailKind == .light)
        #expect(coverPresentation.primaryAction == .toggleCover)
        #expect(coverPresentation.detailKind == .cover)
        #expect(scenePresentation.primaryAction == .activateScene)
        #expect(scenePresentation.detailKind == .entity)
        #expect(sensorPresentation.primaryAction == nil)
        #expect(sensorPresentation.detailKind == .entity)
    }

    private var dashboardTestEntities: [HomeEntity] {
        [
            HomeEntity(
                entityID: "sensor.hallway_temperature",
                domain: .sensor,
                displayName: "Hallway Temperature",
                state: "72",
                iconName: "thermometer.medium",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "light.kitchen",
                domain: .light,
                displayName: "Kitchen",
                state: "on",
                iconName: "lightbulb",
                isAvailable: true,
                lastUpdated: nil
            )
        ]
    }

    @MainActor
    @Test func stateStoreGroupsEntitiesByDomainPriority() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "sensor.temperature", state: "72"),
            HAEntityDTO(entityID: "cover.shades", state: "open"),
            HAEntityDTO(entityID: "light.lamp", state: "on")
        ])

        #expect(store.entitiesByDomain.map(\.domain) == [.light, .cover, .sensor])
    }

    @MainActor
    @Test func stateStoreGroupsEntitiesByDeviceRegistryMetadata() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "sensor.ashtons_ipad_battery_level", state: "72"),
            HAEntityDTO(entityID: "sensor.ashtons_ipad_location_permission", state: "authorized_always"),
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])

        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.ashtons_ipad_battery_level",
                    deviceID: "ipad",
                    originalName: "Battery Level"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.ashtons_ipad_location_permission",
                    deviceID: "ipad",
                    originalName: "Location permission"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "ipad", name: "Ashton's iPad")
            ]
        )

        #expect(store.entityIDGroupsByDevice.map(\.title) == ["Ashton's iPad", "Other Entities"])
        #expect(store.displayNameForDeviceGroupedEntity(entityID: "sensor.ashtons_ipad_location_permission") == "Location permission")
    }
}
