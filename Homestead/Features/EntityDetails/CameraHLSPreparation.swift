import Foundation

/// Starts HA's HLS producer after a grace period, without creating a second player.
@MainActor
final class CameraHLSPreparation {
    private let request: @MainActor () async throws -> URL
    private var delay: Task<Void, Never>?
    private var preparation: Task<URL, Error>?
    private var isCancelled = false
    private var waiters: [UUID: CheckedContinuation<URL, Error>] = [:]

    init(gracePeriod: Duration = .seconds(3), request: @escaping @MainActor () async throws -> URL) {
        self.request = request
        delay = Task { [weak self] in
            do { try await Task.sleep(for: gracePeriod) } catch { return }
            self?.begin()
        }
    }

    /// Wait for the grace period unless native failure has already requested immediate preparation.
    func scheduledValue() async throws -> URL {
        while preparation == nil, !isCancelled {
            try await Task.sleep(for: .milliseconds(25))
        }
        return try await value()
    }

    func startFallback() { begin() }

    func value() async throws -> URL {
        try Task.checkCancellation()
        begin()
        guard let preparation else { throw CancellationError() }
        let waiterID = UUID()
        let url: URL = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                guard !Task.isCancelled, !isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                waiters[waiterID] = continuation
                Task { [weak self] in
                    let result = await preparation.result
                    self?.waiters.removeValue(forKey: waiterID)?.resume(with: result)
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
        try Task.checkCancellation()
        guard !isCancelled else { throw CancellationError() }
        return url
    }

    func cancel() {
        isCancelled = true
        delay?.cancel()
        preparation?.cancel()
        let pending = Array(waiters.values)
        waiters.removeAll()
        for waiter in pending { waiter.resume(throwing: CancellationError()) }
    }

    private func begin() {
        guard !isCancelled, preparation == nil else { return }
        delay?.cancel()
        let request = request
        preparation = Task { try await request() }
    }
}
