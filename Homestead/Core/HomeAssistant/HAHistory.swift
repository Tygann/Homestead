import Foundation

struct HAHistoryRequest: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let entityID: String
    let minimalResponse: Bool
    let noAttributes: Bool
    let significantChangesOnly: Bool

    init(
        startDate: Date,
        endDate: Date,
        entityID: String,
        minimalResponse: Bool = true,
        noAttributes: Bool = true,
        significantChangesOnly: Bool = false
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.entityID = entityID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.minimalResponse = minimalResponse
        self.noAttributes = noAttributes
        self.significantChangesOnly = significantChangesOnly
    }
}

struct HAHistoryResponseDTO: Decodable, Equatable, Sendable {
    let series: [[HAHistoryStateDTO]]

    init(series: [[HAHistoryStateDTO]]) {
        self.series = series
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        series = try container.decode([[HAHistoryStateDTO]].self)
    }
}

struct HAHistoryStateDTO: Decodable, Equatable, Sendable {
    let entityID: String?
    let state: String
    let lastChanged: Date
    let lastUpdated: Date?
    let attributes: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case attributes
    }

    init(
        entityID: String? = nil,
        state: String,
        lastChanged: Date,
        lastUpdated: Date? = nil,
        attributes: [String: JSONValue]? = nil
    ) {
        self.entityID = entityID
        self.state = state
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
        self.attributes = attributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lastChangedString = try container.decode(String.self, forKey: .lastChanged)
        guard let lastChanged = HADateParser.date(from: lastChangedString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .lastChanged,
                in: container,
                debugDescription: "Expected Home Assistant history last_changed timestamp."
            )
        }

        let lastUpdatedString = try container.decodeIfPresent(String.self, forKey: .lastUpdated)
        if let lastUpdatedString, let parsedLastUpdated = HADateParser.date(from: lastUpdatedString) {
            lastUpdated = parsedLastUpdated
        } else {
            lastUpdated = nil
        }

        entityID = try container.decodeIfPresent(String.self, forKey: .entityID)
        state = try container.decode(String.self, forKey: .state)
        self.lastChanged = lastChanged
        attributes = try container.decodeIfPresent([String: JSONValue].self, forKey: .attributes)
    }
}

enum HAHistoryRangePreset: String, CaseIterable, Identifiable, Equatable, Sendable {
    case oneHour
    case sixHours
    case day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneHour:
            "1H"
        case .sixHours:
            "6H"
        case .day:
            "24H"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .oneHour:
            "Last hour"
        case .sixHours:
            "Last 6 hours"
        case .day:
            "Last 24 hours"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .oneHour:
            60 * 60
        case .sixHours:
            6 * 60 * 60
        case .day:
            24 * 60 * 60
        }
    }

    func interval(endingAt endDate: Date = Date()) -> DateInterval {
        DateInterval(start: endDate.addingTimeInterval(-duration), end: endDate)
    }
}

struct HAHistorySample: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let value: Double

    init(occurredAt: Date, value: Double) {
        self.id = "\(occurredAt.timeIntervalSince1970)-\(value)"
        self.occurredAt = occurredAt
        self.value = value
    }
}

struct HAHistoryChartSeries: Equatable, Sendable {
    let entityID: String
    let displayName: String
    let unit: String?
    let range: HAHistoryRangePreset
    let samples: [HAHistorySample]

    var isEmpty: Bool {
        samples.isEmpty
    }

    var latestSample: HAHistorySample? {
        samples.last
    }

    var minimumValue: Double? {
        samples.map(\.value).min()
    }

    var maximumValue: Double? {
        samples.map(\.value).max()
    }

    var valueDomain: ClosedRange<Double> {
        guard let minimumValue, let maximumValue else {
            return 0...1
        }

        guard minimumValue != maximumValue else {
            let padding = max(abs(minimumValue) * 0.05, 1)
            return (minimumValue - padding)...(maximumValue + padding)
        }

        let padding = (maximumValue - minimumValue) * 0.12
        return (minimumValue - padding)...(maximumValue + padding)
    }

    var summaryText: String {
        guard !samples.isEmpty,
              let minimumValue,
              let maximumValue,
              let latestSample else {
            return "No recorded numeric history"
        }

        return "Now \(formatValue(latestSample.value)) • Low \(formatValue(minimumValue)) • High \(formatValue(maximumValue))"
    }

    func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        guard let unit, !unit.isEmpty else {
            return numberText
        }

        let separator = unit.hasPrefix("°") || unit == "%" ? "" : " "
        return "\(numberText)\(separator)\(unit)"
    }

    static func make(
        response: HAHistoryResponseDTO,
        request: HAHistoryRequest,
        displayName: String,
        unit: String?,
        range: HAHistoryRangePreset
    ) -> HAHistoryChartSeries {
        let interval = DateInterval(start: request.startDate, end: request.endDate)
        let samples = numericSamples(
            from: response.series.flatMap { $0 },
            fallbackEntityID: request.entityID,
            matching: request.entityID,
            interval: interval
        )

        return HAHistoryChartSeries(
            entityID: request.entityID,
            displayName: displayName,
            unit: unit,
            range: range,
            samples: samples
        )
    }

    static func numericSamples(
        from states: [HAHistoryStateDTO],
        fallbackEntityID: String,
        matching entityID: String,
        interval: DateInterval
    ) -> [HAHistorySample] {
        states.compactMap { state in
            let resolvedEntityID = state.entityID?.nonEmptyHistoryValue ?? fallbackEntityID
            guard resolvedEntityID == entityID,
                  interval.contains(state.lastChanged) || state.lastChanged == interval.end,
                  let value = Double(state.state),
                  value.isFinite else {
                return nil
            }

            return HAHistorySample(occurredAt: state.lastChanged, value: value)
        }
        .sorted { lhs, rhs in
            lhs.occurredAt < rhs.occurredAt
        }
    }

    private var maximumFractionDigits: Int {
        let values = samples.map(\.value)
        guard values.contains(where: { abs($0.rounded() - $0) > 0.001 }) else {
            return 0
        }

        return 2
    }
}

private extension String {
    var nonEmptyHistoryValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
