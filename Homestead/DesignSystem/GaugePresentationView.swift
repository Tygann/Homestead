import SwiftUI

enum GaugePresentationStyle: Equatable, Sendable {
    case card
    case detail
}

struct GaugePresentationView: View {
    let presentation: GaugePresentation
    let style: GaugePresentationStyle
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            if style == .detail {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Text(presentation.valueText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .monospacedDigit()

                    if let unitText = presentation.unitText {
                        Text(unitText)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppSpacing.small)

                    statusLabel
                }
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = width * CGFloat(presentation.normalizedValue)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                        .fill(trackColor)

                    RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                        .fill(statusColor)
                        .frame(width: max(fillWidth, minimumFillWidth))

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: markerSize, height: markerSize)
                        .overlay {
                            Circle()
                                .stroke(statusColor, lineWidth: style == .detail ? 3 : 2)
                        }
                        .shadow(color: .black.opacity(style == .detail ? 0.10 : 0.06), radius: 2, x: 0, y: 1)
                        .offset(x: min(max(fillWidth - markerSize / 2, 0), max(width - markerSize, 0)))
                }
            }
            .frame(height: gaugeHeight)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                Text(rangeText(presentation.range.lowerBound))
                Spacer(minLength: AppSpacing.small)
                if style == .card {
                    Text(presentation.valueText)
                        .foregroundStyle(statusColor)
                }
                Spacer(minLength: AppSpacing.small)
                Text(rangeText(presentation.range.upperBound))
            }
            .font(rangeFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private var statusLabel: some View {
        Text(statusText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var verticalSpacing: CGFloat {
        style == .detail ? AppSpacing.medium : AppSpacing.xSmall
    }

    private var gaugeHeight: CGFloat {
        style == .detail ? 18 : 10
    }

    private var markerSize: CGFloat {
        style == .detail ? 22 : 14
    }

    private var minimumFillWidth: CGFloat {
        presentation.normalizedValue > 0 ? markerSize / 2 : 0
    }

    private var rangeFont: Font {
        style == .detail ? .caption.weight(.medium) : .caption2.weight(.semibold)
    }

    private var trackColor: Color {
        switch style {
        case .card:
            Color(.tertiarySystemGroupedBackground)
        case .detail:
            Color(.tertiarySystemGroupedBackground)
        }
    }

    private var statusColor: Color {
        switch presentation.status {
        case .nominal:
            tint
        case .low, .high:
            .orange
        case .warning:
            .orange
        case .critical:
            .red
        }
    }

    private var statusText: String {
        switch presentation.status {
        case .nominal:
            "Normal"
        case .low:
            "Low"
        case .high:
            "High"
        case .warning:
            "Warning"
        case .critical:
            "Critical"
        }
    }

    private func rangeText(_ value: Double) -> String {
        let formattedValue = gaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        guard let unitText = presentation.unitText,
              !unitText.isEmpty else {
            return formattedValue
        }

        let separator = unitText.hasPrefix("°") || unitText == "%" ? "" : " "
        return "\(formattedValue)\(separator)\(unitText)"
    }
}

private let gaugeRangeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    return formatter
}()

