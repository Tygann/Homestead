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
//            "rectangle"
//            "rectangle.grid.1x2"
//            "rectangle.ratio.16.to.9"
//            "rectangle.tophalf.inset.filled"
            "ellipsis.rectangle"
        case .large:
//            "rectangle.grid.1x2"
            "widget.small"
        case .wide:
//            "rectangle.fill"
            "widget.medium"
        }
    }

    var columnSpan: Int {
        switch self {
        case .compact, .large:
            1
        case .wide:
            2
        }
    }

    var rowSpan: Int {
        switch self {
        case .compact:
            1
        case .large, .wide:
            2
        }
    }

    func renderedHeight(rowSpacing: CGFloat, cardPadding: CGFloat) -> CGFloat {
        let regularRenderedHeight = Self.regularContentMinHeight + (cardPadding * 2)
        return (regularRenderedHeight * CGFloat(rowSpan)) + (rowSpacing * CGFloat(rowSpan - 1))
    }

    func contentMinHeight(rowSpacing: CGFloat, cardPadding: CGFloat) -> CGFloat {
        max(0, renderedHeight(rowSpacing: rowSpacing, cardPadding: cardPadding) - (cardPadding * 2))
    }

    private static let regularContentMinHeight: CGFloat = 44
}
