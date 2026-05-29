import SwiftUI

struct DashboardChipView: View {
    let presentation: DashboardChipPresentation
    var isEditing = false
    var setIconNameOverride: ((String?) -> Void)?
    var rename: (() -> Void)?
    var remove: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: presentation.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
                .background(iconBackground, in: Circle())
                .accessibilityHidden(true)

            Text(presentation.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(presentation.value)
                .font(.caption.weight(.bold))
                .foregroundStyle(presentation.isAvailable ? Color.primary : Color.red)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if isEditing {
                editControls
            }
        }
        .frame(minHeight: 32, alignment: .leading)
        .padding(.leading, 6)
        .padding(.trailing, isEditing ? 8 : 10)
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

    private var editControls: some View {
        HStack(spacing: AppSpacing.xSmall) {
            if let setIconNameOverride {
                DashboardIconOverrideMenu(
                    selectedSystemName: presentation.systemImage,
                    setIconNameOverride: setIconNameOverride
                )
            }

            if let rename {
                Button(action: rename) {
                    Image(systemName: "pencil")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                }
                .accessibilityLabel("Rename \(presentation.title)")
            }

            if let remove {
                Button(action: remove) {
                    Image(systemName: "minus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 22, height: 22)
                        .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                }
                .accessibilityLabel("Remove \(presentation.title)")
            }
        }
    }
}

struct DashboardIconOverrideMenu: View {
    let selectedSystemName: String
    let setIconNameOverride: (String?) -> Void

    var body: some View {
        Menu {
            Button {
                HapticFeedback.selection()
                setIconNameOverride(nil)
            } label: {
                Label("Default Icon", systemImage: selectedSystemName.isEmpty ? "checkmark" : "arrow.counterclockwise")
            }

            ForEach(DashboardIconChoice.choices) { choice in
                Button {
                    HapticFeedback.selection()
                    setIconNameOverride(choice.systemName)
                } label: {
                    Label {
                        Text(choice.title)
                    } icon: {
                        Image(systemName: choice.systemName == selectedSystemName ? "checkmark.circle.fill" : choice.systemName)
                    }
                }
            }
        } label: {
            Image(systemName: "circle.grid.2x2")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .accessibilityLabel("Change icon")
        .accessibilityValue(selectedIconTitle)
    }

    private var selectedIconTitle: String {
        DashboardIconChoice.choices.first { $0.systemName == selectedSystemName }?.title ?? "Default"
    }
}
