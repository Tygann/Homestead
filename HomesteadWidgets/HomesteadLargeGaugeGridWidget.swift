import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadLargeGaugeGridWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadLargeGaugeGridWidget",
            intent: HomesteadLargeGaugeGridWidgetConfigurationIntent.self,
            provider: HomesteadLargeGaugeGridTimelineProvider()
        ) { entry in
            HomesteadGaugeGridWidgetView(entry: entry, layout: .large)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Large Gauge Grid")
        .description("Show up to six Home Assistant gauges.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct HomesteadLargeGaugeGridWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Large Gauge Grid"
    static var description = IntentDescription("Choose up to six Home Assistant gauges.")

    @Parameter(title: "Gauge 1") var item1: HomesteadWidgetItemEntity?
    @Parameter(title: "Gauge 1 Display Name") var customDisplayName1: String?
    @Parameter(title: "Gauge 1 Display", default: .segmentedGauge) var display1: HomesteadSensorWidgetDisplay
    @Parameter(title: "Gauge 1 Scale", default: .automatic) var gaugeScale1: HomesteadGaugeScale
    @Parameter(title: "Gauge 1 Minimum") var gaugeMinimum1: Double?
    @Parameter(title: "Gauge 1 Maximum") var gaugeMaximum1: Double?
    @Parameter(title: "Gauge 1 Zones", default: .automatic) var zoneCount1: HomesteadGaugeZoneCount
    @Parameter(title: "Gauge 1 Zone 1 Color", default: .blue) var zone1Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 1 Zone 2 Begins At") var zone2BeginsAt1: Double?
    @Parameter(title: "Gauge 1 Zone 2 Color", default: .green) var zone2Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 1 Zone 3 Begins At") var zone3BeginsAt1: Double?
    @Parameter(title: "Gauge 1 Zone 3 Color", default: .orange) var zone3Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 1 Zone 4 Begins At") var zone4BeginsAt1: Double?
    @Parameter(title: "Gauge 1 Zone 4 Color", default: .red) var zone4Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 1 Zone 5 Begins At") var zone5BeginsAt1: Double?
    @Parameter(title: "Gauge 1 Zone 5 Color", default: .purple) var zone5Color1: HomesteadGaugeZoneColor

    @Parameter(title: "Gauge 2") var item2: HomesteadWidgetItemEntity?
    @Parameter(title: "Gauge 2 Display Name") var customDisplayName2: String?
    @Parameter(title: "Gauge 2 Display", default: .segmentedGauge) var display2: HomesteadSensorWidgetDisplay
    @Parameter(title: "Gauge 2 Scale", default: .automatic) var gaugeScale2: HomesteadGaugeScale
    @Parameter(title: "Gauge 2 Minimum") var gaugeMinimum2: Double?
    @Parameter(title: "Gauge 2 Maximum") var gaugeMaximum2: Double?
    @Parameter(title: "Gauge 2 Zones", default: .automatic) var zoneCount2: HomesteadGaugeZoneCount
    @Parameter(title: "Gauge 2 Zone 1 Color", default: .blue) var zone1Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 2 Zone 2 Begins At") var zone2BeginsAt2: Double?
    @Parameter(title: "Gauge 2 Zone 2 Color", default: .green) var zone2Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 2 Zone 3 Begins At") var zone3BeginsAt2: Double?
    @Parameter(title: "Gauge 2 Zone 3 Color", default: .orange) var zone3Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 2 Zone 4 Begins At") var zone4BeginsAt2: Double?
    @Parameter(title: "Gauge 2 Zone 4 Color", default: .red) var zone4Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 2 Zone 5 Begins At") var zone5BeginsAt2: Double?
    @Parameter(title: "Gauge 2 Zone 5 Color", default: .purple) var zone5Color2: HomesteadGaugeZoneColor

    @Parameter(title: "Gauge 3") var item3: HomesteadWidgetItemEntity?
    @Parameter(title: "Gauge 3 Display Name") var customDisplayName3: String?
    @Parameter(title: "Gauge 3 Display", default: .segmentedGauge) var display3: HomesteadSensorWidgetDisplay
    @Parameter(title: "Gauge 3 Scale", default: .automatic) var gaugeScale3: HomesteadGaugeScale
    @Parameter(title: "Gauge 3 Minimum") var gaugeMinimum3: Double?
    @Parameter(title: "Gauge 3 Maximum") var gaugeMaximum3: Double?
    @Parameter(title: "Gauge 3 Zones", default: .automatic) var zoneCount3: HomesteadGaugeZoneCount
    @Parameter(title: "Gauge 3 Zone 1 Color", default: .blue) var zone1Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 3 Zone 2 Begins At") var zone2BeginsAt3: Double?
    @Parameter(title: "Gauge 3 Zone 2 Color", default: .green) var zone2Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 3 Zone 3 Begins At") var zone3BeginsAt3: Double?
    @Parameter(title: "Gauge 3 Zone 3 Color", default: .orange) var zone3Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 3 Zone 4 Begins At") var zone4BeginsAt3: Double?
    @Parameter(title: "Gauge 3 Zone 4 Color", default: .red) var zone4Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 3 Zone 5 Begins At") var zone5BeginsAt3: Double?
    @Parameter(title: "Gauge 3 Zone 5 Color", default: .purple) var zone5Color3: HomesteadGaugeZoneColor

    @Parameter(title: "Gauge 4") var item4: HomesteadWidgetItemEntity?
    @Parameter(title: "Gauge 4 Display Name") var customDisplayName4: String?
    @Parameter(title: "Gauge 4 Display", default: .segmentedGauge) var display4: HomesteadSensorWidgetDisplay
    @Parameter(title: "Gauge 4 Scale", default: .automatic) var gaugeScale4: HomesteadGaugeScale
    @Parameter(title: "Gauge 4 Minimum") var gaugeMinimum4: Double?
    @Parameter(title: "Gauge 4 Maximum") var gaugeMaximum4: Double?
    @Parameter(title: "Gauge 4 Zones", default: .automatic) var zoneCount4: HomesteadGaugeZoneCount
    @Parameter(title: "Gauge 4 Zone 1 Color", default: .blue) var zone1Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 4 Zone 2 Begins At") var zone2BeginsAt4: Double?
    @Parameter(title: "Gauge 4 Zone 2 Color", default: .green) var zone2Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 4 Zone 3 Begins At") var zone3BeginsAt4: Double?
    @Parameter(title: "Gauge 4 Zone 3 Color", default: .orange) var zone3Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 4 Zone 4 Begins At") var zone4BeginsAt4: Double?
    @Parameter(title: "Gauge 4 Zone 4 Color", default: .red) var zone4Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 4 Zone 5 Begins At") var zone5BeginsAt4: Double?
    @Parameter(title: "Gauge 4 Zone 5 Color", default: .purple) var zone5Color4: HomesteadGaugeZoneColor

    @Parameter(title: "Gauge 5") var item5: HomesteadWidgetItemEntity?
    @Parameter(title: "Gauge 5 Display Name") var customDisplayName5: String?
    @Parameter(title: "Gauge 5 Display", default: .segmentedGauge) var display5: HomesteadSensorWidgetDisplay
    @Parameter(title: "Gauge 5 Scale", default: .automatic) var gaugeScale5: HomesteadGaugeScale
    @Parameter(title: "Gauge 5 Minimum") var gaugeMinimum5: Double?
    @Parameter(title: "Gauge 5 Maximum") var gaugeMaximum5: Double?
    @Parameter(title: "Gauge 5 Zones", default: .automatic) var zoneCount5: HomesteadGaugeZoneCount
    @Parameter(title: "Gauge 5 Zone 1 Color", default: .blue) var zone1Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 5 Zone 2 Begins At") var zone2BeginsAt5: Double?
    @Parameter(title: "Gauge 5 Zone 2 Color", default: .green) var zone2Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 5 Zone 3 Begins At") var zone3BeginsAt5: Double?
    @Parameter(title: "Gauge 5 Zone 3 Color", default: .orange) var zone3Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 5 Zone 4 Begins At") var zone4BeginsAt5: Double?
    @Parameter(title: "Gauge 5 Zone 4 Color", default: .red) var zone4Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 5 Zone 5 Begins At") var zone5BeginsAt5: Double?
    @Parameter(title: "Gauge 5 Zone 5 Color", default: .purple) var zone5Color5: HomesteadGaugeZoneColor

    @Parameter(title: "Gauge 6") var item6: HomesteadWidgetItemEntity?
    @Parameter(title: "Gauge 6 Display Name") var customDisplayName6: String?
    @Parameter(title: "Gauge 6 Display", default: .segmentedGauge) var display6: HomesteadSensorWidgetDisplay
    @Parameter(title: "Gauge 6 Scale", default: .automatic) var gaugeScale6: HomesteadGaugeScale
    @Parameter(title: "Gauge 6 Minimum") var gaugeMinimum6: Double?
    @Parameter(title: "Gauge 6 Maximum") var gaugeMaximum6: Double?
    @Parameter(title: "Gauge 6 Zones", default: .automatic) var zoneCount6: HomesteadGaugeZoneCount
    @Parameter(title: "Gauge 6 Zone 1 Color", default: .blue) var zone1Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 6 Zone 2 Begins At") var zone2BeginsAt6: Double?
    @Parameter(title: "Gauge 6 Zone 2 Color", default: .green) var zone2Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 6 Zone 3 Begins At") var zone3BeginsAt6: Double?
    @Parameter(title: "Gauge 6 Zone 3 Color", default: .orange) var zone3Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 6 Zone 4 Begins At") var zone4BeginsAt6: Double?
    @Parameter(title: "Gauge 6 Zone 4 Color", default: .red) var zone4Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Gauge 6 Zone 5 Begins At") var zone5BeginsAt6: Double?
    @Parameter(title: "Gauge 6 Zone 5 Color", default: .purple) var zone5Color6: HomesteadGaugeZoneColor

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$item1
            \.$customDisplayName1
            \.$display1
            \.$gaugeScale1
            \.$gaugeMinimum1
            \.$gaugeMaximum1
            \.$zoneCount1
            \.$zone1Color1
            \.$zone2BeginsAt1
            \.$zone2Color1
            \.$zone3BeginsAt1
            \.$zone3Color1
            \.$zone4BeginsAt1
            \.$zone4Color1
            \.$zone5BeginsAt1
            \.$zone5Color1
            \.$item2
            \.$customDisplayName2
            \.$display2
            \.$gaugeScale2
            \.$gaugeMinimum2
            \.$gaugeMaximum2
            \.$zoneCount2
            \.$zone1Color2
            \.$zone2BeginsAt2
            \.$zone2Color2
            \.$zone3BeginsAt2
            \.$zone3Color2
            \.$zone4BeginsAt2
            \.$zone4Color2
            \.$zone5BeginsAt2
            \.$zone5Color2
            \.$item3
            \.$customDisplayName3
            \.$display3
            \.$gaugeScale3
            \.$gaugeMinimum3
            \.$gaugeMaximum3
            \.$zoneCount3
            \.$zone1Color3
            \.$zone2BeginsAt3
            \.$zone2Color3
            \.$zone3BeginsAt3
            \.$zone3Color3
            \.$zone4BeginsAt3
            \.$zone4Color3
            \.$zone5BeginsAt3
            \.$zone5Color3
            \.$item4
            \.$customDisplayName4
            \.$display4
            \.$gaugeScale4
            \.$gaugeMinimum4
            \.$gaugeMaximum4
            \.$zoneCount4
            \.$zone1Color4
            \.$zone2BeginsAt4
            \.$zone2Color4
            \.$zone3BeginsAt4
            \.$zone3Color4
            \.$zone4BeginsAt4
            \.$zone4Color4
            \.$zone5BeginsAt4
            \.$zone5Color4
            \.$item5
            \.$customDisplayName5
            \.$display5
            \.$gaugeScale5
            \.$gaugeMinimum5
            \.$gaugeMaximum5
            \.$zoneCount5
            \.$zone1Color5
            \.$zone2BeginsAt5
            \.$zone2Color5
            \.$zone3BeginsAt5
            \.$zone3Color5
            \.$zone4BeginsAt5
            \.$zone4Color5
            \.$zone5BeginsAt5
            \.$zone5Color5
            \.$item6
            \.$customDisplayName6
            \.$display6
            \.$gaugeScale6
            \.$gaugeMinimum6
            \.$gaugeMaximum6
            \.$zoneCount6
            \.$zone1Color6
            \.$zone2BeginsAt6
            \.$zone2Color6
            \.$zone3BeginsAt6
            \.$zone3Color6
            \.$zone4BeginsAt6
            \.$zone4Color6
            \.$zone5BeginsAt6
            \.$zone5Color6
        }
    }

    var selectedSlots: [HomesteadGaugeGridSlot] {
        [
            slot(item1, customDisplayName1, display1, gaugeScale1, gaugeMinimum1, gaugeMaximum1, zoneCount1, zone1Color1, zone2BeginsAt1, zone2Color1, zone3BeginsAt1, zone3Color1, zone4BeginsAt1, zone4Color1, zone5BeginsAt1, zone5Color1),
            slot(item2, customDisplayName2, display2, gaugeScale2, gaugeMinimum2, gaugeMaximum2, zoneCount2, zone1Color2, zone2BeginsAt2, zone2Color2, zone3BeginsAt2, zone3Color2, zone4BeginsAt2, zone4Color2, zone5BeginsAt2, zone5Color2),
            slot(item3, customDisplayName3, display3, gaugeScale3, gaugeMinimum3, gaugeMaximum3, zoneCount3, zone1Color3, zone2BeginsAt3, zone2Color3, zone3BeginsAt3, zone3Color3, zone4BeginsAt3, zone4Color3, zone5BeginsAt3, zone5Color3),
            slot(item4, customDisplayName4, display4, gaugeScale4, gaugeMinimum4, gaugeMaximum4, zoneCount4, zone1Color4, zone2BeginsAt4, zone2Color4, zone3BeginsAt4, zone3Color4, zone4BeginsAt4, zone4Color4, zone5BeginsAt4, zone5Color4),
            slot(item5, customDisplayName5, display5, gaugeScale5, gaugeMinimum5, gaugeMaximum5, zoneCount5, zone1Color5, zone2BeginsAt5, zone2Color5, zone3BeginsAt5, zone3Color5, zone4BeginsAt5, zone4Color5, zone5BeginsAt5, zone5Color5),
            slot(item6, customDisplayName6, display6, gaugeScale6, gaugeMinimum6, gaugeMaximum6, zoneCount6, zone1Color6, zone2BeginsAt6, zone2Color6, zone3BeginsAt6, zone3Color6, zone4BeginsAt6, zone4Color6, zone5BeginsAt6, zone5Color6)
        ]
    }

    private func slot(
        _ item: HomesteadWidgetItemEntity?,
        _ customDisplayName: String?,
        _ display: HomesteadSensorWidgetDisplay,
        _ gaugeScale: HomesteadGaugeScale,
        _ gaugeMinimum: Double?,
        _ gaugeMaximum: Double?,
        _ zoneCount: HomesteadGaugeZoneCount,
        _ zone1Color: HomesteadGaugeZoneColor,
        _ zone2BeginsAt: Double?,
        _ zone2Color: HomesteadGaugeZoneColor,
        _ zone3BeginsAt: Double?,
        _ zone3Color: HomesteadGaugeZoneColor,
        _ zone4BeginsAt: Double?,
        _ zone4Color: HomesteadGaugeZoneColor,
        _ zone5BeginsAt: Double?,
        _ zone5Color: HomesteadGaugeZoneColor
    ) -> HomesteadGaugeGridSlot {
        HomesteadGaugeGridSlot(
            item: item,
            configuration: .init(
                customDisplayName: customDisplayName,
                display: display,
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
        )
    }
}

struct HomesteadLargeGaugeGridTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadGaugeGridEntry {
        HomesteadGaugeGridEntry(
            date: .now,
            items: HomesteadGaugeGridEntry.largePreviewItems,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadLargeGaugeGridWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadGaugeGridEntry {
        if context.isPreview, configuration.selectedSlots.allSatisfy({ $0.item == nil }) {
            return placeholder(in: context)
        }

        return HomesteadGaugeGridEntryBuilder.entry(
            slots: configuration.selectedSlots,
            maximumItemCount: 6
        )
    }

    func timeline(
        for configuration: HomesteadLargeGaugeGridWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadGaugeGridEntry> {
        let entry = HomesteadGaugeGridEntryBuilder.entry(
            slots: configuration.selectedSlots,
            maximumItemCount: 6
        )
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60)))
    }
}

#Preview(as: .systemLarge) {
    HomesteadLargeGaugeGridWidget()
} timeline: {
    HomesteadGaugeGridEntry(
        date: .now,
        items: HomesteadGaugeGridEntry.largePreviewItems,
        isConfigured: true
    )
}
