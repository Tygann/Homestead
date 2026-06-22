import Foundation

actor DashboardHistoryCache {
    struct Key: Hashable, Sendable {
        let dataSourceID: String
        let entityID: String
        let range: HAHistoryRangePreset
        let endDateMinuteBucket: Int
    }

    private struct CachedSeries: Sendable {
        let series: HAHistoryChartSeries
        let savedAt: Date
    }

    private struct InFlightLoad: Sendable {
        let id: Int
        let task: Task<HAHistoryChartSeries, Error>
    }

    private let freshnessInterval: TimeInterval
    private let requestGate: DashboardHistoryRequestGate
    private var cachedSeriesByKey: [Key: CachedSeries] = [:]
    private var inFlightLoadsByKey: [Key: InFlightLoad] = [:]
    private var cacheGeneration = 0
    private var nextLoadID = 0

    init(
        freshnessInterval: TimeInterval = 2 * 60,
        maximumConcurrentRequests: Int = 3
    ) {
        self.freshnessInterval = freshnessInterval
        requestGate = DashboardHistoryRequestGate(maximumConcurrentRequests: maximumConcurrentRequests)
    }

    func series(
        for key: Key,
        now: Date = Date(),
        load: @Sendable @escaping () async throws -> HAHistoryChartSeries
    ) async throws -> HAHistoryChartSeries {
        if let cachedSeries = cachedSeriesByKey[key],
           now.timeIntervalSince(cachedSeries.savedAt) <= freshnessInterval {
            return cachedSeries.series
        }

        if let inFlightLoad = inFlightLoadsByKey[key] {
            return try await inFlightLoad.task.value
        }

        let requestGate = requestGate
        let loadID = nextLoadID
        let loadGeneration = cacheGeneration
        nextLoadID += 1
        let task = Task<HAHistoryChartSeries, Error> {
            try await requestGate.perform(load)
        }
        inFlightLoadsByKey[key] = InFlightLoad(
            id: loadID,
            task: task
        )

        do {
            let series = try await task.value
            if cacheGeneration == loadGeneration {
                cachedSeriesByKey[key] = CachedSeries(series: series, savedAt: Date())
            }
            removeInFlightLoad(for: key, id: loadID)
            return series
        } catch {
            removeInFlightLoad(for: key, id: loadID)
            throw error
        }
    }

    func removeAll() {
        cacheGeneration += 1
        inFlightLoadsByKey.values.forEach { $0.task.cancel() }
        cachedSeriesByKey.removeAll()
        inFlightLoadsByKey.removeAll()
    }

    private func removeInFlightLoad(for key: Key, id: Int) {
        guard inFlightLoadsByKey[key]?.id == id else { return }
        inFlightLoadsByKey[key] = nil
    }
}

private actor DashboardHistoryRequestGate {
    private let maximumConcurrentRequests: Int
    private var activeRequestCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maximumConcurrentRequests: Int) {
        self.maximumConcurrentRequests = max(1, maximumConcurrentRequests)
    }

    func perform<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquire() async {
        guard activeRequestCount >= maximumConcurrentRequests else {
            activeRequestCount += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            activeRequestCount -= 1
            return
        }

        waiters.removeFirst().resume()
    }
}
