import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Medium Sensor Board

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

enum HomesteadSensorBoardGaugeStyle: String, AppEnum {
    case circular
    case segmented
    case bar

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Gauge Style")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .circular: "Circular",
        .segmented: "Segmented",
        .bar: "Bar"
    ]

    var widgetStyle: WidgetSensorBoardGaugeStyle {
        switch self {
        case .circular: .circular
        case .segmented: .segmented
        case .bar: .bar
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

    @Parameter(title: "Slot 1 Gauge Style", default: .segmented)
    var gaugeStyle1: HomesteadSensorBoardGaugeStyle

    @Parameter(title: "Slot 1 Sensor") var sensor1: HomesteadSensorEntity?
    @Parameter(title: "Slot 1 Name") var customDisplayName1: String?

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

    @Parameter(title: "Slot 2 Gauge Style", default: .segmented)
    var gaugeStyle2: HomesteadSensorBoardGaugeStyle

    @Parameter(title: "Slot 2 Sensor") var sensor2: HomesteadSensorEntity?
    @Parameter(title: "Slot 2 Name") var customDisplayName2: String?

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

    @Parameter(title: "Slot 3 Gauge Style", default: .segmented)
    var gaugeStyle3: HomesteadSensorBoardGaugeStyle

    @Parameter(title: "Slot 3 Sensor") var sensor3: HomesteadSensorEntity?
    @Parameter(title: "Slot 3 Name") var customDisplayName3: String?

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
                        \.$sensor1
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
                                \.$gaugeStyle1
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
                                \.$gaugeStyle1
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
                                \.$gaugeStyle1
                                \.$gaugeScale1
                                \.$zoneCount1
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display1
                                \.$sensor1
                                \.$customDisplayName1
                                \.$gaugeStyle1
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
                        \.$sensor2
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
                                \.$gaugeStyle2
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
                                \.$gaugeStyle2
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
                                \.$gaugeStyle2
                                \.$gaugeScale2
                                \.$zoneCount2
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display2
                                \.$sensor2
                                \.$customDisplayName2
                                \.$gaugeStyle2
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
                        \.$sensor3
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
                                \.$gaugeStyle3
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
                                \.$gaugeStyle3
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
                                \.$gaugeStyle3
                                \.$gaugeScale3
                                \.$zoneCount3
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display3
                                \.$sensor3
                                \.$customDisplayName3
                                \.$gaugeStyle3
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
            style: gaugeStyle1.widgetStyle,
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
            style: gaugeStyle2.widgetStyle,
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
            style: gaugeStyle3.widgetStyle,
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
                customDisplayName: customDisplayName1,
                gaugeConfiguration: gaugeConfiguration1
            ),
            HomesteadSensorBoardSlotConfiguration(
                display: display2,
                sensor: sensor2,
                customDisplayName: customDisplayName2,
                gaugeConfiguration: gaugeConfiguration2
            ),
            HomesteadSensorBoardSlotConfiguration(
                display: display3,
                sensor: sensor3,
                customDisplayName: customDisplayName3,
                gaugeConfiguration: gaugeConfiguration3
            )
        ]
    }
}

