import Foundation

nonisolated enum WidgetSnapshotPersistence {
    struct Request: Sendable {
        let profileID: UUID
        let serverName: String
        let entitiesByID: [String: HomeEntity]
        let lightEntitiesByID: [String: LightEntity]
        let coverEntitiesByID: [String: CoverEntity]
        let fanEntitiesByID: [String: FanEntity]
        let sensorEntitiesByID: [String: SensorEntity]
        let contextByEntityID: [String: WidgetEntityContext]
    }

    struct Payload: Equatable, Sendable {
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

    @discardableResult
    static func save(_ request: Request) -> Payload {
        let payload = makePayload(
            entitiesByID: request.entitiesByID,
            lightEntitiesByID: request.lightEntitiesByID,
            coverEntitiesByID: request.coverEntitiesByID,
            fanEntitiesByID: request.fanEntitiesByID,
            sensorEntitiesByID: request.sensorEntitiesByID,
            contextForEntityID: { request.contextByEntityID[$0] ?? .empty }
        )

        WidgetServerSnapshotStore.save(
            WidgetServerSnapshot(
                profileID: request.profileID,
                serverName: request.serverName,
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

actor WidgetSnapshotPersistenceCoordinator {
    typealias Completion = @MainActor @Sendable (UUID, WidgetSnapshotPersistence.Payload) -> Void
    typealias Persist = @Sendable (WidgetSnapshotPersistence.Request) -> WidgetSnapshotPersistence.Payload

    private struct PendingRequest {
        let sequence: UInt64
        let request: WidgetSnapshotPersistence.Request
        let completion: Completion
        let isImmediate: Bool
    }

    private let coalescingInterval: Duration
    private let persist: Persist
    private var pendingByProfileID: [UUID: PendingRequest] = [:]
    private var persistenceTasksByProfileID: [UUID: Task<Void, Never>] = [:]

    init(
        coalescingInterval: Duration = .seconds(1),
        persist: @escaping Persist = WidgetSnapshotPersistence.save
    ) {
        self.coalescingInterval = coalescingInterval
        self.persist = persist
    }

    func schedule(
        sequence: UInt64,
        request: WidgetSnapshotPersistence.Request,
        immediately: Bool = false,
        completion: @escaping Completion
    ) {
        let profileID = request.profileID
        if let pending = pendingByProfileID[profileID], pending.sequence > sequence {
            return
        }

        pendingByProfileID[profileID] = PendingRequest(
            sequence: sequence,
            request: request,
            completion: completion,
            isImmediate: immediately
        )

        if immediately, let task = persistenceTasksByProfileID.removeValue(forKey: profileID) {
            task.cancel()
        }
        startPersistenceTaskIfNeeded(profileID: profileID)
    }

    func flush(profileID: UUID) async {
        persistenceTasksByProfileID.removeValue(forKey: profileID)?.cancel()
        await persistPendingRequest(profileID: profileID)
    }

    private func startPersistenceTaskIfNeeded(profileID: UUID) {
        guard persistenceTasksByProfileID[profileID] == nil,
              let pending = pendingByProfileID[profileID] else {
            return
        }

        let coalescingInterval = coalescingInterval
        persistenceTasksByProfileID[profileID] = Task { [weak self] in
            if !pending.isImmediate {
                do {
                    try await Task.sleep(for: coalescingInterval)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await self?.persistPendingRequest(profileID: profileID)
        }
    }

    private func persistPendingRequest(profileID: UUID) async {
        guard let pending = pendingByProfileID.removeValue(forKey: profileID) else {
            persistenceTasksByProfileID[profileID] = nil
            return
        }

        let payload = persist(pending.request)
        persistenceTasksByProfileID[profileID] = nil
        startPersistenceTaskIfNeeded(profileID: profileID)
        await pending.completion(profileID, payload)
    }
}
