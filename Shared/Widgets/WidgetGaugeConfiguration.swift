import AppIntents
import Foundation

enum HomesteadGaugeScale: String, AppEnum {
    case automatic
    case custom

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Scale")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "Automatic",
        .custom: "Custom"
    ]
}

enum HomesteadGaugeZoneCount: Int, AppEnum {
    case automatic = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Zones")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "Automatic",
        .one: "1",
        .two: "2",
        .three: "3",
        .four: "4",
        .five: "5"
    ]
}

enum HomesteadGaugeZoneColor: String, AppEnum {
    case blue
    case green
    case orange
    case red
    case purple
    case gray

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Zone Color")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .blue: "Blue",
        .green: "Green",
        .orange: "Orange",
        .red: "Red",
        .purple: "Purple",
        .gray: "Gray"
    ]

    var widgetColor: WidgetGaugeColor {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .purple: .purple
        case .gray: .gray
        }
    }
}

enum HomesteadSensorWidgetDisplay: String, AppEnum {
    case reading
    case chart
    case circularGauge
    case segmentedGauge
    case barGauge

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [HomesteadSensorWidgetDisplay: DisplayRepresentation] = [
        .reading: "Reading",
        .chart: "Chart",
        .circularGauge: "Gauge - Circular",
        .segmentedGauge: "Gauge - Segmented",
        .barGauge: "Gauge - Bar"
    ]
}


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

func sensorBoardGaugeConfiguration(
    gaugeScale: HomesteadGaugeScale,
    gaugeMinimum: Double?,
    gaugeMaximum: Double?,
    zoneCount: HomesteadGaugeZoneCount,
    zone1Color: HomesteadGaugeZoneColor,
    zone2BeginsAt: Double?,
    zone2Color: HomesteadGaugeZoneColor,
    zone3BeginsAt: Double?,
    zone3Color: HomesteadGaugeZoneColor,
    zone4BeginsAt: Double?,
    zone4Color: HomesteadGaugeZoneColor,
    zone5BeginsAt: Double?,
    zone5Color: HomesteadGaugeZoneColor
) -> HomesteadGaugeWidgetConfiguration {
    HomesteadGaugeWidgetConfiguration(
        customDisplayName: nil,
        display: .segmentedGauge,
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

extension WidgetSensorBoardCompactItem {
    func applyingGaugeConfiguration(_ configuration: HomesteadGaugeWidgetConfiguration) -> Self {
        guard let gauge else { return self }

        return Self(
            id: id,
            displayName: displayName,
            icon: icon,
            valueText: valueText,
            isAvailable: isAvailable,
            requestedPresentation: requestedPresentation,
            gauge: configuration.resolvedGauge(gauge)
        )
    }
}
