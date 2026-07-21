import Foundation

struct HomesteadGaugeWidgetConfiguration: Equatable, Sendable {
    let customDisplayName: String?
    let display: HomesteadSensorWidgetDisplay
    let gaugeScale: HomesteadGaugeScale
    let gaugeMinimum: Double?
    let gaugeMaximum: Double?
    let zoneCount: HomesteadGaugeZoneCount
    let zone1Color: HomesteadGaugeZoneColor
    let zone2BeginsAt: Double?
    let zone2Color: HomesteadGaugeZoneColor
    let zone3BeginsAt: Double?
    let zone3Color: HomesteadGaugeZoneColor
    let zone4BeginsAt: Double?
    let zone4Color: HomesteadGaugeZoneColor
    let zone5BeginsAt: Double?
    let zone5Color: HomesteadGaugeZoneColor

    static let automatic = Self(
        customDisplayName: nil,
        display: .segmentedGauge,
        gaugeScale: .automatic,
        gaugeMinimum: nil,
        gaugeMaximum: nil,
        zoneCount: .automatic,
        zone1Color: .blue,
        zone2BeginsAt: nil,
        zone2Color: .green,
        zone3BeginsAt: nil,
        zone3Color: .orange,
        zone4BeginsAt: nil,
        zone4Color: .red,
        zone5BeginsAt: nil,
        zone5Color: .purple
    )

    func resolvedGauge(_ gauge: WidgetGaugePresentation) -> WidgetGaugePresentation {
        guard [.circularGauge, .segmentedGauge, .barGauge].contains(display) else { return gauge }

        let lowerBound = gaugeScale == .custom
            ? gaugeMinimum ?? gauge.lowerBound
            : gauge.lowerBound
        let upperBound = gaugeScale == .custom
            ? gaugeMaximum ?? gauge.upperBound
            : gauge.upperBound
        guard lowerBound < upperBound else { return gauge }

        let configuredBeginsAt = [zone2BeginsAt, zone3BeginsAt, zone4BeginsAt, zone5BeginsAt]
        if zoneCount == .automatic {
            let clippedSections = gauge.sections.compactMap { section -> WidgetGaugeSection? in
                let lower = max(section.lowerBound, lowerBound)
                let upper = min(section.upperBound, upperBound)
                guard lower < upper else { return nil }
                return WidgetGaugeSection(lowerBound: lower, upperBound: upper, color: section.color)
            }
            let sections = clippedSections.isEmpty
                ? [WidgetGaugeSection(lowerBound: lowerBound, upperBound: upperBound, color: .green)]
                : clippedSections

            return gauge.applyingConfiguration(
                lowerBound: lowerBound,
                boundaries: sections.dropLast().map(\.upperBound),
                upperBound: upperBound,
                colors: sections.map(\.color)
            )
        }

        let zoneCount = zoneCount.rawValue
        let configuredBoundaries = configuredBeginsAt.prefix(max(zoneCount - 1, 0))
        let span = upperBound - lowerBound
        let boundaries = configuredBoundaries.enumerated().map { index, value in
            value ?? lowerBound + (span * Double(index + 1) / Double(zoneCount))
        }
        let colors = [
            zone1Color.widgetColor,
            zone2Color.widgetColor,
            zone3Color.widgetColor,
            zone4Color.widgetColor,
            zone5Color.widgetColor
        ].prefix(zoneCount).map { $0 }

        return gauge.applyingConfiguration(
            lowerBound: lowerBound,
            boundaries: boundaries,
            upperBound: upperBound,
            colors: colors
        )
    }

    var resolvedDisplayName: String? {
        let value = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}

extension HomesteadSensorChartWidgetConfigurationIntent {
    var gaugeWidgetConfiguration: HomesteadGaugeWidgetConfiguration {
        HomesteadGaugeWidgetConfiguration(
            customDisplayName: customDisplayName,
            display: display ?? .chart,
            gaugeScale: gaugeScale,
            gaugeMinimum: gaugeMinimum,
            gaugeMaximum: gaugeMaximum,
            zoneCount: zoneCount,
            zone1Color: zone1Color,
            zone2BeginsAt: zone2BeginsAt,
            zone2Color: zone2Color,
            zone3BeginsAt: zone3BeginsAt,
            zone3Color: zone3Color,
            zone4BeginsAt: zone4BeginsAt,
            zone4Color: zone4Color,
            zone5BeginsAt: zone5BeginsAt,
            zone5Color: zone5Color
        )
    }
}
