import SwiftUI

struct DashboardCardIconView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let presentation: DashboardCardIconPresentation
    let isActive: Bool
    let isAvailable: Bool
    let accentColor: Color
    var size: CGFloat = 44
    var symbolSize: CGFloat = 21
    var displaysProfilePicture = true
    var usesPreviewProfilePicture = false
    var fallbackIconColor: Color?

    // MARK: - Body

    var body: some View {
        switch presentation {
        case .icon(let icon):
            fallbackIcon(icon)

        case .personProfilePicture(let path, let fallbackIcon):
            if displaysProfilePicture {
                profilePicture(path: path, fallbackIcon: fallbackIcon)
            } else {
                self.fallbackIcon(fallbackIcon)
            }
        }
    }

    // MARK: - Presentation

    private func profilePicture(path: String, fallbackIcon: ResolvedIcon) -> some View {
        Group {
            if usesPreviewProfilePicture {
                styledProfilePicture {
                    previewProfilePicture
                }
            } else {
                HomeAssistantAsyncImage(
                    id: taskID(path: path),
                    request: {
                        await homeAssistantService.homeAssistantImageRequest(
                            settings: connectionSettings,
                            pathOrURL: path
                        )
                    }
                ) { image in
                    if let image {
                        styledProfilePicture {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    } else {
                        self.fallbackIcon(fallbackIcon)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var previewProfilePicture: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.9), Color.cyan.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "person.fill")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .offset(y: size * 0.08)
        }
    }

    private func styledProfilePicture<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .saturation(isAvailable ? 1 : 0.25)
            .opacity(isAvailable ? 1 : 0.62)
    }

    private func fallbackIcon(_ icon: ResolvedIcon) -> some View {
        Group {
            if let fallbackIconColor {
                HomesteadIconView(icon: icon, pointSize: symbolSize)
                    .foregroundStyle(fallbackIconColor)
                    .frame(width: size, height: size)
            } else {
                CardIconView(
                    icon: icon,
                    isActive: isActive,
                    isAvailable: isAvailable,
                    accentColor: accentColor,
                    size: size,
                    symbolSize: symbolSize
                )
            }
        }
    }

    // MARK: - Helpers

    private func taskID(path: String) -> String {
        [
            connectionSettings.activeProfileID.uuidString,
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            path
        ].joined(separator: "|")
    }
}
