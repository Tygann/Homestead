import Foundation

enum HADateParser {
    nonisolated static func date(from value: String?) -> Date? {
        guard let value else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        return fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }
}
