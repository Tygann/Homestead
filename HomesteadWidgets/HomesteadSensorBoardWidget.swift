import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Configuration

struct HomesteadSensorBoardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: HomesteadWidgetKind.sensorBoard.rawValue,
            intent: HomesteadSensorBoardWidgetConfigurationIntent.self,
            provider: HomesteadSensorBoardTimelineProvider()
        ) { entry in
            HomesteadSensorBoardWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(SharedFeatureCatalog.widgetDescriptor(for: .sensorBoard)!.displayName)
        .description(SharedFeatureCatalog.widgetDescriptor(for: .sensorBoard)!.description)
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

enum HomesteadSensorBoardCompactDisplay: String, AppEnum {
    case automatic
    case gauge
    case reading

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Compact Display")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "Automatic",
        .gauge: "Gauge",
        .reading: "Reading"
    ]

    var presentation: WidgetSensorBoardCompactPresentation {
        switch self {
        case .automatic: .automatic
        case .gauge: .gauge
        case .reading: .reading
        }
    }
}

struct HomesteadSensorBoardWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Sensor Board"
    static var description = IntentDescription("Combine two sensor readings or gauges with a six-hour trend.")

    @Parameter(title: "Sensor 1") var sensor1: HomesteadSensorEntity?
    @Parameter(title: "Sensor 1 Display", default: .automatic) var display1: HomesteadSensorBoardCompactDisplay
    @Parameter(title: "Sensor 1 Display Name") var customDisplayName1: String?

    @Parameter(title: "Sensor 2") var sensor2: HomesteadSensorEntity?
    @Parameter(title: "Sensor 2 Display", default: .automatic) var display2: HomesteadSensorBoardCompactDisplay
    @Parameter(title: "Sensor 2 Display Name") var customDisplayName2: String?

    @Parameter(title: "Trend Sensor") var trendSensor: HomesteadTrendSensorEntity?
    @Parameter(title: "Trend Display Name") var customTrendDisplayName: String?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$sensor1
            \.$display1
            \.$customDisplayName1
            \.$sensor2
            \.$display2
            \.$customDisplayName2
            \.$trendSensor
            \.$customTrendDisplayName
        }
    }

    var compactSlots: [HomesteadSensorBoardCompactSlot] {
        [
            HomesteadSensorBoardCompactSlot(
                sensor: sensor1,
                display: display1,
                customDisplayName: customDisplayName1
            ),
            HomesteadSensorBoardCompactSlot(
                sensor: sensor2,
                display: display2,
                customDisplayName: customDisplayName2
            )
        ]
    }
}

struct HomesteadSensorBoardCompactSlot {
    let sensor: HomesteadSensorEntity?
    let display: HomesteadSensorBoardCompactDisplay
    let customDisplayName: String?
}

// MARK: - Trend Entity Picker

struct HomesteadTrendSensorEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Trend Sensor")
    static var defaultQuery = HomesteadTrendSensorEntityQuery()

    let id: String
    let displayName: String
    let valueText: String
    let unit: String?
    let areaName: String?
    let deviceName: String?
    let isAvailable: Bool
    let icon: ResolvedIcon
    var historyChartInterpolationStyle: HomesteadTrendChartInterpolationStyle? = nil

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(pickerDisplayName)",
            image: DisplayRepresentation.Image(systemName: icon.fallbackSFSymbol)
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
            fallback: "Numeric Sensors"
        )
    }

    func matches(_ query: String) -> Bool {
        HomesteadWidgetEntityPickerText.matches(
            query: query,
            values: [displayName, pickerDisplayName, valueText, areaName, deviceName, id, "trend", "chart"]
        )
    }
}

struct HomesteadTrendSensorEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    typealias Result = IntentItemCollection<HomesteadTrendSensorEntity>

    func entities(for identifiers: [HomesteadTrendSensorEntity.ID]) async throws -> [HomesteadTrendSensorEntity] {
        allItems().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HomesteadTrendSensorEntity> {
        collection(from: allItems().filter { $0.matches(string) })
    }

    func allEntities() async throws -> IntentItemCollection<HomesteadTrendSensorEntity> {
        collection(from: allItems())
    }

    func suggestedEntities() async throws -> IntentItemCollection<HomesteadTrendSensorEntity> {
        try await allEntities()
    }

    func defaultResult() async -> HomesteadTrendSensorEntity? {
        nil
    }

    private func allItems() -> [HomesteadTrendSensorEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots
            .filter { $0.isNumeric == true }
            .map(Self.entity(from:))
    }

    private func collection(
        from items: [HomesteadTrendSensorEntity]
    ) -> IntentItemCollection<HomesteadTrendSensorEntity> {
        HomesteadWidgetEntityPickerText.collection(
            from: items,
            groupedBy: \.pickerGroupTitle,
            sortedBy: \.pickerDisplayName
        )
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadTrendSensorEntity {
        HomesteadTrendSensorEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            unit: snapshot.unit,
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName,
            isAvailable: snapshot.isAvailable,
            icon: snapshot.resolvedIcon,
            historyChartInterpolationStyle: snapshot.historyChartInterpolationStyle
        )
    }
}

