import Foundation

nonisolated struct DashboardHistoryCardPresentation: Equatable, Sendable {
    static let defaultRange: HAHistoryRangePreset = .sixHours

    let entityID: String
    let displayName: String
    let unit: String?
    let range: HAHistoryRangePreset
    let samples: [HAHistorySample]
    let valueDomain: ClosedRange<Double>
    let summaryText: String
    let rangeSummaryText: String
    let changeSummaryText: String?
    let latestValueText: String?
    let latestTimeText: String?
    private let requestedInterval: DateInterval?

    var isEmpty: Bool {
        samples.isEmpty
    }

    var accessibilityLabel: String {
        "\(displayName) dashboard history"
    }

    var accessibilityValue: String {
        isEmpty ? "No numeric history for \(range.accessibilityTitle.lowercased())." : summaryText
    }

    init(series: HAHistoryChartSeries) {
        entityID = series.entityID
        displayName = series.displayName
        unit = series.unit
        range = series.range
        samples = series.samples
        valueDomain = Self.dashboardValueDomain(for: series)
        summaryText = series.summaryText
        rangeSummaryText = Self.rangeSummaryText(for: series)
        changeSummaryText = Self.changeSummaryText(for: series)
        latestValueText = series.latestSample.map { series.formatValue($0.value) }
        latestTimeText = series.latestSample?.occurredAt.formatted(date: .omitted, time: .shortened)
        requestedInterval = series.requestedInterval
    }

    func includingCurrentSample(value: Double?, occurredAt: Date?) -> DashboardHistoryCardPresentation {
        guard let value,
              value.isFinite,
              let occurredAt,
              samples.last.map({ occurredAt > $0.occurredAt }) ?? true else {
            return self
        }

        return DashboardHistoryCardPresentation(series: HAHistoryChartSeries(
            entityID: entityID,
            displayName: displayName,
            unit: unit,
            range: range,
            samples: samples + [HAHistorySample(occurredAt: occurredAt, value: value)],
            requestedInterval: requestedInterval
        ))
    }

    func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = samples.contains(where: { abs($0.value.rounded() - $0.value) > 0.001 }) ? 2 : 0
        formatter.minimumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        guard let unit, !unit.isEmpty else { return numberText }

        let separator = unit.hasPrefix("°") || unit == "%" ? "" : " "
        return "\(numberText)\(separator)\(unit)"
    }

    private static func dashboardValueDomain(for series: HAHistoryChartSeries) -> ClosedRange<Double> {
        guard let minimum = series.minimumValue,
              let maximum = series.maximumValue else {
            return 0...1
        }

        let midpoint = (minimum + maximum) / 2
        let observedSpan = maximum - minimum
        let minimumSpan: Double

        switch series.unit {
        case "°F", "F": minimumSpan = 4
        case "°C", "C": minimumSpan = 2
        case "%": minimumSpan = 10
        default: minimumSpan = max(abs(midpoint) * 0.04, 1)
        }

        let displaySpan = max(observedSpan * 1.24, minimumSpan)
        return (midpoint - (displaySpan / 2))...(midpoint + (displaySpan / 2))
    }

    private static func rangeSummaryText(for series: HAHistoryChartSeries) -> String {
        guard let minimum = series.minimumValue,
              let maximum = series.maximumValue else {
            return "No recent range"
        }

        return "L \(compactValue(minimum, series: series)) · H \(compactValue(maximum, series: series))"
    }

    private static func changeSummaryText(for series: HAHistoryChartSeries) -> String? {
        guard let first = series.samples.first,
              let latest = series.samples.last else {
            return nil
        }

        let change = latest.value - first.value
        let displayTolerance = series.unit?.hasPrefix("°") == true ? 0.05 : 0.005
        let tolerance = max(abs(first.value) * 0.0001, displayTolerance)
        guard abs(change) > tolerance else { return "Steady" }

        return "\(change > 0 ? "Up" : "Down") \(compactValue(abs(change), series: series))"
    }

    private static func compactValue(_ value: Double, series: HAHistoryChartSeries) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        if series.unit?.hasPrefix("°") == true {
            formatter.maximumFractionDigits = 1
        } else if series.unit == "%" {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
        }
        let numberText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"

        guard let unit = series.unit, !unit.isEmpty else { return numberText }
        if unit.hasPrefix("°") { return "\(numberText)°" }

        let separator = unit == "%" ? "" : " "
        return "\(numberText)\(separator)\(unit)"
    }

    @MainActor
    static func preview(entityBox: HAEntityState) -> DashboardHistoryCardPresentation? {
        guard let sensor = entityBox.sensorEntity,
              let value = sensor.numericValue else {
            return nil
        }

        // Keep Debug gallery history aligned with the fixture's live sample so the
        // current-value extension cannot compress the whole trend into the leading edge.
        let endDate = sensor.lastUpdated ?? Date(timeIntervalSince1970: 1_784_515_200)
        let interval = defaultRange.interval(endingAt: endDate)
        let offsets = [-0.08, -0.03, 0.04, -0.01, 0.07, 0.02, 0.09, 0.0]
        let scale = max(abs(value) * 0.08, 1)
        let samples = offsets.enumerated().map { index, offset in
            HAHistorySample(
                occurredAt: interval.start.addingTimeInterval(
                    interval.duration * Double(index) / Double(offsets.count - 1)
                ),
                value: value + (offset * scale)
            )
        }

        return DashboardHistoryCardPresentation(series: HAHistoryChartSeries(
            entityID: entityBox.entityID,
            displayName: sensor.displayName,
            unit: sensor.unitText,
            range: defaultRange,
            samples: samples,
            requestedInterval: interval
        ))
    }

    @MainActor
    static func isEligible(entityBox: HAEntityState, size: DashboardCardSize) -> Bool {
        guard size.supportsDashboardHistoryChart,
              entityBox.domain == .sensor,
              entityBox.sensorEntity?.numericValue != nil else {
            return false
        }

        return entityBox.homeEntity.isAvailable
    }

    @MainActor
    static func request(
        for entityBox: HAEntityState,
        size: DashboardCardSize,
        range: HAHistoryRangePreset = defaultRange,
        endingAt endDate: Date = Date()
    ) -> HAHistoryRequest? {
        guard isEligible(entityBox: entityBox, size: size) else {
            return nil
        }

        let interval = range.interval(endingAt: endDate)
        return HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: entityBox.entityID
        )
    }
}

