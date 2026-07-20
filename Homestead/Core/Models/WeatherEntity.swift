import Foundation

struct WeatherEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let condition: WeatherCondition
    let temperature: Double?
    let temperatureUnit: String?
    let humidity: Double?
    let windSpeed: Double?
    let windSpeedUnit: String?
    let windBearing: Double?
    let supportedFeatures: Int
    let forecastCount: Int?
    let attribution: String?
    let lastUpdated: Date?

    var id: String { entityID }

    var isAvailable: Bool {
        condition.isAvailable
    }

    var iconName: String {
        condition.systemImage
    }

    var displaySubtitle: String {
        isAvailable ? condition.displayName : "Weather unavailable"
    }

    var primaryReadingText: String {
        guard isAvailable else {
            return condition.displayName
        }

        return temperatureText ?? condition.displayName
    }

    var temperatureText: String? {
        guard isAvailable, let temperature else { return nil }
        return temperatureText(for: temperature)
    }

    func temperatureText(for value: Double) -> String {
        formattedValue(value, unit: displayTemperatureUnit, maximumFractionDigits: 1)
    }

    var humidityText: String? {
        guard isAvailable, let humidity else { return nil }
        return formattedValue(humidity, unit: "%", maximumFractionDigits: 0)
    }

    var windText: String? {
        guard isAvailable, let windSpeed else { return nil }

        let speedText = formattedValue(windSpeed, unit: windSpeedUnit, maximumFractionDigits: 1)
        guard let windDirectionText else {
            return speedText
        }

        return "\(windDirectionText) \(speedText)"
    }

    var windDirectionText: String? {
        guard let windBearing else { return nil }

        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalizedBearing = windBearing.truncatingRemainder(dividingBy: 360)
        let positiveBearing = normalizedBearing < 0 ? normalizedBearing + 360 : normalizedBearing
        let index = Int(((positiveBearing + 22.5) / 45.0).rounded(.down)) % directions.count
        return directions[index]
    }

    var hasForecast: Bool {
        !supportedForecastTypes.isEmpty || (forecastCount ?? 0) > 0
    }

    var supportedForecastTypes: [WeatherForecastType] {
        WeatherForecastType.allCases.filter { type in
            supportedFeatures & type.featureFlag != 0
        }
    }

    var defaultForecastType: WeatherForecastType? {
        supportedForecastTypes.first
    }

    var forecastAvailabilityText: String {
        guard let forecastCount, forecastCount > 0 else {
            return "No forecast in state"
        }

        return forecastCount == 1 ? "1 forecast item" : "\(forecastCount) forecast items"
    }

    var attributionText: String? {
        attribution?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue
    }

    private var displayTemperatureUnit: String? {
        switch temperatureUnit {
        case "F":
            "°F"
        case "C":
            "°C"
        default:
            temperatureUnit
        }
    }

    private func formattedValue(
        _ value: Double,
        unit: String?,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0

        let valueText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        guard let unit, !unit.isEmpty else {
            return valueText
        }

        let separator = unit.hasPrefix("°") || unit == "%" ? "" : " "
        return "\(valueText)\(separator)\(unit)"
    }
}

nonisolated enum WeatherForecastType: String, CaseIterable, Codable, Hashable, Sendable {
    case daily
    case twiceDaily = "twice_daily"
    case hourly

    var featureFlag: Int {
        switch self {
        case .daily: 1
        case .hourly: 2
        case .twiceDaily: 4
        }
    }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .twiceDaily: "Day & Night"
        case .hourly: "Hourly"
        }
    }

    var itemLimit: Int {
        switch self {
        case .daily: 7
        case .twiceDaily: 8
        case .hourly: 12
        }
    }
}

nonisolated struct WeatherForecastSnapshot: Equatable, Sendable {
    let type: WeatherForecastType
    let entries: [WeatherForecastEntry]
    let receivedAt: Date
}

nonisolated struct WeatherForecastEntry: Identifiable, Equatable, Sendable {
    let datetime: Date
    let condition: WeatherCondition
    let temperature: Double?
    let lowTemperature: Double?
    let precipitation: Double?
    let precipitationProbability: Double?
    let humidity: Double?
    let isDaytime: Bool?
    let windSpeed: Double?
    let windBearing: Double?

    var id: Date { datetime }
}

nonisolated enum WeatherCondition: Equatable, Sendable {
    case clearNight
    case cloudy
    case exceptional
    case fog
    case hail
    case lightning
    case lightningRainy
    case partlyCloudy
    case pouring
    case rainy
    case snowy
    case snowyRainy
    case sunny
    case windy
    case windyVariant
    case unavailable
    case unknown
    case other(String)

    init(state: String) {
        switch state.lowercased() {
        case "clear-night":
            self = .clearNight
        case "cloudy":
            self = .cloudy
        case "exceptional":
            self = .exceptional
        case "fog":
            self = .fog
        case "hail":
            self = .hail
        case "lightning":
            self = .lightning
        case "lightning-rainy":
            self = .lightningRainy
        case "partlycloudy":
            self = .partlyCloudy
        case "pouring":
            self = .pouring
        case "rainy":
            self = .rainy
        case "snowy":
            self = .snowy
        case "snowy-rainy":
            self = .snowyRainy
        case "sunny":
            self = .sunny
        case "windy":
            self = .windy
        case "windy-variant":
            self = .windyVariant
        case "unavailable":
            self = .unavailable
        case "unknown":
            self = .unknown
        default:
            self = .other(state)
        }
    }

    var isAvailable: Bool {
        switch self {
        case .unavailable, .unknown:
            false
        case .clearNight, .cloudy, .exceptional, .fog, .hail, .lightning, .lightningRainy, .partlyCloudy, .pouring, .rainy, .snowy, .snowyRainy, .sunny, .windy, .windyVariant, .other:
            true
        }
    }

    var displayName: String {
        switch self {
        case .clearNight:
            "Clear Night"
        case .cloudy:
            "Cloudy"
        case .exceptional:
            "Exceptional"
        case .fog:
            "Fog"
        case .hail:
            "Hail"
        case .lightning:
            "Lightning"
        case .lightningRainy:
            "Storms"
        case .partlyCloudy:
            "Partly Cloudy"
        case .pouring:
            "Pouring"
        case .rainy:
            "Rainy"
        case .snowy:
            "Snowy"
        case .snowyRainy:
            "Snowy Rain"
        case .sunny:
            "Sunny"
        case .windy:
            "Windy"
        case .windyVariant:
            "Windy"
        case .unavailable:
            "Unavailable"
        case .unknown:
            "Unknown"
        case .other(let state):
            state.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    var systemImage: String {
        switch self {
        case .sunny:
            "sun.max.fill"
        case .clearNight:
            "moon.stars.fill"
        case .cloudy:
            "cloud.fill"
        case .partlyCloudy:
            "cloud.sun.fill"
        case .rainy:
            "cloud.rain.fill"
        case .pouring:
            "cloud.heavyrain.fill"
        case .snowy, .snowyRainy:
            "cloud.snow.fill"
        case .lightning, .lightningRainy:
            "cloud.bolt.rain.fill"
        case .windy, .windyVariant:
            "wind"
        case .fog:
            "cloud.fog.fill"
        case .hail:
            "cloud.hail.fill"
        case .exceptional:
            "exclamationmark.triangle.fill"
        case .unavailable, .unknown, .other:
            "cloud.sun.fill"
        }
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
