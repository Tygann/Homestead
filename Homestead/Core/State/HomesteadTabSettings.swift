import Foundation
import Observation

enum HomesteadPrimaryTab: String, CaseIterable, Codable, Identifiable, Sendable {
    case home
    case areas

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:
            "Home"
        case .areas:
            "Areas"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .areas:
            "square.split.bottomrightquarter"
        }
    }
}

@MainActor
@Observable
final class HomesteadTabSettings {
    var primaryTab: HomesteadPrimaryTab {
        didSet { defaults.set(primaryTab.rawValue, forKey: Keys.primaryTab) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        primaryTab = defaults.string(forKey: Keys.primaryTab).flatMap(HomesteadPrimaryTab.init(rawValue:)) ?? .home
    }

    private enum Keys {
        static let primaryTab = "homestead.tabs.primaryTab"
    }
}
