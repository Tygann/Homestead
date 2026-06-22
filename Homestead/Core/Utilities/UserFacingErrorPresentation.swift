import Foundation

nonisolated enum UserFacingErrorPresentation {
    static func message(for error: Error) -> String {
        message(forRawMessage: error.localizedDescription)
    }

    static func message(forRawMessage rawMessage: String) -> String {
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Something went wrong. Try again in a moment."
        }

        let lowercased = trimmed.lowercased()

        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return "The request timed out. Try again in a moment."
        }

        if lowercased.contains("offline") ||
            lowercased.contains("network") ||
            lowercased.contains("internet") ||
            lowercased.contains("route") ||
            lowercased.contains("host") ||
            lowercased.contains("connect") {
            return "Check your connection, then try again."
        }

        if lowercased.contains("denied") ||
            lowercased.contains("restricted") ||
            lowercased.contains("not authorized") ||
            lowercased.contains("authorization") ||
            lowercased.contains("permission") {
            return "Check access in Settings, then try again."
        }

        if lowercased.contains("unauthorized") ||
            lowercased.contains("authentication") ||
            lowercased.contains("token") {
            return "Sign in again from Settings > Account."
        }

        return "Something went wrong. Try again in a moment."
    }
}
