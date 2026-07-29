import SwiftUI

struct SupervisorAppArtworkView: View {
    enum Kind: Equatable {
        case icon
        case logo
    }

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.colorScheme) private var colorScheme

    let app: HASupervisorApp
    let kind: Kind
    let height: CGFloat

    var body: some View {
        Group {
            if kind == .logo {
                authenticatedArtwork
                    .backgroundExtensionEffect()
            } else {
                authenticatedArtwork
            }
        }
        .accessibilityHidden(true)
    }

    private var authenticatedArtwork: some View {
        HomeAssistantAsyncImage(
            id: taskID,
            request: {
                guard let imagePath else {
                    return nil
                }

                return await homeAssistantService.homeAssistantImageRequest(
                    settings: connectionSettings,
                    pathOrURL: imagePath
                )
            }
        ) { image in
            if let image {
                loadedArtwork(image)
            } else {
                fallbackArtwork
            }
        }
        .frame(
            width: kind == .icon ? height : nil,
            height: height
        )
        .frame(maxWidth: kind == .logo ? .infinity : nil)
        .clipShape(clipShape)
    }

    @ViewBuilder
    private func loadedArtwork(_ image: Image) -> some View {
        switch kind {
        case .icon:
            GeometryReader { proxy in
                ZStack {
                    Color(.secondarySystemBackground)

                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.08)
                        .blur(radius: height * 0.18, opaque: true)

                    image
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: max(0, proxy.size.width - (imagePadding * 2)),
                            height: max(0, proxy.size.height - (imagePadding * 2))
                        )

                    bannerContrastOverlay
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        case .logo:
            GeometryReader { proxy in
                ZStack {
                    Color(.secondarySystemBackground)

                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .saturation(1.1)
                        .scaleEffect(1.08)
                        .blur(radius: 44, opaque: true)

                    image
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: max(0, proxy.size.width - (AppSpacing.small * 2)),
                            height: max(0, proxy.size.height - (AppSpacing.medium * 2))
                        )
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.12),
                                    .init(color: .black, location: 0.88),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }

                    bannerContrastOverlay
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        }
    }

    private var bannerContrastOverlay: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.04)
            : Color.white.opacity(0.02)
    }

    private var imagePath: String? {
        switch kind {
        case .icon:
            app.iconPath ?? app.logoPath
        case .logo:
            app.logoPath ?? app.iconPath
        }
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            imagePath ?? "no-image",
            kind == .logo ? "logo" : "icon"
        ].joined(separator: "|")
    }

    private var imagePadding: CGFloat {
        kind == .icon ? height * 0.06 : height * 0.12
    }

    @ViewBuilder
    private var fallbackArtwork: some View {
        switch kind {
        case .icon:
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: height * 0.48, weight: .semibold))
                .foregroundStyle(app.status.tint)
                .frame(width: height, height: height)
                .background(
                    app.status.tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: max(10, height * 0.22), style: .continuous)
                )
        case .logo:
            ZStack {
                LinearGradient(
                    colors: [
                        app.status.tint.opacity(0.22),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: height * 0.32, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var clipShape: AnyShape {
        switch kind {
        case .icon:
            AnyShape(RoundedRectangle(cornerRadius: max(10, height * 0.22), style: .continuous))
        case .logo:
            AnyShape(Rectangle())
        }
    }
}

extension HASupervisorAppStatus {
    var tint: Color {
        switch self {
        case .running:
            .green
        case .stopped:
            .secondary
        case .unknown:
            .gray
        }
    }
}
