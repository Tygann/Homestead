import Foundation

struct CoverEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let position: Int?
    let deviceClass: String?
    let iconName: String

    var id: String { entityID }

    var isOpen: Bool {
        state == "open" || state == "opening"
    }

    var isClosed: Bool {
        state == "closed" || state == "closing"
    }

    var isMoving: Bool {
        state == "opening" || state == "closing"
    }

    var displayState: String {
        switch state {
        case "open":
            "Open"
        case "closed":
            "Closed"
        case "opening":
            "Opening"
        case "closing":
            "Closing"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var positionPercentage: Int? {
        position.map { min(max($0, 0), 100) }
    }

    var displaySubtitle: String {
        if let positionPercentage, positionPercentage > 0 {
            "\(displayState) • \(positionPercentage)%"
        } else {
            displayState
        }
    }
}
