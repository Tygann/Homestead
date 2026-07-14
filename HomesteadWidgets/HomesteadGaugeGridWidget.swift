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

    @Parameter(title: "Gauge 2")
    var item2: HomesteadWidgetItemEntity?

    @Parameter(title: "Gauge 3")
    var item3: HomesteadWidgetItemEntity?

    @Parameter(title: "Gauge 4")
    var item4: HomesteadWidgetItemEntity?

    @Parameter(title: "Gauge 5")
    var item5: HomesteadWidgetItemEntity?

    @Parameter(title: "Gauge 6")
    var item6: HomesteadWidgetItemEntity?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$item1
            \.$item2
            \.$item3
            \.$item4
            \.$item5
            \.$item6
        }
    }

    var selectedItems: [HomesteadWidgetItemEntity] {
        [item1, item2, item3, item4, item5, item6].compactMap { $0 }
    }
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
        if context.isPreview, configuration.selectedItems.isEmpty {
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
        let items: [HomesteadWidgetItem?] = configuration.selectedItems.map { configuredItem in
            HomesteadWidgetSharedStore.sensorSnapshot(entityID: configuredItem.id)
                .flatMap(HomesteadWidgetItem.sensorGauge(from:))
                ?? configuredItem.item()
        }

        return HomesteadGaugeGridEntry(
            date: .now,
            items: HomesteadWidgetGridSelection.compacted(items),
            isConfigured: !items.isEmpty
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
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 4
            ) {
                ForEach(entry.items) { item in
                    HomesteadGaugeGridTile(item: item)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
        }
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
                WidgetGaugeCompactInstrumentView(
                    gauge: item.isAvailable ? gauge : gauge.updating(value: gauge.value, valueText: "—"),
                    tint: widgetGaugeColor(for: gauge.currentColor)
                )
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 66, maxHeight: .infinity)
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
