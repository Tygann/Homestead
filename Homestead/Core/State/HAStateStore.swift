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
    @ObservationIgnored private(set) var sensorEntitiesByID: [String: SensorEntity] = [:]
    @ObservationIgnored private var rawEntitiesByID: [String: HAEntityDTO] = [:]
    @ObservationIgnored private var entityBoxesByID: [String: HAEntityState] = [:]
    @ObservationIgnored private var pendingCommandsByID: [String: HAEntityPendingCommand] = [:]
    @ObservationIgnored private var entityRegistryByID: [String: HAEntityRegistryDisplayDTO] = [:]
    @ObservationIgnored private var deviceRegistryByID: [String: HADeviceRegistryDTO] = [:]
    @ObservationIgnored private var areaRegistryByID: [String: HAAreaRegistryDTO] = [:]
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
        guard !entityRegistryByID.isEmpty || !deviceRegistryByID.isEmpty || !areaRegistryByID.isEmpty else {
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

    func areaName(for entityID: String) -> String? {
        if let areaID = entityRegistryByID[entityID]?.areaID?.nonEmptyValue,
           let areaName = areaRegistryByID[areaID]?.name.nonEmptyValue {
            return areaName
        }

        guard let deviceID = entityRegistryByID[entityID]?.deviceID?.nonEmptyValue,
              let areaID = deviceRegistryByID[deviceID]?.areaID?.nonEmptyValue,
              let areaName = areaRegistryByID[areaID]?.name.nonEmptyValue else {
            return nil
        }

        return areaName
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

    func sensorEntity(for entityID: String) -> SensorEntity? {
        sensorEntitiesByID[entityID]
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
            saveWidgetLightSnapshots()
        }
        snapshotBatchNeedsWidgetSave = false
    }

    func applyRegistryMetadata(
        entities: [HAEntityRegistryDisplayDTO],
        devices: [HADeviceRegistryDTO],
        areas: [HAAreaRegistryDTO] = []
    ) {
        entityRegistryByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityID, $0) })
        deviceRegistryByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        areaRegistryByID = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
        refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
    }

    func applyRegistryMetadata(_ metadata: HARegistryMetadataSnapshot) {
        applyRegistryMetadata(
            entities: metadata.entities,
            devices: metadata.devices,
            areas: metadata.areas
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
        sensorEntitiesByID.removeAll()
        rawEntitiesByID.removeAll()
        entityBoxesByID.removeAll()
        pendingCommandsByID.removeAll()
        entityRegistryByID.removeAll()
        deviceRegistryByID.removeAll()
        areaRegistryByID.removeAll()
        isApplyingSnapshotBatch = false
        snapshotBatchNeedsWidgetSave = false
        saveWidgetLightSnapshots()
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
        sensorEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.sensorEntity(from: dto).map { ($0.entityID, $0) }
        })
        var updatedEntityBoxesByID: [String: HAEntityState] = [:]
        for dto in entities {
            let homeEntity = EntityMapper.homeEntity(from: dto)

            if let entityBox = entityBoxesByID[dto.entityID] {
                entityBox.update(
                    homeEntity: homeEntity,
                    lightEntity: EntityMapper.lightEntity(from: dto),
                    climateEntity: EntityMapper.climateEntity(from: dto),
                    coverEntity: EntityMapper.coverEntity(from: dto),
                    sensorEntity: EntityMapper.sensorEntity(from: dto),
                    pendingCommand: pendingCommandsByID[dto.entityID]
                )
                updatedEntityBoxesByID[dto.entityID] = entityBox
            } else {
                updatedEntityBoxesByID[dto.entityID] = HAEntityState(
                    homeEntity: homeEntity,
                    lightEntity: EntityMapper.lightEntity(from: dto),
                    climateEntity: EntityMapper.climateEntity(from: dto),
                    coverEntity: EntityMapper.coverEntity(from: dto),
                    sensorEntity: EntityMapper.sensorEntity(from: dto),
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
        sensorEntitiesByID[dto.entityID] = EntityMapper.sensorEntity(from: dto)
        updateEntityBox(
            entityID: dto.entityID,
            homeEntity: homeEntity,
            lightEntity: lightEntitiesByID[dto.entityID],
            climateEntity: climateEntitiesByID[dto.entityID],
            coverEntity: coverEntitiesByID[dto.entityID],
            sensorEntity: sensorEntitiesByID[dto.entityID],
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

        if homeEntity.domain == .light {
            if isApplyingSnapshotBatch {
                snapshotBatchNeedsWidgetSave = true
            } else {
                saveWidgetLightSnapshots()
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
        sensorEntitiesByID.removeValue(forKey: entityID)
        entityBoxesByID.removeValue(forKey: entityID)
        pendingCommandsByID.removeValue(forKey: entityID)

        if removedEntity != nil {
            if isApplyingSnapshotBatch {
                if removedEntity?.domain == .light {
                    snapshotBatchNeedsWidgetSave = true
                }
            } else {
                refreshEntityIndexes(previousCatalogSignature: previousCatalogSignature)
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
        sensorEntity: SensorEntity?,
        pendingCommand: HAEntityPendingCommand?
    ) {
        if let entityBox = entityBoxesByID[entityID] {
            entityBox.update(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                sensorEntity: sensorEntity,
                pendingCommand: pendingCommand
            )
        } else {
            entityBoxesByID[entityID] = HAEntityState(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                sensorEntity: sensorEntity,
                pendingCommand: pendingCommand
            )
        }
    }

    private func saveWidgetLightSnapshots() {
        WidgetSharedStore.saveLightSnapshots(Array(lightEntitiesByID.values))
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

@MainActor
@Observable
final class HAEntityState: Identifiable {
    var homeEntity: HomeEntity
    var lightEntity: LightEntity?
    var climateEntity: ClimateEntity?
    var coverEntity: CoverEntity?
    var sensorEntity: SensorEntity?
    var pendingCommand: HAEntityPendingCommand?

    var id: String { homeEntity.entityID }
    var entityID: String { homeEntity.entityID }
    var domain: EntityDomain { homeEntity.domain }

    init(
        homeEntity: HomeEntity,
        lightEntity: LightEntity? = nil,
        climateEntity: ClimateEntity? = nil,
        coverEntity: CoverEntity? = nil,
        sensorEntity: SensorEntity? = nil,
        pendingCommand: HAEntityPendingCommand? = nil
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.sensorEntity = sensorEntity
        self.pendingCommand = pendingCommand
    }

    func update(
        homeEntity: HomeEntity,
        lightEntity: LightEntity?,
        climateEntity: ClimateEntity?,
        coverEntity: CoverEntity?,
        sensorEntity: SensorEntity?,
        pendingCommand: HAEntityPendingCommand?
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.sensorEntity = sensorEntity
        self.pendingCommand = pendingCommand
    }
}
