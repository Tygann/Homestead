import SwiftUI

enum GaugePresentationStyle: Equatable, Sendable {
    case arc
    case instrument
    case segmentedInstrument
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
        GeometryReader { proxy in
            let titleHeight: CGFloat = title == nil ? 0 : 17
            let titleSpacing: CGFloat = title == nil ? 0 : 2
            let bodyHeight = max(proxy.size.height - titleHeight - titleSpacing, 0)

            VStack(spacing: titleSpacing) {
                if let title {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 6)
                        .frame(height: titleHeight)
                }

                GeometryReader { bodyProxy in
                    let diameter = min(bodyProxy.size.width, bodyProxy.size.height / 0.79)
                    let lineWidth = min(max(diameter * 0.085, 10), 17)

                    ZStack {
                        instrumentTrack(diameter: diameter, lineWidth: lineWidth)

                        instrumentValueIndicator(diameter: diameter, lineWidth: lineWidth)

                        instrumentContent(diameter: diameter, lineWidth: lineWidth)
                    }
                    .frame(width: diameter, height: diameter)
                    .position(x: bodyProxy.size.width / 2, y: diameter / 2)
                }
                .frame(height: bodyHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    @ViewBuilder
    private func instrumentTrack(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        if style == .instrument || style == .segmentedInstrument {
            ForEach(presentation.sections.indices, id: \.self) { index in
                let section = presentation.sections[index]
                let segment = instrumentSegment(for: section)

                GaugeInstrumentArcShape(
                    start: segment.start,
                    end: segment.end,
                    inset: lineWidth / 2
                )
                    .stroke(
                        sectionColor(for: section),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .butt,
                            lineJoin: .round
                        )
                    )
            }

            if let first = presentation.sections.first {
                instrumentEndpointCap(
                    value: first.range.lowerBound,
                    color: sectionColor(for: first),
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }

            if let last = presentation.sections.last {
                instrumentEndpointCap(
                    value: last.range.upperBound,
                    color: sectionColor(for: last),
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }
        }
    }

    private func instrumentValueIndicator(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let angle = Angle.degrees(150 + (240 * presentation.normalizedValue))
        let dotDiameter = lineWidth + 1

        return Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black.opacity(0.14), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            .frame(width: dotDiameter, height: dotDiameter)
            .position(
                x: (diameter / 2) + (radius * CGFloat(cos(angle.radians))),
                y: (diameter / 2) + (radius * CGFloat(sin(angle.radians)))
            )
    }

    private func instrumentEndpointCap(
        value: Double,
        color: Color,
        diameter: CGFloat,
        lineWidth: CGFloat
    ) -> some View {
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let angle = Angle.degrees(150 + (240 * normalized(value)))

        return Circle()
            .fill(color)
            .frame(width: lineWidth, height: lineWidth)
            .position(
                x: (diameter / 2) + (radius * CGFloat(cos(angle.radians))),
                y: (diameter / 2) + (radius * CGFloat(sin(angle.radians)))
            )
    }

    private func instrumentSegment(for section: GaugePresentationSection) -> (start: Double, end: Double) {
        let rawStart = normalized(section.range.lowerBound)
        let rawEnd = normalized(section.range.upperBound)
        return (rawStart, max(rawEnd, rawStart))
    }

    private func instrumentContent(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        let valueFontSize = min(max(diameter * 0.25, 28), 58)
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let endpointY = (diameter / 2) + (radius * 0.5)
        let endpointBottomY = endpointY + (lineWidth / 2)
        let legendWidth = max((sqrt(3) * radius) - (lineWidth * 1.8), 0)
        let iconSize = instrumentIconSize(diameter: diameter)

        return AnyView(ZStack {
            GaugeInstrumentReadoutView(
                valueText: presentation.valueText,
                unitText: presentation.unitText,
                value: presentation.value,
                fontSize: valueFontSize,
                diameter: diameter,
                lineWidth: lineWidth
            )

            instrumentLegend(diameter: diameter)
                .frame(width: legendWidth)
                .frame(height: iconSize, alignment: .bottom)
                .position(x: diameter / 2, y: endpointBottomY - (iconSize / 2))
        })
    }

    private func instrumentLegend(diameter: CGFloat) -> some View {
        let iconSize = instrumentIconSize(diameter: diameter)

        return HStack(alignment: .bottom, spacing: 0) {
            Text(rangeValueText(presentation.range.lowerBound))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let icon {
                CardIconView(
                    icon: icon,
                    isActive: true,
                    accentColor: statusColor(for: presentation.status),
                    size: iconSize,
                    symbolSize: 21,
                    showsBackground: false
                )
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
            } else {
                Color.clear
                    .frame(width: iconSize, height: iconSize)
            }

            Text(rangeValueText(presentation.range.upperBound))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.secondary.opacity(0.72))
        .monospacedDigit()
    }

    private func instrumentIconSize(diameter: CGFloat) -> CGFloat {
        min(max(diameter * 0.16, 26), 28)
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

                    ForEach(Array(presentation.sections.enumerated()), id: \.offset) { index, section in
                        let segment = visualSegment(for: section, at: index)
                        let start = segment.start
                        let end = segment.end
                        let segmentWidth = max(CGFloat(end - start) * width, 0)

                        Capsule()
                            .fill(sectionColor(for: section).opacity(sectionBackgroundOpacity(for: section)))
                            .frame(width: segmentWidth)
                            .offset(x: CGFloat(start) * width)
                    }

                    if presentation.normalizedValue > 0 {
                        Capsule()
                            .fill(statusColor(for: presentation.status))
                            .frame(width: max(CGFloat(presentation.normalizedValue) * width, GaugeVisualMetrics.barMinimumFillWidth))
                    }

                    Capsule()
                        .strokeBorder(Color.white.opacity(GaugeVisualMetrics.barBorderOpacity), lineWidth: 1)

                    sectionBoundaryTicks(width: width)
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

    @ViewBuilder
    private func sectionBoundaryTicks(width: CGFloat) -> some View {
        ForEach(presentation.sections.indices.dropLast(), id: \.self) { index in
            let boundary = normalized(presentation.sections[index].range.upperBound)
            let xOffset = min(
                max(CGFloat(boundary) * width, GaugeVisualMetrics.barTrackHeight / 2),
                width - (GaugeVisualMetrics.barTrackHeight / 2)
            )

            Capsule()
                .fill(Color.white.opacity(GaugeVisualMetrics.barBoundaryOpacity))
                .frame(width: 1.5, height: GaugeVisualMetrics.barTrackHeight - 3)
                .offset(x: xOffset - 0.75)
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
