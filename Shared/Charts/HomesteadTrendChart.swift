import Charts
import SwiftUI

// MARK: - Presentation

nonisolated enum HomesteadTrendChartInterpolationStyle: String, Codable, Equatable, Sendable {
    case linear
    case smooth
}

nonisolated struct HomesteadTrendChartSample: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let value: Double

    init(occurredAt: Date, value: Double) {
        id = "\(occurredAt.timeIntervalSince1970)-\(value)"
        self.occurredAt = occurredAt
        self.value = value
    }
}

nonisolated enum HomesteadTrendChartDomain {
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

struct HomesteadTrendChartPlot: View {
    let samples: [HomesteadTrendChartSample]
    let valueDomain: ClosedRange<Double>
    let accentColor: Color
    let interpolationStyle: HomesteadTrendChartInterpolationStyle

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
        HomesteadTrendChartDomain.addingHeadroom(to: valueDomain)
    }

    private var interpolationMethod: InterpolationMethod {
        interpolationStyle == .smooth ? .catmullRom : .linear
    }
}
