import Foundation
import Observation

@MainActor
@Observable
final class HAStateStore {
    @ObservationIgnored private(set) var entitiesByID: [String: HomeEntity] = [:]
    private(set) var allEntities: [HomeEntity] = []
    private(set) var entitiesByDomain: [(domain: EntityDomain, entities: [HomeEntity])] = []
    private(set) var entityIDGroupsByDomain: [EntityDomainGroup] = []
    private(set) var entityIDGroupsByDevice: [EntityDeviceGroup] = []
    private(set) var availableEntityIDs: Set<String> = []
    private(set) var entityCatalogSignature = ""
    private(set) var hasEntities = false
    private(set) var hasLoadedInitialSnapshot = false
    private(set) var dataSourceID: String?
    @ObservationIgnored private(set) var lightEntitiesByID: [String: LightEntity] = [:]
    @ObservationIgnored private(set) var climateEntitiesByID: [String: ClimateEntity] = [:]
    @ObservationIgnored private(set) var coverEntitiesByID: [String: CoverEntity] = [:]
    @ObservationIgnored private(set) var fanEntitiesByID: [String: FanEntity] = [:]
    @ObservationIgnored private(set) var mediaPlayerEntitiesByID: [String: MediaPlayerEntity] = [:]
    @ObservationIgnored private(set) var sensorEntitiesByID: [String: SensorEntity] = [:]
    @ObservationIgnored private(set) var binarySensorEntitiesByID: [String: BinarySensorEntity] = [:]
    @ObservationIgnored private(set) var weatherEntitiesByID: [String: WeatherEntity] = [:]
    @ObservationIgnored private(set) var selectEntitiesByID: [String: SelectEntity] = [:]
    private(set) var updateEntities: [HAUpdateEntity] = []
    @ObservationIgnored private var rawEntitiesByID: [String: HAEntityDTO] = [:]
    @ObservationIgnored private var entityBoxesByID: [String: HAEntityState] = [:]
    @ObservationIgnored private var pendingCommandsByID: [String: HAEntityPendingCommand] = [:]
    @ObservationIgnored private var entityRegistryByID: [String: HAEntityRegistryDisplayDTO] = [:]
    @ObservationIgnored private var deviceRegistryByID: [String: HADeviceRegistryDTO] = [:]
    @ObservationIgnored private var areaRegistryByID: [String: HAAreaRegistryDTO] = [:]
    @ObservationIgnored private var floorRegistryByID: [String: HAFloorRegistryDTO] = [:]
    @ObservationIgnored private var floorSortOrderByID: [String: Int] = [:]
    @ObservationIgnored private var isApplyingSnapshotBatch = false
    @ObservationIgnored private var snapshotBatchNeedsWidgetSave = false

    var lightEntityIDs: [String] {
        entityIDs(for: .light)
    }

    var sensorEntityIDs: [String] {
        entityIDs(for: .sensor)
    }

    func entities(for domain: EntityDomain) -> [HomeEntity] {
        allEntities.filter { $0.domain == domain }
    }

    func entity(for entityID: String) -> HomeEntity? {
        entitiesByID[entityID]
    }

    func entityBox(for entityID: String) -> HAEntityState? {
        entityBoxesByID[entityID]
    }

    func rawEntity(for entityID: String) -> HAEntityDTO? {
        rawEntitiesByID[entityID]
    }

    func rawEntitySnapshot() -> [HAEntityDTO] {
        rawEntitiesByID.values.sorted { lhs, rhs in
            lhs.entityID.localizedCaseInsensitiveCompare(rhs.entityID) == .orderedAscending
        }
    }

    func registryMetadataSnapshot() -> HARegistryMetadataSnapshot? {
        guard !entityRegistryByID.isEmpty || !deviceRegistryByID.isEmpty || !areaRegistryByID.isEmpty || !floorRegistryByID.isEmpty else {
            return nil
        }

        return HARegistryMetadataSnapshot(
            entities: entityRegistryByID.values.sorted {
                $0.entityID.localizedCaseInsensitiveCompare($1.entityID) == .orderedAscending
            },
            devices: deviceRegistryByID.values.sorted {
                $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
            },
            areas: areaRegistryByID.values.sorted {
                $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
            },
            floors: floorRegistryByID.values.sorted {
                floorSortOrderByID[$0.id, default: Int.max] < floorSortOrderByID[$1.id, default: Int.max]
            }
        )
    }

    func allEntityBoxes() -> [HAEntityState] {
        allEntities.compactMap { entityBoxesByID[$0.entityID] }
    }

    func pendingCommand(for entityID: String) -> HAEntityPendingCommand? {
        pendingCommandsByID[entityID]
    }

    func entityRegistryMetadata(for entityID: String) -> HAEntityRegistryDisplayDTO? {
        entityRegistryByID[entityID]
    }

    func deviceRegistryMetadata(for deviceID: String) -> HADeviceRegistryDTO? {
        deviceRegistryByID[deviceID]
    }

