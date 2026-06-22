import Foundation
import Testing
@testable import Homestead

struct WidgetSnapshotPersistenceTests {
    @Test @MainActor func widgetSnapshotPersistenceBuildsCompactPayloadWithContextAndIcons() {
        let entityIcon = ResolvedIcon.sfSymbol("lamp.floor.fill", provenance: .haRegistryIcon)
        let entitiesByID = [
            "light.kitchen_lamp": HomeEntity(
                entityID: "light.kitchen_lamp",
                domain: .light,
                displayName: "Kitchen Lamp",
                state: "on",
                resolvedIcon: entityIcon,
                isAvailable: true,
                lastUpdated: nil
            ),
            "switch.coffee": HomeEntity(
                entityID: "switch.coffee",
                domain: .switch,
                displayName: "Coffee",
                state: "on",
                iconName: "mug.fill",
                isAvailable: true,
                lastUpdated: nil
            ),
            "lock.front_door": HomeEntity(
                entityID: "lock.front_door",
                domain: .lock,
                displayName: "Front Door",
                state: "locked",
                iconName: "lock.fill",
                isAvailable: true,
                lastUpdated: nil
            ),
            "person.tyler": HomeEntity(
                entityID: "person.tyler",
                domain: .person,
                displayName: "Tyler",
                state: "home",
                iconName: "person.fill",
                isAvailable: true,
                lastUpdated: nil
            ),
            "scene.movie": HomeEntity(
                entityID: "scene.movie",
                domain: .scene,
                displayName: "Movie",
                state: "scening",
                iconName: "sparkles",
                isAvailable: true,
                lastUpdated: nil
            )
        ]

        let payload = WidgetSnapshotPersistence.makePayload(
            entitiesByID: entitiesByID,
            lightEntitiesByID: [
                "light.kitchen_lamp": LightEntity(
                    entityID: "light.kitchen_lamp",
                    displayName: "Kitchen Lamp",
                    isOn: true,
                    brightness: 128,
                    supportsBrightness: true,
                    lastUpdated: nil
                )
            ],
            coverEntitiesByID: [
                "cover.kitchen_shade": CoverEntity(
                    entityID: "cover.kitchen_shade",
                    displayName: "Kitchen Shade",
                    state: "closed",
                    position: 0,
                    deviceClass: "shade"
                )
            ],
            fanEntitiesByID: [
                "fan.kitchen": FanEntity(
                    entityID: "fan.kitchen",
                    displayName: "Kitchen Fan",
                    state: "on",
                    percentage: 40,
                    percentageStep: 1,
                    presetMode: nil,
                    presetModes: []
                )
            ],
            sensorEntitiesByID: [
                "sensor.kitchen_temperature": SensorEntity(
                    entityID: "sensor.kitchen_temperature",
                    displayName: "Kitchen Temperature",
                    value: "72",
                    unit: "F",
                    deviceClass: "temperature",
                    lastUpdated: nil
                )
            ],
            contextForEntityID: { entityID in
                WidgetEntityContext(
                    areaName: entityID.contains("kitchen") ? "Kitchen" : "Entry",
                    deviceName: entityID.contains("kitchen") ? "Kitchen Device" : "Entry Device"
                )
            }
        )

        #expect(payload.lights.first?.brightnessPercentage == 50)
        #expect(payload.lights.first?.areaName == "Kitchen")
        #expect(payload.lights.first?.icon == entityIcon)
        #expect(payload.switches.first?.displayName == "Coffee")
        #expect(payload.covers.first?.isAvailable == true)
        #expect(payload.fans.first?.statusText == "On • 40%")
        #expect(payload.locks.first?.statusText == "Locked")
        #expect(payload.sensors.first?.valueText == "72°F")
        #expect(payload.presence.first?.statusText == "Home")
        #expect(payload.actions.first?.domain == "scene")
    }

    @Test func widgetSnapshotsPreserveUnavailableStateForVisibleFallbacks() {
        let entities = [
            HomeEntity(
                entityID: "lock.front_door",
                domain: .lock,
                displayName: "Front Door",
                state: "unavailable",
                iconName: "lock.fill",
                isAvailable: false,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "person.guest",
                domain: .person,
                displayName: "Guest",
                state: "unavailable",
                iconName: "person",
                isAvailable: false,
                lastUpdated: nil
            )
        ]
        let covers = [
            CoverEntity(
                entityID: "cover.garage",
                displayName: "Garage",
                state: "unavailable",
                position: nil,
                deviceClass: "garage"
            )
        ]
        let fans = [
            FanEntity(
                entityID: "fan.office",
                displayName: "Office",
                state: "unavailable",
                percentage: nil,
                percentageStep: nil,
                presetMode: nil,
                presetModes: []
            )
        ]
        let sensors = [
            SensorEntity(
                entityID: "sensor.battery",
                displayName: "Battery",
                value: "unavailable",
                unit: "%",
                deviceClass: "battery",
                lastUpdated: nil
            )
        ]

        #expect(WidgetSharedStore.coverSnapshots(from: covers).first?.isAvailable == false)
        #expect(WidgetSharedStore.coverSnapshots(from: covers).first?.statusText == "Unavailable")
        #expect(WidgetSharedStore.fanSnapshots(from: fans).first?.isAvailable == false)
        #expect(WidgetSharedStore.fanSnapshots(from: fans).first?.statusText == "Unavailable")
        #expect(WidgetSharedStore.lockSnapshots(from: entities).first?.isAvailable == false)
        #expect(WidgetSharedStore.lockSnapshots(from: entities).first?.statusText == "Unavailable")
        #expect(WidgetSharedStore.sensorSnapshots(from: sensors).first?.isAvailable == false)
        #expect(WidgetSharedStore.sensorSnapshots(from: sensors).first?.valueText == "Unavailable")
        #expect(WidgetSharedStore.presenceSnapshots(from: entities).first?.isAvailable == false)
        #expect(WidgetSharedStore.presenceSnapshots(from: entities).first?.statusText == "Unavailable")
    }
}
