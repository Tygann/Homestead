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

enum HomesteadSensorBoardSlotDisplay: String, AppEnum {
    case automatic
    case gauge
    case reading
    case chart

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .automatic: "Automatic",
        .gauge: "Gauge - Segmented",
        .reading: "Reading",
        .chart: "Chart"
    ]

    var compactPresentation: WidgetSensorBoardCompactPresentation? {
        switch self {
        case .automatic: .automatic
        case .gauge: .gauge
        case .reading: .reading
        case .chart: nil
        }
    }
}

enum HomesteadSensorBoardEditingSlot: String, AppEnum {
    case one
    case two
    case three

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Configure Slot")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .one: "Slot 1",
        .two: "Slot 2",
        .three: "Slot 3"
    ]
}

struct HomesteadSensorBoardWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Sensor Board"
    static var description = IntentDescription("Combine three sensor readings, gauges, or six-hour charts.")

    @Parameter(title: "Configure Slot", default: .one)
    var editingSlot: HomesteadSensorBoardEditingSlot

    @Parameter(title: "Slot 1 Display", default: .automatic)
    var display1: HomesteadSensorBoardSlotDisplay

    @Parameter(title: "Slot 1 Sensor") var sensor1: HomesteadSensorEntity?
    @Parameter(title: "Slot 1 Chart Sensor") var chartSensor1: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 1 Display Name") var customDisplayName1: String?

    @Parameter(title: "Slot 1 Scale", default: .automatic)
    var gaugeScale1: HomesteadGaugeScale
    @Parameter(title: "Slot 1 Minimum") var gaugeMinimum1: Double?
    @Parameter(title: "Slot 1 Maximum") var gaugeMaximum1: Double?
    @Parameter(title: "Slot 1 Zones", default: .automatic)
    var zoneCount1: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 1 Zone 1 Color", default: .blue)
    var zone1Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 1 Zone 2 Begins At") var zone2BeginsAt1: Double?
    @Parameter(title: "Slot 1 Zone 2 Color", default: .green)
    var zone2Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 1 Zone 3 Begins At") var zone3BeginsAt1: Double?
    @Parameter(title: "Slot 1 Zone 3 Color", default: .orange)
    var zone3Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 1 Zone 4 Begins At") var zone4BeginsAt1: Double?
    @Parameter(title: "Slot 1 Zone 4 Color", default: .red)
    var zone4Color1: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 1 Zone 5 Begins At") var zone5BeginsAt1: Double?
    @Parameter(title: "Slot 1 Zone 5 Color", default: .purple)
    var zone5Color1: HomesteadGaugeZoneColor

    @Parameter(title: "Slot 2 Display", default: .automatic)
    var display2: HomesteadSensorBoardSlotDisplay

    @Parameter(title: "Slot 2 Sensor") var sensor2: HomesteadSensorEntity?
    @Parameter(title: "Slot 2 Chart Sensor") var chartSensor2: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 2 Display Name") var customDisplayName2: String?

    @Parameter(title: "Slot 2 Scale", default: .automatic)
    var gaugeScale2: HomesteadGaugeScale
    @Parameter(title: "Slot 2 Minimum") var gaugeMinimum2: Double?
    @Parameter(title: "Slot 2 Maximum") var gaugeMaximum2: Double?
    @Parameter(title: "Slot 2 Zones", default: .automatic)
    var zoneCount2: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 2 Zone 1 Color", default: .blue)
    var zone1Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 2 Zone 2 Begins At") var zone2BeginsAt2: Double?
    @Parameter(title: "Slot 2 Zone 2 Color", default: .green)
    var zone2Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 2 Zone 3 Begins At") var zone3BeginsAt2: Double?
    @Parameter(title: "Slot 2 Zone 3 Color", default: .orange)
    var zone3Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 2 Zone 4 Begins At") var zone4BeginsAt2: Double?
    @Parameter(title: "Slot 2 Zone 4 Color", default: .red)
    var zone4Color2: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 2 Zone 5 Begins At") var zone5BeginsAt2: Double?
    @Parameter(title: "Slot 2 Zone 5 Color", default: .purple)
    var zone5Color2: HomesteadGaugeZoneColor

    @Parameter(title: "Slot 3 Display", default: .chart)
    var display3: HomesteadSensorBoardSlotDisplay

    @Parameter(title: "Slot 3 Sensor") var sensor3: HomesteadSensorEntity?
    @Parameter(title: "Slot 3 Chart Sensor") var chartSensor3: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 3 Display Name") var customDisplayName3: String?

    @Parameter(title: "Slot 3 Scale", default: .automatic)
    var gaugeScale3: HomesteadGaugeScale
    @Parameter(title: "Slot 3 Minimum") var gaugeMinimum3: Double?
    @Parameter(title: "Slot 3 Maximum") var gaugeMaximum3: Double?
    @Parameter(title: "Slot 3 Zones", default: .automatic)
    var zoneCount3: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 3 Zone 1 Color", default: .blue)
    var zone1Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 3 Zone 2 Begins At") var zone2BeginsAt3: Double?
    @Parameter(title: "Slot 3 Zone 2 Color", default: .green)
    var zone2Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 3 Zone 3 Begins At") var zone3BeginsAt3: Double?
    @Parameter(title: "Slot 3 Zone 3 Color", default: .orange)
    var zone3Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 3 Zone 4 Begins At") var zone4BeginsAt3: Double?
    @Parameter(title: "Slot 3 Zone 4 Color", default: .red)
    var zone4Color3: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 3 Zone 5 Begins At") var zone5BeginsAt3: Double?
    @Parameter(title: "Slot 3 Zone 5 Color", default: .purple)
    var zone5Color3: HomesteadGaugeZoneColor

    static var parameterSummary: some ParameterSummary {
        Switch(\.$editingSlot) {
            Case(.one) {
                When(\.$display1, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display1
                        \.$chartSensor1
                        \.$customDisplayName1
                    }
                } otherwise: {
                    When(\.$display1, .equalTo, .gauge) {
                        When(\.$gaugeScale1, .equalTo, .custom) {
                            When(\.$zoneCount1, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display1
                                \.$sensor1
                                \.$customDisplayName1
                                \.$gaugeScale1
                                \.$gaugeMinimum1
                                \.$gaugeMaximum1
                                \.$zoneCount1
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display1
                                \.$sensor1
                                \.$customDisplayName1
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
                            }
                            }
                        } otherwise: {
                            When(\.$zoneCount1, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display1
                                \.$sensor1
                                \.$customDisplayName1
                                \.$gaugeScale1
                                \.$zoneCount1
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display1
                                \.$sensor1
                                \.$customDisplayName1
                                \.$gaugeScale1
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
                            }
                            }
                        }
                    } otherwise: {
                        Summary {
                            \.$editingSlot
                            \.$display1
                            \.$sensor1
                            \.$customDisplayName1
                        }
                    }
                }
            }
            Case(.two) {
                When(\.$display2, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display2
                        \.$chartSensor2
                        \.$customDisplayName2
                    }
                } otherwise: {
                    When(\.$display2, .equalTo, .gauge) {
                        When(\.$gaugeScale2, .equalTo, .custom) {
                            When(\.$zoneCount2, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display2
                                \.$sensor2
                                \.$customDisplayName2
                                \.$gaugeScale2
                                \.$gaugeMinimum2
                                \.$gaugeMaximum2
                                \.$zoneCount2
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display2
                                \.$sensor2
                                \.$customDisplayName2
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
                            }
                            }
                        } otherwise: {
                            When(\.$zoneCount2, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display2
                                \.$sensor2
                                \.$customDisplayName2
                                \.$gaugeScale2
                                \.$zoneCount2
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display2
                                \.$sensor2
                                \.$customDisplayName2
                                \.$gaugeScale2
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
                            }
                            }
                        }
                    } otherwise: {
                        Summary {
                            \.$editingSlot
                            \.$display2
                            \.$sensor2
                            \.$customDisplayName2
                        }
                    }
                }
            }
            Case(.three) {
                When(\.$display3, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display3
                        \.$chartSensor3
                        \.$customDisplayName3
                    }
                } otherwise: {
                    When(\.$display3, .equalTo, .gauge) {
                        When(\.$gaugeScale3, .equalTo, .custom) {
                            When(\.$zoneCount3, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display3
                                \.$sensor3
                                \.$customDisplayName3
                                \.$gaugeScale3
                                \.$gaugeMinimum3
                                \.$gaugeMaximum3
                                \.$zoneCount3
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display3
                                \.$sensor3
                                \.$customDisplayName3
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
                        } otherwise: {
                            When(\.$zoneCount3, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display3
                                \.$sensor3
                                \.$customDisplayName3
                                \.$gaugeScale3
                                \.$zoneCount3
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display3
                                \.$sensor3
                                \.$customDisplayName3
                                \.$gaugeScale3
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
                        }
                    } otherwise: {
                        Summary {
                            \.$editingSlot
                            \.$display3
                            \.$sensor3
                            \.$customDisplayName3
                        }
                    }
                }
            }
            DefaultCase {
                Summary {
                    \.$editingSlot
                }
            }
        }
    }

    private var gaugeConfiguration1: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale1,
            gaugeMinimum: gaugeMinimum1,
            gaugeMaximum: gaugeMaximum1,
            zoneCount: zoneCount1,
            zone1Color: zone1Color1,
            zone2BeginsAt: zone2BeginsAt1,
            zone2Color: zone2Color1,
            zone3BeginsAt: zone3BeginsAt1,
            zone3Color: zone3Color1,
            zone4BeginsAt: zone4BeginsAt1,
            zone4Color: zone4Color1,
            zone5BeginsAt: zone5BeginsAt1,
            zone5Color: zone5Color1
        )
    }

    private var gaugeConfiguration2: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale2,
            gaugeMinimum: gaugeMinimum2,
            gaugeMaximum: gaugeMaximum2,
            zoneCount: zoneCount2,
            zone1Color: zone1Color2,
            zone2BeginsAt: zone2BeginsAt2,
            zone2Color: zone2Color2,
            zone3BeginsAt: zone3BeginsAt2,
            zone3Color: zone3Color2,
            zone4BeginsAt: zone4BeginsAt2,
            zone4Color: zone4Color2,
            zone5BeginsAt: zone5BeginsAt2,
            zone5Color: zone5Color2
        )
    }

    private var gaugeConfiguration3: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale3,
            gaugeMinimum: gaugeMinimum3,
            gaugeMaximum: gaugeMaximum3,
            zoneCount: zoneCount3,
            zone1Color: zone1Color3,
            zone2BeginsAt: zone2BeginsAt3,
            zone2Color: zone2Color3,
            zone3BeginsAt: zone3BeginsAt3,
            zone3Color: zone3Color3,
            zone4BeginsAt: zone4BeginsAt3,
            zone4Color: zone4Color3,
            zone5BeginsAt: zone5BeginsAt3,
            zone5Color: zone5Color3
        )
    }

    var slots: [HomesteadSensorBoardSlotConfiguration] {
        [
            HomesteadSensorBoardSlotConfiguration(
                display: display1,
                sensor: sensor1,
                chartSensor: chartSensor1,
                customDisplayName: customDisplayName1,
                customChartDisplayName: customDisplayName1,
                gaugeConfiguration: gaugeConfiguration1
            ),
            HomesteadSensorBoardSlotConfiguration(
                display: display2,
                sensor: sensor2,
                chartSensor: chartSensor2,
                customDisplayName: customDisplayName2,
                customChartDisplayName: customDisplayName2,
                gaugeConfiguration: gaugeConfiguration2
            ),
            HomesteadSensorBoardSlotConfiguration(
                display: display3,
                sensor: sensor3,
                chartSensor: chartSensor3,
                customDisplayName: customDisplayName3,
                customChartDisplayName: customDisplayName3,
                gaugeConfiguration: gaugeConfiguration3
            )
        ]
    }
}