nonisolated extension DashboardCardSize {
    var supportsDashboardHistoryChart: Bool {
        switch self {
        case .square, .wide, .large:
            true
        case .mini, .compact, .row:
            false
        }
    }
}

nonisolated enum DashboardHistoryInterpolationStyle: Equatable, Sendable {
    case smooth
    case linear
}

extension SensorEntity {
    var dashboardHistoryInterpolationStyle: DashboardHistoryInterpolationStyle {
        if stateClass == .total || stateClass == .totalIncreasing {
            return .linear
        }

        return switch displayKind {
        case .battery, .data, .date, .duration, .enum, .energy, .energyDistance,
             .energyStorage, .gas, .monetary, .powerFactor, .precipitation,
             .reactiveEnergy, .signal, .uptime, .water, .generic:
            .linear
        case .airQuality, .area, .carbonDioxide, .carbonMonoxide, .conductivity,
             .distance, .frequency, .humidity, .illuminance, .irradiance, .moisture,
             .pH, .particulateMatter, .power, .pressure, .problem, .reactivePower,
             .soundPressure, .speed, .temperature, .temperatureDelta, .current,
             .voltage, .volatileOrganicCompounds, .volume, .volumeFlowRate, .weight,
             .windDirection:
            .smooth
        }
    }
}
