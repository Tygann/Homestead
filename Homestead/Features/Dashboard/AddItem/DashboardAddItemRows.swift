import SwiftUI

struct DashboardAddCardRow: View {
    let candidate: DashboardAddCardCandidate
    let openChooser: () -> Void
    let quickAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Button(action: openChooser) {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(candidate.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(candidate.entityID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } icon: {
                    HomesteadIconView(icon: candidate.icon, pointSize: 18)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityHint("Choose card size and features")
            .layoutPriority(1)

            Button(action: quickAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(candidate.displayName)")
            .accessibilityHint("Adds the suggested \(candidate.recommendedSize.displayName) card")
        }
        .frame(minHeight: 48)
        .padding(.vertical, AppSpacing.xSmall)
    }
}

struct DashboardAddFilterChip: View {
    let title: String
    let systemImage: String
    var trailingValue: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                HStack(spacing: AppSpacing.xSmall) {
                    Text(title)
                    if let trailingValue {
                        Text(trailingValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.secondary)
                    }
                }
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, AppSpacing.medium)
            .frame(height: 34)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct DashboardAddEntityRow: View {
    let candidate: DashboardAddEntityCandidate

    var body: some View {
        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(candidate.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(candidate.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(1)

                Spacer(minLength: AppSpacing.medium)

                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
        } icon: {
            HomesteadIconView(icon: candidate.icon, pointSize: 18)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

struct DashboardAddSummaryChipRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .layoutPriority(1)

                Spacer(minLength: AppSpacing.medium)

                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}
