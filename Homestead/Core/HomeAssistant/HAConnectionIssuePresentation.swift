import Foundation

nonisolated enum HAConnectionIssuePresentation {
    static func message(for error: Error) -> String {
        if let webSocketError = error as? HAWebSocketError {
            return message(for: webSocketError)
        }

        if let urlError = error as? URLError {
            return message(for: urlError)
        }

        return fallbackMessage(forRawMessage: error.localizedDescription)
    }

    static func fallbackMessage(forRawMessage rawMessage: String) -> String {
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Check your Home Assistant connection and try again."
        }

        let lowercased = trimmed.lowercased()
        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return "Home Assistant did not respond in time. Try again in a moment."
        }

        if lowercased.contains("offline") ||
            lowercased.contains("network") ||
            lowercased.contains("internet") ||
            lowercased.contains("route") ||
            lowercased.contains("host") ||
            lowercased.contains("connect") {
            return "Check your network or Home Assistant address, then try again."
        }

        if lowercased.contains("unauthorized") ||
            lowercased.contains("authentication") ||
            lowercased.contains("token") {
            return "Sign in again from Settings > Account."
        }

        return "Check your Home Assistant connection and try again."
    }

    private static func message(for error: HAWebSocketError) -> String {
        switch error {
        case .invalidURL:
            return "Check the Home Assistant address in Settings."
        case .notConnected:
            return "Reconnect to Home Assistant, then try again."
        case .requestTimedOut:
            return "Home Assistant did not respond in time. Try again in a moment."
        case .transportFailure:
            return "Check your network or Home Assistant address, then try again."
        case .authenticationFailed:
            return "Sign in again from Settings > Account."
        case .unexpectedMessage, .requestFailed, .missingResult:
            return "Home Assistant returned an unexpected response. Try again in a moment."
        }
    }

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "Check your network connection, then try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Check your Home Assistant address, then try again."
        case .timedOut:
            return "Home Assistant did not respond in time. Try again in a moment."
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            return "Check the Home Assistant certificate or address, then try again."
        default:
            return fallbackMessage(forRawMessage: error.localizedDescription)
        }
    }
}
