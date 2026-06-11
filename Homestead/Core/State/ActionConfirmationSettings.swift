import Foundation
import Observation

enum ActionConfirmationMode: String, CaseIterable, Identifiable, Sendable {
    case smart
    case all
    case off

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smart:
            "Smart Confirmations"
        case .all:
            "Confirm All Actions"
        case .off:
            "Off"
        }
    }

    var summary: String {
        switch self {
        case .smart:
            "Ask before sensitive actions only."
        case .all:
            "Ask before every dashboard action."
        case .off:
            "Run actions immediately."
        }
    }
}

struct ActionConfirmationSettingsSnapshot: Equatable, Sendable {
    var mode: ActionConfirmationMode
    var confirmsLockUnlocks: Bool
    var confirmsSecurityCoverOpens: Bool
    var confirmsScenes: Bool
    var confirmsScripts: Bool
    var confirmsOtherImpactfulActions: Bool
}

@MainActor
@Observable
final class ActionConfirmationSettings {
    var mode: ActionConfirmationMode {
        didSet { defaults.set(mode.rawValue, forKey: Keys.mode) }
    }

    var confirmsLockUnlocks: Bool {
        didSet { defaults.set(confirmsLockUnlocks, forKey: Keys.confirmsLockUnlocks) }
    }

    var confirmsSecurityCoverOpens: Bool {
        didSet { defaults.set(confirmsSecurityCoverOpens, forKey: Keys.confirmsSecurityCoverOpens) }
    }

    var confirmsScenes: Bool {
        didSet { defaults.set(confirmsScenes, forKey: Keys.confirmsScenes) }
    }

    var confirmsScripts: Bool {
        didSet { defaults.set(confirmsScripts, forKey: Keys.confirmsScripts) }
    }

    var confirmsOtherImpactfulActions: Bool {
        didSet { defaults.set(confirmsOtherImpactfulActions, forKey: Keys.confirmsOtherImpactfulActions) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    var snapshot: ActionConfirmationSettingsSnapshot {
        ActionConfirmationSettingsSnapshot(
            mode: mode,
            confirmsLockUnlocks: confirmsLockUnlocks,
            confirmsSecurityCoverOpens: confirmsSecurityCoverOpens,
            confirmsScenes: confirmsScenes,
            confirmsScripts: confirmsScripts,
            confirmsOtherImpactfulActions: confirmsOtherImpactfulActions
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: Keys.mode).flatMap(ActionConfirmationMode.init(rawValue:)) ?? .smart
        confirmsLockUnlocks = Self.boolValue(defaults, key: Keys.confirmsLockUnlocks, defaultValue: true)
        confirmsSecurityCoverOpens = Self.boolValue(defaults, key: Keys.confirmsSecurityCoverOpens, defaultValue: true)
        confirmsScenes = Self.boolValue(defaults, key: Keys.confirmsScenes, defaultValue: true)
        confirmsScripts = Self.boolValue(defaults, key: Keys.confirmsScripts, defaultValue: true)
        confirmsOtherImpactfulActions = Self.boolValue(defaults, key: Keys.confirmsOtherImpactfulActions, defaultValue: true)
    }

    private static func boolValue(_ defaults: UserDefaults, key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }

    private enum Keys {
        static let mode = "homestead.actionConfirmations.mode"
        static let confirmsLockUnlocks = "homestead.actionConfirmations.confirmsLockUnlocks"
        static let confirmsSecurityCoverOpens = "homestead.actionConfirmations.confirmsSecurityCoverOpens"
        static let confirmsScenes = "homestead.actionConfirmations.confirmsScenes"
        static let confirmsScripts = "homestead.actionConfirmations.confirmsScripts"
        static let confirmsOtherImpactfulActions = "homestead.actionConfirmations.confirmsOtherImpactfulActions"
    }
}
