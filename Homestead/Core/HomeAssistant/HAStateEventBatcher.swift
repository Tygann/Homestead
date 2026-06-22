import Foundation

actor HAStateEventBatcher {
    private let flushInterval: Duration
    private var pendingUpdatesByID: [String: HAStateChangedEventDTO] = [:]
    private var flushTask: Task<Void, Never>?
    private var flushHandler: (@MainActor @Sendable ([HAStateChangedEventDTO]) -> Void)?

    init(flushInterval: Duration = .milliseconds(200)) {
        self.flushInterval = flushInterval
    }

    func setFlushHandler(_ handler: (@MainActor @Sendable ([HAStateChangedEventDTO]) -> Void)?) {
        flushHandler = handler
    }

    func enqueue(_ update: HAStateChangedEventDTO) {
        pendingUpdatesByID[update.entityID] = update
        scheduleFlushIfNeeded()
    }

    func discardPendingUpdates() {
        flushTask?.cancel()
        flushTask = nil
        pendingUpdatesByID.removeAll()
    }

    private func scheduleFlushIfNeeded() {
        guard flushTask == nil else {
            return
        }

        flushTask = Task {
            do {
                try await Task.sleep(for: flushInterval)
            } catch {
                return
            }

            await flush()
        }
    }

    private func flush() async {
        let updates = Array(pendingUpdatesByID.values)
        pendingUpdatesByID.removeAll()
        flushTask = nil

        guard !updates.isEmpty, let flushHandler else {
            return
        }

        await flushHandler(updates)
    }
}