struct HomesteadSensorBoardSlotConfiguration {
    let display: HomesteadSensorBoardSlotDisplay
    let sensor: HomesteadSensorEntity?
    let chartSensor: HomesteadChartSensorEntity?
    let customDisplayName: String?
    let customChartDisplayName: String?
    let gaugeConfiguration: HomesteadGaugeWidgetConfiguration
}

// MARK: - Chart Entity Picker

struct HomesteadChartSensorEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Chart Sensor")
    static var defaultQuery = HomesteadChartSensorEntityQuery()

    let id: String
    let displayName: String
    let valueText: String
    let unit: String?
    let areaName: String?
    let deviceName: String?
    let isAvailable: Bool
    let icon: ResolvedIcon
    var historyChartInterpolationStyle: HomesteadChartInterpolationStyle? = nil
    var chartAccentColor: WidgetGaugeColor? = nil

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
            values: [displayName, pickerDisplayName, valueText, areaName, deviceName, id, "chart", "chart"]
        )
    }
}

struct HomesteadChartSensorEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    typealias Result = IntentItemCollection<HomesteadChartSensorEntity>

    func entities(for identifiers: [HomesteadChartSensorEntity.ID]) async throws -> [HomesteadChartSensorEntity] {
        allItems().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HomesteadChartSensorEntity> {
        collection(from: allItems().filter { $0.matches(string) })
    }

    func allEntities() async throws -> IntentItemCollection<HomesteadChartSensorEntity> {
        collection(from: allItems())
    }

    func suggestedEntities() async throws -> IntentItemCollection<HomesteadChartSensorEntity> {
        try await allEntities()
    }

    func defaultResult() async -> HomesteadChartSensorEntity? {
        nil
    }

    private func allItems() -> [HomesteadChartSensorEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots
            .filter { $0.isNumeric == true }
            .map(Self.entity(from:))
    }

    private func collection(
        from items: [HomesteadChartSensorEntity]
    ) -> IntentItemCollection<HomesteadChartSensorEntity> {
        HomesteadWidgetEntityPickerText.collection(
            from: items,
            groupedBy: \.pickerGroupTitle,
            sortedBy: \.pickerDisplayName
        )
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadChartSensorEntity {
        HomesteadChartSensorEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            unit: snapshot.unit,
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName,
            isAvailable: snapshot.isAvailable,
            icon: snapshot.resolvedIcon,
            historyChartInterpolationStyle: snapshot.historyChartInterpolationStyle,
            chartAccentColor: snapshot.chartAccentColor
        )
    }
}

