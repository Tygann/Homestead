import Foundation

nonisolated struct HAWeatherForecastEventDTO: Decodable, Equatable, Sendable {
    let type: WeatherForecastType
    let forecast: [HAWeatherForecastEntryDTO]?
}

nonisolated struct HAWeatherForecastEntryDTO: Decodable, Equatable, Sendable {
    let datetime: Date
    let condition: String?
    let temperature: Double?
    let lowTemperature: Double?
    let precipitation: Double?
    let precipitationProbability: Double?
    let humidity: Double?
    let isDaytime: Bool?
    let windSpeed: Double?
    let windBearing: Double?

    enum CodingKeys: String, CodingKey {
        case datetime
        case condition
        case temperature
        case lowTemperature = "templow"
        case precipitation
        case precipitationProbability = "precipitation_probability"
        case humidity
        case isDaytime = "is_daytime"
        case windSpeed = "wind_speed"
        case windBearing = "wind_bearing"
    }

    init(
        datetime: Date,
        condition: String? = nil,
        temperature: Double? = nil,
        lowTemperature: Double? = nil,
        precipitation: Double? = nil,
        precipitationProbability: Double? = nil,
        humidity: Double? = nil,
        isDaytime: Bool? = nil,
        windSpeed: Double? = nil,
        windBearing: Double? = nil
    ) {
        self.datetime = datetime
        self.condition = condition
        self.temperature = temperature
        self.lowTemperature = lowTemperature
        self.precipitation = precipitation
        self.precipitationProbability = precipitationProbability
        self.humidity = humidity
        self.isDaytime = isDaytime
        self.windSpeed = windSpeed
        self.windBearing = windBearing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let datetimeText = try container.decode(String.self, forKey: .datetime)
        guard let datetime = HADateParser.date(from: datetimeText) else {
            throw DecodingError.dataCorruptedError(
                forKey: .datetime,
                in: container,
                debugDescription: "Invalid Home Assistant forecast date."
            )
        }

        self.datetime = datetime
        condition = try container.decodeIfPresent(String.self, forKey: .condition)
        temperature = Self.decodeDouble(from: container, forKey: .temperature)
        lowTemperature = Self.decodeDouble(from: container, forKey: .lowTemperature)
        precipitation = Self.decodeDouble(from: container, forKey: .precipitation)
        precipitationProbability = Self.decodeDouble(from: container, forKey: .precipitationProbability)
        humidity = Self.decodeDouble(from: container, forKey: .humidity)
        isDaytime = try container.decodeIfPresent(Bool.self, forKey: .isDaytime)
        windSpeed = Self.decodeDouble(from: container, forKey: .windSpeed)
        windBearing = Self.decodeDouble(from: container, forKey: .windBearing)
    }

    private static func decodeDouble(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}
