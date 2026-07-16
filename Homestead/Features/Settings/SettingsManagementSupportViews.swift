import SwiftUI

struct SettingsNavigationRowLabel<Title: View>: View {
    let systemImage: String
    @ViewBuilder let title: () -> Title

    init(_ title: String, systemImage: String) where Title == Text {
        self.systemImage = systemImage
        self.title = { Text(title) }
    }

    init(systemImage: String, @ViewBuilder title: @escaping () -> Title) {
        self.systemImage = systemImage
        self.title = title
    }

    var body: some View {
        Label {
            title()
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}

struct SettingsManagementOverviewRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}

struct SettingsFeaturePlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        SettingsManagementPlaceholderView(
            title: title,
            systemImage: systemImage,
            message: message
        )
    }
}

struct SettingsManagementPlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}
