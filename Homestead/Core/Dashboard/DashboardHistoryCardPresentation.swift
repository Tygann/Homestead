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
        case .wide, .large:
            true
        case .mini, .compact, .row, .square:
            false
        }
    }
}
