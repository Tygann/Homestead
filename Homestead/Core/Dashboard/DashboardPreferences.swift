import CoreGraphics
import Foundation
import Observation

@Observable
final class DashboardPreferences {
    var density: DashboardDensity {
        didSet {
            defaults.set(density.rawValue, forKey: Self.densityKey)
        }
    }

    var showsOnlyActiveDevices: Bool {
        didSet {
            defaults.set(showsOnlyActiveDevices, forKey: Self.showsOnlyActiveDevicesKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedDensity = defaults.string(forKey: Self.densityKey)
        density = savedDensity.flatMap(DashboardDensity.init(rawValue:)) ?? .balanced
        showsOnlyActiveDevices = defaults.object(forKey: Self.showsOnlyActiveDevicesKey) as? Bool ?? false
    }

    private static let densityKey = "dashboard.density"
    private static let showsOnlyActiveDevicesKey = "dashboard.showsOnlyActiveDevices"
}

enum DashboardDensity: String, CaseIterable, Identifiable, Sendable {
    case comfortable
    case balanced
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comfortable:
            "Comfortable"
        case .balanced:
            "Balanced"
        case .compact:
            "Compact"
        }
    }

    var subtitle: String {
        switch self {
        case .comfortable:
            "Spacious cards for everyday control."
        case .balanced:
            "A clean mix of control and information."
        case .compact:
            "More controls in less space."
        }
    }

    var visibleEntityLimit: Int {
        switch self {
        case .comfortable:
            6
        case .balanced:
            10
        case .compact:
            16
        }
    }

    func effectiveCardSize(for configuredSize: DashboardCardSize) -> DashboardCardSize {
        switch self {
        case .comfortable:
            switch configuredSize {
            case .compact:
                .square
            default:
                configuredSize
            }
        case .balanced:
            configuredSize
        case .compact:
            switch configuredSize {
            case .mini:
                .mini
            case .row, .wide:
                .square
            default:
                .compact
            }
        }
    }
}
