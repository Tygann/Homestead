import Foundation

struct MediaPlayerEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let volumeLevel: Double?
    let source: String?
    let sourceList: [String]
    let mediaTitle: String?
    let mediaArtist: String?

    var id: String { entityID }

    var isAvailable: Bool {
        !["unknown", "unavailable"].contains(state)
    }

    var isPlaying: Bool {
        state == "playing"
    }

    var volumePercentage: Int? {
        guard let volumeLevel else { return nil }
        return Int((min(max(volumeLevel, 0), 1) * 100).rounded())
    }

    var displayState: String {
        switch state {
        case "playing":
            "Playing"
        case "paused":
            "Paused"
        case "idle":
            "Idle"
        case "standby":
            "Standby"
        case "off":
            "Off"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var nowPlayingText: String? {
        switch (mediaTitle?.nonEmptyValue, mediaArtist?.nonEmptyValue) {
        case let (title?, artist?):
            "\(title) - \(artist)"
        case let (title?, nil):
            title
        case let (nil, artist?):
            artist
        case (nil, nil):
            nil
        }
    }

    var displaySubtitle: String {
        guard isAvailable else { return "Media player unavailable" }
        return nowPlayingText ?? source?.nonEmptyValue ?? displayState
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
