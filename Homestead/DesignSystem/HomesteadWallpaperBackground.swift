import SwiftUI
import UIKit

struct HomesteadWallpaperBackground: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var wallpaperImage: UIImage?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if appearanceSettings.activeWallpaperURL != nil, let wallpaperImage {
                GeometryReader { proxy in
                    Image(uiImage: wallpaperImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()

                Color.black
                    .opacity(colorScheme == .dark ? 0.22 : 0.06)
                    .ignoresSafeArea()

                Color(.systemGroupedBackground)
                    .opacity(colorScheme == .dark ? 0.04 : 0.18)
                    .ignoresSafeArea()
            }
        }
        .task(id: wallpaperTaskID) {
            loadWallpaperImage()
        }
    }

    private var wallpaperTaskID: String {
        [
            appearanceSettings.isWallpaperEnabled.description,
            appearanceSettings.wallpaperRevision.description,
            appearanceSettings.activeWallpaperURL?.path ?? "none"
        ].joined(separator: "|")
    }

    private func loadWallpaperImage() {
        guard let url = appearanceSettings.activeWallpaperURL,
              let image = UIImage(contentsOfFile: url.path) else {
            wallpaperImage = nil
            return
        }

        wallpaperImage = image
    }
}

extension View {
    func homesteadWallpaperBackground() -> some View {
        modifier(HomesteadWallpaperBackgroundModifier())
    }
}

private struct HomesteadWallpaperBackgroundModifier: ViewModifier {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings

    func body(content: Content) -> some View {
        content
            .background {
                HomesteadWallpaperBackground()
            }
            .environment(\.homesteadWallpaperSurfaceActive, appearanceSettings.activeWallpaperURL != nil)
    }
}
