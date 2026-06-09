import SwiftUI

struct CardIconView: View {
    let systemName: String
    var isActive = false
    var isAvailable = true
    var accentColor = Color.accentColor
    var size: CGFloat = 44
    var symbolSize: CGFloat = 21

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(iconForeground)
            .frame(width: size, height: size)
            .background(iconBackground, in: RoundedRectangle(cornerRadius: iconRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    private var iconForeground: Color {
        guard isAvailable else {
            return .secondary
        }

        return isActive ? accentColor : .primary
    }

    private var iconBackground: Color {
        guard isAvailable else {
            return Color(.tertiarySystemGroupedBackground)
        }

        return isActive ? accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var iconRadius: CGFloat {
        min(AppRadius.icon, max(8, size * 0.32))
    }
}
