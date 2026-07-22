import SwiftUI

struct GaugeInstrumentVisualSection {
    let lowerBound: Double
    let upperBound: Double
    let color: Color
}

struct GaugeInstrumentVisualPresentation {
    let value: Double
    let lowerBound: Double
    let upperBound: Double
    let valueText: String
    let unitText: String?
    let lowerBoundText: String
    let upperBoundText: String
    let sections: [GaugeInstrumentVisualSection]
    let accessibilityLabel: String
    let accessibilityValue: String

    var normalizedValue: Double {
        normalized(value)
    }

    func normalized(_ value: Double) -> Double {
        guard upperBound > lowerBound else { return 0 }
        return min(max((value - lowerBound) / (upperBound - lowerBound), 0), 1)
    }
}

enum GaugeInstrumentTrackStyle {
    case continuous
    case segmented
}

enum GaugeInstrumentDensity {
    case standard
    case compact
}

enum GaugeInstrumentRenderingStyle {
    case fullColor
    case accented
}

/// The single instrument canvas used by app cards and widgets. Callers only adapt
/// their presentation model and choose the track style.
struct GaugeInstrumentCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentation: GaugeInstrumentVisualPresentation
    let tint: Color
    let title: String?
    let icon: ResolvedIcon?
    let trackStyle: GaugeInstrumentTrackStyle
    let density: GaugeInstrumentDensity
    var renderingStyle: GaugeInstrumentRenderingStyle = .fullColor
    var editableTitle: Binding<String>? = nil
    var editIcon: (() -> Void)? = nil
    var commitEditableTitle: (() -> Void)? = nil

    private let visibleInstrumentHeightRatio = 0.82
    private let accentedSectionGap = 0.012
    private let accentedSectionOpacity = 0.34
    private let accentedCurrentSectionOpacity = 0.58
    // The lower legend and icon add visual weight beneath the readout. Keep the
    // lockup together and lower it slightly without moving the instrument bounds.
    private let readoutVerticalOffsetRatio: CGFloat = 0.03

    var body: some View {
        GeometryReader { proxy in
            let titleHeight: CGFloat = title == nil ? 0 : 17
            let titleSpacing: CGFloat = title == nil ? 0 : 2
            let availableInstrumentHeight = max(proxy.size.height - titleHeight - titleSpacing, 0)
            let diameter = min(proxy.size.width, availableInstrumentHeight / visibleInstrumentHeightRatio)
            let visibleInstrumentHeight = diameter * visibleInstrumentHeightRatio
            let metrics = metrics(for: diameter)

            VStack(spacing: titleSpacing) {
                instrument(diameter: diameter, metrics: metrics)
                    .frame(width: diameter, height: diameter)
                    .frame(width: diameter, height: visibleInstrumentHeight, alignment: .top)

                if let editableTitle {
                    TextField("Card Name", text: editableTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: metrics.titleFontSize, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .submitLabel(.done)
                        .onSubmit { commitEditableTitle?() }
                        .padding(.horizontal, 3)
                        .frame(height: titleHeight)
                        .accessibilityLabel("Card name")
                } else if let title {
                    Text(title)
                        .font(.system(size: metrics.titleFontSize, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 3)
                        .frame(height: titleHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: editableTitle == nil && editIcon == nil ? .ignore : .contain)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private func instrument(diameter: CGFloat, metrics: Metrics) -> some View {
        ZStack {
            instrumentTrack(diameter: diameter, lineWidth: metrics.lineWidth)

            if trackStyle == .segmented {
                valueIndicator(diameter: diameter, lineWidth: metrics.lineWidth)
            } else if presentation.normalizedValue > 0 {
                GaugeInstrumentCanvasArcShape(
                    start: 0,
                    end: presentation.normalizedValue,
                    inset: metrics.lineWidth / 2
                )
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: metrics.lineWidth, lineCap: .round, lineJoin: .round)
                )
            }

            instrumentContent(diameter: diameter, metrics: metrics)
        }
    }

    @ViewBuilder
    private func instrumentTrack(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        if trackStyle == .segmented {
            ForEach(presentation.sections.indices, id: \.self) { index in
                let section = presentation.sections[index]
                instrumentSection(
                    section,
                    at: index,
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }
        } else {
            GaugeInstrumentCanvasArcShape(start: 0, end: 1, inset: lineWidth / 2)
                .stroke(
                    Color.secondary.opacity(0.16),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
        }
    }

    @ViewBuilder
    private func instrumentSection(
        _ section: GaugeInstrumentVisualSection,
        at index: Int,
        diameter: CGFloat,
        lineWidth: CGFloat
    ) -> some View {
        if renderingStyle == .accented {
            instrumentSectionGeometry(
                section,
                at: index,
                diameter: diameter,
                lineWidth: lineWidth
            )
            // Flatten the translucent arc and endpoint before applying opacity
            // so their overlap reads as one continuous rounded stroke.
            .compositingGroup()
            .opacity(sectionOpacity(for: section, at: index))
        } else {
            instrumentSectionGeometry(
                section,
                at: index,
                diameter: diameter,
                lineWidth: lineWidth
            )
        }
    }

    private func instrumentSectionGeometry(
        _ section: GaugeInstrumentVisualSection,
        at index: Int,
        diameter: CGFloat,
        lineWidth: CGFloat
    ) -> some View {
        let segment = instrumentSegment(for: section, at: index)
        let isFirstSection = index == presentation.sections.startIndex
        let isLastSection = index == presentation.sections.index(before: presentation.sections.endIndex)

        return ZStack {
            GaugeInstrumentCanvasArcShape(
                start: segment.start,
                end: segment.end,
                inset: lineWidth / 2
            )
            .stroke(
                section.color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
            )

            if isFirstSection {
                endpointCap(
                    value: section.lowerBound,
                    color: section.color,
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }

            if isLastSection {
                endpointCap(
                    value: section.upperBound,
                    color: section.color,
                    diameter: diameter,
                    lineWidth: lineWidth
                )
            }
        }
    }

    private func valueIndicator(diameter: CGFloat, lineWidth: CGFloat) -> some View {
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

    private func endpointCap(
        value: Double,
        color: Color,
        diameter: CGFloat,
        lineWidth: CGFloat
    ) -> some View {
        let radius = max((diameter / 2) - (lineWidth / 2), 0)
        let angle = Angle.degrees(150 + (240 * presentation.normalized(value)))

        return Circle()
            .fill(color)
            .frame(width: lineWidth, height: lineWidth)
            .position(
                x: (diameter / 2) + (radius * CGFloat(cos(angle.radians))),
                y: (diameter / 2) + (radius * CGFloat(sin(angle.radians)))
            )
    }

    private func instrumentSegment(
        for section: GaugeInstrumentVisualSection,
        at index: Int
    ) -> (start: Double, end: Double) {
        let rawStart = presentation.normalized(section.lowerBound)
        let rawEnd = presentation.normalized(section.upperBound)

        guard renderingStyle == .accented else {
            return (rawStart, max(rawEnd, rawStart))
        }

        // Accented rendering collapses every zone to white, so preserve the
        // segmentation structurally instead of depending on hue alone.
        let start = index == presentation.sections.startIndex
            ? rawStart
            : rawStart + (accentedSectionGap / 2)
        let end = index == presentation.sections.index(before: presentation.sections.endIndex)
            ? rawEnd
            : rawEnd - (accentedSectionGap / 2)
        return (start, max(end, start))
    }

    private func sectionOpacity(for section: GaugeInstrumentVisualSection, at index: Int) -> Double {
        guard renderingStyle == .accented else { return 1 }

        return isCurrentSection(section, at: index)
            ? accentedCurrentSectionOpacity
            : accentedSectionOpacity
    }

    private func isCurrentSection(_ section: GaugeInstrumentVisualSection, at index: Int) -> Bool {
        let isLastSection = index == presentation.sections.index(before: presentation.sections.endIndex)
        return presentation.value >= section.lowerBound
            && (presentation.value < section.upperBound
                || (isLastSection && presentation.value <= section.upperBound))
    }

    private func instrumentContent(diameter: CGFloat, metrics: Metrics) -> some View {
        let radius = max((diameter / 2) - (metrics.lineWidth / 2), 0)
        let endpointY = (diameter / 2) + (radius * 0.5)
        let endpointBottomY = endpointY + (metrics.lineWidth / 2)
        // Pull the range labels slightly inward so they have horizontal clearance
        // from the arc endpoint caps while remaining aligned to the instrument.
        let rangeLabelHorizontalInset = min(max(diameter * 0.025, 2), 4)
        let legendWidth = max(
            (sqrt(3) * radius) - (metrics.lineWidth * 1.1) - (rangeLabelHorizontalInset * 2),
            0
        )

        return ZStack {
            readout(diameter: diameter, metrics: metrics)

            legend(metrics: metrics)
                .frame(width: legendWidth, height: metrics.iconSize, alignment: .bottom)
                .position(x: diameter / 2, y: endpointBottomY - (metrics.iconSize / 2))
        }
    }

    private func readout(diameter: CGFloat, metrics: Metrics) -> some View {
        let parts = gaugeValueParts(from: presentation.valueText, unitText: presentation.unitText)
        let readoutWidth = max(diameter - (metrics.lineWidth * 3.6), diameter * 0.45)
        let readoutOffset = diameter * readoutVerticalOffsetRatio

        return ZStack {
            Text(parts.value)
                .font(.system(size: metrics.valueFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: readoutWidth)
                .position(x: diameter / 2, y: (diameter * 0.39) + readoutOffset)

            if let unit = parts.unit {
                Text(unit)
                    .font(.system(size: metrics.valueFontSize * 0.28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: readoutWidth)
                    .position(x: diameter / 2, y: (diameter * 0.55) + readoutOffset)
            }
        }
        .frame(width: diameter, height: diameter)
        .monospacedDigit()
        .contentTransition(.numericText(value: presentation.value))
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: presentation.value)
    }

    private func legend(metrics: Metrics) -> some View {
        HStack(alignment: .bottom, spacing: metrics.iconSize + 4) {
            legendLabel(presentation.lowerBoundText, alignment: .leading)
            legendLabel(presentation.upperBoundText, alignment: .trailing)
        }
        .overlay {
            if let icon {
                if let editIcon {
                    Button(action: editIcon) {
                        HomesteadIconView(
                            icon: icon,
                            pointSize: metrics.iconPointSize,
                            weight: .semibold
                        )
                        .foregroundStyle(tint)
                        .frame(width: metrics.iconSize, height: metrics.iconSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change card icon")
                    .accessibilityHint("Opens the icon picker")
                } else {
                    HomesteadIconView(
                        icon: icon,
                        pointSize: metrics.iconPointSize,
                        weight: .semibold
                    )
                    .foregroundStyle(tint)
                    .frame(width: metrics.iconSize, height: metrics.iconSize)
                    .accessibilityHidden(true)
                }
            }
        }
        .font(.system(size: metrics.rangeFontSize, weight: .semibold))
        .foregroundStyle(Color.secondary.opacity(0.72))
        .monospacedDigit()
    }

    private func legendLabel(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func metrics(for diameter: CGFloat) -> Metrics {
        switch density {
        case .standard:
            Metrics(
                lineWidth: min(max(diameter * 0.085, 7), 17),
                valueFontSize: min(max(diameter * 0.25, 22), 58),
                iconSize: min(max(diameter * 0.16, 16), 28),
                iconPointSize: min(max(diameter * 0.12, 12), 21),
                rangeFontSize: min(max(diameter * 0.055, 8), 11),
                titleFontSize: min(max(diameter * 0.06, 11), 12)
            )
        case .compact:
            Metrics(
                lineWidth: min(max(diameter * 0.08, 5), 7),
                valueFontSize: min(max(diameter * 0.24, 15), 22),
                iconSize: min(max(diameter * 0.18, 12), 16),
                iconPointSize: min(max(diameter * 0.14, 10), 13),
                rangeFontSize: min(max(diameter * 0.08, 7), 8),
                titleFontSize: min(max(diameter * 0.11, 9), 10)
            )
        }
    }

    private struct Metrics {
        let lineWidth: CGFloat
        let valueFontSize: CGFloat
        let iconSize: CGFloat
        let iconPointSize: CGFloat
        let rangeFontSize: CGFloat
        let titleFontSize: CGFloat
    }
}

private struct GaugeInstrumentCanvasArcShape: Shape {
    let start: Double
    let end: Double
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = max((min(rect.width, rect.height) / 2) - inset, 0)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let clampedStart = min(max(start, 0), 1)
        let clampedEnd = min(max(end, clampedStart), 1)
        var path = Path()

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(150 + (240 * clampedStart)),
            endAngle: .degrees(150 + (240 * clampedEnd)),
            clockwise: false
        )

        return path
    }
}
