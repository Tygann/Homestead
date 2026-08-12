import SwiftUI

/// A quiet, Canvas-rendered backdrop for the setup flow. The motion is decorative and stops
/// completely when Reduce Motion is enabled.
struct HomesteadOnboardingBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var intensity: Double = 1

    var body: some View {
        Group {
            if reduceMotion {
                background(elapsedTime: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    background(elapsedTime: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func background(elapsedTime: TimeInterval) -> some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.006, green: 0.025, blue: 0.05),
                        Color(red: 0.01, green: 0.06, blue: 0.10),
                        .black
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            context.addFilter(.blur(radius: max(size.width * 0.16, 54)))
            for ribbon in OnboardingLightRibbon.allCases {
                let center = ribbon.center(
                    in: size,
                    elapsedTime: elapsedTime,
                    intensity: intensity
                )
                let radius = ribbon.radius(in: size)
                let rect = CGRect(
                    x: center.x - radius.width,
                    y: center.y - radius.height,
                    width: radius.width * 2,
                    height: radius.height * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [ribbon.color(intensity: intensity), .clear]),
                        center: center,
                        startRadius: 0,
                        endRadius: max(radius.width, radius.height)
                    )
                )
            }
        }
    }
}

private enum OnboardingLightRibbon: CaseIterable {
    case upperCyan
    case centerBlue
    case lowerTeal

    func color(intensity: Double) -> Color {
        let clampedIntensity = min(max(intensity, 0), 1)
        return switch self {
        case .upperCyan:
            Color(red: 0.0, green: 0.62, blue: 0.82).opacity(0.32 * clampedIntensity)
        case .centerBlue:
            Color(red: 0.04, green: 0.28, blue: 0.52).opacity(0.28 * clampedIntensity)
        case .lowerTeal:
            Color(red: 0.0, green: 0.40, blue: 0.46).opacity(0.18 * clampedIntensity)
        }
    }

    func center(in size: CGSize, elapsedTime: TimeInterval, intensity: Double) -> CGPoint {
        let time = elapsedTime * 0.18
        let motionScale = 0.65 + (min(max(intensity, 0), 1) * 0.35)
        return switch self {
        case .upperCyan:
            CGPoint(
                x: size.width * (0.84 + sin(time) * 0.08 * motionScale),
                y: size.height * (0.16 + cos(time * 0.7) * 0.04 * motionScale)
            )
        case .centerBlue:
            CGPoint(
                x: size.width * (0.14 + cos(time * 0.8) * 0.09 * motionScale),
                y: size.height * (0.48 + sin(time * 0.6) * 0.06 * motionScale)
            )
        case .lowerTeal:
            CGPoint(
                x: size.width * (0.76 + sin(time * 0.65) * 0.10 * motionScale),
                y: size.height * (0.78 + cos(time * 0.5) * 0.05 * motionScale)
            )
        }
    }

    func radius(in size: CGSize) -> CGSize {
        switch self {
        case .upperCyan:
            CGSize(width: size.width * 0.62, height: size.height * 0.28)
        case .centerBlue:
            CGSize(width: size.width * 0.68, height: size.height * 0.34)
        case .lowerTeal:
            CGSize(width: size.width * 0.56, height: size.height * 0.28)
        }
    }
}

#Preview {
    HomesteadOnboardingBackground()
}
