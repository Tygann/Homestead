import Testing
@testable import Homestead

struct DashboardWeatherForecastPhaseTests {
    @Test func supportedForecastStartsInLoadingBeforeSubscriptionFlagsArrive() {
        let phase = DashboardWeatherForecastPhase.resolve(
            supportedTypes: [.hourly, .daily],
            availableTypes: [],
            loadingTypes: [],
            failedTypes: [],
            expectsHydration: true
        )

        #expect(phase == .loading)
    }

    @Test func partialInitialForecastStaysLoadingUntilEveryTypeResolves() {
        let phase = DashboardWeatherForecastPhase.resolve(
            supportedTypes: [.hourly, .daily],
            availableTypes: [.hourly],
            loadingTypes: [.daily],
            failedTypes: [],
            expectsHydration: true
        )

        #expect(phase == .loading)
    }

    @Test func availableForecastRemainsVisibleAfterRefreshBegins() {
        let phase = DashboardWeatherForecastPhase.resolve(
            supportedTypes: [.hourly, .daily],
            availableTypes: [.hourly, .daily],
            loadingTypes: [.hourly, .daily],
            failedTypes: [],
            expectsHydration: true
        )

        #expect(phase == .content)
    }

    @Test func availableForecastDisplaysWhenAnotherTypeFails() {
        let phase = DashboardWeatherForecastPhase.resolve(
            supportedTypes: [.hourly, .daily],
            availableTypes: [.hourly],
            loadingTypes: [],
            failedTypes: [.daily],
            expectsHydration: true
        )

        #expect(phase == .content)
    }

    @Test func disconnectedEmptyForecastShowsUnavailableState() {
        let phase = DashboardWeatherForecastPhase.resolve(
            supportedTypes: [.hourly],
            availableTypes: [],
            loadingTypes: [],
            failedTypes: [],
            expectsHydration: false
        )

        #expect(phase == .unavailable)
    }
}
