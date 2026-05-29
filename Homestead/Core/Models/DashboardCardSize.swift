import CoreGraphics
import Foundation

nonisolated enum DashboardCardSize: String, CaseIterable, Codable, Equatable, Sendable {
    case mini
    case compact
    case row
    case square
    case wide
    case large

    var displayName: String {
        switch self {
        case .mini:
            "Mini 1x1"
        case .compact:
            "Compact 2x1"
        case .row:
            "Row 4x1"
        case .square:
            "Square 2x2"
        case .wide:
            "Wide 4x2"
        case .large:
            "Large 4x4"
        }
    }

    var systemImage: String {
        switch self {
        case .mini:
            "square"
        case .compact:
            "ellipsis.rectangle"
        case .row:
            "rectangle"
        case .square:
            "widget.small"
        case .wide:
            "widget.medium"
        case .large:
            "widget.large"
        }
    }

    var layoutMetadata: DashboardCardLayoutMetadata {
        DashboardCardLayoutMetadata(columnSpan: columnSpan, rowSpan: rowSpan)
    }

    var columnSpan: Int {
        switch self {
        case .mini:
            1
        case .compact:
            2
        case .row:
            4
        case .square:
            2
        case .wide:
            4
        case .large:
            4
        }
    }

    var rowSpan: Int {
        switch self {
        case .mini, .compact, .row:
            1
        case .square, .wide:
            2
        case .large:
            4
        }
    }

    static func renderedGridUnitHeight(cardPadding: CGFloat) -> CGFloat {
        gridUnitContentMinHeight + (cardPadding * 2)
    }

    func renderedHeight(rowSpacing: CGFloat, cardPadding: CGFloat) -> CGFloat {
        let gridUnitHeight = Self.renderedGridUnitHeight(cardPadding: cardPadding)
        return (gridUnitHeight * CGFloat(rowSpan)) + (rowSpacing * CGFloat(rowSpan - 1))
    }

    func contentMinHeight(rowSpacing: CGFloat, cardPadding: CGFloat) -> CGFloat {
        max(0, renderedHeight(rowSpacing: rowSpacing, cardPadding: cardPadding) - (cardPadding * 2))
    }

    private static let gridUnitContentMinHeight: CGFloat = 44
}

nonisolated struct DashboardCardLayoutMetadata: Codable, Equatable, Sendable {
    let columnSpan: Int
    let rowSpan: Int
}
