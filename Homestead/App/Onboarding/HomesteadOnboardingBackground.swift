import SwiftUI

/// A shared wallpaper backdrop that keeps onboarding visually connected to Homestead dashboards.
struct HomesteadOnboardingBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.005, green: 0.015, blue: 0.025)

                Image("OnboardingWallpaper")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        .black.opacity(0.18),
                        .black.opacity(0.28),
                        .black.opacity(0.48)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    HomesteadOnboardingBackground()
}
