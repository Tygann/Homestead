import SwiftUI

// MARK: - Preview

struct DashboardCardEditorPreviewStage<Content: View>: View {
    let size: DashboardCardSize
    let accessibilityValue: String
    @ViewBuilder let content: Content

    init(
        size: DashboardCardSize,
        accessibilityValue: String,
        @ViewBuilder content: () -> Content
    ) {
        self.size = size
        self.accessibilityValue = accessibilityValue
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = DashboardCardEditorPreviewLayout(
                availableWidth: proxy.size.width,
                size: size
            )

            content
                .frame(
                    width: layout.unscaledCardSize.width,
                    height: layout.unscaledCardSize.height
                )
                .scaleEffect(layout.scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: DashboardCardEditorPreviewLayout.stageHeight(for: size))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card preview")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Updates as card settings change")
    }
}

nonisolated struct DashboardCardEditorPreviewLayout: Equatable, Sendable {
    static let columnCount = 4
    static let spacing: CGFloat = AppSpacing.medium
    static let cardPadding: CGFloat = AppSpacing.medium
    static let stagePadding: CGFloat = AppSpacing.medium
    static let maximumStageHeight: CGFloat = 280

    let availableWidth: CGFloat
    let size: DashboardCardSize

    var unscaledCardSize: CGSize {
        let usableWidth = max(availableWidth - (Self.stagePadding * 2), 0)
        let trackWidth = max(
            (usableWidth - (Self.spacing * CGFloat(Self.columnCount - 1)))
                / CGFloat(Self.columnCount),
            0
        )
        let width = (trackWidth * CGFloat(size.columnSpan))
            + (Self.spacing * CGFloat(size.columnSpan - 1))
        let height = size.renderedHeight(
            rowSpacing: Self.spacing,
            cardPadding: Self.cardPadding
        )
        return CGSize(width: width, height: height)
    }

    var scale: CGFloat {
        let cardSize = unscaledCardSize
        guard cardSize.width > 0, cardSize.height > 0 else { return 1 }

        let usableWidth = max(availableWidth - (Self.stagePadding * 2), 0)
        let usableHeight = max(Self.stageHeight(for: size) - (Self.verticalPadding(for: size) * 2), 0)
        return min(1, usableWidth / cardSize.width, usableHeight / cardSize.height)
    }

    static func stageHeight(for size: DashboardCardSize) -> CGFloat {
        min(
            size.renderedHeight(rowSpacing: spacing, cardPadding: cardPadding)
                + (verticalPadding(for: size) * 2),
            maximumStageHeight
        )
    }

    private static func verticalPadding(for size: DashboardCardSize) -> CGFloat {
        switch size {
        case .mini, .compact, .row:
            AppSpacing.xSmall
        case .square, .wide, .large:
            stagePadding
        }
    }
}
