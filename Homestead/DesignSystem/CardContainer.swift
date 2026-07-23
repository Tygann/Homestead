import SwiftUI

struct CardContainer<Content: View>: View {
    var minHeight: CGFloat = 132
    var padding = AppSpacing.medium
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(padding)
            .homesteadCardSurface()
    }
}
