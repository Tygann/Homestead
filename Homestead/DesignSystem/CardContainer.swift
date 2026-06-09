import SwiftUI

struct CardContainer<Content: View>: View {
    var isActive = false
    var accentColor = Color.accentColor
    var minHeight: CGFloat = 132
    @ViewBuilder var content: Content

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)

        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(AppSpacing.medium)
            .background(cardBackground, in: cardShape)
            .overlay {
                cardShape.strokeBorder(cardBorder, lineWidth: 0.5)
            }
    }

    private var cardBackground: some ShapeStyle {
        isActive ? AnyShapeStyle(accentColor.opacity(0.18)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

    private var cardBorder: Color {
        isActive ? accentColor.opacity(0.18) : Color(.separator).opacity(0.16)
    }
}
