import Foundation

nonisolated struct DashboardHistoryCardPresentation: Equatable, Sendable {
    static let defaultRange: HAHistoryRangePreset = .sixHours

    let entityID: String
    let displayName: String
    let range: HAHistoryRangePreset
    let samples: [HAHistorySample]
    let valueDomain: ClosedRange<Double>
    let summaryText: String
    let latestValueText: String?
    let latestTimeText: String?

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
        range = series.range
        samples = series.samples
        valueDomain = series.valueDomain
        summaryText = series.summaryText
        latestValueText = series.latestSample.map { series.formatValue($0.value) }
        latestTimeText = series.latestSample?.occurredAt.formatted(date: .omitted, time: .shortened)
    }

    @MainActor
    static func preview(entityBox: HAEntityState) -> DashboardHistoryCardPresentation? {
        guard let sensor = entityBox.sensorEntity,
              let value = sensor.numericValue else {
            return nil
        }

        let endDate = Date(timeIntervalSince1970: 1_784_515_200)
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
