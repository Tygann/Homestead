import SwiftUI

struct WeatherForecastTemperatureRangeBar: View {
    let range: ClosedRange<Double>
    let domain: ClosedRange<Double>
    let temperatureUnit: String?
    var trackColor = Color(.tertiarySystemFill)
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let domainSpan = max(domain.upperBound - domain.lowerBound, 1)
            let start = min(max((range.lowerBound - domain.lowerBound) / domainSpan, 0), 1)
            let end = min(max((range.upperBound - domain.lowerBound) / domainSpan, start), 1)
            let startX = proxy.size.width * start
            let rangeWidth = max(proxy.size.width * (end - start), height)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: height)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                WeatherForecastTemperatureScale.color(
                                    for: range.lowerBound,
                                    unit: temperatureUnit
                                ),
                                WeatherForecastTemperatureScale.color(
                                    for: range.upperBound,
                                    unit: temperatureUnit
                                )
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: min(rangeWidth, max(proxy.size.width - startX, 0)),
                        height: height
                    )
                    .offset(x: startX)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }
}

enum WeatherForecastTemperatureScale {
    static func range(for entry: WeatherForecastEntry) -> ClosedRange<Double>? {
        guard let first = entry.lowTemperature ?? entry.temperature,
              let second = entry.temperature ?? entry.lowTemperature else {
            return nil
        }
        return min(first, second)...max(first, second)
    }

    static func domain(for entries: [WeatherForecastEntry]) -> ClosedRange<Double> {
        let ranges = entries.compactMap(range(for:))
        guard let minimum = ranges.map(\.lowerBound).min(),
              let maximum = ranges.map(\.upperBound).max() else {
            return 0...1
        }
        guard minimum < maximum else {
            return (minimum - 1)...(maximum + 1)
        }
        return minimum...maximum
    }

    static func color(for temperature: Double, unit: String?) -> Color {
        let fahrenheitTemperature: Double
        if unit == "C" || unit == "°C" {
            fahrenheitTemperature = (temperature * 9 / 5) + 32
        } else {
            fahrenheitTemperature = temperature
        }

        return switch fahrenheitTemperature {
        case ..<50:
            Color(red: 0.04, green: 0.52, blue: 1.00)
        case 50..<60:
            interpolatedColor(
                progress: (fahrenheitTemperature - 50) / 10,
                from: (0.04, 0.52, 1.00),
                to: (0.39, 0.82, 1.00)
            )
        case 60..<68:
            interpolatedColor(
                progress: (fahrenheitTemperature - 60) / 8,
                from: (0.39, 0.82, 1.00),
                to: (1.00, 0.84, 0.04)
            )
        case 68..<76:
            interpolatedColor(
                progress: (fahrenheitTemperature - 68) / 8,
                from: (1.00, 0.84, 0.04),
                to: (1.00, 0.62, 0.04)
            )
        case 76..<100:
            interpolatedColor(
                progress: (fahrenheitTemperature - 76) / 24,
                from: (1.00, 0.62, 0.04),
                to: (1.00, 0.27, 0.23)
            )
        default:
            Color(red: 1.00, green: 0.27, blue: 0.23)
        }
    }

    private static func interpolatedColor(
        progress: Double,
        from start: (red: Double, green: Double, blue: Double),
        to end: (red: Double, green: Double, blue: Double)
    ) -> Color {
        let progress = min(max(progress, 0), 1)
        return Color(
            red: start.red + ((end.red - start.red) * progress),
            green: start.green + ((end.green - start.green) * progress),
            blue: start.blue + ((end.blue - start.blue) * progress)
        )
    }
}
