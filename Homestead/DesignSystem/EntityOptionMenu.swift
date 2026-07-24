import SwiftUI

enum EntityOptionMenuStyle {
    case heroAccessory
    case controlRow
    case dashboardCard
}

struct EntityOptionMenu: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let presentation: EntityOptionSelectionPresentation
    let style: EntityOptionMenuStyle
    let isDisabled: Bool
    let select: (String) -> Void

    // MARK: - Body

    var body: some View {
        Menu {
            ForEach(presentation.options) { option in
                Toggle(
                    option.displayValue,
                    isOn: Binding(
                        get: { option.isSelected },
                        set: { isSelected in
                            guard isSelected, !option.isSelected else { return }
                            HapticFeedback.selection()
                            select(option.value)
                        }
                    )
                )
            }
        } label: {
            label
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || presentation.options.isEmpty)
        .accessibilityLabel("Options")
        .accessibilityValue(presentation.selectedDisplayValue)
    }

    // MARK: - Presentation

    @ViewBuilder
    private var label: some View {
        switch style {
        case .heroAccessory:
            HStack(spacing: AppSpacing.small) {
                Text(presentation.selectedDisplayValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.medium)
            .frame(minWidth: 76, maxWidth: 112)
            .frame(height: 40)
            .background(
                controlBackground,
                in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))

        case .controlRow:
            HStack(spacing: AppSpacing.medium) {
                Label("Current", systemImage: "checkmark.circle")
                    .font(.body)

                Spacer(minLength: AppSpacing.medium)

                Text(presentation.selectedDisplayValue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())

        case .dashboardCard:
            HStack(spacing: AppSpacing.small) {
                Text(presentation.selectedDisplayValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: AppSpacing.xSmall)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.medium)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                controlBackground,
                in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
        }
    }

    private var controlBackground: Color {
        HomesteadSurfaceStyle.controlBackground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: false
        )
    }
}
