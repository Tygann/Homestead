import SwiftUI
import UIKit

struct SupervisorAppArtworkView: View {
    enum Kind: Equatable {
        case icon
        case logo
    }

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    @State private var loadedLogo: UIImage?
    @State private var logoPalette: SupervisorArtworkPalette?

    let app: HASupervisorApp
    let kind: Kind
    let height: CGFloat

    @ViewBuilder
    var body: some View {
        switch kind {
        case .icon:
            SoftwareArtworkIconView(
                id: "\(app.slug)|icon",
                imagePath: app.iconPath ?? app.logoPath,
                size: height
            ) {
                fallbackIcon
            }
        case .logo:
            authenticatedLogoArtwork
                .accessibilityHidden(true)
        }
    }

    // MARK: - Logo

    private var authenticatedLogoArtwork: some View {
        ZStack {
            fallbackLogo

            if let loadedLogo {
                logoArtwork(
                    Image(uiImage: loadedLogo),
                    palette: logoPalette
                )
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .backgroundExtensionEffect()
        .task(id: logoTaskID) {
            await loadLogoArtwork()
        }
    }

    private func logoArtwork(
        _ image: Image,
        palette: SupervisorArtworkPalette?
    ) -> some View {
        GeometryReader { proxy in
            ZStack {
                ZStack {
                    Color(uiColor: palette?.backgroundColor ?? .secondarySystemBackground)

                    image
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: max(0, proxy.size.width - (AppSpacing.large * 2)),
                            height: max(0, proxy.size.height - (AppSpacing.large * 2))
                        )
                        .blur(radius: 34)
                        .opacity(0.58)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .compositingGroup()

                image
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: max(0, proxy.size.width - (AppSpacing.small * 2)),
                        height: max(0, proxy.size.height - (AppSpacing.medium * 2))
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @MainActor
    private func loadLogoArtwork() async {
        loadedLogo = nil
        logoPalette = nil

        guard let imagePath = app.logoPath ?? app.iconPath,
              let request = await homeAssistantService.homeAssistantImageRequest(
                settings: connectionSettings,
                pathOrURL: imagePath
              ),
              let image = await HomeAssistantImageCache.shared.image(for: request),
              !Task.isCancelled else {
            return
        }

        loadedLogo = image
        logoPalette = SupervisorArtworkPalette(image: image)
    }

    private var logoTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            app.logoPath ?? app.iconPath ?? "no-image",
            "logo"
        ].joined(separator: "|")
    }

    // MARK: - Fallbacks

    private var fallbackIcon: some View {
        Image(systemName: "puzzlepiece.extension")
            .font(.system(size: height * 0.48, weight: .semibold))
            .foregroundStyle(app.status.tint)
            .frame(width: height, height: height)
            .background(
                app.status.tint.opacity(0.12),
                in: RoundedRectangle(cornerRadius: max(10, height * 0.22), style: .continuous)
            )
    }

    private var fallbackLogo: some View {
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

struct SoftwareArtworkIconView<Fallback: View>: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.colorScheme) private var colorScheme

    @State private var loadedImage: UIImage?
    @State private var artworkPalette: SupervisorArtworkPalette?

    let id: String
    let imagePath: String?
    let size: CGFloat
    let fallback: Fallback

    init(
        id: String,
        imagePath: String?,
        size: CGFloat,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.id = id
        self.imagePath = imagePath
        self.size = size
        self.fallback = fallback()
    }

    var body: some View {
        Group {
            if let loadedImage {
                loadedArtwork(Image(uiImage: loadedImage))
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(iconShape)
        .overlay {
            iconShape
                .strokeBorder(iconBorderColor, lineWidth: 0.5)
        }
        .task(id: taskID) {
            await loadArtwork()
        }
        .accessibilityHidden(true)
    }

    private func loadedArtwork(_ image: Image) -> some View {
        ZStack {
            if let artworkPalette, artworkPalette.hasMeaningfulTransparency {
                LinearGradient(
                    colors: artworkPalette.iconBackdropColors(for: colorScheme),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.clear
            }

            image
                .resizable()
                .scaledToFit()
                .padding(artworkPalette?.hasMeaningfulTransparency == true ? size * 0.035 : 0)
                .shadow(color: iconContrastHalo, radius: 1.5)
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

    private var taskID: String {
        [
            id,
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            imagePath ?? "no-image"
        ].joined(separator: "|")
    }

    private var iconShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: max(10, size * 0.22), style: .continuous)
    }

    private var iconContrastHalo: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.12)
    }

    private var iconBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.1)
    }
}

private struct SupervisorArtworkPalette {
    let leadingColor: UIColor
    let trailingColor: UIColor
    let transparentPixelRatio: Double

    var hasMeaningfulTransparency: Bool {
        transparentPixelRatio > 0.08
    }

    var averageLuminance: CGFloat {
        (leadingColor.relativeLuminance + trailingColor.relativeLuminance) / 2
    }

    var backgroundColor: UIColor {
        leadingColor.mixed(with: trailingColor, amount: 0.5)
    }

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

        let transparentPixelCount = stride(from: 3, to: pixels.count, by: bytesPerPixel)
            .count { pixels[$0] < 230 }
        transparentPixelRatio = Double(transparentPixelCount) / Double(width * height)

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

        self.leadingColor = leadingColor
        self.trailingColor = trailingColor
    }

    func iconBackdropColors(for colorScheme: ColorScheme) -> [Color] {
        let foregroundIsDark = averageLuminance < 0.52
        let targetColor: UIColor
        let targetAmount: CGFloat

        switch (colorScheme, foregroundIsDark) {
        case (.dark, true):
            targetColor = .white
            targetAmount = 0.34
        case (.dark, false):
            targetColor = .black
            targetAmount = 0.5
        case (.light, true):
            targetColor = .white
            targetAmount = 0.7
        case (.light, false):
            targetColor = .black
            targetAmount = 0.28
        @unknown default:
            targetColor = foregroundIsDark ? .white : .black
            targetAmount = 0.4
        }

        return [leadingColor, trailingColor].map { color in
            Color(uiColor: color.mixed(with: targetColor, amount: targetAmount))
        }
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

private extension UIColor {
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var otherRed: CGFloat = 0
        var otherGreen: CGFloat = 0
        var otherBlue: CGFloat = 0
        var otherAlpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              other.getRed(
                &otherRed,
                green: &otherGreen,
                blue: &otherBlue,
                alpha: &otherAlpha
              ) else {
            return self
        }

        let clampedAmount = min(max(amount, 0), 1)
        return UIColor(
            red: red + ((otherRed - red) * clampedAmount),
            green: green + ((otherGreen - green) * clampedAmount),
            blue: blue + ((otherBlue - blue) * clampedAmount),
            alpha: alpha + ((otherAlpha - alpha) * clampedAmount)
        )
    }

    var relativeLuminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0.5
        }

        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * linearized(red)) +
            (0.7152 * linearized(green)) +
            (0.0722 * linearized(blue))
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
