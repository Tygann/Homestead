import SwiftUI

struct CardIconView: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let icon: ResolvedIcon
    var isActive = false
    var isAvailable = true
    var accentColor = Color.accentColor
    var size: CGFloat = 44
    var symbolSize: CGFloat = 21
    var showsBackground = true

    init(
        icon: ResolvedIcon,
        isActive: Bool = false,
        isAvailable: Bool = true,
        accentColor: Color = .accentColor,
        size: CGFloat = 44,
        symbolSize: CGFloat = 21,
        showsBackground: Bool = true
    ) {
        self.icon = icon
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.accentColor = accentColor
        self.size = size
        self.symbolSize = symbolSize
        self.showsBackground = showsBackground
    }

    init(
        systemName: String,
        isActive: Bool = false,
        isAvailable: Bool = true,
        accentColor: Color = .accentColor,
        size: CGFloat = 44,
        symbolSize: CGFloat = 21,
        showsBackground: Bool = true
    ) {
        self.init(
            icon: .sfSymbol(systemName, provenance: .homesteadSemanticMapping),
            isActive: isActive,
            isAvailable: isAvailable,
            accentColor: accentColor,
            size: size,
            symbolSize: symbolSize,
            showsBackground: showsBackground
        )
    }

    var body: some View {
        HomesteadIconView(icon: icon, pointSize: symbolSize)
            .foregroundStyle(iconForeground)
            .frame(width: size, height: size)
            .background {
                if showsBackground {
                    iconBackground
                        .clipShape(RoundedRectangle(cornerRadius: iconRadius, style: .continuous))
                }
            }
            .accessibilityHidden(true)
    }

    private var iconForeground: Color {
        HomesteadSurfaceStyle.iconForeground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: isActive,
            isAvailable: isAvailable,
            accentColor: accentColor
        )
    }

    private var iconBackground: Color {
        HomesteadSurfaceStyle.iconBackground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: isActive,
            isAvailable: isAvailable,
            accentColor: accentColor
        )
    }

    private var iconRadius: CGFloat {
        min(AppRadius.icon, max(8, size * 0.32))
    }
}
