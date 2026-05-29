import SwiftUI

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
