import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadGaugeGridWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadGaugeGridWidget",
            intent: HomesteadGaugeGridWidgetConfigurationIntent.self,
            provider: HomesteadGaugeGridTimelineProvider()
        ) { entry in
            HomesteadGaugeGridWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Gauge Grid")
        .description("Show up to six Home Assistant gauges.")
        .supportedFamilies([.systemMedium])
    }
}

struct HomesteadGaugeGridWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Gauge Grid"
    static var description = IntentDescription("Choose up to six Home Assistant gauges.")

    @Parameter(title: "Gauge 1")
    var item1: HomesteadWidgetItemEntity?

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

    @Parameter(title: "Gauge 2")
    var item2: HomesteadWidgetItemEntity?

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

    @Parameter(title: "Gauge 3")
    var item3: HomesteadWidgetItemEntity?

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

    @Parameter(title: "Gauge 4")
    var item4: HomesteadWidgetItemEntity?

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

    @Parameter(title: "Gauge 5")
    var item5: HomesteadWidgetItemEntity?

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

    @Parameter(title: "Gauge 6")
    var item6: HomesteadWidgetItemEntity?

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
            HomesteadGaugeGridSlot(item: item1, configuration: .init(customDisplayName: customDisplayName1, display: display1, gaugeScale: gaugeScale1, gaugeMinimum: gaugeMinimum1, gaugeMaximum: gaugeMaximum1, zoneCount: zoneCount1, zone1Color: zone1Color1, zone2BeginsAt: zone2BeginsAt1, zone2Color: zone2Color1, zone3BeginsAt: zone3BeginsAt1, zone3Color: zone3Color1, zone4BeginsAt: zone4BeginsAt1, zone4Color: zone4Color1, zone5BeginsAt: zone5BeginsAt1, zone5Color: zone5Color1)),
            HomesteadGaugeGridSlot(item: item2, configuration: .init(customDisplayName: customDisplayName2, display: display2, gaugeScale: gaugeScale2, gaugeMinimum: gaugeMinimum2, gaugeMaximum: gaugeMaximum2, zoneCount: zoneCount2, zone1Color: zone1Color2, zone2BeginsAt: zone2BeginsAt2, zone2Color: zone2Color2, zone3BeginsAt: zone3BeginsAt2, zone3Color: zone3Color2, zone4BeginsAt: zone4BeginsAt2, zone4Color: zone4Color2, zone5BeginsAt: zone5BeginsAt2, zone5Color: zone5Color2)),
            HomesteadGaugeGridSlot(item: item3, configuration: .init(customDisplayName: customDisplayName3, display: display3, gaugeScale: gaugeScale3, gaugeMinimum: gaugeMinimum3, gaugeMaximum: gaugeMaximum3, zoneCount: zoneCount3, zone1Color: zone1Color3, zone2BeginsAt: zone2BeginsAt3, zone2Color: zone2Color3, zone3BeginsAt: zone3BeginsAt3, zone3Color: zone3Color3, zone4BeginsAt: zone4BeginsAt3, zone4Color: zone4Color3, zone5BeginsAt: zone5BeginsAt3, zone5Color: zone5Color3)),
            HomesteadGaugeGridSlot(item: item4, configuration: .init(customDisplayName: customDisplayName4, display: display4, gaugeScale: gaugeScale4, gaugeMinimum: gaugeMinimum4, gaugeMaximum: gaugeMaximum4, zoneCount: zoneCount4, zone1Color: zone1Color4, zone2BeginsAt: zone2BeginsAt4, zone2Color: zone2Color4, zone3BeginsAt: zone3BeginsAt4, zone3Color: zone3Color4, zone4BeginsAt: zone4BeginsAt4, zone4Color: zone4Color4, zone5BeginsAt: zone5BeginsAt4, zone5Color: zone5Color4)),
            HomesteadGaugeGridSlot(item: item5, configuration: .init(customDisplayName: customDisplayName5, display: display5, gaugeScale: gaugeScale5, gaugeMinimum: gaugeMinimum5, gaugeMaximum: gaugeMaximum5, zoneCount: zoneCount5, zone1Color: zone1Color5, zone2BeginsAt: zone2BeginsAt5, zone2Color: zone2Color5, zone3BeginsAt: zone3BeginsAt5, zone3Color: zone3Color5, zone4BeginsAt: zone4BeginsAt5, zone4Color: zone4Color5, zone5BeginsAt: zone5BeginsAt5, zone5Color: zone5Color5)),
            HomesteadGaugeGridSlot(item: item6, configuration: .init(customDisplayName: customDisplayName6, display: display6, gaugeScale: gaugeScale6, gaugeMinimum: gaugeMinimum6, gaugeMaximum: gaugeMaximum6, zoneCount: zoneCount6, zone1Color: zone1Color6, zone2BeginsAt: zone2BeginsAt6, zone2Color: zone2Color6, zone3BeginsAt: zone3BeginsAt6, zone3Color: zone3Color6, zone4BeginsAt: zone4BeginsAt6, zone4Color: zone4Color6, zone5BeginsAt: zone5BeginsAt6, zone5Color: zone5Color6))
        ]
    }
}

