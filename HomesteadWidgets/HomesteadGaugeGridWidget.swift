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
        .description("Show up to three Home Assistant gauges.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct HomesteadGaugeGridWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Gauge Grid"
    static var description = IntentDescription("Choose up to three Home Assistant gauges.")

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
        }
    }

    var selectedSlots: [HomesteadGaugeGridSlot] {
        [
            HomesteadGaugeGridSlot(item: item1, configuration: .init(customDisplayName: customDisplayName1, display: display1, gaugeScale: gaugeScale1, gaugeMinimum: gaugeMinimum1, gaugeMaximum: gaugeMaximum1, zoneCount: zoneCount1, zone1Color: zone1Color1, zone2BeginsAt: zone2BeginsAt1, zone2Color: zone2Color1, zone3BeginsAt: zone3BeginsAt1, zone3Color: zone3Color1, zone4BeginsAt: zone4BeginsAt1, zone4Color: zone4Color1, zone5BeginsAt: zone5BeginsAt1, zone5Color: zone5Color1)),
            HomesteadGaugeGridSlot(item: item2, configuration: .init(customDisplayName: customDisplayName2, display: display2, gaugeScale: gaugeScale2, gaugeMinimum: gaugeMinimum2, gaugeMaximum: gaugeMaximum2, zoneCount: zoneCount2, zone1Color: zone1Color2, zone2BeginsAt: zone2BeginsAt2, zone2Color: zone2Color2, zone3BeginsAt: zone3BeginsAt2, zone3Color: zone3Color2, zone4BeginsAt: zone4BeginsAt2, zone4Color: zone4Color2, zone5BeginsAt: zone5BeginsAt2, zone5Color: zone5Color2)),
            HomesteadGaugeGridSlot(item: item3, configuration: .init(customDisplayName: customDisplayName3, display: display3, gaugeScale: gaugeScale3, gaugeMinimum: gaugeMinimum3, gaugeMaximum: gaugeMaximum3, zoneCount: zoneCount3, zone1Color: zone1Color3, zone2BeginsAt: zone2BeginsAt3, zone2Color: zone2Color3, zone3BeginsAt: zone3BeginsAt3, zone3Color: zone3Color3, zone4BeginsAt: zone4BeginsAt3, zone4Color: zone4Color3, zone5BeginsAt: zone5BeginsAt3, zone5Color: zone5Color3))
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
        previewItem(
            id: "temperature",
            name: "Living Room",
            icon: "thermometer.medium",
            gauge: .gaugeGridPreview(
                value: 76.6,
                lowerBound: 70,
                upperBound: 86,
                valueText: "76.6°F",
                unitText: "°F",
                sections: [
                    .init(lowerBound: 70, upperBound: 72, color: .red),
                    .init(lowerBound: 72, upperBound: 84, color: .green),
                    .init(lowerBound: 84, upperBound: 86, color: .red)
                ]
            )
        ),
        previewItem(
            id: "magnesium",
            name: "Magnesium",
            icon: "testtube.2",
            gauge: .gaugeGridPreview(
                value: 1_640,
                lowerBound: 1_000,
                upperBound: 1_700,
                valueText: "1,640 ppm",
                unitText: "ppm",
                sections: [
                    .init(lowerBound: 1_000, upperBound: 1_300, color: .purple),
                    .init(lowerBound: 1_300, upperBound: 1_550, color: .green),
                    .init(lowerBound: 1_550, upperBound: 1_700, color: .purple)
                ]
            )
        ),
        previewItem(
            id: "calcium",
            name: "Calcium",
            icon: "drop",
            gauge: .gaugeGridPreview(
                value: 593,
                lowerBound: 300,
                upperBound: 600,
                valueText: "593 ppm",
                unitText: "ppm",
                sections: [
                    .init(lowerBound: 300, upperBound: 450, color: .blue),
                    .init(lowerBound: 450, upperBound: 600, color: .green)
                ]
            )
        )
    ]

    private static func previewItem(
        id: String,
        name: String,
        icon: String,
        gauge: WidgetGaugePresentation
    ) -> HomesteadWidgetItem {
        HomesteadWidgetItem(
            id: id,
            kind: .sensorGauge,
            displayName: name,
            icon: .sfSymbol(icon, provenance: .homesteadSemanticMapping),
            valueText: gauge.valueText,
            unitText: gauge.unitText,
            isAvailable: true,
            gauge: gauge,
            accessibilityLabel: "\(name) gauge",
            accessibilityValue: gauge.accessibilityValue
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
            items: HomesteadWidgetGridSelection.compacted(items, maximumItemCount: 3),
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
    static func gaugeGridPreview(
        value: Double,
        lowerBound: Double,
        upperBound: Double,
        valueText: String,
        unitText: String,
        sections: [WidgetGaugeSection]
    ) -> Self {
        Self(
            value: value,
            lowerBound: lowerBound,
            upperBound: upperBound,
            valueText: valueText,
            unitText: unitText,
            status: .nominal,
            statusDisplayText: "Available",
            sections: sections,
            accessibilityLabel: "Gauge",
            accessibilityValue: valueText
        )
    }
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
                let horizontalPadding: CGFloat = 8
                let columnSpacing: CGFloat = 8
                let availableWidth = max(
                    proxy.size.width - (horizontalPadding * 2) - (columnSpacing * 2),
                    0
                )
                let tileSize = availableWidth / 3

                HStack(spacing: columnSpacing) {
                    ForEach(0..<3, id: \.self) { index in
                        if index < entry.items.count {
                            HomesteadGaugeGridTile(item: entry.items[index])
                                .frame(width: tileSize, height: tileSize)
                        } else {
                            Color.clear
                                .frame(width: tileSize, height: tileSize)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, horizontalPadding)
            }
        }
    }
}

private struct HomesteadGaugeGridTile: View {
    let item: HomesteadWidgetItem

    var body: some View {
        Group {
            if let gauge = item.gauge {
                WidgetGaugeInstrumentView(
                    gauge: item.isAvailable ? gauge : gauge.updating(value: gauge.value, valueText: "—"),
                    tint: widgetGaugeColor(for: gauge.currentColor),
                    title: item.displayName,
                    icon: item.icon,
                    style: .segmented
                )
            } else {
                VStack(spacing: 4) {
                    Spacer(minLength: 0)

                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Text(item.displayName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
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
