import SwiftUI

struct DashboardChipView: View {
    let presentation: DashboardChipPresentation

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: presentation.systemImage)
//                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
//                .background(iconBackground, in: Circle())
                .accessibilityHidden(true)
            
            VStack(alignment: .leading) {
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(presentation.value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(presentation.isAvailable ? Color.primary : Color.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(minHeight: 32, alignment: .leading)
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.72), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color(.separator).opacity(0.12), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private var iconColor: Color {
        guard presentation.isAvailable else { return .red }
        return presentation.isActive ? .accentColor : .secondary
    }

    private var iconBackground: Color {
        guard presentation.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? Color.accentColor.opacity(0.14) : Color(.tertiarySystemGroupedBackground)
    }
}

// MARK: - Previews
#if DEBUG
private struct DashboardChipPreviewContainer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                DashboardChipView(presentation: .init(
                    title: "Lights",
                    value: "3 on",
                    systemImage: "lightbulb.fill",
                    isActive: true,
                    isAvailable: true
                ))

                DashboardChipView(presentation: .init(
                    title: "Doors",
                    value: "All closed",
                    systemImage: "door.left.hand.open",
                    isActive: false,
                    isAvailable: true
                ))

                DashboardChipView(presentation: .init(
                    title: "Cameras",
                    value: "1 unavailable",
                    systemImage: "camera",
                    isActive: true,
                    isAvailable: false
                ))
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Chip States") {
    DashboardChipPreviewContainer()
}

#Preview("Editing Mode") {
    VStack(alignment: .leading, spacing: 8) {
        DashboardChipView(
            presentation: .init(
                title: "Locks",
                value: "2 unlocked",
                systemImage: "lock.open",
                isActive: true,
                isAvailable: true
            )
        )

        DashboardChipView(
            presentation: .init(
                title: "Batteries",
                value: "1 low",
                systemImage: "battery.25percent",
                isActive: true,
                isAvailable: true
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