struct HomesteadGaugeGridSlot {
    let item: HomesteadWidgetItemEntity?
    let configuration: HomesteadGaugeWidgetConfiguration
}

struct HomesteadWidgetItemEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Gauge")
    static var defaultQuery = HomesteadWidgetItemEntityQuery()

    let id: String
    let displayName: String
    let valueText: String
    let systemImage: String
    let areaName: String?
    let deviceName: String?
    let isAvailable: Bool
    let gauge: WidgetGaugePresentation?
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(pickerDisplayName)",
            image: DisplayRepresentation.Image(systemName: resolvedIcon.fallbackSFSymbol)
        )
    }

    var pickerDisplayName: String {
        HomesteadWidgetEntityPickerText.contextualDisplayName(
            displayName,
            areaName: areaName,
            deviceName: deviceName
        )
    }

    var pickerGroupTitle: String {
        HomesteadWidgetEntityPickerText.groupName(
            areaName: areaName,
            deviceName: deviceName,
            fallback: "Gauges"
        )
    }

    func matches(_ query: String) -> Bool {
        HomesteadWidgetEntityPickerText.matches(
            query: query,
            values: [displayName, pickerDisplayName, valueText, areaName, deviceName, id, "gauge"]
        )
    }

    func item() -> HomesteadWidgetItem {
        HomesteadWidgetItem(
            id: id,
            kind: .sensorGauge,
            displayName: displayName,
            icon: resolvedIcon,
            valueText: gauge?.valueText ?? valueText,
            unitText: gauge?.unitText,
            isAvailable: isAvailable,
            gauge: gauge,
            accessibilityLabel: gauge?.accessibilityLabel ?? "\(displayName) gauge",
            accessibilityValue: gauge?.accessibilityValue ?? valueText
        )
    }
}

struct HomesteadWidgetItemEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    typealias Result = IntentItemCollection<HomesteadWidgetItemEntity>

    func entities(for identifiers: [HomesteadWidgetItemEntity.ID]) async throws -> [HomesteadWidgetItemEntity] {
        allItems().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HomesteadWidgetItemEntity> {
        collection(from: allItems().filter { $0.matches(string) })
    }

    func allEntities() async throws -> IntentItemCollection<HomesteadWidgetItemEntity> {
        collection(from: allItems())
    }

    func suggestedEntities() async throws -> IntentItemCollection<HomesteadWidgetItemEntity> {
        try await allEntities()
    }

    func defaultResult() async -> HomesteadWidgetItemEntity? {
        nil
    }

    private func allItems() -> [HomesteadWidgetItemEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots
            .filter { $0.gauge != nil }
            .map(Self.entity(from:))
    }

    private func collection(from items: [HomesteadWidgetItemEntity]) -> IntentItemCollection<HomesteadWidgetItemEntity> {
        HomesteadWidgetEntityPickerText.collection(
            from: items,
            groupedBy: \.pickerGroupTitle,
            sortedBy: \.pickerDisplayName
        )
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadWidgetItemEntity {
        HomesteadWidgetItemEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName,
            isAvailable: snapshot.isAvailable,
            gauge: snapshot.gauge,
            icon: snapshot.resolvedIcon
        )
    }
}

struct HomesteadGaugeGridEntry: TimelineEntry {
    let date: Date
    let items: [HomesteadWidgetItem]
    let isConfigured: Bool

    static let previewItems: [HomesteadWidgetItem] = [
        previewItem("Living Room", value: "72°F", icon: "thermometer.medium", gauge: .gaugeGridPreview),
        previewItem("Magnesium", value: "1,640 ppm", icon: "testtube.2", gauge: .gaugeGridPreview),
        previewItem("Calcium", value: "593 ppm", icon: "drop", gauge: .gaugeGridPreview),
        previewItem("Alkalinity", value: "8.3 dKH", icon: "flask", gauge: .gaugeGridPreview),
        previewItem("Alkalinity", value: "8.3 dKH", icon: "flask", gauge: .gaugeGridPreview),
        previewItem("Alkalinity", value: "8.3 dKH", icon: "flask", gauge: .gaugeGridPreview)
    ]

    private static func previewItem(
        _ name: String,
        value: String,
        icon: String,
        gauge: WidgetGaugePresentation
    ) -> HomesteadWidgetItem {
        HomesteadWidgetItem(
            id: name,
            kind: .sensorGauge,
            displayName: name,
            icon: .sfSymbol(icon, provenance: .homesteadSemanticMapping),
            valueText: value,
            unitText: gauge.unitText,
            isAvailable: true,
            gauge: gauge,
            accessibilityLabel: "\(name) gauge",
            accessibilityValue: value
        )
    }
}

