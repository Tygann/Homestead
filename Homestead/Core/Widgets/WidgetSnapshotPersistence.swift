import Foundation

enum WidgetSnapshotPersistence {
    struct Payload: Equatable {
        var lights: [WidgetLightSnapshot]
        var switches: [WidgetSwitchSnapshot]
        var covers: [WidgetCoverSnapshot]
        var fans: [WidgetFanSnapshot]
        var locks: [WidgetLockSnapshot]
        var sensors: [WidgetSensorSnapshot]
        var presence: [WidgetPresenceSnapshot]
        var actions: [WidgetActionSnapshot]
    }

    @MainActor
    static func save(
        entitiesByID: [String: HomeEntity],
        lightEntitiesByID: [String: LightEntity],
        coverEntitiesByID: [String: CoverEntity],
        fanEntitiesByID: [String: FanEntity],
        sensorEntitiesByID: [String: SensorEntity],
        contextForEntityID: (String) -> WidgetEntityContext
    ) {
        let payload = makePayload(
            entitiesByID: entitiesByID,
            lightEntitiesByID: lightEntitiesByID,
            coverEntitiesByID: coverEntitiesByID,
            fanEntitiesByID: fanEntitiesByID,
            sensorEntitiesByID: sensorEntitiesByID,
            contextForEntityID: contextForEntityID
        )

        WidgetSharedStore.saveLightSnapshotPayload(payload.lights)
        WidgetSharedStore.saveSwitchSnapshotPayload(payload.switches)
        WidgetSharedStore.saveCoverSnapshotPayload(payload.covers)
        WidgetSharedStore.saveFanSnapshotPayload(payload.fans)
        WidgetSharedStore.saveLockSnapshotPayload(payload.locks)
        WidgetSharedStore.saveSensorSnapshotPayload(payload.sensors)
        WidgetSharedStore.savePresenceSnapshotPayload(payload.presence)
        WidgetSharedStore.saveActionSnapshotPayload(payload.actions)
    }

    @MainActor
    static func makePayload(
        entitiesByID: [String: HomeEntity],
        lightEntitiesByID: [String: LightEntity],
        coverEntitiesByID: [String: CoverEntity],
        fanEntitiesByID: [String: FanEntity],
        sensorEntitiesByID: [String: SensorEntity],
        contextForEntityID: (String) -> WidgetEntityContext
    ) -> Payload {
        let entities = Array(entitiesByID.values)
        let iconForEntityID: (String) -> ResolvedIcon? = { entityID in
            entitiesByID[entityID]?.resolvedIcon
        }

        return Payload(
            lights: WidgetSharedStore.lightSnapshots(
                from: Array(lightEntitiesByID.values),
                contextForEntityID: contextForEntityID,
                iconForEntityID: iconForEntityID
            ),
            switches: WidgetSharedStore.switchSnapshots(from: entities, contextForEntityID: contextForEntityID),
            covers: WidgetSharedStore.coverSnapshots(
                from: Array(coverEntitiesByID.values),
                contextForEntityID: contextForEntityID,
                iconForEntityID: iconForEntityID
            ),
            fans: WidgetSharedStore.fanSnapshots(
                from: Array(fanEntitiesByID.values),
                contextForEntityID: contextForEntityID,
                iconForEntityID: iconForEntityID
            ),
            locks: WidgetSharedStore.lockSnapshots(from: entities, contextForEntityID: contextForEntityID),
            sensors: WidgetSharedStore.sensorSnapshots(
                from: Array(sensorEntitiesByID.values),
                contextForEntityID: contextForEntityID,
                iconForEntityID: iconForEntityID
            ),
            presence: WidgetSharedStore.presenceSnapshots(from: entities, contextForEntityID: contextForEntityID),
            actions: WidgetSharedStore.actionSnapshots(from: entities, contextForEntityID: contextForEntityID)
        )
    }
}
