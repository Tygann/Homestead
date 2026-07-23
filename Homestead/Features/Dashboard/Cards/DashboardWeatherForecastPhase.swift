nonisolated enum DashboardWeatherForecastPhase: Equatable, Sendable {
    case loading
    case content
    case unavailable

    static func resolve(
        supportedTypes: Set<WeatherForecastType>,
        availableTypes: Set<WeatherForecastType>,
        loadingTypes: Set<WeatherForecastType>,
        failedTypes: Set<WeatherForecastType>,
        expectsHydration: Bool
    ) -> DashboardWeatherForecastPhase {
        let resolvedTypes = availableTypes.union(failedTypes)
        let unresolvedTypes = supportedTypes.subtracting(resolvedTypes)

        if !unresolvedTypes.isEmpty,
           expectsHydration || !loadingTypes.isEmpty {
            return .loading
        }

        if !availableTypes.isEmpty {
            return .content
        }

        return .unavailable
    }
}