struct HomesteadGaugeGridTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadGaugeGridEntry {
        HomesteadGaugeGridEntry(date: .now, items: HomesteadGaugeGridEntry.previewItems, isConfigured: true)
    }

    func snapshot(
        for configuration: HomesteadGaugeGridWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadGaugeGridEntry {
        if context.isPreview, configuration.selectedSlots.allSatisfy({ $0.item == nil }) {
            return placeholder(in: context)
        }

        return entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadGaugeGridWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadGaugeGridEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(30 * 60)))
    }

    private func entry(for configuration: HomesteadGaugeGridWidgetConfigurationIntent) -> HomesteadGaugeGridEntry {
        let items: [HomesteadWidgetItem?] = configuration.selectedSlots.compactMap { slot in
            guard let configuredItem = slot.item else { return nil }

            let item = HomesteadWidgetSharedStore.sensorSnapshot(entityID: configuredItem.id)
                .flatMap(HomesteadWidgetItem.sensorGauge(from:))
                ?? configuredItem.item()

            return item.applying(slot.configuration)
        }

        return HomesteadGaugeGridEntry(
            date: .now,
            items: HomesteadWidgetGridSelection.compacted(items),
            isConfigured: !items.isEmpty
        )
    }
}

private extension HomesteadWidgetItem {
    func applying(_ configuration: HomesteadGaugeWidgetConfiguration) -> Self {
        guard let gauge else { return self }

        let resolvedGauge = configuration.resolvedGauge(gauge)
        let currentDisplayName = configuration.resolvedDisplayName ?? displayName
        let resolvedIcon = gaugeDisplayIcon(
            base: icon,
            value: resolvedGauge.value,
            status: resolvedGauge.status.visualStatus
        )

        return Self(
            id: id,
            kind: kind,
            displayName: currentDisplayName,
            icon: resolvedIcon,
            valueText: resolvedGauge.valueText,
            unitText: resolvedGauge.unitText,
            isAvailable: isAvailable,
            gauge: resolvedGauge,
            accessibilityLabel: "\(currentDisplayName) gauge",
            accessibilityValue: resolvedGauge.accessibilityValue
        )
    }
}

private extension WidgetGaugePresentation {
    static let gaugeGridPreview = WidgetGaugePresentation(
        value: 72,
        lowerBound: 0,
        upperBound: 120,
        valueText: "72°F",
        unitText: "°F",
        status: .nominal,
        statusDisplayText: "Comfortable",
        sections: [
            WidgetGaugeSection(lowerBound: 0, upperBound: 40, color: .orange),
            WidgetGaugeSection(lowerBound: 40, upperBound: 60, color: .blue),
            WidgetGaugeSection(lowerBound: 60, upperBound: 80, color: .green),
            WidgetGaugeSection(lowerBound: 80, upperBound: 120, color: .orange)
        ],
        accessibilityLabel: "Gauge",
        accessibilityValue: "72°F"
    )
}

struct HomesteadGaugeGridWidgetView: View {
    let entry: HomesteadGaugeGridEntry

    var body: some View {
        if entry.items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "gauge.medium")
                    .font(.title2)
                Text("Choose Gauges")
                    .font(.headline)
                Text("Edit the widget to select sensors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                let rowSpacing: CGFloat = 1
                let rowHeight = max((proxy.size.height - rowSpacing) / 2, 0)

                VStack(spacing: rowSpacing) {
                    gaugeRow(items: entry.items, range: 0..<3)
                        .frame(height: rowHeight)

                    gaugeRow(items: entry.items, range: 3..<6)
                        .frame(height: rowHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private func gaugeRow(items: [HomesteadWidgetItem], range: Range<Int>) -> some View {
        HStack(spacing: 4) {
            ForEach(range, id: \.self) { index in
                if index < items.count {
                    HomesteadGaugeGridTile(item: items[index])
                } else {
                    Color.clear
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HomesteadGaugeGridTile: View {
    let item: HomesteadWidgetItem

    var body: some View {
        VStack(spacing: 1) {
            Text(item.displayName)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            if let gauge = item.gauge {
                WidgetGaugeInstrumentView(
                    gauge: item.isAvailable ? gauge : gauge.updating(value: gauge.value, valueText: "—"),
                    tint: widgetGaugeColor(for: gauge.currentColor),
                    icon: item.icon,
                    style: .segmented
                )
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityValue(item.isAvailable ? item.accessibilityValue : "Unavailable")
    }
}

#Preview(as: .systemMedium) {
    HomesteadGaugeGridWidget()
} timeline: {
    HomesteadGaugeGridEntry(date: .now, items: HomesteadGaugeGridEntry.previewItems, isConfigured: true)
}
