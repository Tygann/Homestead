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
            Text(gauge.valueText)
                .font(.system(size: valueFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
                .contentTransition(.numericText(value: gauge.value))
                .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: gauge.value)
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
