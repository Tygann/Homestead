import SwiftUI

private struct HomesteadWallpaperSurfaceActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var homesteadWallpaperSurfaceActive: Bool {
        get { self[HomesteadWallpaperSurfaceActiveKey.self] }
        set { self[HomesteadWallpaperSurfaceActiveKey.self] = newValue }
    }
}

enum HomesteadSurfaceStyle {
    static func cardBackground(
        isWallpaperActive: Bool,
        isActive: Bool,
        accentColor: Color
    ) -> AnyShapeStyle {
        guard isWallpaperActive else {
            return AnyShapeStyle(isActive ? accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
        }

        if isActive {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.36),
                        Color.black.opacity(0.54)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color.black.opacity(0.72))
    }

    static func cardBorder(
        isWallpaperActive: Bool,
        isActive: Bool,
        accentColor: Color
    ) -> Color {
        guard isWallpaperActive else {
            return isActive ? accentColor.opacity(0.18) : Color(.separator).opacity(0.16)
        }

        return isActive ? accentColor.opacity(0.38) : Color.white.opacity(0.10)
    }

    static func chipBackground(isWallpaperActive: Bool) -> AnyShapeStyle {
        isWallpaperActive
            ? AnyShapeStyle(Color.black.opacity(0.58))
            : AnyShapeStyle(Color(.secondarySystemGroupedBackground).opacity(0.72))
    }

    static func chipBorder(isWallpaperActive: Bool) -> Color {
        isWallpaperActive ? Color.white.opacity(0.14) : Color(.separator).opacity(0.12)
    }

    static func iconBackground(
        isWallpaperActive: Bool,
        isActive: Bool,
        isAvailable: Bool,
        accentColor: Color
    ) -> Color {
        guard isAvailable else {
            return isWallpaperActive ? Color.white.opacity(0.08) : Color(.tertiarySystemGroupedBackground)
        }

        if isActive {
            return accentColor.opacity(isWallpaperActive ? 0.24 : 0.12)
        }

        return isWallpaperActive ? Color.white.opacity(0.10) : Color(.tertiarySystemGroupedBackground)
    }

    static func controlBackground(isWallpaperActive: Bool, isActive: Bool) -> Color {
        if isActive {
            return Color.accentColor.opacity(isWallpaperActive ? 0.24 : 0.12)
        }

        return isWallpaperActive ? Color.white.opacity(0.10) : Color(.tertiarySystemGroupedBackground)
    }
}
