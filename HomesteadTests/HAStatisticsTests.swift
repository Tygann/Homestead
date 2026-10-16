import Foundation
import Testing
@testable import Homestead

@MainActor
struct HAStatisticsTests {
    private let end = Date(timeIntervalSince1970: 1_800_000_000)

    private func sensor(stateClass: SensorStateClass = .measurement) -> SensorEntity {
        SensorEntity(entityID: "sensor.temperature", displayName: "Temperature", value: "22",
                     unit: "°C", deviceClass: "temperature", stateClass: stateClass, lastUpdated: nil)
    }

    private var request: HAHistoryRequest {
        HAHistoryRequest(startDate: end.addingTimeInterval(-30 * 86400), endDate: end,
                         entityID: "sensor.temperature")
    }

    @Test func historyBooleanUsesExplicitServerValues() throws {
        for significant in [false, true] {
            let request = HAHistoryRequest(startDate: end, endDate: end, entityID: "sensor.temperature",
                                           significantChangesOnly: significant)
            let url = try HomeAssistantEndpointBuilder.historyURL(from: "https://example.test", request: request)
            let fields = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            #expect(fields?.first(where: { $0.name == "significant_changes_only" })?.value == (significant ? "1" : "0"))
        }
    }

    @Test func statisticsRequestIsBoundedAndRequestsOnlyHourlyMean() {
        let fields = HAStatisticsRequest(entityID: request.entityID, startDate: request.startDate, endDate: end).fields
        #expect(fields["statistic_ids"] == .array([.string(request.entityID)]))
        #expect(fields["period"] == .string("hour"))
        #expect(fields["types"] == .array([.string("mean")]))
        #expect(fields["start_time"] == .string(request.startDate.ISO8601Format()))
        #expect(fields["end_time"] == .string(end.ISO8601Format()))
    }

    @Test func mergesMillisecondHourlyRowsWithRecentDetail() async throws {
        var rawStart: Date?
        let series = try await HAHistoryStatisticsProvider.load(
            request: request, sensor: sensor(), range: .month,
            fetchHistory: { requested in
                rawStart = requested.startDate
                return HAHistoryResponseDTO(series: [[HAHistoryStateDTO(
                    state: "22", lastChanged: requested.startDate)]])
            },
            fetchMetadata: { _ in [HAStatisticMetadataDTO(statisticID: "sensor.temperature", unit: "°C", meanType: 1, hasMean: nil)] },
            fetchStatistics: { requested in
                let start = requested.startDate.addingTimeInterval(3600)
                return [requested.entityID: [HAStatisticRowDTO(start: start.timeIntervalSince1970 * 1000,
                    end: start.addingTimeInterval(3600).timeIntervalSince1970 * 1000, mean: 18)]]
            }
        )
        #expect(rawStart! > request.startDate)
        #expect(series.samples.map(\.value) == [18, 22])
        #expect(series.samples.first?.occurredAt == request.startDate.addingTimeInterval(3600))
        #expect(series.hourlyAveragesBefore == rawStart)
        #expect(series.coverageNotice?.contains("hourly averages") == true)
    }

    @Test func rejectsDifferentUnitsAndPreservesFullRawRequest() async throws {
        var rawStart: Date?
        var queriedStatistics = false
        _ = try await HAHistoryStatisticsProvider.load(
            request: request, sensor: sensor(), range: .month,
            fetchHistory: { requested in rawStart = requested.startDate; return HAHistoryResponseDTO(series: []) },
            fetchMetadata: { _ in [HAStatisticMetadataDTO(statisticID: "sensor.temperature", unit: "°F", meanType: 1, hasMean: nil)] },
            fetchStatistics: { _ in queriedStatistics = true; return [:] }
        )
        #expect(rawStart == request.startDate)
        #expect(!queriedStatistics)
    }

    @Test func nonMeasurementAndShortRangesKeepRawHistory() async throws {
        for (stateClass, range) in [(SensorStateClass.totalIncreasing, HAHistoryRangePreset.month), (.measurement, .week)] {
            var queriedMetadata = false
            _ = try await HAHistoryStatisticsProvider.load(
                request: request, sensor: sensor(stateClass: stateClass), range: range,
                fetchHistory: { _ in HAHistoryResponseDTO(series: []) },
                fetchMetadata: { _ in queriedMetadata = true; return [] },
                fetchStatistics: { _ in [:] }
            )
            #expect(!queriedMetadata)
        }
    }

    @Test func missingOrFailedStatisticsFallBackToFullRawHistory() async throws {
        for fails in [false, true] {
            var rawStart: Date?
            let series = try await HAHistoryStatisticsProvider.load(
                request: request, sensor: sensor(), range: .month,
                fetchHistory: { requested in rawStart = requested.startDate; return HAHistoryResponseDTO(series: []) },
                fetchMetadata: { _ in [HAStatisticMetadataDTO(statisticID: "sensor.temperature", unit: "°C", meanType: 1, hasMean: nil)] },
                fetchStatistics: { _ in
                    if fails { throw HAWebSocketError.missingResult }
                    return [:]
                }
            )
            #expect(rawStart == request.startDate)
            #expect(series.hourlyAveragesBefore == nil)
        }
    }

    @Test func loneHourlyBucketDoesNotClaimHistoryThroughNow() async throws {
        let bucketStart = request.startDate.addingTimeInterval(3600)
        let bucketEnd = bucketStart.addingTimeInterval(3600)
        let series = try await HAHistoryStatisticsProvider.load(
            request: request, sensor: sensor(), range: .month,
            fetchHistory: { _ in HAHistoryResponseDTO(series: []) },
            fetchMetadata: { _ in [HAStatisticMetadataDTO(statisticID: "sensor.temperature", unit: "°C", meanType: 1, hasMean: nil)] },
            fetchStatistics: { requested in [requested.entityID: [HAStatisticRowDTO(
                start: bucketStart.timeIntervalSince1970 * 1000,
                end: bucketEnd.timeIntervalSince1970 * 1000, mean: 18)]] }
        )
        #expect(series.samples.first?.validUntil == bucketEnd)
        #expect(series.averageValue == 18)
        #expect(series.coverageNotice?.contains("History available until") == true)
        #expect(series.summaryText.hasPrefix("Latest"))
        #expect(series.chartSegments().first?.samples.last?.occurredAt == bucketEnd)
    }

    @Test func hourlyGapsDoNotContributeToAverageOrConnectOnChart() {
        let start = request.startDate
        let firstEnd = start.addingTimeInterval(3600)
        let secondStart = start.addingTimeInterval(10 * 86400)
        let secondEnd = secondStart.addingTimeInterval(3600)
        let series = HAHistoryChartSeries(
            entityID: request.entityID, displayName: "Temperature", unit: "°C", range: .month,
            samples: [HAHistorySample(occurredAt: start, value: 10, validUntil: firstEnd),
                      HAHistorySample(occurredAt: secondStart, value: 30, validUntil: secondEnd)],
            requestedInterval: DateInterval(start: request.startDate, end: end), hourlyAveragesBefore: secondEnd
        )
        #expect(series.averageValue == 20)
        #expect(series.coverageNotice?.contains("Some history in this period is unavailable") == true)
        let segments = series.chartSegments()
        #expect(segments.count == 2)
        #expect(segments[0].samples.last?.occurredAt == firstEnd)
        #expect(segments[1].samples.first?.occurredAt == secondStart)
    }
}
