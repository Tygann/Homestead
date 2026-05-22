import CoreGraphics
import Foundation

enum DashboardCardSize: String, CaseIterable, Codable, Equatable, Sendable {
    case compact
    case large
    case wide

    var displayName: String {
        switch self {
        case .compact:
            "Regular"
        case .large:
            "Large"
        case .wide:
            "Wide"
        }
    }

    var systemImage: String {
        switch self {
        case .compact:
            "rectangle"
        case .large:
            "rectangle.grid.1x2"
        case .wide:
            "rectangle.fill"
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .compact:
            44
        case .large, .wide:
            101
        }
    }

}