// MARK: - Timeline

struct HomesteadSensorBoardEntry: TimelineEntry {
    let date: Date
    let items: [WidgetSensorBoardItem?]
    let isConfigured: Bool

    static let placeholder = HomesteadSensorBoardEntry(
        date: .now,
        items: [
            .compact(WidgetSensorBoardCompactItem.sensor(
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
            )),
            .compact(WidgetSensorBoardCompactItem.sensor(
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
            )),
            .chart(.sensorBoardPreview)
        ],
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
        guard HomesteadWidgetPlusPolicy.allowsSensorBoard(
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        ) else {
            return .placeholder
        }
        if context.isPreview,
           configuration.slots.allSatisfy({ $0.sensor == nil && $0.chartSensor == nil }) {
            return .placeholder
        }

        return await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadSensorBoardWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSensorBoardEntry> {
        guard HomesteadWidgetPlusPolicy.allowsSensorBoard(
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        ) else {
            return Timeline(
                entries: [.placeholder],
                policy: .after(.now.addingTimeInterval(30 * 60))
            )
        }
        return Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(.now.addingTimeInterval(30 * 60))
        )
    }

    private func entry(
        for configuration: HomesteadSensorBoardWidgetConfigurationIntent
    ) async -> HomesteadSensorBoardEntry {
        await HomesteadSensorBoardEntryBuilder.entry(slots: configuration.slots)
    }
}

