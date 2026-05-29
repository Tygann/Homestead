import SwiftUI

struct DashboardEntityStatusCard: View {
    let iconName: String
    let title: String
    let badge: String
    let summary: String
    let iconColor: Color
    let badgeColor: Color
    let iconBackground: Color
    let badgeBackground: Color

    init(
        iconName: String,
        title: String,
        badge: String,
        summary: String,
        iconColor: Color,
        badgeColor: Color? = nil,
        iconBackground: Color? = nil,
        badgeBackground: Color? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.badge = badge
        self.summary = summary
        self.iconColor = iconColor
        self.badgeColor = badgeColor ?? iconColor
        self.iconBackground = iconBackground ?? iconColor.opacity(0.12)
        self.badgeBackground = badgeBackground ?? iconColor.opacity(0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 64, height: 64)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    .accessibilityHidden(true)

                Spacer()

                Text(badge)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(badgeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(badgeBackground, in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(summary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct DashboardPrimaryActionButton: View {
    let title: String
    let systemImage: String
    let isProminent: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        isProminent: Bool = true,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isProminent = isProminent
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        if isProminent {
            actionButton
                .buttonStyle(.borderedProminent)
        } else {
            actionButton
                .buttonStyle(.bordered)
        }
    }

    private var actionButton: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .controlSize(.large)
        .disabled(isDisabled)
    }
}

struct DashboardControlPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct DashboardEntityContextPanel: View {
    let title: String
    let systemImage: String
    let rows: [DashboardEntityDetailRow]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            ForEach(rows) { row in
                row
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct DashboardEntityDetailRow: View, Identifiable {
    let title: String
    let value: String

    var id: String { title }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.medium)

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}

extension String {
    var displayStateText: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}
