import SwiftUI

// MARK: - Appearance

struct DashboardCardIdentityEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let icon: ResolvedIcon
    let displayName: Binding<String>
    let changeIcon: () -> Void
    let commitDisplayName: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    iconButton
                    nameEditor
                }
            } else {
                HStack(alignment: .center, spacing: AppSpacing.large) {
                    iconButton
                    nameEditor
                }
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private var iconButton: some View {
        Button(action: changeIcon) {
            VStack(spacing: AppSpacing.xSmall) {
                CardIconView(
                    icon: icon,
                    accentColor: .accentColor,
                    size: 56,
                    symbolSize: 25
                )

                Text("Change")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(minWidth: 64, minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(DashboardCardIdentityIconButtonStyle())
        .accessibilityLabel("Change card icon")
        .accessibilityHint("Opens the icon picker")
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text("Name")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Card Name", text: displayName)
                .font(.headline)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(commitDisplayName)
                .accessibilityLabel("Card name")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardCardIdentityIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.68 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct DashboardCardEditorPreviewStage<Content: View>: View {
    let size: DashboardCardSize
    let accessibilityValue: String
    @ViewBuilder let content: Content

    init(
        size: DashboardCardSize,
        accessibilityValue: String,
        @ViewBuilder content: () -> Content
    ) {
        self.size = size
        self.accessibilityValue = accessibilityValue
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = DashboardCardEditorPreviewLayout(
                availableWidth: proxy.size.width,
                size: size
            )

            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))

                content
                    .frame(
                        width: layout.unscaledCardSize.width,
                        height: layout.unscaledCardSize.height
                    )
                    .scaleEffect(layout.scale)
            }
        }
        .frame(height: DashboardCardEditorPreviewLayout.stageHeight(for: size))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card preview")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Updates as card settings change")
    }
}

nonisolated struct DashboardCardEditorPreviewLayout: Equatable, Sendable {
    static let columnCount = 4
    static let spacing: CGFloat = AppSpacing.medium
    static let cardPadding: CGFloat = AppSpacing.medium
    static let stagePadding: CGFloat = AppSpacing.medium
    static let maximumStageHeight: CGFloat = 280

    let availableWidth: CGFloat
    let size: DashboardCardSize

    var unscaledCardSize: CGSize {
        let usableWidth = max(availableWidth - (Self.stagePadding * 2), 0)
        let trackWidth = max(
            (usableWidth - (Self.spacing * CGFloat(Self.columnCount - 1)))
                / CGFloat(Self.columnCount),
            0
        )
        let width = (trackWidth * CGFloat(size.columnSpan))
            + (Self.spacing * CGFloat(size.columnSpan - 1))
        let height = size.renderedHeight(
            rowSpacing: Self.spacing,
            cardPadding: Self.cardPadding
        )
        return CGSize(width: width, height: height)
    }

    var scale: CGFloat {
        let cardSize = unscaledCardSize
        guard cardSize.width > 0, cardSize.height > 0 else { return 1 }

        let usableWidth = max(availableWidth - (Self.stagePadding * 2), 0)
        let usableHeight = max(Self.stageHeight(for: size) - (Self.stagePadding * 2), 0)
        return min(1, usableWidth / cardSize.width, usableHeight / cardSize.height)
    }

    static func stageHeight(for size: DashboardCardSize) -> CGFloat {
        min(
            size.renderedHeight(rowSpacing: spacing, cardPadding: cardPadding)
                + (stagePadding * 2),
            maximumStageHeight
        )
    }
}
