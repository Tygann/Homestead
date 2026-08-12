import SwiftUI

/// A restrained dark backdrop that keeps attention on onboarding content and actions.
struct HomesteadOnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.005, green: 0.015, blue: 0.025),
                    Color(red: 0.008, green: 0.028, blue: 0.045),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.0, green: 0.24, blue: 0.30).opacity(0.22),
                    .clear
                ],
                center: UnitPoint(x: 0.78, y: 0.12),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    HomesteadOnboardingBackground()
}