enum HomesteadSensorBoardEntryBuilder {
    static func entry(
        slots: [HomesteadSensorBoardSlotConfiguration]
    ) async -> HomesteadSensorBoardEntry {
        let snapshotsByEntityID = HomesteadWidgetSharedStore.sensorSnapshots.reduce(into: [:]) { result, snapshot in
            result[snapshot.entityID] = snapshot
        }
        let compactEntityIDs = Set(
            slots.compactMap { slot in
                slot.display == .chart ? nil : slot.sensor?.id
            }
        )
        let liveReadingsByEntityID: [String: WidgetSensorLiveReading]

        do {
            liveReadingsByEntityID = try await HAWidgetActionClient()
                .fetchSensorStates(entityIDs: compactEntityIDs)
                .mapValues(\.liveReading)
        } catch {
            liveReadingsByEntityID = [:]
        }

        var items = Array<WidgetSensorBoardItem?>(repeating: nil, count: slots.count)
        await withTaskGroup(of: (Int, WidgetSensorBoardChartItem).self) { group in
            for (index, slot) in slots.enumerated() {
                switch slot.display {
                case .chart:
                    guard let sensor = slot.chartSensor else { continue }
                    let snapshot = snapshotsByEntityID[sensor.id]
                    group.addTask {
                        let item = await Self.makeChartItem(
                            sensor: sensor,
                            customDisplayName: slot.customChartDisplayName,
                            snapshot: snapshot
                        )
                        return (index, item)
                    }
                case .automatic, .gauge, .reading:
                    guard let sensor = slot.sensor,
                          let presentation = slot.display.compactPresentation else {
                        continue
                    }
                    let snapshot = snapshotsByEntityID[sensor.id] ?? sensor.fallbackSnapshot
                    let item = WidgetSensorBoardCompactItem.sensor(
                        from: snapshot,
                        customDisplayName: slot.customDisplayName,
                        presentation: presentation
                    )
                    let updatedItem = liveReadingsByEntityID[sensor.id].map(item.updating(with:)) ?? item
                    let configuredItem = slot.display == .gauge
                        ? updatedItem.applyingGaugeConfiguration(slot.gaugeConfiguration)
                        : updatedItem
                    items[index] = .compact(configuredItem)
                }
            }

            for await (index, item) in group {
                items[index] = .chart(item)
            }
        }

        return HomesteadSensorBoardEntry(
            date: .now,
            items: items,
            isConfigured: items.contains(where: { $0 != nil })
        )
    }

