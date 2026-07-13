import SwiftUI

enum GaugeVisualStatus: Equatable, Sendable {
    case nominal
    case low
    case high
    case warning
    case critical
}

enum WidgetGaugeInstrumentStyle: Equatable, Sendable {
    case standard
    case segmented
}

enum GaugeVisualMetrics {
    static let compactHeaderSpacing: CGFloat = 12
    static let compactHeaderTextSpacing: CGFloat = 4
    static let compactHeaderIconSize: CGFloat = 44
    static let compactHeaderIconPointSize: CGFloat = 22
    static let compactHeaderIconCornerRadius: CGFloat = 14
    static let compactHeaderTitleFont: Font = .headline.weight(.semibold)
    static let compactHeaderStatusFont: Font = .caption.weight(.semibold)
    static let compactHeaderTitleMinimumScale = 0.84
    static let compactHeaderStatusMinimumScale = 0.82
    static let barTrackHeight: CGFloat = 11
    static let barRangeMarkerHeight: CGFloat = 10
    static let barRangeMarkerSpacing: CGFloat = 3
    static let barRangeMarkerOpacity = 0.72
    static let barMinimumFillWidth: CGFloat = 11
    static let barSectionGap = 0.018
    static let barBoundaryOpacity = 0.13
    static let barBorderOpacity = 0.10

    static var barTotalHeight: CGFloat {
        barTrackHeight + barRangeMarkerHeight + barRangeMarkerSpacing
    }
}

struct WidgetGaugeInstrumentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let gauge: WidgetGaugePresentation
    let tint: Color
    var title: String? = nil
    var icon: ResolvedIcon? = nil
    var style: WidgetGaugeInstrumentStyle = .standard

    var body: some View {
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

                        if style == .segmented {
                            instrumentValueIndicator(diameter: diameter, lineWidth: lineWidth)
                        } else if gauge.normalizedValue > 0 {
                            WidgetGaugeInstrumentArcShape(start: 0, end: gauge.normalizedValue, inset: lineWidth / 2)
                                .stroke(
                                    widgetGaugeColor(for: gauge.currentColor),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                                )
                        }

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
        .accessibilityLabel(gauge.accessibilityLabel)
        .accessibilityValue(gauge.accessibilityValue)
    }

    @ViewBuilder
    private func instrumentTrack(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        if style == .segmented {
            ForEach(gauge.sections.indices, id: \.self) { index in
                let section = gauge.sections[index]
                let segment = instrumentSegment(for: section)

                WidgetGaugeInstrumentArcShape(
                    start: segment.start,
                    end: segment.end,
                    inset: lineWidth / 2
                )
                    .stroke(
                        widgetGaugeColor(for: section.color),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
                    )
            }

            if let first = gauge.sections.first {
                instrumentEndpointCap(
                    value: first.lowerBound,
                    color: widgetGaugeColor(for: first.color),
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }

            if let last = gauge.sections.last {
                instrumentEndpointCap(
                    value: last.upperBound,
                    color: widgetGaugeColor(for: last.color),
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }
        } else {
            WidgetGaugeInstrumentArcShape(start: 0, end: 1, inset: lineWidth / 2)
                .stroke(
                    Color.secondary.opacity(0.16),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
        }
    }

    private func instrumentValueIndicator(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let angle = Angle.degrees(150 + (240 * gauge.normalizedValue))
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

    private func normalized(_ value: Double) -> Double {
        guard gauge.upperBound > gauge.lowerBound else { return 0 }
        return min(max((value - gauge.lowerBound) / (gauge.upperBound - gauge.lowerBound), 0), 1)
    }

    private func visualSegment(for section: WidgetGaugeSection, at index: Int) -> (start: Double, end: Double) {
        let rawStart = normalized(section.lowerBound)
        let rawEnd = normalized(section.upperBound)
        let start = index == 0 ? rawStart : rawStart + (GaugeVisualMetrics.barSectionGap / 2)
        let end = index == gauge.sections.indices.last ? rawEnd : rawEnd - (GaugeVisualMetrics.barSectionGap / 2)
        return (min(max(start, 0), 1), min(max(end, start), 1))
    }

    private func instrumentSegment(for section: WidgetGaugeSection) -> (start: Double, end: Double) {
        let rawStart = normalized(section.lowerBound)
        let rawEnd = normalized(section.upperBound)
        return (rawStart, max(rawEnd, rawStart))
    }

    private func sectionBackgroundOpacity(for color: WidgetGaugeColor) -> Double {
        color == gauge.currentColor ? 0.34 : 0.22
    }

    private func instrumentContent(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        let valueFontSize = min(max(diameter * 0.25, 28), 58)
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let endpointY = (diameter / 2) + (radius * 0.5)
        let endpointBottomY = endpointY + (lineWidth / 2)
        let legendWidth = max((sqrt(3) * radius) - (lineWidth * 1.8), 0)
        let iconSize = instrumentIconSize(diameter: diameter)

        return AnyView(ZStack {
            instrumentReadout(fontSize: valueFontSize)
                .position(x: diameter / 2, y: diameter * 0.43)

            instrumentLegend(diameter: diameter)
                .frame(width: legendWidth)
                .frame(height: iconSize, alignment: .bottom)
                .position(x: diameter / 2, y: endpointBottomY - (iconSize / 2))
        })
    }

    private func instrumentLegend(diameter: CGFloat) -> some View {
        let iconSize = instrumentIconSize(diameter: diameter)

        return HStack(alignment: .bottom, spacing: 0) {
            Text(rangeText(gauge.lowerBound))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let icon {
                HomesteadIconView(
                    icon: icon,
                    pointSize: 21,
                    weight: .semibold
                )
                .foregroundStyle(tint)
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
            } else {
                Color.clear
                    .frame(width: iconSize, height: iconSize)
            }

            Text(rangeText(gauge.upperBound))
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

    private func instrumentReadout(fontSize: CGFloat) -> some View {
        let parts = gaugeValueParts(from: gauge.valueText, unitText: gauge.unitText)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.value)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            if let unit = parts.unit {
                Text(unit)
                    .font(.system(size: fontSize * 0.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .baselineOffset(fontSize * 0.08)
                    .padding(.leading, -1)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .monospacedDigit()
        .contentTransition(.numericText(value: gauge.value))
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: gauge.value)
    }

    private func rangeText(_ value: Double) -> String {
        widgetGaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct WidgetGaugeInstrumentArcShape: Shape {
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

func gaugeVisualStatusColor(for status: GaugeVisualStatus) -> Color {
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

func widgetGaugeColor(for color: WidgetGaugeColor) -> Color {
    switch color {
    case .blue:
        .blue
    case .green:
        .green
    case .orange:
        .orange
    case .red:
        .red
    case .purple:
        .purple
    case .gray:
        .gray
    }
}

func gaugeSectionBackgroundOpacity(current: GaugeVisualStatus, section: GaugeVisualStatus) -> Double {
    switch current {
    case .nominal:
        section == .nominal ? 0.18 : 0.10
    case .low, .high, .warning, .critical:
        section == current ? 0.28 : 0.16
    }
}

func gaugeDisplayIcon(base icon: ResolvedIcon, value: Double, status: GaugeVisualStatus) -> ResolvedIcon {
    switch icon.provenance {
    case .dashboardOverride, .appOverride, .haRegistryIcon, .haExplicitIcon:
        return icon
    case .haSemanticMapping, .homesteadSemanticMapping, .fallback:
        break
    }

    let currentSymbol = icon.sfSymbolName
    guard currentSymbol.hasPrefix("battery."),
          !currentSymbol.contains("bolt") else {
        return icon
    }

    let symbol: String
    if status == .critical || value <= 10 {
        symbol = "battery.0percent"
    } else if status == .warning || status == .low || value <= 25 {
        symbol = "battery.25percent"
    } else if value <= 50 {
        symbol = "battery.50percent"
    } else if value <= 85 {
        symbol = "battery.75percent"
    } else {
        symbol = "battery.100percent"
    }

    guard symbol != currentSymbol else {
        return icon
    }

    return .sfSymbol(
        symbol,
        provenance: icon.provenance,
        sourceIdentifier: icon.sourceIdentifier
    )
}

struct WidgetGaugeBarView: View {
    let gauge: WidgetGaugePresentation

    var body: some View {
        VStack(spacing: GaugeVisualMetrics.barRangeMarkerSpacing) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let fillWidth = max(width * CGFloat(gauge.normalizedValue), GaugeVisualMetrics.barMinimumFillWidth)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.16))

                    ForEach(Array(gauge.sections.enumerated()), id: \.offset) { index, section in
                        let segment = visualSegment(for: section, at: index)
                        let segmentWidth = max(CGFloat(segment.end - segment.start) * width, 0)

                        Capsule()
                            .fill(widgetGaugeColor(for: section.color).opacity(sectionBackgroundOpacity(for: section.color)))
                            .frame(width: segmentWidth)
                            .offset(x: CGFloat(segment.start) * width)
                    }

                    if gauge.normalizedValue > 0 {
                        Capsule()
                            .fill(widgetGaugeColor(for: gauge.currentColor))
                            .frame(width: fillWidth)
                    }

                    Capsule()
                        .strokeBorder(Color.white.opacity(GaugeVisualMetrics.barBorderOpacity), lineWidth: 1)

                    sectionBoundaryTicks(width: width)
                }
            }
            .frame(height: GaugeVisualMetrics.barTrackHeight)
            .clipShape(Capsule())

            HStack {
                Text(rangeText(gauge.lowerBound))
                Spacer(minLength: 8)
                Text(rangeText(gauge.upperBound))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.secondary.opacity(GaugeVisualMetrics.barRangeMarkerOpacity))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .monospacedDigit()
        }
        .frame(height: GaugeVisualMetrics.barTotalHeight)
    }

    private func visualSegment(for section: WidgetGaugeSection, at index: Int) -> (start: Double, end: Double) {
        let rawStart = normalized(section.lowerBound)
        let rawEnd = normalized(section.upperBound)
        let start = index == 0 ? rawStart : rawStart + (GaugeVisualMetrics.barSectionGap / 2)
        let end = index == gauge.sections.indices.last ? rawEnd : rawEnd - (GaugeVisualMetrics.barSectionGap / 2)

        return (min(max(start, 0), 1), min(max(end, start), 1))
    }

    private func normalized(_ value: Double) -> Double {
        guard gauge.upperBound > gauge.lowerBound else { return 0 }
        let normalizedValue = (value - gauge.lowerBound) / (gauge.upperBound - gauge.lowerBound)
        return min(max(normalizedValue, 0), 1)
    }

    private func sectionBackgroundOpacity(for color: WidgetGaugeColor) -> Double {
        color == gauge.currentColor ? 0.34 : 0.22
    }

    private func rangeText(_ value: Double) -> String {
        widgetGaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    @ViewBuilder
    private func sectionBoundaryTicks(width: CGFloat) -> some View {
        ForEach(gauge.sections.indices.dropLast(), id: \.self) { index in
            let boundary = normalized(gauge.sections[index].upperBound)
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
}

func gaugeValueParts(from valueText: String, unitText: String?) -> (value: String, unit: String?) {
    guard let unitText,
          !unitText.isEmpty else {
        return (valueText, nil)
    }

    guard valueText.hasSuffix(unitText) else {
        return (valueText, unitText)
    }

    let value = valueText.dropLast(unitText.count).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
        return (valueText, nil)
    }

    return (value, unitText)
}

extension WidgetGaugeStatus {
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

let widgetGaugeRangeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    return formatter
}()

extension WidgetGaugePresentation {
    static let previewBattery = WidgetGaugePresentation(
        value: 100,
        lowerBound: 0,
        upperBound: 100,
        valueText: "100",
        unitText: "%",
        status: .nominal,
        statusDisplayText: "Normal",
        sections: [
            WidgetGaugeSection(lowerBound: 0, upperBound: 10, color: .red),
            WidgetGaugeSection(lowerBound: 10, upperBound: 20, color: .orange),
            WidgetGaugeSection(lowerBound: 20, upperBound: 100, color: .green)
        ],
        accessibilityLabel: "Battery gauge",
        accessibilityValue: "100%"
    )

    static let previewLowBattery = WidgetGaugePresentation(
        value: 18,
        lowerBound: 0,
        upperBound: 100,
        valueText: "18",
        unitText: "%",
        status: .warning,
        statusDisplayText: "Warning",
        sections: [
            WidgetGaugeSection(lowerBound: 0, upperBound: 10, color: .red),
            WidgetGaugeSection(lowerBound: 10, upperBound: 20, color: .orange),
            WidgetGaugeSection(lowerBound: 20, upperBound: 100, color: .green)
        ],
        accessibilityLabel: "Battery gauge",
        accessibilityValue: "18%, warning"
    )
}