struct HomesteadSensorBoardSlotConfiguration {
    let display: HomesteadSensorBoardSlotDisplay
    let sensor: HomesteadSensorEntity?
    let customDisplayName: String?
    let gaugeConfiguration: HomesteadGaugeWidgetConfiguration
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
           configuration.slots.allSatisfy({ $0.sensor == nil }) {
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
        let snapshotsByIdentifier = HomesteadWidgetSharedStore.scopedSensorSnapshots.reduce(into: [:]) { result, scoped in
            result[scoped.reference.encodedID] = scoped.value
        }
        async let liveResult = loadLiveReadings(slots: slots)
        async let historyResult = loadHistories(slots: slots)
        let (liveReadingsByIdentifier, histories) = await (liveResult, historyResult)
        var items = Array<WidgetSensorBoardItem?>(repeating: nil, count: slots.count)

        for (index, slot) in slots.enumerated() {
            switch slot.display {
            case .chart:
                guard let sensor = slot.sensor,
                      let reference = HomesteadWidgetSharedStore.reference(for: sensor.id) else {
                    continue
                }
                items[index] = .chart(
                    makeChartItem(
                        sensor: sensor,
                        customDisplayName: slot.customDisplayName,
                        snapshot: snapshotsByIdentifier[sensor.id],
                        series: histories.seriesByIdentifier[sensor.id],
                        connectionFailed: histories.failedProfiles.contains(reference.profileID)
                            || !HomesteadWidgetSharedStore.isServerAvailable(profileID: reference.profileID)
                    )
                )
            case .automatic, .gauge, .reading:
                guard let sensor = slot.sensor,
                      let reference = HomesteadWidgetSharedStore.reference(for: sensor.id),
                      let presentation = slot.display.compactPresentation else {
                    continue
                }
                let snapshot = snapshotsByIdentifier[sensor.id] ?? sensor.fallbackSnapshot
                let item = WidgetSensorBoardCompactItem.sensor(
                    from: snapshot,
                    customDisplayName: slot.customDisplayName,
                    presentation: presentation
                )
                let updatedItem = liveReadingsByIdentifier[sensor.id].map(item.updating(with:)) ?? item
                let configuredItem = slot.display == .gauge
                    ? updatedItem.applyingGaugeConfiguration(slot.gaugeConfiguration)
                    : updatedItem
                items[index] = .compact(configuredItem.scoped(to: reference))
            }
        }

        return HomesteadSensorBoardEntry(
            date: .now,
            items: items,
            isConfigured: items.contains(where: { $0 != nil })
        )
    }

    private static func loadLiveReadings(
        slots: [HomesteadSensorBoardSlotConfiguration]
    ) async -> [String: WidgetSensorLiveReading] {
        let references = slots.compactMap { slot -> EntityPresentationReference? in
            guard slot.display != .chart, let identifier = slot.sensor?.id else { return nil }
            return HomesteadWidgetSharedStore.reference(for: identifier)
        }
        let grouped = Dictionary(grouping: references, by: \.profileID)

        return await withTaskGroup(of: [String: WidgetSensorLiveReading].self) { group in
            for (profileID, references) in grouped {
                guard HomesteadWidgetSharedStore.isServerAvailable(profileID: profileID) else { continue }
                group.addTask {
                    do {
                        let readings = try await HAWidgetActionClient(profileID: profileID)
                            .fetchSensorStates(entityIDs: Set(references.map(\.entityID)))
                            .mapValues(\.liveReading)
                        return references.reduce(into: [:]) { result, reference in
                            result[reference.encodedID] = readings[reference.entityID]
                        }
                    } catch {
                        return [:]
                    }
                }
            }

            var result: [String: WidgetSensorLiveReading] = [:]
            for await values in group {
                result.merge(values, uniquingKeysWith: { _, latest in latest })
            }
            return result
        }
    }

    private static func loadHistories(
        slots: [HomesteadSensorBoardSlotConfiguration]
    ) async -> HistoryLoadResult {
        let sensors = slots.compactMap { slot in
            slot.display == .chart && slot.sensor?.isNumeric == true ? slot.sensor : nil
        }
        let grouped = Dictionary(grouping: sensors) {
            HomesteadWidgetSharedStore.reference(for: $0.id)?.profileID
        }

        return await withTaskGroup(of: HistoryLoadResult.self) { group in
            for (optionalProfileID, sensors) in grouped {
                guard let profileID = optionalProfileID,
                      HomesteadWidgetSharedStore.isServerAvailable(profileID: profileID) else {
                    if let profileID = optionalProfileID {
                        group.addTask {
                            HistoryLoadResult(seriesByIdentifier: [:], failedProfiles: [profileID])
                        }
                    }
                    continue
                }
                group.addTask {
                    do {
                        let requests = sensors.compactMap { sensor -> HAWidgetSensorHistoryRequest? in
                            guard let reference = HomesteadWidgetSharedStore.reference(for: sensor.id) else {
                                return nil
                            }
                            return HAWidgetSensorHistoryRequest(
                                entityID: reference.entityID,
                                displayName: sensor.displayName,
                                unit: sensor.unit
                            )
                        }
                        let fetched = try await HAWidgetActionClient(profileID: profileID)
                            .fetchSensorHistories(requests)
                        let scoped = sensors.reduce(
                            into: [String: HAWidgetSensorHistorySeries]()
                        ) { result, sensor in
                            guard let reference = HomesteadWidgetSharedStore.reference(for: sensor.id) else {
                                return
                            }
                            result[sensor.id] = fetched[reference.entityID]
                        }
                        return HistoryLoadResult(seriesByIdentifier: scoped, failedProfiles: [])
                    } catch {
                        return HistoryLoadResult(seriesByIdentifier: [:], failedProfiles: [profileID])
                    }
                }
            }

            var result = HistoryLoadResult(seriesByIdentifier: [:], failedProfiles: [])
            for await partial in group {
                result.seriesByIdentifier.merge(
                    partial.seriesByIdentifier,
                    uniquingKeysWith: { _, latest in latest }
                )
                result.failedProfiles.formUnion(partial.failedProfiles)
            }
            return result
        }
    }

