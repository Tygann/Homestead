import Foundation

nonisolated struct CameraSnapshot: Sendable, Equatable {
    let data: Data
    let capturedAt: Date

    func isFresh(now: Date = Date(), freshnessInterval: TimeInterval) -> Bool {
        now.timeIntervalSince(capturedAt) <= freshnessInterval
    }
}

actor CameraSnapshotStore {
    static let shared = CameraSnapshotStore()

    nonisolated static let freshnessInterval: TimeInterval = 45
    nonisolated static let maximumFallbackAge: TimeInterval = 30 * 60

    private var snapshotsByEntityID: [String: CameraSnapshot] = [:]

    func snapshot(for entityID: String, now: Date = Date()) -> CameraSnapshot? {
        guard let snapshot = snapshotsByEntityID[entityID] else {
            return nil
        }

        guard now.timeIntervalSince(snapshot.capturedAt) <= Self.maximumFallbackAge else {
            snapshotsByEntityID[entityID] = nil
            return nil
        }

        return snapshot
    }

    func store(_ data: Data, for entityID: String, now: Date = Date()) {
        snapshotsByEntityID[entityID] = CameraSnapshot(data: data, capturedAt: now)
    }

}

actor CameraSnapshotRequestGate {
    static let shared = CameraSnapshotRequestGate(maximumConcurrentRequests: 2)

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
