import Foundation

nonisolated struct HAStatisticMetadataDTO: Decodable, Equatable, Sendable {
    let statisticID: String
    let unit: String?
    let meanType: Int?
    let hasMean: Bool?

    enum CodingKeys: String, CodingKey {
        case statisticID = "statistic_id"
        case unit = "statistics_unit_of_measurement"
        case meanType = "mean_type"
        case hasMean = "has_mean"
    }

    var supportsArithmeticMean: Bool {
        meanType.map { $0 == 1 } ?? (hasMean == true)
    }
}

nonisolated struct HAStatisticRowDTO: Decodable, Equatable, Sendable {
    /// Recorder's WebSocket API returns milliseconds, unlike its Python API.
    let start: Double
    let end: Double
    let mean: Double?
}

nonisolated struct HAStatisticsRequest: Equatable, Sendable {
    let entityID: String
    let startDate: Date
    let endDate: Date

    var fields: [String: JSONValue] {
        [
            "start_time": .string(startDate.ISO8601Format()),
            "end_time": .string(endDate.ISO8601Format()),
            "statistic_ids": .array([.string(entityID)]),
            "period": .string("hour"),
            "types": .array([.string("mean")])
        ]
    }
}

/// Combines hourly measurement statistics with recent detail without changing
/// the discrete-state timeline contract or assuming the server's retention.
@MainActor
enum HAHistoryStatisticsProvider {
    static func load(
        request: HAHistoryRequest,
        sensor: SensorEntity?,
        range: HAHistoryRangePreset,
        fetchHistory: (HAHistoryRequest) async throws -> HAHistoryResponseDTO,
        fetchMetadata: (String) async throws -> [HAStatisticMetadataDTO],
        fetchStatistics: (HAStatisticsRequest) async throws -> [String: [HAStatisticRowDTO]]
    ) async throws -> HAHistoryChartSeries {
        func rawSeries(_ response: HAHistoryResponseDTO) -> HAHistoryChartSeries {
            HAHistoryChartSeries.make(
                response: response, request: request,
                displayName: sensor?.displayName ?? request.entityID,
                unit: sensor?.unitText, range: range
            )
        }

        guard range == .month, sensor?.stateClass == .measurement else {
            return rawSeries(try await fetchHistory(request))
        }

        do {
            let metadata = try await fetchMetadata(request.entityID)
            // Never join normalized statistics to live values in another unit.
            guard let metadata = metadata.first(where: { $0.statisticID == request.entityID }),
                  metadata.supportsArithmeticMean,
                  metadata.unit == sensor?.unit else {
                return rawSeries(try await fetchHistory(request))
            }

            let recentStart = Date(timeIntervalSince1970:
                floor(request.endDate.addingTimeInterval(-7 * 24 * 60 * 60).timeIntervalSince1970 / 3600) * 3600)
            guard recentStart > request.startDate else {
                return rawSeries(try await fetchHistory(request))
            }
            let statisticsRequest = HAStatisticsRequest(
                entityID: request.entityID, startDate: request.startDate, endDate: recentStart
            )
            let statistics = try await fetchStatistics(statisticsRequest)
            let olderSamples = (statistics[request.entityID] ?? []).compactMap { row -> HAHistorySample? in
                let start = Date(timeIntervalSince1970: row.start / 1000)
                let end = Date(timeIntervalSince1970: row.end / 1000)
                guard row.start.isFinite, row.end.isFinite,
                      start >= request.startDate, end <= recentStart, end > start,
                      let mean = row.mean, mean.isFinite else { return nil }
                return HAHistorySample(occurredAt: start, value: mean, validUntil: end)
            }.sorted { $0.occurredAt < $1.occurredAt }
            guard !olderSamples.isEmpty else {
                return rawSeries(try await fetchHistory(request))
            }

            let recentRequest = HAHistoryRequest(
                startDate: recentStart, endDate: request.endDate, entityID: request.entityID,
                minimalResponse: request.minimalResponse, noAttributes: request.noAttributes,
                significantChangesOnly: request.significantChangesOnly
            )
            let recent = try await fetchHistory(recentRequest)
            let recentSamples = HAHistoryChartSeries.numericSamples(
                from: recent.series.flatMap { $0 }, fallbackEntityID: request.entityID,
                matching: request.entityID, interval: DateInterval(start: recentStart, end: request.endDate)
            )
            return HAHistoryChartSeries(
                entityID: request.entityID, displayName: sensor?.displayName ?? request.entityID,
                unit: sensor?.unitText, displayPrecision: sensor?.displayPrecision,
                range: range, samples: olderSamples + recentSamples,
                requestedInterval: DateInterval(start: request.startDate, end: request.endDate),
                hourlyAveragesBefore: recentStart
            )
        } catch {
            try Task.checkCancellation()
            // Older HA versions and unrecorded sensors keep the existing path.
            return rawSeries(try await fetchHistory(request))
        }
    }
}