    func deviceRegistryMetadata(forEntityID entityID: String) -> HADeviceRegistryDTO? {
        entityRegistryByID[entityID]?.deviceID.flatMap { deviceRegistryByID[$0] }
    }

    func deviceManagementSummaries() -> [HADeviceManagementSummary] {
        let entityCountsByDeviceID = Dictionary(
            grouping: entityRegistryByID.values.compactMap { metadata -> String? in
                guard let deviceID = metadata.deviceID?.nonEmptyValue else {
                    return nil
                }

                return deviceID
            },
            by: { $0 }
        ).mapValues(\.count)

        return deviceRegistryByID.values
            .map { device in
                let areaName = device.areaID?.nonEmptyValue.flatMap { areaRegistryByID[$0]?.name.nonEmptyValue }
                let manufacturer = device.manufacturer?.nonEmptyValue
                let model = device.model?.nonEmptyValue

                return HADeviceManagementSummary(
                    id: device.id,
                    title: device.displayName,
                    subtitle: deviceManagementSubtitle(
                        manufacturer: manufacturer,
                        model: model,
                        areaName: areaName
                    ),
                    areaName: areaName,
                    manufacturer: manufacturer,
                    model: model,
                    entityCount: entityCountsByDeviceID[device.id, default: 0]
                )
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func entityRegistryAdminDetail(for entityID: String) -> String? {
        guard let entity = entitiesByID[entityID] else {
            return nil
        }

        let registry = entityRegistryByID[entityID]
        let deviceName = registry?.deviceID?.nonEmptyValue.flatMap { deviceRegistryByID[$0]?.displayName.nonEmptyValue }
        let areaName = areaName(for: entityID)

        var parts: [String] = []

        if let areaName {
            parts.append(areaName)
        }

        if let deviceName {
            parts.append(deviceName)
        }

        if let entityCategory = registry?.entityCategory?.nonEmptyValue {
            parts.append(entityCategory.replacingOccurrences(of: "_", with: " ").capitalized)
        }

        if registry?.hiddenBy == true {
            parts.append("Hidden")
        }

        if !entity.isAvailable {
            parts.append("Unavailable")
        }

        return parts.isEmpty ? entity.domain.displayName : parts.joined(separator: " • ")
    }

    func areaName(for entityID: String) -> String? {
        areaContext(for: entityID)?.name
    }

    func areaContext(for entityID: String) -> DashboardAreaContext? {
        guard let areaID = areaID(for: entityID),
              let areaName = areaRegistryByID[areaID]?.name.nonEmptyValue else {
            return nil
        }

        let floorID = areaRegistryByID[areaID]?.floorID?.nonEmptyValue
        let floor = floorID.flatMap { floorRegistryByID[$0] }

        return DashboardAreaContext(
            areaID: areaID,
            name: areaName,
            floorID: floor?.id,
            floorName: floor?.name.nonEmptyValue,
            floorLevel: floor?.level,
            floorSortOrder: floor.flatMap { floorSortOrderByID[$0.id] }
        )
    }

    func areaID(for entityID: String) -> String? {
        if let areaID = entityRegistryByID[entityID]?.areaID?.nonEmptyValue {
            return areaID
        }

        guard let deviceID = entityRegistryByID[entityID]?.deviceID?.nonEmptyValue,
              let areaID = deviceRegistryByID[deviceID]?.areaID?.nonEmptyValue else {
            return nil
        }

        return areaID
    }

    func preferredClimateReadingEntityIDs() -> Set<String> {
        Set(areaRegistryByID.values.flatMap { area in
            [area.temperatureEntityID, area.humidityEntityID].compactMap { $0?.nonEmptyValue }
        })
    }

    func dashboardSummaryMembershipContext() -> DashboardSummaryMembershipContext {
        let metadataByID = entityRegistryByID.mapValues { metadata in
            DashboardSummaryEntityMetadata(
                isHidden: metadata.hiddenBy == true,
                entityCategory: metadata.entityCategory?.nonEmptyValue,
                deviceID: metadata.deviceID?.nonEmptyValue
            )
        }
        let chargingDeviceIDs = Set(entityRegistryByID.values.compactMap { metadata -> String? in
            guard let deviceID = metadata.deviceID?.nonEmptyValue,
                  let entity = rawEntitiesByID[metadata.entityID],
                  entity.attributes["device_class"]?.stringValue == "battery_charging",
                  entity.state == "on" else {
                return nil
            }
            return deviceID
        })

        return DashboardSummaryMembershipContext(
            entityMetadataByID: metadataByID,
            preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs(),
            chargingDeviceIDs: chargingDeviceIDs
        )
    }

    func lightEntity(for entityID: String) -> LightEntity? {
        lightEntitiesByID[entityID]
    }

    func climateEntity(for entityID: String) -> ClimateEntity? {
        climateEntitiesByID[entityID]
    }

    func coverEntity(for entityID: String) -> CoverEntity? {
        coverEntitiesByID[entityID]
    }

    func fanEntity(for entityID: String) -> FanEntity? {
        fanEntitiesByID[entityID]
    }

    func mediaPlayerEntity(for entityID: String) -> MediaPlayerEntity? {
        mediaPlayerEntitiesByID[entityID]
    }

    func sensorEntity(for entityID: String) -> SensorEntity? {
        sensorEntitiesByID[entityID]
    }

    func binarySensorEntity(for entityID: String) -> BinarySensorEntity? {
        binarySensorEntitiesByID[entityID]
    }

    func weatherEntity(for entityID: String) -> WeatherEntity? {
        weatherEntitiesByID[entityID]
    }

    func selectEntity(for entityID: String) -> SelectEntity? {
        selectEntitiesByID[entityID]
    }

    func updateEntity(for entityID: String) -> HAUpdateEntity? {
        updateEntities.first { $0.entityID == entityID }
    }

    func presenceRecords() -> [HAPresenceRecord] {
        let presenceDTOs = rawEntitiesByID.values.filter { dto in
            let domain = EntityDomain(entityID: dto.entityID)
            return domain == .person || domain == .deviceTracker
        }

        let trackerDTOsByID = Dictionary(
            uniqueKeysWithValues: presenceDTOs
                .filter { EntityDomain(entityID: $0.entityID) == .deviceTracker }
                .map { ($0.entityID, $0) }
        )

        let personDTOs = presenceDTOs.filter { EntityDomain(entityID: $0.entityID) == .person }
        let personBySourceTrackerID = personDTOs.reduce(into: [String: HAEntityDTO]()) { peopleByTrackerID, person in
            guard let sourceEntityID = person.attributes["source"]?.stringValue?.nonEmptyValue,
                  trackerDTOsByID[sourceEntityID] != nil,
                  peopleByTrackerID[sourceEntityID] == nil else {
                return
            }

            peopleByTrackerID[sourceEntityID] = person
        }

        return presenceDTOs.compactMap { dto -> HAPresenceRecord? in
            let domain = EntityDomain(entityID: dto.entityID)
            let context = presenceContext(for: dto.entityID)

            if domain == .person {
                let linkedTrackers = linkedTrackerSummaries(for: dto, trackerDTOsByID: trackerDTOsByID)
                return EntityMapper.presenceRecord(
                    from: dto,
                    context: context,
                    linkedTrackers: linkedTrackers
                )
            }

            let linkedPerson = personBySourceTrackerID[dto.entityID]
            return EntityMapper.presenceRecord(
                from: dto,
                context: context,
                linkedPersonEntityID: linkedPerson?.entityID,
                linkedPersonName: linkedPerson.map { EntityMapper.displayName(for: $0) }
            )
        }
        .sorted { lhs, rhs in
            if lhs.domain != rhs.domain {
                return lhs.domain == .person
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func presenceRecord(for entityID: String) -> HAPresenceRecord? {
        presenceRecords().first { $0.entityID == entityID }
    }

    func replaceDataSourceIfNeeded(_ dataSourceID: String) {
        guard self.dataSourceID != dataSourceID else {
            return
        }

        clearAllEntities()
        self.dataSourceID = dataSourceID
    }

    func applyInitialStates(_ entities: [HAEntityDTO], dataSourceID: String? = nil) {
        if let dataSourceID {
            replaceDataSourceIfNeeded(dataSourceID)
        }
        applySnapshot(entities)
    }

    func applySnapshot(_ entities: [HAEntityDTO], dataSourceID: String? = nil) {
        if let dataSourceID {
            replaceDataSourceIfNeeded(dataSourceID)
        }
        hasLoadedInitialSnapshot = true
        isApplyingSnapshotBatch = true
        snapshotBatchNeedsWidgetSave = false

        let snapshotEntityIDs = Set(entities.map(\.entityID))
        let removedEntityIDs = Set(rawEntitiesByID.keys).subtracting(snapshotEntityIDs)

        for entityID in removedEntityIDs {
            removeEntity(entityID)
        }

        for dto in entities {
            let wasApplied = applyConfirmedDTO(dto)

            if wasApplied, pendingCommandsByID[dto.entityID]?.isSatisfied(by: dto) == true {
                clearPendingCommand(entityID: dto.entityID)
            }
        }

        isApplyingSnapshotBatch = false
        refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)

        if snapshotBatchNeedsWidgetSave {
            saveWidgetSnapshots()
        }
        snapshotBatchNeedsWidgetSave = false
    }

    func applyRegistryMetadata(
        entities: [HAEntityRegistryDisplayDTO],
        devices: [HADeviceRegistryDTO],
        areas: [HAAreaRegistryDTO] = [],
        floors: [HAFloorRegistryDTO] = []
    ) {
        entityRegistryByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityID, $0) })
        deviceRegistryByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        areaRegistryByID = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
        floorRegistryByID = Dictionary(uniqueKeysWithValues: floors.map { ($0.id, $0) })
        floorSortOrderByID = Dictionary(uniqueKeysWithValues: floors.enumerated().map { index, floor in
            (floor.id, index)
        })
        refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
    }

    func applyRegistryMetadata(_ metadata: HARegistryMetadataSnapshot) {
        applyRegistryMetadata(
            entities: metadata.entities,
            devices: metadata.devices,
            areas: metadata.areas,
            floors: metadata.floors
        )
    }

    func apply(event: HAEventDTO) {
        guard let stateChanged = event.stateChanged else { return }
        applyStateChanged(stateChanged)
    }

    func applyStateChanged(_ stateChanged: HAStateChangedEventDTO) {
        if let newState = stateChanged.newState {
            if applyConfirmedDTO(newState) {
                if pendingCommandsByID[newState.entityID]?.isSatisfied(by: newState) == true {
                    clearPendingCommand(entityID: newState.entityID)
                }
            }
        } else {
            removeEntity(stateChanged.entityID)
        }
    }

    func applyStateChanges(_ changes: [HAStateChangedEventDTO]) {
        for change in changes {
            applyStateChanged(change)
        }
    }

    func applyLiveStateUpdates(_ updates: [HAEntityDTO]) {
        for update in updates {
            if applyConfirmedDTO(update) {
                if pendingCommandsByID[update.entityID]?.isSatisfied(by: update) == true {
                    clearPendingCommand(entityID: update.entityID)
                }
            }
        }
    }

    func setPendingCommand(_ pendingCommand: HAEntityPendingCommand) {
        pendingCommandsByID[pendingCommand.entityID] = pendingCommand
        entityBoxesByID[pendingCommand.entityID]?.pendingCommand = pendingCommand
    }

    func clearPendingCommand(entityID: String) {
        pendingCommandsByID[entityID] = nil
        entityBoxesByID[entityID]?.pendingCommand = nil
    }

    func displayNameForDeviceGroupedEntity(entityID: String) -> String? {
        guard let entity = entitiesByID[entityID],
              let registry = entityRegistryByID[entityID] else {
            return nil
        }

        let deviceName = registry.deviceID
            .flatMap { deviceRegistryByID[$0]?.displayName.nonEmptyValue }

        if let name = registry.name?.nonEmptyValue {
            return name.removingDeviceNamePrefix(deviceName)
        }

        if let originalName = registry.originalName?.nonEmptyValue {
            return originalName.removingDeviceNamePrefix(deviceName)
        }

        return entity.displayName.removingDeviceNamePrefix(deviceName)
    }

    private func entityIDs(for domain: EntityDomain) -> [String] {
        entitiesByID.values
            .filter { $0.domain == domain }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map(\.entityID)
    }

    private func deviceManagementSubtitle(
        manufacturer: String?,
        model: String?,
        areaName: String?
    ) -> String {
        let parts = [manufacturer, model, areaName].compactMap { $0 }
        return parts.isEmpty ? "No additional details" : parts.joined(separator: " • ")
    }

    private func presenceContext(for entityID: String) -> HAPresenceContext {
        let registry = entityRegistryByID[entityID]
        let deviceID = registry?.deviceID?.nonEmptyValue
        let device = deviceID.flatMap { deviceRegistryByID[$0] }
        let areaContext = areaContext(for: entityID)

        return HAPresenceContext(
            deviceID: deviceID,
            deviceName: device?.displayName.nonEmptyValue,
            areaID: areaContext?.areaID,
            areaName: areaContext?.name,
            floorID: areaContext?.floorID,
            floorName: areaContext?.floorName
        )
    }

    private func linkedTrackerSummaries(
        for person: HAEntityDTO,
        trackerDTOsByID: [String: HAEntityDTO]
    ) -> [HAPresenceTrackerSummary] {
        guard let sourceEntityID = person.attributes["source"]?.stringValue?.nonEmptyValue,
              let tracker = trackerDTOsByID[sourceEntityID] else {
            return []
        }

        return EntityMapper.presenceTrackerSummary(
            from: tracker,
            context: presenceContext(for: tracker.entityID)
        ).map { [$0] } ?? []
    }

    private func clearAllEntities() {
        entitiesByID.removeAll()
        allEntities.removeAll()
        entitiesByDomain.removeAll()
        entityIDGroupsByDomain.removeAll()
        entityIDGroupsByDevice.removeAll()
        availableEntityIDs.removeAll()
        entityCatalogSignature = ""
        hasEntities = false
        hasLoadedInitialSnapshot = false
        lightEntitiesByID.removeAll()
        climateEntitiesByID.removeAll()
        coverEntitiesByID.removeAll()
        fanEntitiesByID.removeAll()
        mediaPlayerEntitiesByID.removeAll()
        sensorEntitiesByID.removeAll()
        binarySensorEntitiesByID.removeAll()
        weatherEntitiesByID.removeAll()
        selectEntitiesByID.removeAll()
        updateEntities.removeAll()
        rawEntitiesByID.removeAll()
        entityBoxesByID.removeAll()
        pendingCommandsByID.removeAll()
        entityRegistryByID.removeAll()
        deviceRegistryByID.removeAll()
        areaRegistryByID.removeAll()
        floorRegistryByID.removeAll()
        floorSortOrderByID.removeAll()
        isApplyingSnapshotBatch = false
        snapshotBatchNeedsWidgetSave = false
        saveWidgetSnapshots()
    }

    private func rebuildMappedEntities(from entities: [HAEntityDTO]) {
        entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityID, EntityMapper.homeEntity(from: $0)) })
        lightEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.lightEntity(from: dto).map { ($0.entityID, $0) }
        })
        climateEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.climateEntity(from: dto).map { ($0.entityID, $0) }
        })
        coverEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.coverEntity(from: dto).map { ($0.entityID, $0) }
        })
        fanEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.fanEntity(from: dto).map { ($0.entityID, $0) }
        })
        mediaPlayerEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.mediaPlayerEntity(from: dto).map { ($0.entityID, $0) }
        })
        sensorEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.sensorEntity(from: dto).map { ($0.entityID, $0) }
        })
        binarySensorEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.binarySensorEntity(from: dto).map { ($0.entityID, $0) }
        })
        weatherEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.weatherEntity(from: dto).map { ($0.entityID, $0) }
        })
        selectEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.selectEntity(from: dto).map { ($0.entityID, $0) }
        })
        refreshUpdateEntities()
        var updatedEntityBoxesByID: [String: HAEntityState] = [:]
        for dto in entities {
            let homeEntity = EntityMapper.homeEntity(from: dto)

            if let entityBox = entityBoxesByID[dto.entityID] {
                entityBox.update(
                    homeEntity: homeEntity,
                    lightEntity: EntityMapper.lightEntity(from: dto),
                    climateEntity: EntityMapper.climateEntity(from: dto),
                    coverEntity: EntityMapper.coverEntity(from: dto),
                    fanEntity: EntityMapper.fanEntity(from: dto),
                    mediaPlayerEntity: EntityMapper.mediaPlayerEntity(from: dto),
                    sensorEntity: EntityMapper.sensorEntity(from: dto),
                    binarySensorEntity: EntityMapper.binarySensorEntity(from: dto),
                    weatherEntity: EntityMapper.weatherEntity(from: dto),
                    selectEntity: EntityMapper.selectEntity(from: dto),
                    pendingCommand: pendingCommandsByID[dto.entityID]
                )
                updatedEntityBoxesByID[dto.entityID] = entityBox
            } else {
                updatedEntityBoxesByID[dto.entityID] = HAEntityState(
                    homeEntity: homeEntity,
                    lightEntity: EntityMapper.lightEntity(from: dto),
                    climateEntity: EntityMapper.climateEntity(from: dto),
                    coverEntity: EntityMapper.coverEntity(from: dto),
                    fanEntity: EntityMapper.fanEntity(from: dto),
                    mediaPlayerEntity: EntityMapper.mediaPlayerEntity(from: dto),
                    sensorEntity: EntityMapper.sensorEntity(from: dto),
                    binarySensorEntity: EntityMapper.binarySensorEntity(from: dto),
                    weatherEntity: EntityMapper.weatherEntity(from: dto),
                    selectEntity: EntityMapper.selectEntity(from: dto),
                    pendingCommand: pendingCommandsByID[dto.entityID]
                )
            }
        }
        entityBoxesByID = updatedEntityBoxesByID
        refreshEntityIndexes()
    }

    @discardableResult
    private func applyConfirmedDTO(_ dto: HAEntityDTO) -> Bool {
        guard shouldApply(dto) else {
            return false
        }

        rawEntitiesByID[dto.entityID] = dto
        apply(dto: dto)
        return true
    }

    private func apply(dto: HAEntityDTO) {
        let previousCatalogSignature = entityCatalogSignature
        let previousEntity = entitiesByID[dto.entityID]
        let homeEntity = EntityMapper.homeEntity(from: dto)

        entitiesByID[dto.entityID] = homeEntity
        lightEntitiesByID[dto.entityID] = EntityMapper.lightEntity(from: dto)
        climateEntitiesByID[dto.entityID] = EntityMapper.climateEntity(from: dto)
        coverEntitiesByID[dto.entityID] = EntityMapper.coverEntity(from: dto)
        fanEntitiesByID[dto.entityID] = EntityMapper.fanEntity(from: dto)
        mediaPlayerEntitiesByID[dto.entityID] = EntityMapper.mediaPlayerEntity(from: dto)
        sensorEntitiesByID[dto.entityID] = EntityMapper.sensorEntity(from: dto)
        binarySensorEntitiesByID[dto.entityID] = EntityMapper.binarySensorEntity(from: dto)
        weatherEntitiesByID[dto.entityID] = EntityMapper.weatherEntity(from: dto)
        selectEntitiesByID[dto.entityID] = EntityMapper.selectEntity(from: dto)
        if !isApplyingSnapshotBatch, previousEntity?.domain == .update || homeEntity.domain == .update {
            refreshUpdateEntities()
        }
        updateEntityBox(
            entityID: dto.entityID,
            homeEntity: homeEntity,
            lightEntity: lightEntitiesByID[dto.entityID],
            climateEntity: climateEntitiesByID[dto.entityID],
            coverEntity: coverEntitiesByID[dto.entityID],
            fanEntity: fanEntitiesByID[dto.entityID],
            mediaPlayerEntity: mediaPlayerEntitiesByID[dto.entityID],
            sensorEntity: sensorEntitiesByID[dto.entityID],
            binarySensorEntity: binarySensorEntitiesByID[dto.entityID],
            weatherEntity: weatherEntitiesByID[dto.entityID],
            selectEntity: selectEntitiesByID[dto.entityID],
            pendingCommand: pendingCommandsByID[dto.entityID]
        )

        if isApplyingSnapshotBatch {
            // Snapshot batches refresh the catalog once after all entity changes are applied.
        } else if previousEntity?.domain == homeEntity.domain,
           previousEntity?.displayName == homeEntity.displayName {
            updateCachedEntity(homeEntity)
        } else {
            refreshEntityIndexes(previousCatalogSignature: previousCatalogSignature)
        }

        if homeEntity.domain.isWidgetSnapshotDomain {
            if isApplyingSnapshotBatch {
                snapshotBatchNeedsWidgetSave = true
            } else {
                saveWidgetSnapshots()
            }
        }
    }

    private func shouldApply(_ dto: HAEntityDTO) -> Bool {
        guard let incomingLastUpdated = dto.lastUpdated,
              let currentLastUpdated = rawEntitiesByID[dto.entityID]?.lastUpdated else {
            return true
        }

        return incomingLastUpdated >= currentLastUpdated
    }

    func removeEntity(_ entityID: String) {
        let previousCatalogSignature = entityCatalogSignature
        let removedEntity = entitiesByID.removeValue(forKey: entityID)

        rawEntitiesByID.removeValue(forKey: entityID)
        lightEntitiesByID.removeValue(forKey: entityID)
        climateEntitiesByID.removeValue(forKey: entityID)
        coverEntitiesByID.removeValue(forKey: entityID)
        fanEntitiesByID.removeValue(forKey: entityID)
        mediaPlayerEntitiesByID.removeValue(forKey: entityID)
        sensorEntitiesByID.removeValue(forKey: entityID)
        binarySensorEntitiesByID.removeValue(forKey: entityID)
        weatherEntitiesByID.removeValue(forKey: entityID)
        selectEntitiesByID.removeValue(forKey: entityID)
        if removedEntity?.domain == .update {
            refreshUpdateEntities()
        }
        entityBoxesByID.removeValue(forKey: entityID)
        pendingCommandsByID.removeValue(forKey: entityID)

        if removedEntity != nil {
            if isApplyingSnapshotBatch {
                if removedEntity?.domain.isWidgetSnapshotDomain == true {
                    snapshotBatchNeedsWidgetSave = true
                }
            } else {
                refreshEntityIndexes(previousCatalogSignature: previousCatalogSignature)
                if removedEntity?.domain.isWidgetSnapshotDomain == true {
                    saveWidgetSnapshots()
                }
            }
        }
    }

    private func refreshEntityIndexes(previousCatalogSignature: String? = nil) {
        allEntities = entitiesByID.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        entitiesByDomain = Dictionary(grouping: allEntities, by: \.domain)
            .map { domain, entities in
                (domain: domain, entities: entities)
            }
            .sorted { lhs, rhs in
                if lhs.domain.dashboardPriority != rhs.domain.dashboardPriority {
                    return lhs.domain.dashboardPriority < rhs.domain.dashboardPriority
                }

                return lhs.domain.displayName.localizedCaseInsensitiveCompare(rhs.domain.displayName) == .orderedAscending
            }
        entityIDGroupsByDomain = entitiesByDomain.map { group in
            EntityDomainGroup(
                domain: group.domain,
                entityIDs: group.entities.map(\.entityID)
            )
        }
        entityIDGroupsByDevice = makeDeviceGroups()
        availableEntityIDs = Set(entitiesByID.keys)
        hasEntities = !availableEntityIDs.isEmpty
        refreshUpdateEntities()

        let signature = availableEntityIDs.sorted().joined(separator: "|")
        if previousCatalogSignature == nil || signature != previousCatalogSignature {
            entityCatalogSignature = signature
        }
    }

    private func updateCachedEntity(_ entity: HomeEntity) {
        guard let entityIndex = allEntities.firstIndex(where: { $0.entityID == entity.entityID }) else {
            refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
            return
        }

        allEntities[entityIndex] = entity

        guard let groupIndex = entitiesByDomain.firstIndex(where: { $0.domain == entity.domain }),
              let groupedEntityIndex = entitiesByDomain[groupIndex].entities.firstIndex(where: { $0.entityID == entity.entityID }) else {
            refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
            return
        }

        entitiesByDomain[groupIndex].entities[groupedEntityIndex] = entity
    }

    private func updateEntityBox(
        entityID: String,
        homeEntity: HomeEntity,
        lightEntity: LightEntity?,
        climateEntity: ClimateEntity?,
        coverEntity: CoverEntity?,
        fanEntity: FanEntity?,
        mediaPlayerEntity: MediaPlayerEntity?,
        sensorEntity: SensorEntity?,
        binarySensorEntity: BinarySensorEntity?,
        weatherEntity: WeatherEntity?,
        selectEntity: SelectEntity?,
        pendingCommand: HAEntityPendingCommand?
    ) {
        if let entityBox = entityBoxesByID[entityID] {
            entityBox.update(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                fanEntity: fanEntity,
                mediaPlayerEntity: mediaPlayerEntity,
                sensorEntity: sensorEntity,
                binarySensorEntity: binarySensorEntity,
                weatherEntity: weatherEntity,
                selectEntity: selectEntity,
                pendingCommand: pendingCommand
            )
        } else {
            entityBoxesByID[entityID] = HAEntityState(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                fanEntity: fanEntity,
                mediaPlayerEntity: mediaPlayerEntity,
                sensorEntity: sensorEntity,
                binarySensorEntity: binarySensorEntity,
                weatherEntity: weatherEntity,
                selectEntity: selectEntity,
                pendingCommand: pendingCommand
            )
        }
    }

    private func saveWidgetSnapshots() {
        let contextForEntityID: (String) -> WidgetEntityContext = { entityID in
            WidgetEntityContext(
                areaName: self.areaName(for: entityID),
                deviceName: self.deviceRegistryMetadata(forEntityID: entityID)?.displayName.nonEmptyValue
            )
        }

        WidgetSharedStore.saveLightSnapshots(Array(lightEntitiesByID.values), contextForEntityID: contextForEntityID)
        WidgetSharedStore.saveSwitchSnapshots(Array(entitiesByID.values), contextForEntityID: contextForEntityID)
        WidgetSharedStore.saveCoverSnapshots(Array(coverEntitiesByID.values), contextForEntityID: contextForEntityID)
        WidgetSharedStore.saveFanSnapshots(Array(fanEntitiesByID.values), contextForEntityID: contextForEntityID)
        WidgetSharedStore.saveLockSnapshots(Array(entitiesByID.values), contextForEntityID: contextForEntityID)
        WidgetSharedStore.saveSensorSnapshots(Array(sensorEntitiesByID.values), contextForEntityID: contextForEntityID)
        WidgetSharedStore.savePresenceSnapshots(Array(entitiesByID.values), contextForEntityID: contextForEntityID)
        WidgetSharedStore.saveActionSnapshots(Array(entitiesByID.values), contextForEntityID: contextForEntityID)
    }

    private func refreshUpdateEntities() {
        updateEntities = rawEntitiesByID.values
            .compactMap { dto in
                updateEntity(from: dto)
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func updateEntity(from dto: HAEntityDTO) -> HAUpdateEntity? {
        let registry = entityRegistryByID[dto.entityID]
        let deviceID = registry?.deviceID?.nonEmptyValue
        let device = deviceID.flatMap { deviceRegistryByID[$0] }
        let areaContext = areaContext(for: dto.entityID)

        return EntityMapper.updateEntity(
            from: dto,
            deviceID: deviceID,
            deviceName: device?.displayName,
            areaID: areaContext?.areaID,
            areaName: areaContext?.name,
            floorID: areaContext?.floorID,
            floorName: areaContext?.floorName
        )
    }

    private func makeDeviceGroups() -> [EntityDeviceGroup] {
        var groupsByDeviceID: [String: [HomeEntity]] = [:]
        var unassignedEntities: [HomeEntity] = []

        for entity in allEntities {
            guard let deviceID = entityRegistryByID[entity.entityID]?.deviceID?.nonEmptyValue else {
                unassignedEntities.append(entity)
                continue
            }

            groupsByDeviceID[deviceID, default: []].append(entity)
        }

        var groups = groupsByDeviceID.map { deviceID, entities in
            EntityDeviceGroup(
                id: deviceID,
                title: deviceRegistryByID[deviceID]?.displayName ?? "Unknown Device",
                entityIDs: entities.sortedByDisplayName.map(\.entityID)
            )
        }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        if !unassignedEntities.isEmpty {
            groups.append(
                EntityDeviceGroup(
                    id: "unassigned",
                    title: "Other Entities",
                    entityIDs: unassignedEntities.sortedByDisplayName.map(\.entityID)
                )
            )
        }

        return groups
    }
}

struct EntityDomainGroup: Equatable, Sendable {
    let domain: EntityDomain
    let entityIDs: [String]
}

struct EntityDeviceGroup: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let entityIDs: [String]
}

