import Foundation

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
