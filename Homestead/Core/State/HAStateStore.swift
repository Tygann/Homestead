import Foundation
import Observation

@MainActor
@Observable
final class HAStateStore {
    private(set) var entitiesByID: [String: HomeEntity] = [:]
    @ObservationIgnored private var rawEntitiesByID: [String: HAEntityDTO] = [:]

    var allEntities: [HomeEntity] {
        entitiesByID.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var lightEntityIDs: [String] {
        entityIDs(for: .light)
    }

    var sensorEntityIDs: [String] {
        entityIDs(for: .sensor)
    }

    func entity(for entityID: String) -> HomeEntity? {
        entitiesByID[entityID]
    }

    func lightEntity(for entityID: String) -> LightEntity? {
        guard let dto = rawEntitiesByID[entityID] else { return nil }
        return EntityMapper.lightEntity(from: dto)
    }

    func climateEntity(for entityID: String) -> ClimateEntity? {
        guard let dto = rawEntitiesByID[entityID] else { return nil }
        return EntityMapper.climateEntity(from: dto)
    }

    func coverEntity(for entityID: String) -> CoverEntity? {
        guard let dto = rawEntitiesByID[entityID] else { return nil }
        return EntityMapper.coverEntity(from: dto)
    }

    func sensorEntity(for entityID: String) -> SensorEntity? {
        guard let dto = rawEntitiesByID[entityID] else { return nil }
        return EntityMapper.sensorEntity(from: dto)
    }

    func applyInitialStates(_ entities: [HAEntityDTO]) {
        rawEntitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityID, $0) })
        entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityID, EntityMapper.homeEntity(from: $0)) })
    }

    func apply(event: HAEventDTO) {
        guard event.eventType == "state_changed",
              let stateChanged = try? event.data.decoded(HAStateChangedEventDTO.self),
              let newState = stateChanged.newState else {
            return
        }

        rawEntitiesByID[newState.entityID] = newState
        entitiesByID[newState.entityID] = EntityMapper.homeEntity(from: newState)
    }

    private func entityIDs(for domain: EntityDomain) -> [String] {
        entitiesByID.values
            .filter { $0.domain == domain }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map(\.entityID)
    }
}