struct HADeviceManagementSummary: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let areaName: String?
    let manufacturer: String?
    let model: String?
    let entityCount: Int

    func matches(query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let searchableText = [
            id,
            title,
            subtitle,
            areaName,
            manufacturer,
            model
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return searchableText.localizedCaseInsensitiveContains(trimmedQuery)
    }
}

private extension HADeviceRegistryDTO {
    var displayName: String {
        nameByUser?.nonEmptyValue ?? name?.nonEmptyValue ?? manufacturer?.nonEmptyValue ?? "Unknown Device"
    }
}

private extension Array where Element == HomeEntity {
    var sortedByDisplayName: [HomeEntity] {
        sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    func removingDeviceNamePrefix(_ deviceName: String) -> String {
        let trimmedName = trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDeviceName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDeviceName.isEmpty,
              trimmedName.localizedCaseInsensitiveContains(trimmedDeviceName),
              trimmedName.lowercased().hasPrefix(trimmedDeviceName.lowercased()) else {
            return trimmedName
        }

        let suffix = trimmedName.dropFirst(trimmedDeviceName.count)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        return suffix.isEmpty ? trimmedName : suffix
    }

    func removingDeviceNamePrefix(_ deviceName: String?) -> String {
        guard let deviceName else {
            return trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return removingDeviceNamePrefix(deviceName)
    }
}

struct HAEntityPendingCommand: Equatable, Sendable {
    let entityID: String
    let expectedState: String?
    let expectedAttributes: [String: JSONValue]
    let startedAt: Date

    init(
        entityID: String,
        expectedState: String? = nil,
        expectedAttributes: [String: JSONValue] = [:],
        startedAt: Date = Date()
    ) {
        self.entityID = entityID
        self.expectedState = expectedState
        self.expectedAttributes = expectedAttributes
        self.startedAt = startedAt
    }

    func isSatisfied(by dto: HAEntityDTO) -> Bool {
        guard dto.entityID == entityID else {
            return false
        }

        if let expectedState, dto.state != expectedState {
            return false
        }

        return expectedAttributes.allSatisfy { key, expectedValue in
            dto.attributes[key]?.matchesCommandExpectation(expectedValue) == true
        }
    }
}

private extension JSONValue {
    func matchesCommandExpectation(_ expectedValue: JSONValue) -> Bool {
        switch (self, expectedValue) {
        case (.number(let actual), .number(let expected)):
            abs(actual - expected) < 0.5
        default:
            self == expectedValue
        }
    }
}

private extension EntityDomain {
    var isWidgetSnapshotDomain: Bool {
        self == .light
            || self == .switch
            || self == .cover
            || self == .fan
            || self == .lock
            || self == .sensor
            || self == .person
            || self == .scene
            || self == .script
    }
}

@MainActor
@Observable
final class HAEntityState: Identifiable {
    var homeEntity: HomeEntity
    var lightEntity: LightEntity?
    var climateEntity: ClimateEntity?
    var coverEntity: CoverEntity?
    var fanEntity: FanEntity?
    var mediaPlayerEntity: MediaPlayerEntity?
    var sensorEntity: SensorEntity?
    var binarySensorEntity: BinarySensorEntity?
    var weatherEntity: WeatherEntity?
    var selectEntity: SelectEntity?
    var pendingCommand: HAEntityPendingCommand?

    var id: String { homeEntity.entityID }
    var entityID: String { homeEntity.entityID }
    var domain: EntityDomain { homeEntity.domain }

    init(
        homeEntity: HomeEntity,
        lightEntity: LightEntity? = nil,
        climateEntity: ClimateEntity? = nil,
        coverEntity: CoverEntity? = nil,
        fanEntity: FanEntity? = nil,
        mediaPlayerEntity: MediaPlayerEntity? = nil,
        sensorEntity: SensorEntity? = nil,
        binarySensorEntity: BinarySensorEntity? = nil,
        weatherEntity: WeatherEntity? = nil,
        selectEntity: SelectEntity? = nil,
        pendingCommand: HAEntityPendingCommand? = nil
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.fanEntity = fanEntity
        self.mediaPlayerEntity = mediaPlayerEntity
        self.sensorEntity = sensorEntity
        self.binarySensorEntity = binarySensorEntity
        self.weatherEntity = weatherEntity
        self.selectEntity = selectEntity
        self.pendingCommand = pendingCommand
    }

    func update(
        homeEntity: HomeEntity,
        lightEntity: LightEntity?,
        climateEntity: ClimateEntity?,
        coverEntity: CoverEntity?,
        fanEntity: FanEntity?,
        mediaPlayerEntity: MediaPlayerEntity?,
        sensorEntity: SensorEntity?,
        binarySensorEntity: BinarySensorEntity?,
        weatherEntity: WeatherEntity?,
        selectEntity: SelectEntity?,
        pendingCommand: HAEntityPendingCommand?
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.fanEntity = fanEntity
        self.mediaPlayerEntity = mediaPlayerEntity
        self.sensorEntity = sensorEntity
        self.binarySensorEntity = binarySensorEntity
        self.weatherEntity = weatherEntity
        self.selectEntity = selectEntity
        self.pendingCommand = pendingCommand
    }
}
