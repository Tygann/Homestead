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

    private func makeChartItem() -> WidgetSensorBoardChartItem {
        WidgetSensorBoardChartItem(
            id: "sensor.living_room_temperature",
            displayName: "Living Room",
            icon: .sfSymbol("thermometer.medium", provenance: .homesteadSemanticMapping),
            valueText: "72°F",
            unitText: "°F",
            supportingText: "No recent chart",
            isAvailable: true,
            samples: [
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
