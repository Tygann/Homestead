import Foundation

nonisolated struct FanEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let percentage: Int?
    let percentageStep: Int?
    let presetMode: String?
    let presetModes: [String]

    var id: String { entityID }

    var isOn: Bool {
        state == "on"
    }

    var isAvailable: Bool {
        !["unknown", "unavailable"].contains(state)
    }

    var supportsPercentageControl: Bool {
        percentage != nil || percentageStep != nil
    }

    var resolvedPercentageStep: Double {
        let step = percentageStep ?? 1
        return Double(max(step, 1))
    }

    var displayState: String {
        switch state {
        case "on":
            "On"
        case "off":
            "Off"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var displaySubtitle: String {
        guard isAvailable else { return "Fan unavailable" }

        if let percentage, isOn {
            return "\(percentage)%"
        }

        if let presetMode, !presetMode.isEmpty, isOn {
            return displayName(forPresetMode: presetMode)
        }

        return displayState
    }

    func displayName(forPresetMode mode: String) -> String {
        mode.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
