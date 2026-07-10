import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeAssistantAsyncImage<Content: View>: View {
    @State private var fallbackImage: Image?

    let id: String
    let requestProvider: () async -> URLRequest?
    let content: (Image?) -> Content

    init(
        id: String,
        request: @escaping () async -> URLRequest?,
        @ViewBuilder content: @escaping (Image?) -> Content
    ) {
        self.id = id
        requestProvider = request
        self.content = content
    }

    var body: some View {
        content(fallbackImage)
        .task(id: id) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        fallbackImage = nil

        guard let request = await requestProvider() else {
            return
        }

        guard !Task.isCancelled else {
            return
        }

        #if canImport(UIKit)
        guard let uiImage = await HomeAssistantImageCache.shared.image(for: request) else {
            return
        }

        guard !Task.isCancelled else {
            return
        }

        fallbackImage = Image(uiImage: uiImage)
        #endif
    }
}