    private static func makeChartItem(
        sensor: HomesteadSensorEntity,
        customDisplayName: String?,
        snapshot: WidgetSensorSnapshot?,
        series: HAWidgetSensorHistorySeries?,
        connectionFailed: Bool
    ) -> WidgetSensorBoardChartItem {
        let trimmedName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = trimmedName.isEmpty ? sensor.displayName : trimmedName
        let interpolationStyle = snapshot?.historyChartInterpolationStyle
            ?? sensor.historyChartInterpolationStyle
            ?? .linear

        guard sensor.isNumeric else {
            return WidgetSensorBoardChartItem(
                id: sensor.id,
                displayName: displayName,
                icon: snapshot?.resolvedIcon ?? sensor.resolvedIcon,
                valueText: snapshot?.valueText ?? sensor.valueText,
                unitText: snapshot?.unit ?? sensor.unit,
                supportingText: WidgetStateText.chartUnavailable,
                isAvailable: snapshot?.isAvailable ?? sensor.isAvailable,
                samples: [],
                valueDomain: 0...1,
                interpolationStyle: interpolationStyle,
                accentColor: snapshot?.chartAccentColor ?? sensor.chartAccentColor ?? .accent
            )
        }

        if let series {
            return WidgetSensorBoardChartItem(
                id: sensor.id,
                displayName: displayName,
                icon: snapshot?.resolvedIcon ?? sensor.resolvedIcon,
                valueText: series.latestValueText ?? snapshot?.valueText ?? sensor.valueText,
                unitText: series.unit,
                supportingText: WidgetStateText.noHistory,
                isAvailable: snapshot?.isAvailable ?? sensor.isAvailable,
                samples: series.samples.map { .init(occurredAt: $0.occurredAt, value: $0.value) },
                valueDomain: HomesteadChartDomain.stabilized(
                    values: series.samples.map(\.value),
                    unit: series.unit
                ),
                interpolationStyle: interpolationStyle,
                accentColor: snapshot?.chartAccentColor ?? sensor.chartAccentColor ?? .accent
            )
        }

        return WidgetSensorBoardChartItem(
            id: sensor.id,
            displayName: displayName,
            icon: snapshot?.resolvedIcon ?? sensor.resolvedIcon,
            valueText: snapshot?.valueText ?? sensor.valueText,
            unitText: snapshot?.unit ?? sensor.unit,
            supportingText: connectionFailed ? WidgetStateText.needsConnection : WidgetStateText.noHistory,
            isAvailable: !connectionFailed && (snapshot?.isAvailable ?? sensor.isAvailable),
            samples: [],
            valueDomain: 0...1,
            interpolationStyle: interpolationStyle,
            accentColor: snapshot?.chartAccentColor ?? sensor.chartAccentColor ?? .accent
        )
    }

    private struct HistoryLoadResult {
        var seriesByIdentifier: [String: HAWidgetSensorHistorySeries]
        var failedProfiles: Set<UUID>
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
