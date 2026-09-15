import SwiftUI

struct DashboardAlarmCard: View {
    let entityBox: HAEntityState
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let showDetails: (() -> Void)?
    let isInteractionEnabled: Bool

    // MARK: - Body

    var body: some View {
        CardContainer(minHeight: size.contentMinHeight(rowSpacing: AppSpacing.medium, cardPadding: AppSpacing.medium)) {
            if size == .row {
                HStack(spacing: AppSpacing.medium) {
                    header
                    AlarmModeControl(entityBox: entityBox, isInteractionEnabled: isInteractionEnabled)
                        .frame(maxWidth: 154)
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    header
                    if size.featureLayout != .hidden {
                        Spacer(minLength: 0)
                        AlarmModeControl(
                            entityBox: entityBox,
                            expanded: size == .large,
                            isInteractionEnabled: isInteractionEnabled
                        )
                    }
                }
                .frame(maxWidth: .infinity, minHeight: size.contentMinHeight(rowSpacing: AppSpacing.medium, cardPadding: AppSpacing.medium), alignment: .topLeading)
            }
        }
    }

    private var header: some View {
        Button { showDetails?() } label: {
            HStack(spacing: size == .square ? AppSpacing.small : AppSpacing.medium) {
                HomesteadIconView(icon: presentation.icon, pointSize: 24)
                    .foregroundStyle(tint)
                    .frame(width: size == .square ? 36 : 44, height: 44)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.icon))
                if size != .mini {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(presentation.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(entityBox.homeEntity.state.displayStateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(presentation.accessibilityDetailLabel)
        .accessibilityValue(entityBox.homeEntity.state.displayStateText)
    }

    private var tint: Color {
        guard entityBox.homeEntity.isAvailable else { return .secondary }
        switch entityBox.homeEntity.state {
        case "triggered": return .red
        case "arming", "pending", "disarming": return .orange
        case "disarmed": return .secondary
        default: return .accentColor
        }
    }
}