// MARK: - Timeline

struct HomesteadSensorBoardEntry: TimelineEntry {
    let date: Date
    let compactItems: [WidgetSensorBoardCompactItem?]
    let trendItem: WidgetSensorBoardTrendItem?
    let isConfigured: Bool

    static let placeholder = HomesteadSensorBoardEntry(
        date: .now,
        compactItems: [
            WidgetSensorBoardCompactItem.sensor(
                from: .sensorBoardPreview(
                    id: "sensor.living_room_temperature",
                    name: "Temperature",
                    valueText: "76.6°F",
                    unit: "°F",
                    icon: "thermometer.medium",
                    gauge: .sensorBoardPreview(
                        value: 76.6,
                        range: 70...86,
                        valueText: "76.6°F",
                        unitText: "°F",
                        sections: [
                            .init(lowerBound: 70, upperBound: 72, color: .red),
                            .init(lowerBound: 72, upperBound: 84, color: .green),
                            .init(lowerBound: 84, upperBound: 86, color: .red)
                        ]
                    )
                )
            ),
            WidgetSensorBoardCompactItem.sensor(
                from: .sensorBoardPreview(
                    id: "sensor.alkalinity",
                    name: "Alkalinity",
                    valueText: "8.3 dKH",
                    unit: "dKH",
                    icon: "testtube.2",
                    gauge: .sensorBoardPreview(
                        value: 8.3,
                        range: 7...11,
                        valueText: "8.3 dKH",
                        unitText: "dKH",
                        sections: [
                            .init(lowerBound: 7, upperBound: 8, color: .red),
                            .init(lowerBound: 8, upperBound: 10, color: .green),
                            .init(lowerBound: 10, upperBound: 11, color: .orange)
                        ]
                    )
                )
            )
        ],
        trendItem: .sensorBoardPreview,
        isConfigured: true
    )
}

struct HomesteadSensorBoardTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSensorBoardEntry {
        .placeholder
    }

    func snapshot(
        for configuration: HomesteadSensorBoardWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadSensorBoardEntry {
        if context.isPreview,
           configuration.compactSlots.allSatisfy({ $0.sensor == nil }),
           configuration.trendSensor == nil {
            return .placeholder
        }

        return await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadSensorBoardWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSensorBoardEntry> {
        Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(.now.addingTimeInterval(30 * 60))
        )
    }

    private func entry(
        for configuration: HomesteadSensorBoardWidgetConfigurationIntent
    ) async -> HomesteadSensorBoardEntry {
        let snapshotsByEntityID = HomesteadWidgetSharedStore.sensorSnapshots.reduce(into: [:]) { result, snapshot in
            result[snapshot.entityID] = snapshot
        }
        let compactEntityIDs = Set(configuration.compactSlots.compactMap(\.sensor?.id))
        let liveReadingsByEntityID: [String: WidgetSensorLiveReading]

        do {
            liveReadingsByEntityID = try await HAWidgetActionClient()
                .fetchSensorStates(entityIDs: compactEntityIDs)
                .mapValues(\.liveReading)
        } catch {
            liveReadingsByEntityID = [:]
        }

        let compactItems = configuration.compactSlots.map { slot -> WidgetSensorBoardCompactItem? in
            guard let sensor = slot.sensor else { return nil }
            let snapshot = snapshotsByEntityID[sensor.id] ?? sensor.fallbackSnapshot
            let item = WidgetSensorBoardCompactItem.sensor(
                from: snapshot,
                customDisplayName: slot.customDisplayName,
                presentation: slot.display.presentation
            )
            return liveReadingsByEntityID[sensor.id].map(item.updating(with:)) ?? item
        }
        let trendItem: WidgetSensorBoardTrendItem?
        if let trendSensor = configuration.trendSensor {
            trendItem = await makeTrendItem(
                sensor: trendSensor,
                customDisplayName: configuration.customTrendDisplayName,
                snapshot: snapshotsByEntityID[trendSensor.id]
            )
        } else {
            trendItem = nil
        }

        return HomesteadSensorBoardEntry(
            date: .now,
            compactItems: compactItems,
            trendItem: trendItem,
            isConfigured: compactItems.contains(where: { $0 != nil }) || trendItem != nil
        )
    }

    private func makeTrendItem(
        sensor: HomesteadTrendSensorEntity,
        customDisplayName: String?,
        snapshot: WidgetSensorSnapshot?
    ) async -> WidgetSensorBoardTrendItem {
        let trimmedName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = trimmedName.isEmpty ? sensor.displayName : trimmedName
        let interpolationStyle = snapshot?.historyChartInterpolationStyle
            ?? sensor.historyChartInterpolationStyle
            ?? .linear

        do {
            let series = try await HAWidgetActionClient().fetchSensorHistory(
                entityID: sensor.id,
                displayName: sensor.displayName,
                unit: sensor.unit
            )
            return WidgetSensorBoardTrendItem(
                id: sensor.id,
                displayName: displayName,
                icon: snapshot?.resolvedIcon ?? sensor.icon,
                valueText: series.latestValueText ?? snapshot?.valueText ?? sensor.valueText,
                supportingText: "6H Trend",
                isAvailable: snapshot?.isAvailable ?? sensor.isAvailable,
                samples: series.samples.map { .init(occurredAt: $0.occurredAt, value: $0.value) },
                valueDomain: HomesteadTrendChartDomain.stabilized(
                    values: series.samples.map(\.value),
                    unit: series.unit
                ),
                interpolationStyle: interpolationStyle
            )
        } catch {
            return WidgetSensorBoardTrendItem(
                id: sensor.id,
                displayName: displayName,
                icon: snapshot?.resolvedIcon ?? sensor.icon,
                valueText: snapshot?.valueText ?? sensor.valueText,
                supportingText: "Needs connection",
                isAvailable: snapshot?.isAvailable ?? sensor.isAvailable,
                samples: [],
                valueDomain: 0...1,
                interpolationStyle: interpolationStyle
            )
        }
    }
}

