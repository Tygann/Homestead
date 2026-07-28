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

    nonisolated static func changedWidgetKinds(
        from previous: Payload?,
        to current: Payload
    ) -> Set<HomesteadWidgetKind> {
        guard let previous else {
            return Set(HomesteadWidgetKind.allCases)
        }

        var kinds: Set<HomesteadWidgetKind> = []
        if previous.lights != current.lights
            || previous.switches != current.switches
            || previous.covers != current.covers
            || previous.fans != current.fans
            || previous.locks != current.locks {
            kinds.insert(.control)
        }
        if previous.sensors != current.sensors {
            kinds.formUnion([.sensor, .sensorBoard, .largeSensorBoard])
        }
        if previous.presence != current.presence {
            kinds.insert(.status)
        }
        if previous.actions != current.actions {
            kinds.insert(.action)
        }
        return kinds
    }

    @MainActor
    @discardableResult
    static func save(
        profileID: UUID,
        serverName: String,
        entitiesByID: [String: HomeEntity],
        lightEntitiesByID: [String: LightEntity],
        coverEntitiesByID: [String: CoverEntity],
        fanEntitiesByID: [String: FanEntity],
        sensorEntitiesByID: [String: SensorEntity],
        contextForEntityID: (String) -> WidgetEntityContext
    ) -> Payload {
        let payload = makePayload(
            entitiesByID: entitiesByID,
            lightEntitiesByID: lightEntitiesByID,
            coverEntitiesByID: coverEntitiesByID,
            fanEntitiesByID: fanEntitiesByID,
            sensorEntitiesByID: sensorEntitiesByID,
            contextForEntityID: contextForEntityID
        )

        WidgetServerSnapshotStore.save(
            WidgetServerSnapshot(
                profileID: profileID,
                serverName: serverName,
                generatedAt: .now,
                lights: payload.lights,
                switches: payload.switches,
                covers: payload.covers,
                fans: payload.fans,
                locks: payload.locks,
                sensors: payload.sensors,
                presence: payload.presence,
                actions: payload.actions
            )
        )
        return payload
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
                iconForEntityID: iconForEntityID,
                isAvailableForEntityID: { entitiesByID[$0]?.isAvailable ?? false }
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
