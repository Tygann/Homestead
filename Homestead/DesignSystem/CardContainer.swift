import SwiftUI

struct CardContainer<Content: View>: View {
    var isActive = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .shadow(color: .black.opacity(isActive ? 0.14 : 0.06), radius: isActive ? 18 : 10, y: isActive ? 10 : 5)
            .animation(.smooth(duration: 0.25), value: isActive)
    }

    private var cardBackground: some ShapeStyle {
        isActive ? AnyShapeStyle(Color.accentColor.opacity(0.22)) : AnyShapeStyle(.regularMaterial)
    }
}
