import SwiftUI

struct CardIconView: View {
    let systemName: String
    var isActive = false

    var body: some View {
        Image(systemName: systemName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .frame(width: 44, height: 44)
            .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .accessibilityHidden(true)
    }

    private var iconBackground: Color {
        isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }
}
