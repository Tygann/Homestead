import Foundation
import Observation

@MainActor
@Observable
final class HAStateStore {
    @ObservationIgnored private(set) var entitiesByID: [String: HomeEntity] = [:]
    private(set) var allEntities: [HomeEntity] = []
    private(set) var entitiesByDomain: [(domain: EntityDomain, entities: [HomeEntity])] = []
    private(set) var entityIDGroupsByDomain: [EntityDomainGroup] = []
    private(set) var availableEntityIDs: Set<String> = []
    private(set) var entityCatalogSignature = ""
    private(set) var hasEntities = false
    @ObservationIgnored private(set) var lightEntitiesByID: [String: LightEntity] = [:]
    @ObservationIgnored private(set) var climateEntitiesByID: [String: ClimateEntity] = [:]
    @ObservationIgnored private(set) var coverEntitiesByID: [String: CoverEntity] = [:]
    @ObservationIgnored private(set) var sensorEntitiesByID: [String: SensorEntity] = [:]
    @ObservationIgnored private var rawEntitiesByID: [String: HAEntityDTO] = [:]
    @ObservationIgnored private var entityBoxesByID: [String: HAEntityState] = [:]

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

    func applyInitialStates(_ entities: [HAEntityDTO]) {
        rawEntitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityID, $0) })
        rebuildMappedEntities(from: entities)
    }

    func apply(event: HAEventDTO) {
        guard let newState = event.stateChangedNewState else {
            return
        }

        rawEntitiesByID[newState.entityID] = newState
        apply(dto: newState)
    }

    func applyLiveStateUpdates(_ updates: [HAEntityDTO]) {
        for update in updates {
            rawEntitiesByID[update.entityID] = update
            apply(dto: update)
        }
    }

    func applyOptimisticLightState(entityID: String, isOn: Bool) {
        guard var dto = rawEntitiesByID[entityID] else {
            return
        }

        dto = HAEntityDTO(
            entityID: dto.entityID,
            state: isOn ? "on" : "off",
            attributes: dto.attributes,
            lastChanged: Date(),
            lastUpdated: Date()
        )
        rawEntitiesByID[entityID] = dto
        apply(dto: dto)
    }

    func applyOptimisticLightBrightness(entityID: String, brightnessPercentage: Double) {
        guard var dto = rawEntitiesByID[entityID] else {
            return
        }

        let clampedPercentage = min(max(brightnessPercentage, 1), 100)
        let brightness = Int((clampedPercentage / 100) * 255)
        var attributes = dto.attributes
        attributes["brightness"] = .number(Double(max(1, brightness)))

        dto = HAEntityDTO(
            entityID: dto.entityID,
            state: "on",
            attributes: attributes,
            lastChanged: Date(),
            lastUpdated: Date()
        )
        rawEntitiesByID[entityID] = dto
        apply(dto: dto)
    }

    private func entityIDs(for domain: EntityDomain) -> [String] {
        entitiesByID.values
            .filter { $0.domain == domain }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map(\.entityID)
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
        entityBoxesByID = Dictionary(uniqueKeysWithValues: entities.map { dto in
            let homeEntity = EntityMapper.homeEntity(from: dto)
            return (
                dto.entityID,
                HAEntityState(
                    homeEntity: homeEntity,
                    lightEntity: EntityMapper.lightEntity(from: dto),
                    climateEntity: EntityMapper.climateEntity(from: dto),
                    coverEntity: EntityMapper.coverEntity(from: dto),
                    sensorEntity: EntityMapper.sensorEntity(from: dto)
                )
            )
        })
        refreshEntityIndexes()
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
            sensorEntity: sensorEntitiesByID[dto.entityID]
        )

        if previousEntity?.domain == homeEntity.domain,
           previousEntity?.displayName == homeEntity.displayName {
            updateCachedEntity(homeEntity)
        } else {
            refreshEntityIndexes(previousCatalogSignature: previousCatalogSignature)
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
        availableEntityIDs = Set(entitiesByID.keys)
        hasEntities = !availableEntityIDs.isEmpty

        let signature = availableEntityIDs.sorted().joined(separator: "|")
        if previousCatalogSignature == nil || signature != previousCatalogSignature {
            entityCatalogSignature = signature
        }
    }

    private func updateCachedEntity(_ entity: HomeEntity) {
        guard allEntities.contains(where: { $0.entityID == entity.entityID }) else {
            refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
            return
        }
    }

    private func updateEntityBox(
        entityID: String,
        homeEntity: HomeEntity,
        lightEntity: LightEntity?,
        climateEntity: ClimateEntity?,
        coverEntity: CoverEntity?,
        sensorEntity: SensorEntity?
    ) {
        if let entityBox = entityBoxesByID[entityID] {
            entityBox.update(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                sensorEntity: sensorEntity
            )
        } else {
            entityBoxesByID[entityID] = HAEntityState(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                sensorEntity: sensorEntity
            )
        }
    }
}

struct EntityDomainGroup: Equatable, Sendable {
    let domain: EntityDomain
    let entityIDs: [String]
}

@MainActor
@Observable
final class HAEntityState: Identifiable {
    var homeEntity: HomeEntity
    var lightEntity: LightEntity?
    var climateEntity: ClimateEntity?
    var coverEntity: CoverEntity?
    var sensorEntity: SensorEntity?

    var id: String { homeEntity.entityID }
    var entityID: String { homeEntity.entityID }
    var domain: EntityDomain { homeEntity.domain }

    init(
        homeEntity: HomeEntity,
        lightEntity: LightEntity? = nil,
        climateEntity: ClimateEntity? = nil,
        coverEntity: CoverEntity? = nil,
        sensorEntity: SensorEntity? = nil
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.sensorEntity = sensorEntity
    }

    func update(
        homeEntity: HomeEntity,
        lightEntity: LightEntity?,
        climateEntity: ClimateEntity?,
        coverEntity: CoverEntity?,
        sensorEntity: SensorEntity?
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.sensorEntity = sensorEntity
    }
}
