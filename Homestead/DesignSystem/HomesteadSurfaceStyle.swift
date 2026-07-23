import SwiftUI

private struct HomesteadWallpaperSurfaceActiveKey: EnvironmentKey {
    static let defaultValue = false
}

private struct HomesteadEntityDetailSurfaceContextKey: EnvironmentKey {
    static let defaultValue = EntityDetailSurfaceContext.standard
}

extension EnvironmentValues {
    var homesteadWallpaperSurfaceActive: Bool {
        get { self[HomesteadWallpaperSurfaceActiveKey.self] }
        set { self[HomesteadWallpaperSurfaceActiveKey.self] = newValue }
    }

    var homesteadEntityDetailSurfaceContext: EntityDetailSurfaceContext {
        get { self[HomesteadEntityDetailSurfaceContextKey.self] }
        set { self[HomesteadEntityDetailSurfaceContextKey.self] = newValue }
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
            return isWallpaperActive
                ? wallpaperControlBackground
                : Color(.tertiarySystemGroupedBackground)
        }

        if isActive {
            return accentColor.opacity(0.12)
        }

        return isWallpaperActive
            ? wallpaperControlBackground
            : Color(.tertiarySystemGroupedBackground)
    }

    static func controlBackground(isWallpaperActive: Bool, isActive: Bool) -> Color {
        if isWallpaperActive {
            return wallpaperControlBackground
        }

        if isActive {
            return Color.accentColor.opacity(0.12)
        }

        return Color(.tertiarySystemGroupedBackground)
    }

    private static var wallpaperControlBackground: Color {
        Color(.tertiaryLabel).opacity(0.50)
    }
}

extension View {
    func homesteadCardSurface(
        cornerRadius: CGFloat = AppRadius.card,
        enhancesWallpaperContrast: Bool = false
    ) -> some View {
        modifier(
            HomesteadCardSurfaceModifier(
                cornerRadius: cornerRadius,
                enhancesWallpaperContrast: enhancesWallpaperContrast
            )
        )
    }

    func homesteadListRowSurface() -> some View {
        listRowBackground(HomesteadListRowBackground())
    }
}

struct HomesteadListSectionHeader: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .foregroundStyle(isWallpaperSurfaceActive ? Color.primary : Color.secondary)
    }
}

private struct HomesteadCardSurfaceModifier: ViewModifier {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let cornerRadius: CGFloat
    let enhancesWallpaperContrast: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                HomesteadSurfaceBackground(
                    isWallpaperSurfaceActive: isWallpaperSurfaceActive,
                    enhancesWallpaperContrast: enhancesWallpaperContrast
                )
                .clipShape(shape)
            }
            .overlay {
                shape.strokeBorder(
                    HomesteadSurfaceStyle.cardBorder(
                        isWallpaperActive: isWallpaperSurfaceActive
                    ),
                    lineWidth: 0.5
                )
            }
    }
}

private struct HomesteadListRowBackground: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    var body: some View {
        HomesteadSurfaceBackground(
            isWallpaperSurfaceActive: isWallpaperSurfaceActive,
            enhancesWallpaperContrast: true
        )
    }
}

private struct HomesteadSurfaceBackground: View {
    let isWallpaperSurfaceActive: Bool
    let enhancesWallpaperContrast: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    HomesteadSurfaceStyle.cardBackground(
                        isWallpaperActive: isWallpaperSurfaceActive
                    )
                )

            if isWallpaperSurfaceActive, enhancesWallpaperContrast {
                Rectangle()
                    .fill(Color(.systemBackground).opacity(0.14))
            }
        }
    }
}
