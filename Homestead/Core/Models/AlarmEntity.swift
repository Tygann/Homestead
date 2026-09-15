import Foundation

nonisolated struct AlarmEntity: Equatable, Sendable {
    let supportedFeatures: Int
    let codeFormat: String?
    let codeArmRequired: Bool

    // MARK: - Capabilities

    var actions: [AlarmServiceAction] {
        AlarmServiceAction.allCases.filter { $0.feature == 0 || supportedFeatures & $0.feature != 0 }
    }

    func requiresCode(for action: AlarmServiceAction) -> Bool {
        codeFormat != nil && (action == .disarm || codeArmRequired)
    }

    static func modeTitle(for state: String) -> String {
        if state == "disarmed" {
            return "Disarmed"
        }
        return AlarmServiceAction.allCases.first { $0.expectedState == state }?.title
            ?? state.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

nonisolated enum AlarmServiceAction: String, CaseIterable, Identifiable, Sendable {
    case disarm, armHome, armAway, armNight, armVacation, armCustomBypass

    var id: String { rawValue }
    var title: String {
        switch self {
        case .disarm: "Disarm"
        case .armHome: "Home"
        case .armAway: "Away"
        case .armNight: "Night"
        case .armVacation: "Vacation"
        case .armCustomBypass: "Custom Bypass"
        }
    }
    var systemImage: String {
        switch self {
        case .disarm: "shield.slash"
        case .armHome: "house.fill"
        case .armAway: "figure.walk"
        case .armNight: "moon.fill"
        case .armVacation: "airplane"
        case .armCustomBypass: "shield.lefthalf.filled"
        }
    }
    var service: String {
        switch self {
        case .disarm: "alarm_disarm"
        case .armHome: "alarm_arm_home"
        case .armAway: "alarm_arm_away"
        case .armNight: "alarm_arm_night"
        case .armVacation: "alarm_arm_vacation"
        case .armCustomBypass: "alarm_arm_custom_bypass"
        }
    }
    var expectedState: String {
        switch self {
        case .disarm: "disarmed"
        case .armHome: "armed_home"
        case .armAway: "armed_away"
        case .armNight: "armed_night"
        case .armVacation: "armed_vacation"
        case .armCustomBypass: "armed_custom_bypass"
        }
    }
    var feature: Int {
        switch self {
        case .disarm: 0
        case .armHome: 1
        case .armAway: 2
        case .armNight: 4
        case .armVacation: 32
        case .armCustomBypass: 16
        }
    }

    func title(isSelected: Bool) -> String {
        self == .disarm && isSelected ? "Disarmed" : title
    }
}
