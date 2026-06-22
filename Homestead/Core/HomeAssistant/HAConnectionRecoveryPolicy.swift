import Foundation

enum HAConnectionRecoveryPolicy {
    static let defaultReconnectDelaySeconds = [1, 2, 5, 10, 30]

    static func reconnectDelaySeconds(
        forAttempt attempt: Int,
        delays: [Int] = defaultReconnectDelaySeconds
    ) -> Int {
        guard !delays.isEmpty else {
            return 0
        }

        return delays[min(max(attempt, 0), delays.count - 1)]
    }

    static func shouldTryFallbackRoute(after error: Error) -> Bool {
        guard let webSocketError = error as? HAWebSocketError else {
            return false
        }

        switch webSocketError {
        case .invalidURL, .notConnected, .requestTimedOut, .transportFailure:
            return true
        case .unexpectedMessage, .authenticationFailed, .requestFailed, .missingResult:
            return false
        }
    }

    static func shouldReconnectSocket(after error: Error) -> Bool {
        guard let webSocketError = error as? HAWebSocketError else {
            return false
        }

        switch webSocketError {
        case .notConnected, .requestTimedOut, .transportFailure:
            return true
        case .invalidURL, .unexpectedMessage, .authenticationFailed, .requestFailed, .missingResult:
            return false
        }
    }

    static func shouldRefreshAfterResume(
        lastSuspendedAt: Date?,
        now: Date = Date(),
        interval: TimeInterval
    ) -> Bool {
        guard let lastSuspendedAt else {
            return false
        }

        return now.timeIntervalSince(lastSuspendedAt) >= interval
    }
}
