import SwiftUI

enum GaugePresentationStyle: Equatable, Sendable {
    case arc
    case row
    case detail
}

struct GaugePresentationView: View {
    let presentation: GaugePresentation
    let style: GaugePresentationStyle
    let tint: Color

    var body: some View {
        switch style {
        case .arc:
            arcGauge(height: 82, lineWidth: 15, markerFont: .caption2.weight(.semibold))
        case .row:
            rowGauge
        case .detail:
            detailGauge
        }
    }

    private var detailGauge: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                Text(presentation.valueText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor(for: presentation.status))
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

                Text(presentation.statusDisplayText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor(for: presentation.status))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(statusColor(for: presentation.status).opacity(0.12), in: Capsule())
            }

            arcGauge(height: 104, lineWidth: 18, markerFont: .caption.weight(.medium))
        }
    }

    private func arcGauge(
        height: CGFloat,
        lineWidth: CGFloat,
        markerFont: Font
    ) -> some View {
        VStack(spacing: AppSpacing.xSmall) {
            ZStack {
                ForEach(Array(presentation.sections.enumerated()), id: \.offset) { _, section in
                    GaugeArcShape(
                        start: normalized(section.range.lowerBound),
                        end: normalized(section.range.upperBound)
                    )
                    .stroke(
                        statusColor(for: section.status).opacity(0.18),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }

                ForEach(Array(presentation.sections.enumerated()), id: \.offset) { _, section in
                    let start = normalized(section.range.lowerBound)
                    let end = min(normalized(section.range.upperBound), presentation.normalizedValue)

                    if end > start {
                        GaugeArcShape(start: start, end: end)
                            .stroke(
                                statusColor(for: section.status),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityValue(presentation.accessibilityValue)

            rangeMarkers(font: markerFont)
        }
    }

    private var rowGauge: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            GeometryReader { proxy in
                let width = proxy.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemGroupedBackground))

                    ForEach(Array(presentation.sections.enumerated()), id: \.offset) { _, section in
                        let start = normalized(section.range.lowerBound)
                        let end = normalized(section.range.upperBound)
                        let segmentWidth = max(CGFloat(end - start) * width, 0)

                        Capsule()
                            .fill(statusColor(for: section.status).opacity(0.18))
                            .frame(width: segmentWidth)
                            .offset(x: CGFloat(start) * width)
                    }

                    ForEach(Array(presentation.sections.enumerated()), id: \.offset) { _, section in
                        let start = normalized(section.range.lowerBound)
                        let end = min(normalized(section.range.upperBound), presentation.normalizedValue)
                        let segmentWidth = max(CGFloat(end - start) * width, 0)

                        if end > start {
                            Capsule()
                                .fill(statusColor(for: section.status))
                                .frame(width: segmentWidth)
                                .offset(x: CGFloat(start) * width)
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)

            rangeMarkers(font: .caption2.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private func rangeMarkers(font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            Text(rangeText(presentation.range.lowerBound))
            Spacer(minLength: AppSpacing.small)
            Text(rangeText(presentation.range.upperBound))
        }
        .font(font)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .monospacedDigit()
    }

    private func normalized(_ value: Double) -> Double {
        guard presentation.range.upperBound > presentation.range.lowerBound else {
            return 0
        }

        let normalizedValue = (value - presentation.range.lowerBound) / (presentation.range.upperBound - presentation.range.lowerBound)
        return min(max(normalizedValue, 0), 1)
    }

    private func statusColor(for status: GaugePresentationStatus) -> Color {
        switch status {
        case .nominal:
            .green
        case .low:
            .blue
        case .high, .warning:
            .orange
        case .critical:
            .red
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

private struct GaugeArcShape: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height * 1.72)
        let center = CGPoint(x: rect.midX, y: rect.maxY - 2)
        var path = Path()

        let clampedStart = min(max(start, 0), 1)
        let clampedEnd = min(max(end, clampedStart), 1)
        let stepCount = max(Int((clampedEnd - clampedStart) * 48), 2)

        for step in 0...stepCount {
            let progress = clampedStart + ((clampedEnd - clampedStart) * (Double(step) / Double(stepCount)))
            let angle = Double.pi * (1 - progress)
            let point = CGPoint(
                x: center.x + (radius * CGFloat(cos(angle))),
                y: center.y - (radius * CGFloat(sin(angle)))
            )

            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

private let gaugeRangeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    return formatter
}()
