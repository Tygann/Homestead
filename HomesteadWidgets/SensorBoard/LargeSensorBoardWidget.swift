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

enum HomesteadLargeSensorBoardEditingSlot: String, AppEnum {
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Configure Slot")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .one: "Slot 1",
        .two: "Slot 2",
        .three: "Slot 3",
        .four: "Slot 4",
        .five: "Slot 5",
        .six: "Slot 6",
        .seven: "Slot 7",
        .eight: "Slot 8",
        .nine: "Slot 9"
    ]
}

struct HomesteadLargeSensorBoardWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Large Sensor Board"
    static var description = IntentDescription(
        "Combine up to nine sensor readings, gauges, or six-hour charts."
    )

    @Parameter(title: "Configure Slot", default: .one)
    var editingSlot: HomesteadLargeSensorBoardEditingSlot

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

    @Parameter(title: "Slot 4 Display", default: .automatic)
    var display4: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 4 Sensor") var sensor4: HomesteadSensorEntity?
    @Parameter(title: "Slot 4 Chart Sensor") var chartSensor4: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 4 Display Name") var customDisplayName4: String?

    @Parameter(title: "Slot 4 Scale", default: .automatic)
    var gaugeScale4: HomesteadGaugeScale
    @Parameter(title: "Slot 4 Minimum") var gaugeMinimum4: Double?
    @Parameter(title: "Slot 4 Maximum") var gaugeMaximum4: Double?
    @Parameter(title: "Slot 4 Zones", default: .automatic)
    var zoneCount4: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 4 Zone 1 Color", default: .blue)
    var zone1Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 4 Zone 2 Begins At") var zone2BeginsAt4: Double?
    @Parameter(title: "Slot 4 Zone 2 Color", default: .green)
    var zone2Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 4 Zone 3 Begins At") var zone3BeginsAt4: Double?
    @Parameter(title: "Slot 4 Zone 3 Color", default: .orange)
    var zone3Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 4 Zone 4 Begins At") var zone4BeginsAt4: Double?
    @Parameter(title: "Slot 4 Zone 4 Color", default: .red)
    var zone4Color4: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 4 Zone 5 Begins At") var zone5BeginsAt4: Double?
    @Parameter(title: "Slot 4 Zone 5 Color", default: .purple)
    var zone5Color4: HomesteadGaugeZoneColor

    @Parameter(title: "Slot 5 Display", default: .automatic)
    var display5: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 5 Sensor") var sensor5: HomesteadSensorEntity?
    @Parameter(title: "Slot 5 Chart Sensor") var chartSensor5: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 5 Display Name") var customDisplayName5: String?

    @Parameter(title: "Slot 5 Scale", default: .automatic)
    var gaugeScale5: HomesteadGaugeScale
    @Parameter(title: "Slot 5 Minimum") var gaugeMinimum5: Double?
    @Parameter(title: "Slot 5 Maximum") var gaugeMaximum5: Double?
    @Parameter(title: "Slot 5 Zones", default: .automatic)
    var zoneCount5: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 5 Zone 1 Color", default: .blue)
    var zone1Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 5 Zone 2 Begins At") var zone2BeginsAt5: Double?
    @Parameter(title: "Slot 5 Zone 2 Color", default: .green)
    var zone2Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 5 Zone 3 Begins At") var zone3BeginsAt5: Double?
    @Parameter(title: "Slot 5 Zone 3 Color", default: .orange)
    var zone3Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 5 Zone 4 Begins At") var zone4BeginsAt5: Double?
    @Parameter(title: "Slot 5 Zone 4 Color", default: .red)
    var zone4Color5: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 5 Zone 5 Begins At") var zone5BeginsAt5: Double?
    @Parameter(title: "Slot 5 Zone 5 Color", default: .purple)
    var zone5Color5: HomesteadGaugeZoneColor

    @Parameter(title: "Slot 6 Display", default: .chart)
    var display6: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 6 Sensor") var sensor6: HomesteadSensorEntity?
    @Parameter(title: "Slot 6 Chart Sensor") var chartSensor6: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 6 Display Name") var customDisplayName6: String?

    @Parameter(title: "Slot 6 Scale", default: .automatic)
    var gaugeScale6: HomesteadGaugeScale
    @Parameter(title: "Slot 6 Minimum") var gaugeMinimum6: Double?
    @Parameter(title: "Slot 6 Maximum") var gaugeMaximum6: Double?
    @Parameter(title: "Slot 6 Zones", default: .automatic)
    var zoneCount6: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 6 Zone 1 Color", default: .blue)
    var zone1Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 6 Zone 2 Begins At") var zone2BeginsAt6: Double?
    @Parameter(title: "Slot 6 Zone 2 Color", default: .green)
    var zone2Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 6 Zone 3 Begins At") var zone3BeginsAt6: Double?
    @Parameter(title: "Slot 6 Zone 3 Color", default: .orange)
    var zone3Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 6 Zone 4 Begins At") var zone4BeginsAt6: Double?
    @Parameter(title: "Slot 6 Zone 4 Color", default: .red)
    var zone4Color6: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 6 Zone 5 Begins At") var zone5BeginsAt6: Double?
    @Parameter(title: "Slot 6 Zone 5 Color", default: .purple)
    var zone5Color6: HomesteadGaugeZoneColor

    @Parameter(title: "Slot 7 Display", default: .automatic)
    var display7: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 7 Sensor") var sensor7: HomesteadSensorEntity?
    @Parameter(title: "Slot 7 Chart Sensor") var chartSensor7: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 7 Display Name") var customDisplayName7: String?

    @Parameter(title: "Slot 7 Scale", default: .automatic)
    var gaugeScale7: HomesteadGaugeScale
    @Parameter(title: "Slot 7 Minimum") var gaugeMinimum7: Double?
    @Parameter(title: "Slot 7 Maximum") var gaugeMaximum7: Double?
    @Parameter(title: "Slot 7 Zones", default: .automatic)
    var zoneCount7: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 7 Zone 1 Color", default: .blue)
    var zone1Color7: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 7 Zone 2 Begins At") var zone2BeginsAt7: Double?
    @Parameter(title: "Slot 7 Zone 2 Color", default: .green)
    var zone2Color7: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 7 Zone 3 Begins At") var zone3BeginsAt7: Double?
    @Parameter(title: "Slot 7 Zone 3 Color", default: .orange)
    var zone3Color7: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 7 Zone 4 Begins At") var zone4BeginsAt7: Double?
    @Parameter(title: "Slot 7 Zone 4 Color", default: .red)
    var zone4Color7: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 7 Zone 5 Begins At") var zone5BeginsAt7: Double?
    @Parameter(title: "Slot 7 Zone 5 Color", default: .purple)
    var zone5Color7: HomesteadGaugeZoneColor

    @Parameter(title: "Slot 8 Display", default: .automatic)
    var display8: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 8 Sensor") var sensor8: HomesteadSensorEntity?
    @Parameter(title: "Slot 8 Chart Sensor") var chartSensor8: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 8 Display Name") var customDisplayName8: String?

    @Parameter(title: "Slot 8 Scale", default: .automatic)
    var gaugeScale8: HomesteadGaugeScale
    @Parameter(title: "Slot 8 Minimum") var gaugeMinimum8: Double?
    @Parameter(title: "Slot 8 Maximum") var gaugeMaximum8: Double?
    @Parameter(title: "Slot 8 Zones", default: .automatic)
    var zoneCount8: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 8 Zone 1 Color", default: .blue)
    var zone1Color8: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 8 Zone 2 Begins At") var zone2BeginsAt8: Double?
    @Parameter(title: "Slot 8 Zone 2 Color", default: .green)
    var zone2Color8: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 8 Zone 3 Begins At") var zone3BeginsAt8: Double?
    @Parameter(title: "Slot 8 Zone 3 Color", default: .orange)
    var zone3Color8: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 8 Zone 4 Begins At") var zone4BeginsAt8: Double?
    @Parameter(title: "Slot 8 Zone 4 Color", default: .red)
    var zone4Color8: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 8 Zone 5 Begins At") var zone5BeginsAt8: Double?
    @Parameter(title: "Slot 8 Zone 5 Color", default: .purple)
    var zone5Color8: HomesteadGaugeZoneColor

    @Parameter(title: "Slot 9 Display", default: .chart)
    var display9: HomesteadSensorBoardSlotDisplay
    @Parameter(title: "Slot 9 Sensor") var sensor9: HomesteadSensorEntity?
    @Parameter(title: "Slot 9 Chart Sensor") var chartSensor9: HomesteadChartSensorEntity?
    @Parameter(title: "Slot 9 Display Name") var customDisplayName9: String?

    @Parameter(title: "Slot 9 Scale", default: .automatic)
    var gaugeScale9: HomesteadGaugeScale
    @Parameter(title: "Slot 9 Minimum") var gaugeMinimum9: Double?
    @Parameter(title: "Slot 9 Maximum") var gaugeMaximum9: Double?
    @Parameter(title: "Slot 9 Zones", default: .automatic)
    var zoneCount9: HomesteadGaugeZoneCount
    @Parameter(title: "Slot 9 Zone 1 Color", default: .blue)
    var zone1Color9: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 9 Zone 2 Begins At") var zone2BeginsAt9: Double?
    @Parameter(title: "Slot 9 Zone 2 Color", default: .green)
    var zone2Color9: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 9 Zone 3 Begins At") var zone3BeginsAt9: Double?
    @Parameter(title: "Slot 9 Zone 3 Color", default: .orange)
    var zone3Color9: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 9 Zone 4 Begins At") var zone4BeginsAt9: Double?
    @Parameter(title: "Slot 9 Zone 4 Color", default: .red)
    var zone4Color9: HomesteadGaugeZoneColor
    @Parameter(title: "Slot 9 Zone 5 Begins At") var zone5BeginsAt9: Double?
    @Parameter(title: "Slot 9 Zone 5 Color", default: .purple)
    var zone5Color9: HomesteadGaugeZoneColor

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
            Case(.four) {
                When(\.$display4, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display4
                        \.$chartSensor4
                        \.$customDisplayName4
                    }
                } otherwise: {
                    When(\.$display4, .equalTo, .gauge) {
                        When(\.$gaugeScale4, .equalTo, .custom) {
                            When(\.$zoneCount4, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display4
                                \.$sensor4
                                \.$customDisplayName4
                                \.$gaugeScale4
                                \.$gaugeMinimum4
                                \.$gaugeMaximum4
                                \.$zoneCount4
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display4
                                \.$sensor4
                                \.$customDisplayName4
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
                            }
                            }
                        } otherwise: {
                            When(\.$zoneCount4, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display4
                                \.$sensor4
                                \.$customDisplayName4
                                \.$gaugeScale4
                                \.$zoneCount4
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display4
                                \.$sensor4
                                \.$customDisplayName4
                                \.$gaugeScale4
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
                            }
                            }
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
                    When(\.$display5, .equalTo, .gauge) {
                        When(\.$gaugeScale5, .equalTo, .custom) {
                            When(\.$zoneCount5, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display5
                                \.$sensor5
                                \.$customDisplayName5
                                \.$gaugeScale5
                                \.$gaugeMinimum5
                                \.$gaugeMaximum5
                                \.$zoneCount5
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display5
                                \.$sensor5
                                \.$customDisplayName5
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
                            }
                            }
                        } otherwise: {
                            When(\.$zoneCount5, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display5
                                \.$sensor5
                                \.$customDisplayName5
                                \.$gaugeScale5
                                \.$zoneCount5
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display5
                                \.$sensor5
                                \.$customDisplayName5
                                \.$gaugeScale5
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
                            }
                            }
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
                    When(\.$display6, .equalTo, .gauge) {
                        When(\.$gaugeScale6, .equalTo, .custom) {
                            When(\.$zoneCount6, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display6
                                \.$sensor6
                                \.$customDisplayName6
                                \.$gaugeScale6
                                \.$gaugeMinimum6
                                \.$gaugeMaximum6
                                \.$zoneCount6
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display6
                                \.$sensor6
                                \.$customDisplayName6
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
                        } otherwise: {
                            When(\.$zoneCount6, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display6
                                \.$sensor6
                                \.$customDisplayName6
                                \.$gaugeScale6
                                \.$zoneCount6
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display6
                                \.$sensor6
                                \.$customDisplayName6
                                \.$gaugeScale6
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
            }
            Case(.seven) {
                When(\.$display7, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display7
                        \.$chartSensor7
                        \.$customDisplayName7
                    }
                } otherwise: {
                    When(\.$display7, .equalTo, .gauge) {
                        When(\.$gaugeScale7, .equalTo, .custom) {
                            When(\.$zoneCount7, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display7
                                \.$sensor7
                                \.$customDisplayName7
                                \.$gaugeScale7
                                \.$gaugeMinimum7
                                \.$gaugeMaximum7
                                \.$zoneCount7
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display7
                                \.$sensor7
                                \.$customDisplayName7
                                \.$gaugeScale7
                                \.$gaugeMinimum7
                                \.$gaugeMaximum7
                                \.$zoneCount7
                                \.$zone1Color7
                                \.$zone2BeginsAt7
                                \.$zone2Color7
                                \.$zone3BeginsAt7
                                \.$zone3Color7
                                \.$zone4BeginsAt7
                                \.$zone4Color7
                                \.$zone5BeginsAt7
                                \.$zone5Color7
                            }
                            }
                        } otherwise: {
                            When(\.$zoneCount7, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display7
                                \.$sensor7
                                \.$customDisplayName7
                                \.$gaugeScale7
                                \.$zoneCount7
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display7
                                \.$sensor7
                                \.$customDisplayName7
                                \.$gaugeScale7
                                \.$zoneCount7
                                \.$zone1Color7
                                \.$zone2BeginsAt7
                                \.$zone2Color7
                                \.$zone3BeginsAt7
                                \.$zone3Color7
                                \.$zone4BeginsAt7
                                \.$zone4Color7
                                \.$zone5BeginsAt7
                                \.$zone5Color7
                            }
                            }
                        }
                    } otherwise: {
                        Summary {
                            \.$editingSlot
                            \.$display7
                            \.$sensor7
                            \.$customDisplayName7
                        }
                    }
                }
            }
            Case(.eight) {
                When(\.$display8, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display8
                        \.$chartSensor8
                        \.$customDisplayName8
                    }
                } otherwise: {
                    When(\.$display8, .equalTo, .gauge) {
                        When(\.$gaugeScale8, .equalTo, .custom) {
                            When(\.$zoneCount8, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display8
                                \.$sensor8
                                \.$customDisplayName8
                                \.$gaugeScale8
                                \.$gaugeMinimum8
                                \.$gaugeMaximum8
                                \.$zoneCount8
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display8
                                \.$sensor8
                                \.$customDisplayName8
                                \.$gaugeScale8
                                \.$gaugeMinimum8
                                \.$gaugeMaximum8
                                \.$zoneCount8
                                \.$zone1Color8
                                \.$zone2BeginsAt8
                                \.$zone2Color8
                                \.$zone3BeginsAt8
                                \.$zone3Color8
                                \.$zone4BeginsAt8
                                \.$zone4Color8
                                \.$zone5BeginsAt8
                                \.$zone5Color8
                            }
                            }
                        } otherwise: {
                            When(\.$zoneCount8, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display8
                                \.$sensor8
                                \.$customDisplayName8
                                \.$gaugeScale8
                                \.$zoneCount8
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display8
                                \.$sensor8
                                \.$customDisplayName8
                                \.$gaugeScale8
                                \.$zoneCount8
                                \.$zone1Color8
                                \.$zone2BeginsAt8
                                \.$zone2Color8
                                \.$zone3BeginsAt8
                                \.$zone3Color8
                                \.$zone4BeginsAt8
                                \.$zone4Color8
                                \.$zone5BeginsAt8
                                \.$zone5Color8
                            }
                            }
                        }
                    } otherwise: {
                        Summary {
                            \.$editingSlot
                            \.$display8
                            \.$sensor8
                            \.$customDisplayName8
                        }
                    }
                }
            }
            Case(.nine) {
                When(\.$display9, .equalTo, .chart) {
                    Summary {
                        \.$editingSlot
                        \.$display9
                        \.$chartSensor9
                        \.$customDisplayName9
                    }
                } otherwise: {
                    When(\.$display9, .equalTo, .gauge) {
                        When(\.$gaugeScale9, .equalTo, .custom) {
                            When(\.$zoneCount9, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display9
                                \.$sensor9
                                \.$customDisplayName9
                                \.$gaugeScale9
                                \.$gaugeMinimum9
                                \.$gaugeMaximum9
                                \.$zoneCount9
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display9
                                \.$sensor9
                                \.$customDisplayName9
                                \.$gaugeScale9
                                \.$gaugeMinimum9
                                \.$gaugeMaximum9
                                \.$zoneCount9
                                \.$zone1Color9
                                \.$zone2BeginsAt9
                                \.$zone2Color9
                                \.$zone3BeginsAt9
                                \.$zone3Color9
                                \.$zone4BeginsAt9
                                \.$zone4Color9
                                \.$zone5BeginsAt9
                                \.$zone5Color9
                            }
                            }
                        } otherwise: {
                            When(\.$zoneCount9, .equalTo, .automatic) {
                            Summary {
                                \.$editingSlot
                                \.$display9
                                \.$sensor9
                                \.$customDisplayName9
                                \.$gaugeScale9
                                \.$zoneCount9
                            }
                            } otherwise: {
                            Summary {
                                \.$editingSlot
                                \.$display9
                                \.$sensor9
                                \.$customDisplayName9
                                \.$gaugeScale9
                                \.$zoneCount9
                                \.$zone1Color9
                                \.$zone2BeginsAt9
                                \.$zone2Color9
                                \.$zone3BeginsAt9
                                \.$zone3Color9
                                \.$zone4BeginsAt9
                                \.$zone4Color9
                                \.$zone5BeginsAt9
                                \.$zone5Color9
                            }
                            }
                        }
                    } otherwise: {
                        Summary {
                            \.$editingSlot
                            \.$display9
                            \.$sensor9
                            \.$customDisplayName9
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

    private var gaugeConfiguration4: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale4,
            gaugeMinimum: gaugeMinimum4,
            gaugeMaximum: gaugeMaximum4,
            zoneCount: zoneCount4,
            zone1Color: zone1Color4,
            zone2BeginsAt: zone2BeginsAt4,
            zone2Color: zone2Color4,
            zone3BeginsAt: zone3BeginsAt4,
            zone3Color: zone3Color4,
            zone4BeginsAt: zone4BeginsAt4,
            zone4Color: zone4Color4,
            zone5BeginsAt: zone5BeginsAt4,
            zone5Color: zone5Color4
        )
    }

    private var gaugeConfiguration5: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale5,
            gaugeMinimum: gaugeMinimum5,
            gaugeMaximum: gaugeMaximum5,
            zoneCount: zoneCount5,
            zone1Color: zone1Color5,
            zone2BeginsAt: zone2BeginsAt5,
            zone2Color: zone2Color5,
            zone3BeginsAt: zone3BeginsAt5,
            zone3Color: zone3Color5,
            zone4BeginsAt: zone4BeginsAt5,
            zone4Color: zone4Color5,
            zone5BeginsAt: zone5BeginsAt5,
            zone5Color: zone5Color5
        )
    }

    private var gaugeConfiguration6: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale6,
            gaugeMinimum: gaugeMinimum6,
            gaugeMaximum: gaugeMaximum6,
            zoneCount: zoneCount6,
            zone1Color: zone1Color6,
            zone2BeginsAt: zone2BeginsAt6,
            zone2Color: zone2Color6,
            zone3BeginsAt: zone3BeginsAt6,
            zone3Color: zone3Color6,
            zone4BeginsAt: zone4BeginsAt6,
            zone4Color: zone4Color6,
            zone5BeginsAt: zone5BeginsAt6,
            zone5Color: zone5Color6
        )
    }

    private var gaugeConfiguration7: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale7,
            gaugeMinimum: gaugeMinimum7,
            gaugeMaximum: gaugeMaximum7,
            zoneCount: zoneCount7,
            zone1Color: zone1Color7,
            zone2BeginsAt: zone2BeginsAt7,
            zone2Color: zone2Color7,
            zone3BeginsAt: zone3BeginsAt7,
            zone3Color: zone3Color7,
            zone4BeginsAt: zone4BeginsAt7,
            zone4Color: zone4Color7,
            zone5BeginsAt: zone5BeginsAt7,
            zone5Color: zone5Color7
        )
    }

    private var gaugeConfiguration8: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale8,
            gaugeMinimum: gaugeMinimum8,
            gaugeMaximum: gaugeMaximum8,
            zoneCount: zoneCount8,
            zone1Color: zone1Color8,
            zone2BeginsAt: zone2BeginsAt8,
            zone2Color: zone2Color8,
            zone3BeginsAt: zone3BeginsAt8,
            zone3Color: zone3Color8,
            zone4BeginsAt: zone4BeginsAt8,
            zone4Color: zone4Color8,
            zone5BeginsAt: zone5BeginsAt8,
            zone5Color: zone5Color8
        )
    }

    private var gaugeConfiguration9: HomesteadGaugeWidgetConfiguration {
        sensorBoardGaugeConfiguration(
            gaugeScale: gaugeScale9,
            gaugeMinimum: gaugeMinimum9,
            gaugeMaximum: gaugeMaximum9,
            zoneCount: zoneCount9,
            zone1Color: zone1Color9,
            zone2BeginsAt: zone2BeginsAt9,
            zone2Color: zone2Color9,
            zone3BeginsAt: zone3BeginsAt9,
            zone3Color: zone3Color9,
            zone4BeginsAt: zone4BeginsAt9,
            zone4Color: zone4Color9,
            zone5BeginsAt: zone5BeginsAt9,
            zone5Color: zone5Color9
        )
    }

    var slots: [HomesteadSensorBoardSlotConfiguration] {
        [
            slot(display1, sensor1, chartSensor1, customDisplayName1, gaugeConfiguration1),
            slot(display2, sensor2, chartSensor2, customDisplayName2, gaugeConfiguration2),
            slot(display3, sensor3, chartSensor3, customDisplayName3, gaugeConfiguration3),
            slot(display4, sensor4, chartSensor4, customDisplayName4, gaugeConfiguration4),
            slot(display5, sensor5, chartSensor5, customDisplayName5, gaugeConfiguration5),
            slot(display6, sensor6, chartSensor6, customDisplayName6, gaugeConfiguration6),
            slot(display7, sensor7, chartSensor7, customDisplayName7, gaugeConfiguration7),
            slot(display8, sensor8, chartSensor8, customDisplayName8, gaugeConfiguration8),
            slot(display9, sensor9, chartSensor9, customDisplayName9, gaugeConfiguration9)
        ]
    }

    private func slot(
        _ display: HomesteadSensorBoardSlotDisplay,
        _ sensor: HomesteadSensorEntity?,
        _ chartSensor: HomesteadChartSensorEntity?,
        _ customDisplayName: String?,
        _ gaugeConfiguration: HomesteadGaugeWidgetConfiguration
    ) -> HomesteadSensorBoardSlotConfiguration {
        HomesteadSensorBoardSlotConfiguration(
            display: display,
            sensor: sensor,
            chartSensor: chartSensor,
            customDisplayName: customDisplayName,
            customChartDisplayName: customDisplayName,
            gaugeConfiguration: gaugeConfiguration
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
        guard HomesteadWidgetPlusPolicy.allowsSensorBoard(
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        ) else {
            return .largePlaceholder
        }
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
        guard HomesteadWidgetPlusPolicy.allowsSensorBoard(
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        ) else {
            return Timeline(
                entries: [.largePlaceholder],
                policy: .after(.now.addingTimeInterval(30 * 60))
            )
        }
        return Timeline(
            entries: [await HomesteadSensorBoardEntryBuilder.entry(slots: configuration.slots)],
            policy: .after(.now.addingTimeInterval(30 * 60))
        )
    }
}

// MARK: - Widget View

struct HomesteadLargeSensorBoardWidgetView: View {
    let entry: HomesteadSensorBoardEntry

    var body: some View {
        if HomesteadWidgetPlusPolicy.allowsSensorBoard(
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        ) {
            WidgetSensorBoardFace(
                items: entry.items,
                layout: .large,
                destinationsByEntityID: destinations
            )
        } else {
            HomesteadPlusWidgetLockView()
        }
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
            items: placeholder.items + placeholder.items + placeholder.items,
            isConfigured: true
        )
    }
}

#Preview(as: .systemLarge) {
    HomesteadLargeSensorBoardWidget()
} timeline: {
    HomesteadSensorBoardEntry.largePlaceholder
}
