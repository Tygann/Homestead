import Charts
import SwiftUI

// MARK: - Presentation

nonisolated enum HomesteadChartInterpolationStyle: String, Codable, Equatable, Sendable {
    case linear
    case smooth
}

nonisolated struct HomesteadChartSample: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let value: Double

    init(occurredAt: Date, value: Double) {
        id = "\(occurredAt.timeIntervalSince1970)-\(value)"
        self.occurredAt = occurredAt
        self.value = value
    }
}

nonisolated enum HomesteadChartDomain {
    static func stabilized(values: [Double], unit: String?) -> ClosedRange<Double> {
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...1
        }

        let midpoint = (minimum + maximum) / 2
        let observedSpan = maximum - minimum
        let minimumSpan: Double

        switch unit {
        case "°F", "F": minimumSpan = 4
        case "°C", "C": minimumSpan = 2
        case "%": minimumSpan = 10
        default: minimumSpan = max(abs(midpoint) * 0.04, 1)
        }

        let displaySpan = max(observedSpan * 1.24, minimumSpan)
        return (midpoint - (displaySpan / 2))...(midpoint + (displaySpan / 2))
    }

    static func addingHeadroom(to domain: ClosedRange<Double>) -> ClosedRange<Double> {
        let headroom = (domain.upperBound - domain.lowerBound) * 0.04
        return (domain.lowerBound - headroom)...(domain.upperBound + headroom)
    }
}

// MARK: - Plot

struct HomesteadChartPlot: View {
    let samples: [HomesteadChartSample]
    let valueDomain: ClosedRange<Double>
    let accentColor: Color
    let interpolationStyle: HomesteadChartInterpolationStyle

    var body: some View {
        Chart(samples) { sample in
            AreaMark(
                x: .value("Time", sample.occurredAt),
                yStart: .value("Baseline", displayDomain.lowerBound),
                yEnd: .value("Value", sample.value)
            )
            .interpolationMethod(interpolationMethod)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.16),
                        accentColor.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", sample.occurredAt),
                y: .value("Value", sample.value)
            )
            .interpolationMethod(interpolationMethod)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .foregroundStyle(accentColor)
        }
        .chartYScale(domain: displayDomain)
        .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 0))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.clipped()
        }
        .clipped()
    }

    private var displayDomain: ClosedRange<Double> {
        HomesteadChartDomain.addingHeadroom(to: valueDomain)
    }

    private var interpolationMethod: InterpolationMethod {
        interpolationStyle == .smooth ? .catmullRom : .linear
    }
}

// MARK: - Widget Composition

nonisolated struct HomesteadWidgetChartPresentation: Equatable, Sendable {
    let title: String
    let valueText: String
    let unitText: String?
    let icon: ResolvedIcon
    let isAvailable: Bool
    let samples: [HomesteadChartSample]
    let valueDomain: ClosedRange<Double>
    let interpolationStyle: HomesteadChartInterpolationStyle
    let rangeTitle: String
    let changeSummaryText: String?
    let emptyLabel: String
}

nonisolated enum HomesteadWidgetChartDensity: Equatable, Sendable {
    case compact
    case small
    case medium
}

struct HomesteadWidgetChartFace: View {
    let presentation: HomesteadWidgetChartPresentation
    let accentColor: Color
    let density: HomesteadWidgetChartDensity

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                chartLayer
                    .frame(height: proxy.size.height * chartHeightFraction)

                VStack(alignment: .leading, spacing: headerSpacing) {
                    HStack(spacing: titleSpacing) {
                        HomesteadIconView(
                            icon: presentation.icon,
                            pointSize: iconPointSize,
                            weight: .semibold
                        )
                        .foregroundStyle(resolvedAccentColor)

                        Text(presentation.title)
                            .font(titleFont)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Spacer(minLength: 4)

                        if density == .medium {
                            trailingSummary
                        }
                    }

                    valueLabel
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presentation.title) chart")
        .accessibilityValue(
            presentation.isAvailable
                ? "\(presentation.valueText), \(presentation.rangeTitle.lowercased()) chart"
                : "Unavailable, \(presentation.emptyLabel.lowercased())"
        )
    }

    @ViewBuilder
    private var chartLayer: some View {
        if presentation.samples.count >= 2 {
            HomesteadChartPlot(
                samples: presentation.samples,
                valueDomain: presentation.valueDomain,
                accentColor: resolvedAccentColor,
                interpolationStyle: presentation.interpolationStyle
            )
        } else {
            HomesteadChartPlaceholder(
                accentColor: resolvedAccentColor,
                label: density == .compact ? nil : presentation.emptyLabel,
                horizontalPadding: contentPadding
            )
        }
    }

    private var valueLabel: some View {
        let parts = gaugeValueParts(
            from: presentation.isAvailable ? presentation.valueText : "—",
            unitText: presentation.unitText
        )

        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(parts.value)
                .font(.system(size: valueFontSize, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .monospacedDigit()

            if let unit = parts.unit, presentation.isAvailable {
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var trailingSummary: some View {
        HStack(spacing: 3) {
            Text(presentation.rangeTitle)

            if let changeSummaryText = presentation.changeSummaryText {
                Text("·")
                Text(changeSummaryText)
            }
        }
        .font(.caption2.monospacedDigit().weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var resolvedAccentColor: Color {
        presentation.isAvailable ? accentColor : .secondary
    }

    private var contentPadding: CGFloat {
        density == .compact ? 0 : 16
    }

    private var chartHeightFraction: CGFloat {
        switch density {
        case .compact, .small: 0.35
        case .medium: 0.48
        }
    }

    private var headerSpacing: CGFloat {
        density == .compact ? 3 : 5
    }

    private var titleSpacing: CGFloat {
        density == .compact ? 6 : 8
    }

    private var iconPointSize: CGFloat {
        density == .compact ? 13 : 18
    }

    private var titleFont: Font {
        density == .compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold)
    }

    private var valueFontSize: CGFloat {
        density == .compact ? 24 : 38
    }

    private var unitFont: Font {
        density == .compact ? .caption.weight(.semibold) : .title3.weight(.semibold)
    }
}

private struct HomesteadChartPlaceholder: View {
    let accentColor: Color
    let label: String?
    let horizontalPadding: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.12),
                    accentColor.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(accentColor.opacity(0.36))
                .frame(height: 2)

            if let label {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 8)
            } else {
                Image(systemName: "chart.xyaxis.line")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 7)
            }
        }
    }
}
