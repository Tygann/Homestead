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
    static func primaryForeground(isWallpaperActive: Bool, isAvailable: Bool = true) -> Color {
        guard isAvailable else {
            return .secondary
        }

        return .primary
    }

    static func secondaryForeground(isWallpaperActive: Bool, isAvailable: Bool = true) -> Color {
        guard isAvailable else {
            return .secondary
        }

        return .secondary
    }

    static func cardBackground(isWallpaperActive: Bool) -> AnyShapeStyle {
        if isWallpaperActive {
            return AnyShapeStyle(.thinMaterial)
        }

        return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

    static func cardBorder(isWallpaperActive: Bool) -> Color {
        if isWallpaperActive {
            return Color(.separator).opacity(0.18)
        }

        return Color(.separator).opacity(0.16)
    }

    static func chipBackground(isWallpaperActive: Bool) -> AnyShapeStyle {
        isWallpaperActive
            ? AnyShapeStyle(.thinMaterial)
            : AnyShapeStyle(Color(.secondarySystemGroupedBackground).opacity(0.72))
    }

    static func chipBorder(isWallpaperActive: Bool) -> Color {
        Color(.separator).opacity(isWallpaperActive ? 0.20 : 0.12)
    }

    static func iconForeground(
        isWallpaperActive: Bool,
        isActive: Bool,
        isAvailable: Bool,
        accentColor: Color
    ) -> Color {
        guard isAvailable else {
            return .secondary
        }

        return isActive ? accentColor : .primary
    }

    static func iconBackground(
        isWallpaperActive: Bool,
        isActive: Bool,
        isAvailable: Bool,
        accentColor: Color
    ) -> Color {
        guard isAvailable else {
            return Color(.tertiarySystemGroupedBackground).opacity(isWallpaperActive ? 0.70 : 1)
        }

        if isActive {
            return accentColor.opacity(isWallpaperActive ? 0.18 : 0.12)
        }

        return Color(.tertiarySystemGroupedBackground).opacity(isWallpaperActive ? 0.70 : 1)
    }

    static func controlBackground(isWallpaperActive: Bool, isActive: Bool) -> Color {
        if isWallpaperActive {
            return Color(.tertiarySystemGroupedBackground).opacity(0.72)
        }

        if isActive {
            return Color.accentColor.opacity(isWallpaperActive ? 0.14 : 0.12)
        }

        return Color(.tertiarySystemGroupedBackground).opacity(isWallpaperActive ? 0.72 : 1)
    }
}
