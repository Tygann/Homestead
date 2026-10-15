import Foundation

/// HA can publish its session ID before the provider has installed that session.
/// Hold trickle candidates until the answer confirms provider setup has completed.
@MainActor
final class CameraWebRTCCandidateQueue {
    // MARK: - Properties
    private var pending: [JSONValue] = []
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var generation = UUID()
    private var sessionID: String?
    private var answerApplied = false
    private let send: (String, JSONValue) async throws -> Void
    private let failed: () -> Void
    private let acknowledged: () -> Void

    // MARK: - Lifecycle
    init(send: @escaping (String, JSONValue) async throws -> Void,
         failed: @escaping () -> Void, acknowledged: @escaping () -> Void = {}) {
        self.send = send
        self.failed = failed
        self.acknowledged = acknowledged
    }

    // MARK: - Public API
    func setSession(_ sessionID: String?) {
        self.sessionID = sessionID
        flush()
    }

    func didApplyAnswer() {
        answerApplied = true
        flush()
    }

    func append(_ candidate: JSONValue) {
        pending.append(candidate)
        flush()
    }

    func stop() {
        generation = UUID()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        pending.removeAll()
        sessionID = nil
        answerApplied = false
    }

    // MARK: - Private Helpers
    private func flush() {
        guard answerApplied, let sessionID else { return }
        // Avoid a full socket round trip per host candidate before sending relay candidates.
        while tasks.count < 4, !pending.isEmpty {
            let candidate = pending.removeFirst()
            let taskID = UUID()
            let owner = generation
            let send = send
            tasks[taskID] = Task { [weak self] in
                guard self?.generation == owner, !Task.isCancelled else { return }
                do {
                    try await send(sessionID, candidate)
                    guard let self, self.generation == owner, !Task.isCancelled else { return }
                    self.tasks[taskID] = nil
                    self.acknowledged()
                    self.flush()
                } catch {
                    guard let self, self.generation == owner, !Task.isCancelled else { return }
                    self.stop()
                    self.failed()
                }
            }
        }
    }
}
