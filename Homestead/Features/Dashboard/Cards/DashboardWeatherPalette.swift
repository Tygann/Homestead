import SwiftUI

struct DashboardWeatherPalette {
    enum ConditionFamily: Equatable {
        case clear
        case cloudy
        case precipitation
        case storm
        case snow
        case wind
        case exceptional
        case neutral
    }

    let conditionFamily: ConditionFamily
    let solarPhase: WeatherSolarPhase?
    let colors: [Color]
}

enum DashboardWeatherPaletteResolver {
    static func resolve(
        condition: WeatherCondition,
        solarPhase: WeatherSolarPhase?
    ) -> DashboardWeatherPalette {
        let conditionFamily = conditionFamily(for: condition)
        let resolvedSolarPhase = resolvedSolarPhase(
            condition: condition,
            solarPhase: solarPhase
        )

        return DashboardWeatherPalette(
            conditionFamily: conditionFamily,
            solarPhase: resolvedSolarPhase,
            colors: colors(
                conditionFamily: conditionFamily,
                solarPhase: resolvedSolarPhase
            )
        )
    }

    // MARK: - Resolution

    private static func resolvedSolarPhase(
        condition: WeatherCondition,
        solarPhase: WeatherSolarPhase?
    ) -> WeatherSolarPhase? {
        if let solarPhase {
            return solarPhase
        }

        switch condition {
        case .clearNight:
            return .night
        case .sunny:
            return .day
        default:
            return nil
        }
    }

    private static func conditionFamily(for condition: WeatherCondition) -> DashboardWeatherPalette.ConditionFamily {
        switch condition {
        case .sunny, .clearNight, .partlyCloudy:
            return .clear
        case .cloudy, .fog:
            return .cloudy
        case .rainy, .pouring, .hail:
            return .precipitation
        case .lightning, .lightningRainy:
            return .storm
        case .snowy, .snowyRainy:
            return .snow
        case .windy, .windyVariant:
            return .wind
        case .exceptional:
            return .exceptional
        case .unavailable, .unknown, .other:
            return .neutral
        }
    }

    // MARK: - Palettes

    private static func colors(
        conditionFamily: DashboardWeatherPalette.ConditionFamily,
        solarPhase: WeatherSolarPhase?
    ) -> [Color] {
        switch solarPhase {
        case .day:
            return dayColors(for: conditionFamily)
        case .twilight:
            return twilightColors(for: conditionFamily)
        case .night:
            return nightColors(for: conditionFamily)
        case nil:
            return neutralPhaseColors(for: conditionFamily)
        }
    }

    private static func dayColors(
        for family: DashboardWeatherPalette.ConditionFamily
    ) -> [Color] {
        switch family {
        case .clear:
            return [Color(red: 0.25, green: 0.63, blue: 0.93), Color(red: 0.08, green: 0.35, blue: 0.68)]
        case .cloudy:
            return [Color(red: 0.43, green: 0.52, blue: 0.61), Color(red: 0.21, green: 0.29, blue: 0.37)]
        case .precipitation:
            return [Color(red: 0.30, green: 0.51, blue: 0.66), Color(red: 0.10, green: 0.22, blue: 0.32)]
        case .storm:
            return [Color(red: 0.34, green: 0.34, blue: 0.55), Color(red: 0.12, green: 0.12, blue: 0.25)]
        case .snow:
            return [Color(red: 0.56, green: 0.72, blue: 0.82), Color(red: 0.27, green: 0.43, blue: 0.55)]
        case .wind:
            return [Color(red: 0.34, green: 0.58, blue: 0.61), Color(red: 0.17, green: 0.34, blue: 0.38)]
        case .exceptional:
            return [Color(red: 0.69, green: 0.37, blue: 0.31), Color(red: 0.36, green: 0.16, blue: 0.18)]
        case .neutral:
            return [Color(red: 0.38, green: 0.41, blue: 0.45), Color(red: 0.19, green: 0.21, blue: 0.24)]
        }
    }

    private static func twilightColors(
        for family: DashboardWeatherPalette.ConditionFamily
    ) -> [Color] {
        switch family {
        case .clear:
            return [Color(red: 0.46, green: 0.36, blue: 0.68), Color(red: 0.20, green: 0.25, blue: 0.52)]
        case .cloudy:
            return [Color(red: 0.39, green: 0.39, blue: 0.55), Color(red: 0.19, green: 0.22, blue: 0.36)]
        case .precipitation:
            return [Color(red: 0.32, green: 0.42, blue: 0.60), Color(red: 0.13, green: 0.19, blue: 0.34)]
        case .storm:
            return [Color(red: 0.38, green: 0.29, blue: 0.55), Color(red: 0.14, green: 0.11, blue: 0.28)]
        case .snow:
            return [Color(red: 0.48, green: 0.59, blue: 0.74), Color(red: 0.23, green: 0.31, blue: 0.50)]
        case .wind:
            return [Color(red: 0.31, green: 0.47, blue: 0.55), Color(red: 0.15, green: 0.26, blue: 0.37)]
        case .exceptional:
            return [Color(red: 0.58, green: 0.31, blue: 0.38), Color(red: 0.29, green: 0.14, blue: 0.25)]
        case .neutral:
            return [Color(red: 0.35, green: 0.36, blue: 0.48), Color(red: 0.18, green: 0.19, blue: 0.30)]
        }
    }

    private static func nightColors(
        for family: DashboardWeatherPalette.ConditionFamily
    ) -> [Color] {
        switch family {
        case .clear:
            return [Color(red: 0.19, green: 0.29, blue: 0.55), Color(red: 0.05, green: 0.09, blue: 0.24)]
        case .cloudy:
            return [Color(red: 0.25, green: 0.31, blue: 0.43), Color(red: 0.10, green: 0.14, blue: 0.24)]
        case .precipitation:
            return [Color(red: 0.20, green: 0.34, blue: 0.50), Color(red: 0.07, green: 0.13, blue: 0.25)]
        case .storm:
            return [Color(red: 0.25, green: 0.22, blue: 0.43), Color(red: 0.07, green: 0.06, blue: 0.18)]
        case .snow:
            return [Color(red: 0.34, green: 0.46, blue: 0.62), Color(red: 0.13, green: 0.21, blue: 0.36)]
        case .wind:
            return [Color(red: 0.20, green: 0.37, blue: 0.44), Color(red: 0.08, green: 0.18, blue: 0.25)]
        case .exceptional:
            return [Color(red: 0.45, green: 0.23, blue: 0.28), Color(red: 0.20, green: 0.08, blue: 0.14)]
        case .neutral:
            return [Color(red: 0.25, green: 0.28, blue: 0.35), Color(red: 0.10, green: 0.12, blue: 0.19)]
        }
    }

    private static func neutralPhaseColors(
        for family: DashboardWeatherPalette.ConditionFamily
    ) -> [Color] {
        dayColors(for: family)
    }
}
