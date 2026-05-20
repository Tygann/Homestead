import Foundation

enum HAWebSocketError: LocalizedError, Sendable {
    case invalidURL
    case notConnected
    case unexpectedMessage(String)
    case authenticationFailed(String?)
    case requestFailed(String?)
    case missingResult

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter a valid Home Assistant URL."
        case .notConnected:
            "Home Assistant is not connected."
        case .unexpectedMessage(let message):
            "Unexpected WebSocket message: \(message)"
        case .authenticationFailed(let message):
            message ?? "Home Assistant authentication failed."
        case .requestFailed(let message):
            message ?? "Home Assistant request failed."
        case .missingResult:
            "Home Assistant did not include a result payload."
        }
    }
}
