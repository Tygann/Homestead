import SwiftUI
import UIKit

struct SupervisorAppArtworkView: View {
    enum Kind: Equatable {
        case icon
        case logo
    }

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.colorScheme) private var colorScheme

    @State private var loadedImage: UIImage?
    @State private var artworkPalette: SupervisorArtworkPalette?

    let app: HASupervisorApp
    let kind: Kind
    let height: CGFloat

    var body: some View {
        authenticatedArtwork
        .accessibilityHidden(true)
    }

    private var authenticatedArtwork: some View {
        Group {
            if let loadedImage {
                loadedArtwork(
                    Image(uiImage: loadedImage),
                    palette: artworkPalette
                )
            } else {
                fallbackArtwork
            }
        }
        .frame(
            width: kind == .icon ? height : nil,
            height: height
        )
        .frame(maxWidth: kind == .logo ? .infinity : nil)
        .modifier(SupervisorArtworkClipModifier(kind: kind, cornerRadius: iconCornerRadius))
        .task(id: taskID) {
            await loadArtwork()
        }
    }

    @ViewBuilder
    private func loadedArtwork(
        _ image: Image,
        palette: SupervisorArtworkPalette?
    ) -> some View {
        switch kind {
        case .icon:
            GeometryReader { proxy in
                ZStack {
                    Color.clear

                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .shadow(color: iconContrastHalo, radius: 2)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay {
                    RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous)
                        .strokeBorder(iconBorderColor, lineWidth: 0.5)
                }
            }
        case .logo:
            GeometryReader { proxy in
                ZStack {
                    bannerBackdrop(palette)
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height + bannerTopExtension
                        )
                        .offset(y: -(bannerTopExtension / 2))

                    image
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: max(0, proxy.size.width - (AppSpacing.small * 2)),
                            height: max(0, proxy.size.height - (AppSpacing.medium * 2))
                        )
                        .mask(verticalBannerFeather)
                        .mask(horizontalBannerFeather)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    @MainActor
    private func loadArtwork() async {
        loadedImage = nil
        artworkPalette = nil

        guard let imagePath,
              let request = await homeAssistantService.homeAssistantImageRequest(
                settings: connectionSettings,
                pathOrURL: imagePath
              ),
              let image = await HomeAssistantImageCache.shared.image(for: request),
              !Task.isCancelled else {
            return
        }

        loadedImage = image
        artworkPalette = SupervisorArtworkPalette(image: image)
    }

    private func bannerBackdrop(_ palette: SupervisorArtworkPalette?) -> some View {
        LinearGradient(
            colors: palette?.colors ?? [
                Color(.secondarySystemBackground),
                Color(.tertiarySystemBackground)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var iconContrastHalo: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.2)
            : Color.black.opacity(0.14)
    }

    private var iconBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.1)
    }

    private var verticalBannerFeather: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var horizontalBannerFeather: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.06),
                .init(color: .black, location: 0.94),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
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

    private var iconCornerRadius: CGFloat {
        max(10, height * 0.22)
    }

    private var bannerTopExtension: CGFloat {
        180
    }
}

private struct SupervisorArtworkClipModifier: ViewModifier {
    let kind: SupervisorAppArtworkView.Kind
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if kind == .icon {
            content.clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
        }
    }
}

private struct SupervisorArtworkPalette {
    let colors: [Color]

    init?(image: UIImage) {
        let sampleSize = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: sampleSize)
        let sample = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
        }

        guard let cgImage = sample.cgImage else {
            return nil
        }

        let width = 12
        let height = 12
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sampledColors = pixels.withUnsafeBufferPointer { buffer in
            guard let bytes = buffer.baseAddress else {
                return (UIColor?.none, UIColor?.none)
            }

            let leadingColor = Self.averageColor(
                bytes: bytes,
                bytesPerPixel: bytesPerPixel,
                bytesPerRow: bytesPerRow,
                xRange: 0..<max(1, width / 3),
                yRange: 0..<height
            )
            let trailingColor = Self.averageColor(
                bytes: bytes,
                bytesPerPixel: bytesPerPixel,
                bytesPerRow: bytesPerRow,
                xRange: max(0, width - max(1, width / 3))..<width,
                yRange: 0..<height
            )
            return (leadingColor, trailingColor)
        }

        guard let leadingColor = sampledColors.0 ?? sampledColors.1,
              let trailingColor = sampledColors.1 ?? sampledColors.0 else {
            return nil
        }

        colors = [Color(uiColor: leadingColor), Color(uiColor: trailingColor)]
    }

    private static func averageColor(
        bytes: UnsafePointer<UInt8>,
        bytesPerPixel: Int,
        bytesPerRow: Int,
        xRange: Range<Int>,
        yRange: Range<Int>
    ) -> UIColor? {
        guard bytesPerPixel >= 4 else { return nil }

        var redTotal = 0.0
        var greenTotal = 0.0
        var blueTotal = 0.0
        var weightTotal = 0.0

        for y in yRange {
            for x in xRange {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let red = Double(bytes[offset])
                let green = Double(bytes[offset + 1])
                let blue = Double(bytes[offset + 2])
                let alpha = Double(bytes[offset + 3]) / 255

                guard alpha > 0.08 else { continue }
                redTotal += red * alpha
                greenTotal += green * alpha
                blueTotal += blue * alpha
                weightTotal += alpha
            }
        }

        guard weightTotal > 0 else { return nil }
        return UIColor(
            red: redTotal / weightTotal / 255,
            green: greenTotal / weightTotal / 255,
            blue: blueTotal / weightTotal / 255,
            alpha: 1
        )
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
