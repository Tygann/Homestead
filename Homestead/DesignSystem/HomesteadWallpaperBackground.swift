import SwiftUI
import UIKit

private struct HomesteadWallpaperDashboardIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var homesteadWallpaperDashboardID: UUID? {
        get { self[HomesteadWallpaperDashboardIDKey.self] }
        set { self[HomesteadWallpaperDashboardIDKey.self] = newValue }
    }
}

struct HomesteadWallpaperBackground: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var wallpaperImage: UIImage?

    let dashboardID: UUID?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if wallpaperURL != nil, let wallpaperImage {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: wallpaperTaskID) {
            loadWallpaperImage()
        }
    }

    private var wallpaperTaskID: String {
        [
            appearanceSettings.wallpaperPresentationRevision(for: dashboardID).description,
            wallpaperURL?.path ?? "none"
        ].joined(separator: "|")
    }

    private var wallpaperURL: URL? {
        appearanceSettings.resolvedWallpaperURL(for: dashboardID)
    }

    private func loadWallpaperImage() {
        guard let url = wallpaperURL,
              let image = UIImage(contentsOfFile: url.path) else {
            wallpaperImage = nil
            return
        }

        wallpaperImage = image
    }
}

extension View {
    func homesteadWallpaperBackground(
        allowsWallpaper: Bool = true,
        dashboardID: UUID? = nil
    ) -> some View {
        modifier(
            HomesteadWallpaperBackgroundModifier(
                allowsWallpaper: allowsWallpaper,
                dashboardID: dashboardID
            )
        )
    }
}

private struct HomesteadWallpaperBackgroundModifier: ViewModifier {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(\.homesteadWallpaperDashboardID) private var inheritedDashboardID

    let allowsWallpaper: Bool
    let dashboardID: UUID?

    func body(content: Content) -> some View {
        let resolvedDashboardID = dashboardID ?? inheritedDashboardID
        let isWallpaperActive = allowsWallpaper
            && appearanceSettings.resolvedWallpaperURL(for: resolvedDashboardID) != nil

        ZStack {
            if isWallpaperActive {
                HomesteadWallpaperBackground(dashboardID: resolvedDashboardID)
            } else {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.homesteadWallpaperSurfaceActive, isWallpaperActive)
    }
}
