import SwiftUI

struct WidgetGaugeInstrumentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let gauge: WidgetGaugePresentation
    let tint: Color
    var title: String? = nil
    var icon: ResolvedIcon? = nil

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
                        WidgetGaugeInstrumentArcShape(start: 0, end: 1, inset: lineWidth / 2)
                            .stroke(
                                Color.secondary.opacity(0.16),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )

                        if gauge.normalizedValue > 0 {
                            WidgetGaugeInstrumentArcShape(start: 0, end: gauge.normalizedValue, inset: lineWidth / 2)
                                .stroke(
                                    widgetGaugeStatusColor(for: gauge.status),
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

    private func instrumentContent(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        let valueFontSize = min(max(diameter * 0.25, 28), 58)
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let endpointY = (diameter / 2) + (radius * 0.5)
        let endpointBottomY = endpointY + (lineWidth / 2)
        let legendWidth = max((sqrt(3) * radius) - (lineWidth * 1.8), 0)
        let iconSize = instrumentIconSize(diameter: diameter)

        return ZStack {
            instrumentReadout(fontSize: valueFontSize)
                .position(x: diameter / 2, y: diameter * 0.43)

            instrumentLegend(diameter: diameter)
                .frame(width: legendWidth)
                .frame(height: iconSize, alignment: .bottom)
                .position(x: diameter / 2, y: endpointBottomY - (iconSize / 2))
        }
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
                    pointSize: iconSize,
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
        min(max(diameter * 0.19, 20), 34)
    }

    private func instrumentReadout(fontSize: CGFloat) -> some View {
        let parts = widgetGaugeValueParts(from: gauge.valueText, unitText: gauge.unitText)

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

    func path(in rect: CGRect) -> Path {
        let radius = max((min(rect.width, rect.height) / 2) - inset, 0)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let clampedStart = min(max(start, 0), 1)
        let clampedEnd = min(max(end, clampedStart), 1)
        var path = Path()
        let startAngle = 150 + (240 * clampedStart)
        let endAngle = 150 + (240 * clampedEnd)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )

        return path
    }
}

func widgetGaugeStatusColor(for status: WidgetGaugeStatus) -> Color {
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

struct WidgetGaugeBarView: View {
    let gauge: WidgetGaugePresentation

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { proxy in
                let fillWidth = max(proxy.size.width * CGFloat(gauge.normalizedValue), 4)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.fill.quaternary)

                    ForEach(Array(gauge.sections.enumerated()), id: \.offset) { _, section in
                        let segment = visualSegment(for: section)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(widgetGaugeStatusColor(for: section.status).opacity(sectionBackgroundOpacity(for: section.status)))
                            .frame(width: max(proxy.size.width * CGFloat(segment.width), 0))
                            .offset(x: proxy.size.width * CGFloat(segment.start))
                    }

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(widgetGaugeStatusColor(for: gauge.status))
                        .frame(width: fillWidth)
                }
            }

            HStack {
                Text(rangeText(gauge.lowerBound))
                Spacer(minLength: 8)
                Text(rangeText(gauge.upperBound))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private func visualSegment(for section: WidgetGaugeSection) -> (start: Double, width: Double) {
        let start = normalized(section.lowerBound)
        let end = normalized(section.upperBound)
        return (start, max(end - start, 0))
    }

    private func normalized(_ value: Double) -> Double {
        guard gauge.upperBound > gauge.lowerBound else { return 0 }
        let normalizedValue = (value - gauge.lowerBound) / (gauge.upperBound - gauge.lowerBound)
        return min(max(normalizedValue, 0), 1)
    }

    private func sectionBackgroundOpacity(for status: WidgetGaugeStatus) -> Double {
        status == gauge.status ? 0.28 : 0.14
    }

    private func rangeText(_ value: Double) -> String {
        widgetGaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

func widgetGaugeValueParts(from valueText: String, unitText: String?) -> (value: String, unit: String?) {
    guard let unitText,
          !unitText.isEmpty,
          valueText.hasSuffix(unitText) else {
        return (valueText, nil)
    }

    let value = valueText.dropLast(unitText.count).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
        return (valueText, nil)
    }

    return (value, unitText)
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
        valueText: "100%",
        unitText: "%",
        status: .nominal,
        statusDisplayText: "Normal",
        sections: [
            WidgetGaugeSection(lowerBound: 0, upperBound: 10, status: .critical),
            WidgetGaugeSection(lowerBound: 10, upperBound: 20, status: .warning),
            WidgetGaugeSection(lowerBound: 20, upperBound: 100, status: .nominal)
        ],
        accessibilityLabel: "Battery gauge",
        accessibilityValue: "100%"
    )

    static let previewLowBattery = WidgetGaugePresentation(
        value: 18,
        lowerBound: 0,
        upperBound: 100,
        valueText: "18%",
        unitText: "%",
        status: .warning,
        statusDisplayText: "Low",
        sections: [
            WidgetGaugeSection(lowerBound: 0, upperBound: 10, status: .critical),
            WidgetGaugeSection(lowerBound: 10, upperBound: 20, status: .warning),
            WidgetGaugeSection(lowerBound: 20, upperBound: 100, status: .nominal)
        ],
        accessibilityLabel: "Battery gauge",
        accessibilityValue: "18%, warning"
    )
}
