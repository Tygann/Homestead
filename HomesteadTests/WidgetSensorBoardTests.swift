import Foundation
import Testing
@testable import Homestead

struct WidgetSensorBoardTests {
    @Test func boardItemUsesConfiguredEntityForEitherPresentation() {
        let compact = WidgetSensorBoardCompactItem.sensor(from: makeSnapshot(gauge: makeGauge()))
        let chart = makeChartItem()

        #expect(WidgetSensorBoardItem.compact(compact).id == compact.id)
        #expect(WidgetSensorBoardItem.chart(chart).id == chart.id)
    }

    @Test func largeBoardPreservesNineOrderedMixedItems() {
        let compact = WidgetSensorBoardCompactItem.sensor(from: makeSnapshot(gauge: makeGauge()))
        let chart = makeChartItem()
        let items: [WidgetSensorBoardItem] = [
            .chart(chart),
            .compact(compact),
            .chart(chart),
            .compact(compact),
            .compact(compact),
            .chart(chart),
            .compact(compact),
            .chart(chart),
            .compact(compact)
        ]

        #expect(items.count == 9)
        #expect(items.map(\.id) == [
            chart.id,
            compact.id,
            chart.id,
            compact.id,
            compact.id,
            chart.id,
            compact.id,
            chart.id,
            compact.id
        ])
    }

    @Test func automaticPresentationUsesGaugeWhenAvailable() {
        let item = WidgetSensorBoardCompactItem.sensor(from: makeSnapshot(gauge: makeGauge()))

        #expect(item.resolvedPresentation == .gauge)
    }

    @Test func sensorBoardItemsPreserveEachGaugeRendererStyle() {
        let snapshot = makeSnapshot(gauge: makeGauge())

        #expect(WidgetSensorBoardCompactItem.sensor(from: snapshot, gaugeStyle: .circular).gaugeStyle == .circular)
        #expect(WidgetSensorBoardCompactItem.sensor(from: snapshot, gaugeStyle: .segmented).gaugeStyle == .segmented)
        #expect(WidgetSensorBoardCompactItem.sensor(from: snapshot, gaugeStyle: .bar).gaugeStyle == .bar)
    }

    @Test func automaticAndRequestedGaugeFallbackToReadingWithoutGaugeData() {
        let snapshot = makeSnapshot(gauge: nil)
        let automaticItem = WidgetSensorBoardCompactItem.sensor(from: snapshot)
        let gaugeItem = WidgetSensorBoardCompactItem.sensor(
            from: snapshot,
            presentation: .gauge
        )

        #expect(automaticItem.resolvedPresentation == .reading)
        #expect(gaugeItem.resolvedPresentation == .reading)
    }

    @Test func explicitReadingKeepsBoundedSensorAsReading() {
        let item = WidgetSensorBoardCompactItem.sensor(
            from: makeSnapshot(gauge: makeGauge()),
            customDisplayName: "Room Temp",
            presentation: .reading
        )

        #expect(item.displayName == "Room Temp")
        #expect(item.resolvedPresentation == .reading)
    }

    @Test func liveReadingRefreshesValueGaugeAvailabilityAndSemanticIcon() {
        let item = WidgetSensorBoardCompactItem.sensor(from: makeSnapshot(gauge: makeGauge()))
        let reading = WidgetSensorLiveReading(
            entityID: item.id,
            valueText: "74°F",
            numericValue: 74,
            isAvailable: false,
            icon: .sfSymbol("thermometer.high", provenance: .haSemanticMapping)
        )

        let updated = item.updating(with: reading)

        #expect(updated.valueText == "74°F")
        #expect(updated.gauge?.value == 74)
        #expect(updated.gauge?.valueText == "74°F")
        #expect(updated.icon == reading.icon)
        #expect(!updated.isAvailable)
    }

    @Test func sharedChartDomainUsesDashboardTemperatureStabilizationAndHeadroom() {
        let domain = HomesteadChartDomain.stabilized(values: [72, 73], unit: "°F")
        let displayDomain = HomesteadChartDomain.addingHeadroom(to: domain)

        #expect(domain.lowerBound == 70.5)
        #expect(domain.upperBound == 74.5)
        #expect(abs(displayDomain.lowerBound - 70.34) < 0.000_001)
        #expect(abs(displayDomain.upperBound - 74.66) < 0.000_001)
    }

    @Test func sharedChartDomainPreservesWiderObservedRanges() {
        let domain = HomesteadChartDomain.stabilized(values: [0, 20], unit: nil)

        #expect(abs(domain.lowerBound - -2.4) < 0.000_001)
        #expect(abs(domain.upperBound - 22.4) < 0.000_001)
    }

    @Test func sensorBoardChartUsesSharedWidgetChartPresentation() {
        let item = makeChartItem()
        let samples = item.samples

        #expect(item.chartPresentation.title == "Living Room")
        #expect(item.chartPresentation.unitText == "°F")
        #expect(item.chartPresentation.samples == samples)
        #expect(item.chartPresentation.interpolationStyle == .smooth)
        #expect(item.chartPresentation.rangeTitle == "6H")
        #expect(item.accentColor == .orange)
    }

    @Test func sensorBoardChartDistinguishesPlotNoHistoryUnavailableAndConnectionStates() {
        let plotted = makeChartItem()
        let noHistory = makeChartItem(samples: [], isAvailable: true, supportingText: WidgetStateText.noHistory)
        let unavailable = makeChartItem(samples: [], isAvailable: false, supportingText: WidgetStateText.noHistory)
        let unsupported = makeChartItem(
            samples: [],
            isAvailable: true,
            supportingText: WidgetStateText.chartUnavailable
        )
        let disconnected = makeChartItem(
            samples: [],
            isAvailable: false,
            supportingText: WidgetStateText.needsConnection
        )

        #expect(plotted.hasChart)
        #expect(noHistory.chartStatusText == WidgetStateText.noHistory)
        #expect(unavailable.chartStatusText == WidgetStateText.unavailable)
        #expect(unsupported.chartStatusText == WidgetStateText.chartUnavailable)
        #expect(disconnected.chartStatusText == WidgetStateText.needsConnection)
    }

    @Test func barGaugeSlotAppliesStyleScaleBoundariesAndColors() {
        let item = WidgetSensorBoardCompactItem.sensor(
            from: makeSnapshot(gauge: makeGauge()),
            presentation: .gauge
        )
        let configuration = sensorBoardGaugeConfiguration(
            style: .bar,
            gaugeScale: .custom,
            gaugeMinimum: 60,
            gaugeMaximum: 90,
            zoneCount: .three,
            zone1Color: .blue,
            zone2BeginsAt: 70,
            zone2Color: .green,
            zone3BeginsAt: 80,
            zone3Color: .red,
            zone4BeginsAt: nil,
            zone4Color: .orange,
            zone5BeginsAt: nil,
            zone5Color: .purple
        )

        let configured = item.applyingGaugeConfiguration(configuration)

        #expect(configured.gauge?.lowerBound == 60)
        #expect(configured.gauge?.upperBound == 90)
        #expect(configured.gauge?.sections == [
            WidgetGaugeSection(lowerBound: 60, upperBound: 70, color: .blue),
            WidgetGaugeSection(lowerBound: 70, upperBound: 80, color: .green),
            WidgetGaugeSection(lowerBound: 80, upperBound: 90, color: .red)
        ])
        #expect(configured.requestedPresentation == .gauge)
        #expect(configured.gaugeStyle == .bar)
    }

    private func makeChartItem(
        samples: [HomesteadChartSample]? = nil,
        isAvailable: Bool = true,
        supportingText: String = "No recent chart"
    ) -> WidgetSensorBoardChartItem {
        WidgetSensorBoardChartItem(
            id: "sensor.living_room_temperature",
            displayName: "Living Room",
            icon: .sfSymbol("thermometer.medium", provenance: .homesteadSemanticMapping),
            valueText: "72°F",
            unitText: "°F",
            supportingText: supportingText,
            isAvailable: isAvailable,
            samples: samples ?? [
                HomesteadChartSample(occurredAt: .now.addingTimeInterval(-60), value: 71),
                HomesteadChartSample(occurredAt: .now, value: 72)
            ],
            valueDomain: 70...74,
            interpolationStyle: .smooth,
            accentColor: .orange
        )
    }

    private func makeSnapshot(gauge: WidgetGaugePresentation?) -> WidgetSensorSnapshot {
        WidgetSensorSnapshot(
            entityID: "sensor.living_room_temperature",
            displayName: "Living Room Temperature",
            valueText: "72°F",
            subtitle: "Temperature",
            systemImage: "thermometer.medium",
            unit: "°F",
            isNumeric: true,
            isAlerting: false,
            isAvailable: true,
            areaName: "Living Room",
            deviceName: nil,
            gauge: gauge
        )
    }

    private func makeGauge() -> WidgetGaugePresentation {
        WidgetGaugePresentation(
            value: 72,
            lowerBound: 60,
            upperBound: 85,
            valueText: "72°F",
            unitText: "°F",
            status: .nominal,
            statusDisplayText: "Comfortable",
            sections: [.init(lowerBound: 60, upperBound: 85, color: .green)],
            accessibilityLabel: "Living Room Temperature gauge",
            accessibilityValue: "72°F"
        )
    }
}