// MARK: - Widget View

struct HomesteadSensorBoardWidgetView: View {
    let entry: HomesteadSensorBoardEntry

    var body: some View {
        WidgetSensorBoardFace(
            compactItems: entry.compactItems,
            trendItem: entry.trendItem,
            destinationsByEntityID: destinations
        )
    }

    private var destinations: [String: URL] {
        let entityIDs = entry.compactItems.compactMap { $0?.id } + [entry.trendItem?.id].compactMap { $0 }
        return entityIDs.reduce(into: [:]) { result, entityID in
            result[entityID] = HomesteadWidgetDeepLink.entityURL(entityID: entityID)
        }
    }
}

// MARK: - Helpers

private extension HomesteadSensorEntity {
    var fallbackSnapshot: WidgetSensorSnapshot {
        WidgetSensorSnapshot(
            entityID: id,
            displayName: displayName,
            valueText: valueText,
            subtitle: subtitle,
            systemImage: systemImage,
            unit: unit,
            isNumeric: isNumeric,
            isAlerting: isAlerting,
            isAvailable: isAvailable,
            areaName: areaName,
            deviceName: deviceName,
            icon: resolvedIcon
        )
    }
}

private extension WidgetSensorSnapshot {
    static func sensorBoardPreview(
        id: String,
        name: String,
        valueText: String,
        unit: String?,
        icon: String,
        gauge: WidgetGaugePresentation?
    ) -> Self {
        Self(
            entityID: id,
            displayName: name,
            valueText: valueText,
            subtitle: "Sensor",
            systemImage: icon,
            unit: unit,
            isNumeric: true,
            isAlerting: false,
            isAvailable: true,
            areaName: nil,
            deviceName: nil,
            gauge: gauge
        )
    }
}

private extension WidgetGaugePresentation {
    static func sensorBoardPreview(
        value: Double,
        range: ClosedRange<Double>,
        valueText: String,
        unitText: String?,
        sections: [WidgetGaugeSection]
    ) -> Self {
        Self(
            value: value,
            lowerBound: range.lowerBound,
            upperBound: range.upperBound,
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

private extension WidgetSensorBoardTrendItem {
    static var sensorBoardPreview: Self {
        let now = Date()
        return Self(
            id: "sensor.salinity",
            displayName: "Salinity",
            icon: .sfSymbol("water.waves", provenance: .homesteadSemanticMapping),
            valueText: "33.8 ppt",
            supportingText: "6H Trend",
            isAvailable: true,
            samples: [33.2, 33.5, 33.4, 33.7, 33.5, 33.6, 33.8].enumerated().map { index, value in
                HomesteadTrendChartSample(
                    occurredAt: now.addingTimeInterval(Double(index - 6) * 60 * 60),
                    value: value
                )
            },
            valueDomain: HomesteadTrendChartDomain.stabilized(
                values: [33.2, 33.5, 33.4, 33.7, 33.5, 33.6, 33.8],
                unit: "ppt"
            ),
            interpolationStyle: .smooth
        )
    }
}

#Preview(as: .systemMedium) {
    HomesteadSensorBoardWidget()
} timeline: {
    HomesteadSensorBoardEntry.placeholder
}
