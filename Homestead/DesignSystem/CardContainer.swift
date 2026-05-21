import SwiftUI

struct CardContainer<Content: View>: View {
    var isActive = false
    var minHeight: CGFloat = 132
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(AppSpacing.medium)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .shadow(color: .black.opacity(isActive ? 0.08 : 0.035), radius: isActive ? 8 : 4, y: isActive ? 4 : 2)
    }

    private var cardBackground: some ShapeStyle {
        isActive ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }
}
