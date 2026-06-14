import SwiftUI

struct CardContainer<Content: View>: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    var isActive = false
    var accentColor = Color.accentColor
    var minHeight: CGFloat = 132
    var padding = AppSpacing.medium
    @ViewBuilder var content: Content

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)

        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(padding)
            .background(cardBackground, in: cardShape)
            .overlay {
                cardShape.strokeBorder(cardBorder, lineWidth: 0.5)
            }
    }

    private var cardBackground: some ShapeStyle {
        HomesteadSurfaceStyle.cardBackground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: isActive,
            accentColor: accentColor
        )
    }

    private var cardBorder: Color {
        HomesteadSurfaceStyle.cardBorder(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: isActive,
            accentColor: accentColor
        )
    }
}