    private static func makeChartItem(
        sensor: HomesteadChartSensorEntity,
        customDisplayName: String?,
        snapshot: WidgetSensorSnapshot?
    ) async -> WidgetSensorBoardChartItem {
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
            return WidgetSensorBoardChartItem(
                id: sensor.id,
                displayName: displayName,
                icon: snapshot?.resolvedIcon ?? sensor.icon,
                valueText: series.latestValueText ?? snapshot?.valueText ?? sensor.valueText,
                unitText: series.unit,
                supportingText: "No recent chart",
                isAvailable: snapshot?.isAvailable ?? sensor.isAvailable,
                samples: series.samples.map { .init(occurredAt: $0.occurredAt, value: $0.value) },
                valueDomain: HomesteadChartDomain.stabilized(
                    values: series.samples.map(\.value),
                    unit: series.unit
                ),
                interpolationStyle: interpolationStyle,
                accentColor: snapshot?.chartAccentColor ?? sensor.chartAccentColor ?? .accent
            )
        } catch {
            return WidgetSensorBoardChartItem(
                id: sensor.id,
                displayName: displayName,
                icon: snapshot?.resolvedIcon ?? sensor.icon,
                valueText: snapshot?.valueText ?? sensor.valueText,
                unitText: snapshot?.unit ?? sensor.unit,
                supportingText: "Needs connection",
                isAvailable: snapshot?.isAvailable ?? sensor.isAvailable,
                samples: [],
                valueDomain: 0...1,
                interpolationStyle: interpolationStyle,
                accentColor: snapshot?.chartAccentColor ?? sensor.chartAccentColor ?? .accent
            )
        }
    }
}

// MARK: - Widget View

struct HomesteadSensorBoardWidgetView: View {
    let entry: HomesteadSensorBoardEntry

    var body: some View {
        if HomesteadWidgetPlusPolicy.allowsSensorBoard(
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        ) {
            WidgetSensorBoardFace(
                items: entry.items,
                destinationsByEntityID: destinations
            )
        } else {
            HomesteadPlusWidgetLockView()
        }
    }

    private var destinations: [String: URL] {
        let entityIDs = entry.items.compactMap { $0?.id }
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

private extension WidgetSensorBoardChartItem {
    static var sensorBoardPreview: Self {
        let now = Date()
        return Self(
            id: "sensor.salinity",
            displayName: "Salinity",
            icon: .sfSymbol("water.waves", provenance: .homesteadSemanticMapping),
            valueText: "33.8 ppt",
            unitText: "ppt",
            supportingText: "No recent chart",
            isAvailable: true,
            samples: [33.2, 33.5, 33.4, 33.7, 33.5, 33.6, 33.8].enumerated().map { index, value in
                HomesteadChartSample(
                    occurredAt: now.addingTimeInterval(Double(index - 6) * 60 * 60),
                    value: value
                )
            },
            valueDomain: HomesteadChartDomain.stabilized(
                values: [33.2, 33.5, 33.4, 33.7, 33.5, 33.6, 33.8],
                unit: "ppt"
            ),
            interpolationStyle: .smooth,
            accentColor: .blue
        )
    }
}

#Preview(as: .systemMedium) {
    HomesteadSensorBoardWidget()
} timeline: {
    HomesteadSensorBoardEntry.placeholder
}
