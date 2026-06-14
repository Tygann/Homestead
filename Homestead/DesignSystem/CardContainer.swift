import SwiftUI

struct CardContainer<Content: View>: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

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
        HomesteadSurfaceStyle.cardBackground(isWallpaperActive: isWallpaperSurfaceActive)
    }

    private var cardBorder: Color {
        HomesteadSurfaceStyle.cardBorder(isWallpaperActive: isWallpaperSurfaceActive)
    }
}
