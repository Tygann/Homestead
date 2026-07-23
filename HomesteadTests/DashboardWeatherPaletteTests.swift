import Testing
@testable import Homestead

@MainActor
struct DashboardWeatherPaletteTests {
    @Test func solarPhaseUsesHomeAssistantElevationThresholds() {
        #expect(EntityMapper.weatherSolarPhase(from: sunDTO(state: "above_horizon", elevation: 12)) == .day)
        #expect(EntityMapper.weatherSolarPhase(from: sunDTO(state: "below_horizon", elevation: -2)) == .twilight)
        #expect(EntityMapper.weatherSolarPhase(from: sunDTO(state: "below_horizon", elevation: -12)) == .night)
    }

    @Test func solarPhaseFallsBackToSunStateWithoutElevation() {
        #expect(EntityMapper.weatherSolarPhase(from: sunDTO(state: "above_horizon")) == .day)
        #expect(EntityMapper.weatherSolarPhase(from: sunDTO(state: "below_horizon")) == .night)
        #expect(EntityMapper.weatherSolarPhase(from: sunDTO(state: "unknown")) == nil)
    }

    @Test func stateStoreTracksSunUpdatesAndRemoval() {
        let store = HAStateStore()
        store.applyInitialStates([sunDTO(state: "above_horizon", elevation: 18)])
        #expect(store.weatherSolarPhase == .day)

        store.applyLiveStateUpdates([sunDTO(state: "below_horizon", elevation: -3)])
        #expect(store.weatherSolarPhase == .twilight)

        store.applyLiveStateUpdates([sunDTO(state: "below_horizon", elevation: -14)])
        #expect(store.weatherSolarPhase == .night)

        store.removeEntity("sun.sun")
        #expect(store.weatherSolarPhase == nil)
    }

    @Test func paletteCombinesConditionFamilyWithSolarPhase() {
        let daytimeRain = DashboardWeatherPaletteResolver.resolve(
            condition: .rainy,
            solarPhase: .day
        )
        let nighttimeRain = DashboardWeatherPaletteResolver.resolve(
            condition: .rainy,
            solarPhase: .night
        )

        #expect(daytimeRain.conditionFamily == .precipitation)
        #expect(daytimeRain.solarPhase == .day)
        #expect(nighttimeRain.conditionFamily == .precipitation)
        #expect(nighttimeRain.solarPhase == .night)
    }

    @Test func paletteUsesExplicitWeatherConditionAsSolarFallback() {
        #expect(
            DashboardWeatherPaletteResolver.resolve(
                condition: .clearNight,
                solarPhase: nil
            ).solarPhase == .night
        )
        #expect(
            DashboardWeatherPaletteResolver.resolve(
                condition: .sunny,
                solarPhase: nil
            ).solarPhase == .day
        )
        #expect(
            DashboardWeatherPaletteResolver.resolve(
                condition: .cloudy,
                solarPhase: nil
            ).solarPhase == nil
        )
    }

    private func sunDTO(state: String, elevation: Double? = nil) -> HAEntityDTO {
        var attributes: [String: JSONValue] = [:]
        if let elevation {
            attributes["elevation"] = .number(elevation)
        }

        return HAEntityDTO(
            entityID: "sun.sun",
            state: state,
            attributes: attributes
        )
    }
}
