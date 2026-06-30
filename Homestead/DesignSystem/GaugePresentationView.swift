import SwiftUI

enum GaugePresentationStyle: Equatable, Sendable {
    case arc
    case instrument
    case row
    case detail
}

struct GaugePresentationView: View {
    let presentation: GaugePresentation
    let style: GaugePresentationStyle
    let tint: Color
    var title: String? = nil
    var icon: ResolvedIcon? = nil

    private let dashboardLineWidth: CGFloat = 11
    private let sectionGap: Double = 0.018
    private let arcMarkerHeight: CGFloat = 10

    var body: some View {
        switch style {
        case .arc:
            arcGauge(arcHeight: 68, lineWidth: dashboardLineWidth, markerFont: .caption2.weight(.semibold))
        case .instrument:
            instrumentGauge
        case .row:
            rowGauge
        case .detail:
            detailGauge
        }
    }

    private var instrumentGauge: some View {
        GeometryReader { proxy in
            let titleHeight: CGFloat = title == nil ? 0 : 17
            let titleSpacing: CGFloat = 0
            let diameter = min(proxy.size.width, max(proxy.size.height - titleHeight - titleSpacing, 0))
            let lineWidth = min(max(diameter * 0.085, 10), 17)

            VStack(spacing: titleSpacing) {
                if let title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(height: titleHeight)
                }

                ZStack {
                    ForEach(Array(presentation.sections.enumerated()), id: \.offset) { index, section in
                        let segment = visualSegment(for: section, at: index)

                        GaugeInstrumentArcShape(start: segment.start, end: segment.end, inset: lineWidth / 2)
                            .stroke(
                                statusColor(for: section.status).opacity(sectionBackgroundOpacity(for: section.status)),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                    }

                    if presentation.normalizedValue > 0 {
                        GaugeInstrumentArcShape(start: 0, end: presentation.normalizedValue, inset: lineWidth / 2)
                            .stroke(
                                statusColor(for: presentation.status),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                    }

                    instrumentLabels(diameter: diameter, lineWidth: lineWidth)
                }
                .frame(width: diameter, height: diameter)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private func instrumentLabels(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        let valueFontSize = min(max(diameter * 0.25, 28), 58)
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let endpointOffset = radius / sqrt(2)
        let endpointY = (diameter / 2) + endpointOffset
        let lowerEndpointX = (diameter / 2) - endpointOffset
        let upperEndpointX = (diameter / 2) + endpointOffset
        let labelInset = max(lineWidth * 1.3, 14)

        return ZStack {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(presentation.valueText)
                    .font(.system(size: valueFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let unitText = presentation.unitText {
                    Text(unitText)
                        .font(.system(size: valueFontSize * 0.58, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .baselineOffset(-1)
                        .lineLimit(1)
                }
            }
            .minimumScaleFactor(0.55)
            .monospacedDigit()
            .position(x: diameter / 2, y: diameter * 0.48)

            if let icon {
                HomesteadIconView(
                    icon: icon,
                    pointSize: min(max(diameter * 0.18, 18), 28),
                    weight: .semibold
                )
                .foregroundStyle(tint)
                .position(x: diameter / 2, y: endpointY)
                .accessibilityHidden(true)
            }

            Text(rangeValueText(presentation.range.lowerBound))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .position(x: lowerEndpointX + labelInset, y: endpointY - 2)

            Text(rangeValueText(presentation.range.upperBound))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .position(x: upperEndpointX - labelInset, y: endpointY - 2)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .monospacedDigit()
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

            arcGauge(arcHeight: 104, lineWidth: 14, markerFont: .caption.weight(.medium))
        }
    }

    private func arcGauge(
        arcHeight: CGFloat,
        lineWidth: CGFloat,
        markerFont: Font
    ) -> some View {
        GeometryReader { proxy in
            let maxArcWidth = max((arcHeight - lineWidth) * 2 * horizontalArcScale, 0)
            let arcWidth = min(max(proxy.size.width - lineWidth, 0), maxArcWidth)

            VStack(spacing: 0) {
                ZStack {
                    ForEach(Array(presentation.sections.enumerated()), id: \.offset) { index, section in
                        let segment = visualSegment(for: section, at: index)

                        GaugeArcShape(
                            start: segment.start,
                            end: segment.end,
                            inset: lineWidth / 2,
                            horizontalScale: horizontalArcScale
                        )
                        .stroke(
                            statusColor(for: section.status).opacity(sectionBackgroundOpacity(for: section.status)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }

                    if presentation.normalizedValue > 0 {
                        GaugeArcShape(
                            start: 0,
                            end: presentation.normalizedValue,
                            inset: lineWidth / 2,
                            horizontalScale: horizontalArcScale
                        )
                            .stroke(
                                statusColor(for: presentation.status),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
                .frame(width: arcWidth, height: arcHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(presentation.accessibilityLabel)
                .accessibilityValue(presentation.accessibilityValue)

                endpointRangeMarkers(
                    width: arcWidth,
                    endpointInset: lineWidth / 2,
                    font: markerFont
                )
                    .opacity(0.78)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: arcHeight + arcMarkerHeight)
    }

    private var rowGauge: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            VStack(spacing: 3) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemGroupedBackground))

                    ForEach(Array(presentation.sections.enumerated()), id: \.offset) { index, section in
                        let segment = visualSegment(for: section, at: index)
                        let start = segment.start
                        let end = segment.end
                        let segmentWidth = max(CGFloat(end - start) * width, 0)

                        Capsule()
                            .fill(statusColor(for: section.status).opacity(sectionBackgroundOpacity(for: section.status)))
                            .frame(width: segmentWidth)
                            .offset(x: CGFloat(start) * width)
                    }

                    if presentation.normalizedValue > 0 {
                        Capsule()
                            .fill(statusColor(for: presentation.status))
                            .frame(width: max(CGFloat(presentation.normalizedValue) * width, dashboardLineWidth))
                    }

                    Capsule()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)

                    sectionBoundaryTicks(width: width)
                }
                .frame(height: dashboardLineWidth)
                .clipShape(Capsule())

                rangeMarkers(font: .caption2.weight(.semibold))
                    .opacity(0.72)
            }
        }
        .frame(height: dashboardLineWidth + arcMarkerHeight + 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private func endpointRangeMarkers(
        width: CGFloat,
        endpointInset: CGFloat,
        font: Font
    ) -> some View {
        ZStack {
            Text(rangeText(presentation.range.lowerBound))
                .position(x: endpointInset, y: arcMarkerHeight / 2)

            Text(rangeText(presentation.range.upperBound))
                .position(x: width - endpointInset, y: arcMarkerHeight / 2)
        }
        .frame(width: width, height: arcMarkerHeight)
        .font(font)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .monospacedDigit()
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

    private func visualSegment(
        for section: GaugePresentationSection,
        at index: Int
    ) -> (start: Double, end: Double) {
        let rawStart = normalized(section.range.lowerBound)
        let rawEnd = normalized(section.range.upperBound)
        let start = index == 0 ? rawStart : rawStart + (sectionGap / 2)
        let end = index == presentation.sections.indices.last ? rawEnd : rawEnd - (sectionGap / 2)

        return (min(max(start, 0), 1), min(max(end, start), 1))
    }

    private func sectionBackgroundOpacity(for status: GaugePresentationStatus) -> Double {
        switch presentation.status {
        case .nominal:
            status == .nominal ? 0.18 : 0.10
        case .low, .high, .warning, .critical:
            status == presentation.status ? 0.28 : 0.16
        }
    }

    private var horizontalArcScale: CGFloat {
        switch style {
        case .arc:
            1.24
        case .instrument:
            1
        case .row:
            1
        case .detail:
            1.08
        }
    }

    @ViewBuilder
    private func sectionBoundaryTicks(width: CGFloat) -> some View {
        ForEach(presentation.sections.indices.dropLast(), id: \.self) { index in
            let boundary = normalized(presentation.sections[index].range.upperBound)
            let xOffset = min(max(CGFloat(boundary) * width, dashboardLineWidth / 2), width - (dashboardLineWidth / 2))

            Capsule()
                .fill(Color.white.opacity(0.13))
                .frame(width: 1.5, height: dashboardLineWidth - 3)
                .offset(x: xOffset - 0.75)
        }
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
        let formattedValue = rangeValueText(value)
        guard let unitText = presentation.unitText,
              !unitText.isEmpty else {
            return formattedValue
        }

        let separator = unitText.hasPrefix("°") || unitText == "%" ? "" : " "
        return "\(formattedValue)\(separator)\(unitText)"
    }

    private func rangeValueText(_ value: Double) -> String {
        gaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct GaugeInstrumentArcShape: Shape {
    let start: Double
    let end: Double
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = max((min(rect.width, rect.height) / 2) - inset, 0)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let clampedStart = min(max(start, 0), 1)
        let clampedEnd = min(max(end, clampedStart), 1)
        let stepCount = max(Int((clampedEnd - clampedStart) * 72), 2)
        var path = Path()

        for step in 0...stepCount {
            let progress = clampedStart + ((clampedEnd - clampedStart) * (Double(step) / Double(stepCount)))
            let angle = (Double.pi * 1.25) - (Double.pi * 1.5 * progress)
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

private struct GaugeArcShape: Shape {
    let start: Double
    let end: Double
    let inset: CGFloat
    let horizontalScale: CGFloat

    func path(in rect: CGRect) -> Path {
        let yRadius = max(rect.height - (inset * 2), 0)
        let xRadius = max(min((rect.width - (inset * 2)) / 2, yRadius * horizontalScale), 0)
        let center = CGPoint(x: rect.midX, y: rect.maxY - inset)
        var path = Path()

        let clampedStart = min(max(start, 0), 1)
        let clampedEnd = min(max(end, clampedStart), 1)
        let stepCount = max(Int((clampedEnd - clampedStart) * 48), 2)

        for step in 0...stepCount {
            let progress = clampedStart + ((clampedEnd - clampedStart) * (Double(step) / Double(stepCount)))
            let angle = Double.pi * (1 - progress)
            let point = CGPoint(
                x: center.x + (xRadius * CGFloat(cos(angle))),
                y: center.y - (yRadius * CGFloat(sin(angle)))
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
