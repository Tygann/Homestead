import Testing
@testable import Homestead

struct WidgetSensorBoardTests {
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
