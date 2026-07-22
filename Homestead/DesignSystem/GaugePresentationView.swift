import SwiftUI

enum GaugePresentationStyle: Equatable, Sendable {
    case arc
    case instrument
    case segmentedInstrument
    case row
    case detail
}

struct GaugePresentationView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: GaugePresentation
    let style: GaugePresentationStyle
    let tint: Color
    var title: String? = nil
    var icon: ResolvedIcon? = nil
    var editableTitle: Binding<String>? = nil
    var editIcon: (() -> Void)? = nil
    var commitEditableTitle: (() -> Void)? = nil

    private let dashboardLineWidth: CGFloat = 11
    private let arcMarkerHeight: CGFloat = 10

    var body: some View {
        switch style {
        case .arc:
            arcGauge(arcHeight: 68, lineWidth: dashboardLineWidth, markerFont: .caption2.weight(.semibold))
        case .instrument:
            instrumentGauge
        case .segmentedInstrument:
            instrumentGauge
        case .row:
            rowGauge
        case .detail:
            detailGauge
        }
    }

    private var instrumentGauge: some View {
        instrumentGauge(
            trackStyle: style == .segmentedInstrument ? .segmented : .continuous,
            density: .standard
        )
    }

    private func instrumentGauge(
        trackStyle: GaugeInstrumentTrackStyle,
        density: GaugeInstrumentDensity
    ) -> some View {
        GaugeInstrumentCanvas(
            presentation: GaugeInstrumentVisualPresentation(
                value: presentation.value,
                lowerBound: presentation.range.lowerBound,
                upperBound: presentation.range.upperBound,
                valueText: presentation.valueText,
                unitText: presentation.unitText,
                lowerBoundText: rangeValueText(presentation.range.lowerBound),
                upperBoundText: rangeValueText(presentation.range.upperBound),
                sections: presentation.sections.map { section in
                    GaugeInstrumentVisualSection(
                        lowerBound: section.range.lowerBound,
                        upperBound: section.range.upperBound,
                        color: sectionColor(for: section)
                    )
                },
                accessibilityLabel: presentation.accessibilityLabel,
                accessibilityValue: presentation.accessibilityValue
            ),
            tint: statusColor(for: presentation.status),
            title: title,
            icon: icon,
            trackStyle: trackStyle,
            density: density,
            editableTitle: editableTitle,
            editIcon: editIcon,
            commitEditableTitle: commitEditableTitle
        )
    }

    @ViewBuilder
    private var detailGauge: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                detailReadout

                rowGauge
            }
        } else {
            instrumentGauge(
                trackStyle: presentation.sections.count > 1 ? .segmented : .continuous,
                density: .standard
            )
            .frame(height: 206)
        }
    }

    private var detailReadout: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            Text(presentation.valueText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
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
                            sectionColor(for: section).opacity(sectionBackgroundOpacity(for: section)),
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

            VStack(spacing: GaugeVisualMetrics.barRangeMarkerSpacing) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.16))

                    if presentation.normalizedValue > 0 {
                        Capsule()
                            .fill(statusColor(for: presentation.status))
                            .frame(width: max(CGFloat(presentation.normalizedValue) * width, GaugeVisualMetrics.barMinimumFillWidth))
                    }

                    Capsule()
                        .strokeBorder(Color.white.opacity(GaugeVisualMetrics.barBorderOpacity), lineWidth: 1)
                }
                .frame(height: GaugeVisualMetrics.barTrackHeight)
                .clipShape(Capsule())

                rangeMarkers(font: .caption2.weight(.semibold))
            }
        }
        .frame(height: GaugeVisualMetrics.barTotalHeight)
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
            Text(rangeValueText(presentation.range.lowerBound))
            Spacer(minLength: AppSpacing.small)
            Text(rangeValueText(presentation.range.upperBound))
        }
        .font(font)
        .foregroundStyle(Color.secondary.opacity(GaugeVisualMetrics.barRangeMarkerOpacity))
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
        let start = index == 0 ? rawStart : rawStart + (GaugeVisualMetrics.barSectionGap / 2)
        let end = index == presentation.sections.indices.last ? rawEnd : rawEnd - (GaugeVisualMetrics.barSectionGap / 2)

        return (min(max(start, 0), 1), min(max(end, start), 1))
    }

    private func sectionBackgroundOpacity(for section: GaugePresentationSection) -> Double {
        section.color == nil
            ? gaugeSectionBackgroundOpacity(current: presentation.status.visualStatus, section: section.status.visualStatus)
            : 1
    }

    private func sectionColor(for section: GaugePresentationSection) -> Color {
        section.color?.color ?? statusColor(for: section.status)
    }

    private var horizontalArcScale: CGFloat {
        switch style {
        case .arc:
            1.24
        case .instrument:
            1
        case .segmentedInstrument:
            1
        case .row:
            1
        case .detail:
            1.08
        }
    }

    private func statusColor(for status: GaugePresentationStatus) -> Color {
        gaugeVisualStatusColor(for: status.visualStatus)
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

extension GaugePresentationStatus {
    var visualStatus: GaugeVisualStatus {
        switch self {
        case .nominal:
            .nominal
        case .low:
            .low
        case .high:
            .high
        case .warning:
            .warning
        case .critical:
            .critical
        }
    }
}

private struct GaugeInstrumentArcShape: Shape {
    let start: Double
    let end: Double
    let inset: CGFloat
    var startAngle: Double = 150
    var sweepAngle: Double = 240

    func path(in rect: CGRect) -> Path {
        let radius = max((min(rect.width, rect.height) / 2) - inset, 0)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let clampedStart = min(max(start, 0), 1)
        let clampedEnd = min(max(end, clampedStart), 1)
        var path = Path()
        let resolvedStartAngle = startAngle + (sweepAngle * clampedStart)
        let resolvedEndAngle = startAngle + (sweepAngle * clampedEnd)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(resolvedStartAngle),
            endAngle: .degrees(resolvedEndAngle),
            clockwise: false
        )

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
