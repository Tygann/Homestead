import SwiftUI
import WidgetKit

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
    case compactSegmented

    var isSegmented: Bool {
        self != .standard
    }

    var isCompact: Bool {
        self == .compactSegmented
    }
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
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let gauge: WidgetGaugePresentation
    let tint: Color
    var title: String? = nil
    var icon: ResolvedIcon? = nil
    var style: WidgetGaugeInstrumentStyle = .standard

    var body: some View {
        GaugeInstrumentCanvas(
            presentation: GaugeInstrumentVisualPresentation(
                value: gauge.value,
                lowerBound: gauge.lowerBound,
                upperBound: gauge.upperBound,
                valueText: gauge.valueText,
                unitText: gauge.unitText,
                lowerBoundText: rangeText(gauge.lowerBound),
                upperBoundText: rangeText(gauge.upperBound),
                sections: gauge.sections.map { section in
                    GaugeInstrumentVisualSection(
                        lowerBound: section.lowerBound,
                        upperBound: section.upperBound,
                        color: widgetGaugeColor(for: section.color)
                    )
                },
                accessibilityLabel: gauge.accessibilityLabel,
                accessibilityValue: gauge.accessibilityValue
            ),
            tint: tint,
            title: title,
            icon: icon,
            trackStyle: style.isSegmented ? .segmented : .continuous,
            density: style.isCompact ? .compact : .standard,
            renderingStyle: widgetRenderingMode == .accented ? .accented : .fullColor
        )
    }

    private func rangeText(_ value: Double) -> String {
        widgetGaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct GaugeInstrumentReadoutView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let valueText: String
    let unitText: String?
    let value: Double
    let fontSize: CGFloat
    let diameter: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        let parts = gaugeValueParts(from: valueText, unitText: unitText)
        let readoutWidth = max(diameter - (lineWidth * 3.6), diameter * 0.45)

        ZStack {
            valueLabel(parts.value)
                .frame(width: readoutWidth)
                .position(x: diameter / 2, y: diameter * 0.37)

            if let unit = parts.unit {
                unitLabel(unit)
                    .frame(width: readoutWidth)
                    .position(x: diameter / 2, y: diameter * 0.53)
            }
        }
        .frame(width: diameter, height: diameter)
        .monospacedDigit()
        .contentTransition(.numericText(value: value))
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: value)
    }

    private func unitLabel(_ unit: String) -> some View {
        Text(unit)
            .font(.system(size: fontSize * 0.28, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func valueLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity)
    }
}

struct WidgetGaugeInstrumentArcShape: Shape {
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

struct WidgetGaugeCompactInstrumentView: View {
    let gauge: WidgetGaugePresentation
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let lineWidth = min(max(diameter * 0.095, 5), 9)

            ZStack {
                WidgetGaugeInstrumentArcShape(start: 0, end: 1, inset: lineWidth / 2)
                    .stroke(
                        Color.secondary.opacity(0.16),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                if gauge.normalizedValue > 0 {
                    WidgetGaugeInstrumentArcShape(
                        start: 0,
                        end: gauge.normalizedValue,
                        inset: lineWidth / 2
                    )
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                }

                GaugeInstrumentReadoutView(
                    valueText: gauge.valueText,
                    unitText: gauge.unitText,
                    value: gauge.value,
                    fontSize: min(max(diameter * 0.23, 14), 24),
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gauge.accessibilityLabel)
        .accessibilityValue(gauge.accessibilityValue)
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
    case .accent:
        .accentColor
    case .blue:
        .blue
    case .cyan:
        .cyan
    case .green:
        .green
    case .yellow:
        .yellow
    case .orange:
        .orange
    case .mint:
        .mint
    case .red:
        .red
    case .purple:
        .purple
    case .gray:
        .gray
    }
}

func widgetGaugeColor(for color: GaugeZoneColor) -> Color {
    color.color
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

    private func sectionBackgroundOpacity(for color: GaugeZoneColor) -> Double {
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
