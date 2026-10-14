import Foundation

/// Starts HA's HLS producer after a grace period, without creating a second player.
@MainActor
final class CameraHLSPreparation {
    private let request: @MainActor () async throws -> URL
    private var delay: Task<Void, Never>?
    private var preparation: Task<URL, Error>?
    private var isCancelled = false

    init(gracePeriod: Duration = .seconds(3), request: @escaping @MainActor () async throws -> URL) {
        self.request = request
        delay = Task { [weak self] in
            do { try await Task.sleep(for: gracePeriod) } catch { return }
            self?.begin()
        }
    }

    func value() async throws -> URL {
        try Task.checkCancellation()
        begin()
        guard let preparation else { throw CancellationError() }
        let url = try await withTaskCancellationHandler {
            try await preparation.value
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
    }

    private func begin() {
        guard !isCancelled, preparation == nil else { return }
        delay?.cancel()
        let request = request
        preparation = Task { try await request() }
    }
}
