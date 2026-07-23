import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Configuration

struct HomesteadLargeSensorBoardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: HomesteadWidgetKind.largeSensorBoard.rawValue,
            intent: HomesteadLargeSensorBoardWidgetConfigurationIntent.self,
            provider: HomesteadLargeSensorBoardTimelineProvider()
        ) { entry in
            HomesteadLargeSensorBoardWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(
            SharedFeatureCatalog.widgetDescriptor(for: .largeSensorBoard)!.displayName
        )
        .description(SharedFeatureCatalog.widgetDescriptor(for: .largeSensorBoard)!.description)
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

enum HomesteadLargeSensorBoardEditingSlot: Int, AppEnum {
    case one = 1
    case two
    case three
    case four
    case five
    case six

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Configure Slot")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .one: "Slot 1",
        .two: "Slot 2",
        .three: "Slot 3",
        .four: "Slot 4",
        .five: "Slot 5",
        .six: "Slot 6"
    ]
}

struct HomesteadLargeSensorBoardWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Large Sensor Board"
    static var description = IntentDescription(
        "Combine up to six sensor readings, gauges, or six-hour charts."
    )

    @Parameter(title: "Configure Slot", default: .one)
    var editingSlot: HomesteadLargeSensorBoardEditingSlot

    @Parameter(title: "Slot 1 Display", default: .automatic)
    var display1: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 1 Sensor") var sensor1: HomesteadSensorEntity?
    @Parameter(title: "Slot 1 Chart Sensor") var chartSensor1: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 1 Display Name") var customDisplayName1: String?

    @Parameter(title: "Slot 2 Display", default: .automatic)
    var display2: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 2 Sensor") var sensor2: HomesteadSensorEntity?
    @Parameter(title: "Slot 2 Chart Sensor") var chartSensor2: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 2 Display Name") var customDisplayName2: String?

    @Parameter(title: "Slot 3 Display", default: .chart)
    var display3: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 3 Sensor") var sensor3: HomesteadSensorEntity?
    @Parameter(title: "Slot 3 Chart Sensor") var chartSensor3: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 3 Display Name") var customDisplayName3: String?

    @Parameter(title: "Slot 4 Display", default: .automatic)
    var display4: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 4 Sensor") var sensor4: HomesteadSensorEntity?
    @Parameter(title: "Slot 4 Chart Sensor") var chartSensor4: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 4 Display Name") var customDisplayName4: String?

    @Parameter(title: "Slot 5 Display", default: .automatic)
    var display5: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 5 Sensor") var sensor5: HomesteadSensorEntity?
    @Parameter(title: "Slot 5 Chart Sensor") var chartSensor5: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 5 Display Name") var customDisplayName5: String?

    @Parameter(title: "Slot 6 Display", default: .chart)
    var display6: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 6 Sensor") var sensor6: HomesteadSensorEntity?
    @Parameter(title: "Slot 6 Chart Sensor") var chartSensor6: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 6 Display Name") var customDisplayName6: String?

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
                    Summary {
                        \.$editingSlot
                        \.$display1
                        \.$sensor1
                        \.$customDisplayName1
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
                    Summary {
                        \.$editingSlot
                        \.$display2
                        \.$sensor2
                        \.$customDisplayName2
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
                    Summary {
                        \.$editingSlot
                        \.$display3
                        \.$sensor3
                        \.$customDisplayName3
                    }
                }
            }
            Case(.four) {
                When(\.$display4, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display4
                        \.$chartSensor4
                        \.$customDisplayName4
                    }
                } otherwise: {
                    Summary {
                        \.$editingSlot
                        \.$display4
                        \.$sensor4
                        \.$customDisplayName4
                    }
                }
            }
            Case(.five) {
                When(\.$display5, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display5
                        \.$chartSensor5
                        \.$customDisplayName5
                    }
                } otherwise: {
                    Summary {
                        \.$editingSlot
                        \.$display5
                        \.$sensor5
                        \.$customDisplayName5
                    }
                }
            }
            Case(.six) {
                When(\.$display6, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display6
                        \.$chartSensor6
                        \.$customDisplayName6
                    }
                } otherwise: {
                    Summary {
                        \.$editingSlot
                        \.$display6
                        \.$sensor6
                        \.$customDisplayName6
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

    var slots: [HomesteadSensorBoardSlotConfiguration] {
        [
            slot(display1, sensor1, chartSensor1, customDisplayName1),
            slot(display2, sensor2, chartSensor2, customDisplayName2),
            slot(display3, sensor3, chartSensor3, customDisplayName3),
            slot(display4, sensor4, chartSensor4, customDisplayName4),
            slot(display5, sensor5, chartSensor5, customDisplayName5),
            slot(display6, sensor6, chartSensor6, customDisplayName6)
        ]
    }

    private func slot(
        _ display: HomesteadSensorBoardSlotDisplay,
        _ sensor: HomesteadSensorEntity?,
        _ chartSensor: HomesteadChartSensorEntity?,
        _ customDisplayName: String?
    ) -> HomesteadSensorBoardSlotConfiguration {
        HomesteadSensorBoardSlotConfiguration(
            display: display,
            sensor: sensor,
            chartSensor: chartSensor,
            customDisplayName: customDisplayName,
            customChartDisplayName: customDisplayName
        )
    }
}

// MARK: - Timeline

struct HomesteadLargeSensorBoardTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSensorBoardEntry {
        .largePlaceholder
    }

    func snapshot(
        for configuration: HomesteadLargeSensorBoardWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadSensorBoardEntry {
        if context.isPreview,
           configuration.slots.allSatisfy({ $0.sensor == nil && $0.chartSensor == nil }) {
            return .largePlaceholder
        }

        return await HomesteadSensorBoardEntryBuilder.entry(slots: configuration.slots)
    }

    func timeline(
        for configuration: HomesteadLargeSensorBoardWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSensorBoardEntry> {
        Timeline(
            entries: [await HomesteadSensorBoardEntryBuilder.entry(slots: configuration.slots)],
            policy: .after(.now.addingTimeInterval(30 * 60))
        )
    }
}

// MARK: - Widget View

struct HomesteadLargeSensorBoardWidgetView: View {
    let entry: HomesteadSensorBoardEntry

    var body: some View {
        WidgetSensorBoardFace(
            items: entry.items,
            layout: .large,
            destinationsByEntityID: destinations
        )
    }

    private var destinations: [String: URL] {
        entry.items.compactMap { $0?.id }.reduce(into: [:]) { result, entityID in
            result[entityID] = HomesteadWidgetDeepLink.entityURL(entityID: entityID)
        }
    }
}

// MARK: - Preview

private extension HomesteadSensorBoardEntry {
    static var largePlaceholder: Self {
        Self(
            date: .now,
            items: placeholder.items + placeholder.items,
            isConfigured: true
        )
    }
}

#Preview(as: .systemLarge) {
    HomesteadLargeSensorBoardWidget()
} timeline: {
    HomesteadSensorBoardEntry.largePlaceholder
}
