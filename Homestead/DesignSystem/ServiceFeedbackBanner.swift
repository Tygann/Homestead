import SwiftUI

struct ServiceFeedbackBanner: View {
    let feedback: HAServiceFeedback

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: feedback.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(feedback.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let message = feedback.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: AppSpacing.small)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }

    private var iconColor: Color {
        switch feedback.style {
        case .success:
            Color.green
        case .failure:
            Color.red
        }
    }
}
