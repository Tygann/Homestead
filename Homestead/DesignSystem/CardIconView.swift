import SwiftUI

struct CardIconView: View {
    let systemName: String
    var isActive = false

    var body: some View {
        Image(systemName: systemName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .accessibilityHidden(true)
    }
}
