import Foundation
import Observation

@MainActor
@Observable
final class HAStateStore {
    private(set) var entitiesByID: [String: HomeEntity] = [:]
    private(set) var lightEntitiesByID: [String: LightEntity] = [:]
    private(set) var climateEntitiesByID: [String: ClimateEntity] = [:]
    private(set) var coverEntitiesByID: [String: CoverEntity] = [:]
    private(set) var sensorEntitiesByID: [String: SensorEntity] = [:]
    @ObservationIgnored private var rawEntitiesByID: [String: HAEntityDTO] = [:]

    var allEntities: [HomeEntity] {
        entitiesByID.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var entitiesByDomain: [(domain: EntityDomain, entities: [HomeEntity])] {
        Dictionary(grouping: allEntities, by: \.domain)
            .map { domain, entities in
                (domain: domain, entities: entities)
            }
            .sorted { lhs, rhs in
                if lhs.domain.dashboardPriority != rhs.domain.dashboardPriority {
                    return lhs.domain.dashboardPriority < rhs.domain.dashboardPriority
                }

                return lhs.domain.displayName.localizedCaseInsensitiveCompare(rhs.domain.displayName) == .orderedAscending
            }
    }

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
        guard event.eventType == "state_changed",
              let stateChanged = try? event.data.decoded(HAStateChangedEventDTO.self),
              let newState = stateChanged.newState else {
            return
        }

        rawEntitiesByID[newState.entityID] = newState
        apply(dto: newState)
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
    }

    private func apply(dto: HAEntityDTO) {
        entitiesByID[dto.entityID] = EntityMapper.homeEntity(from: dto)
        lightEntitiesByID[dto.entityID] = EntityMapper.lightEntity(from: dto)
        climateEntitiesByID[dto.entityID] = EntityMapper.climateEntity(from: dto)
        coverEntitiesByID[dto.entityID] = EntityMapper.coverEntity(from: dto)
        sensorEntitiesByID[dto.entityID] = EntityMapper.sensorEntity(from: dto)
    }
}
