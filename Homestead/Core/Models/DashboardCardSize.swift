import CoreGraphics
import Foundation

enum DashboardCardSize: String, CaseIterable, Codable, Equatable, Sendable {
    case compact
    case large

    var displayName: String {
        switch self {
        case .compact:
            "Regular"
        case .large:
            "Large"
        }
    }

    var systemImage: String {
        switch self {
        case .compact:
            "rectangle"
        case .large:
            "rectangle.grid.1x2"
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .compact:
            88
        case .large:
            184
        }
    }
}
