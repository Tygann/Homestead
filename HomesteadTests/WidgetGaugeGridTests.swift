import Foundation
import Testing
@testable import Homestead

struct WidgetGaugeGridTests {
    @Test func gridSelectionCompactsEmptySlotsAndPreservesOrder() {
        let items = (1...7).map { index in
            makeItem(id: "sensor.gauge_\(index)", name: "Gauge \(index)")
        }

        let selected = HomesteadWidgetGridSelection.compacted([
            items[2],
            nil,
            items[0],
            items[1],
            items[3],
            items[4],
            items[5],
            items[6]
        ])

        #expect(selected.map(\.id) == [
            "sensor.gauge_3",
            "sensor.gauge_1",
            "sensor.gauge_2",
            "sensor.gauge_4",
            "sensor.gauge_5",
            "sensor.gauge_6"
        ])
    }

    @Test func gridSelectionHonorsWidgetItemLimit() {
        let items = (1...5).map { index in
            makeItem(id: "sensor.gauge_\(index)", name: "Gauge \(index)")
        }

        let selected = HomesteadWidgetGridSelection.compacted(
            items.map(Optional.some),
            maximumItemCount: 3
        )

        #expect(selected.map(\.id) == [
            "sensor.gauge_1",
            "sensor.gauge_2",
            "sensor.gauge_3"
        ])
    }

    @Test func sensorGaugeItemMapsSnapshotPresentationAndAccessibility() {
        let gauge = makeGauge(value: 72, valueText: "72°F")
        let snapshot = WidgetSensorSnapshot(
            entityID: "sensor.living_room_temperature",
            displayName: "Living Room",
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

        let item = HomesteadWidgetItem.sensorGauge(from: snapshot)

        #expect(item?.id == snapshot.entityID)
        #expect(item?.kind == .sensorGauge)
        #expect(item?.displayName == "Living Room")
        #expect(item?.valueText == "72°F")
        #expect(item?.accessibilityLabel == "Living Room gauge")
        #expect(item?.accessibilityValue == "72°F")
    }

    @Test func sensorGaugeItemRejectsSnapshotsWithoutGaugeData() {
        let snapshot = WidgetSensorSnapshot(
            entityID: "sensor.text_only",
            displayName: "Text Sensor",
            valueText: "Ready",
            subtitle: "Status",
            systemImage: "textformat",
            unit: nil,
            isNumeric: false,
            isAlerting: false,
            isAvailable: true,
            areaName: nil,
            deviceName: nil
        )

        #expect(HomesteadWidgetItem.sensorGauge(from: snapshot) == nil)
    }

    private func makeItem(id: String, name: String) -> HomesteadWidgetItem {
        HomesteadWidgetItem(
            id: id,
            kind: .sensorGauge,
            displayName: name,
            icon: .sfSymbol("gauge.medium", provenance: .homesteadSemanticMapping),
            valueText: "72",
            unitText: nil,
            isAvailable: true,
            gauge: makeGauge(value: 72, valueText: "72"),
            accessibilityLabel: "\(name) gauge",
            accessibilityValue: "72"
        )
    }

    private func makeGauge(value: Double, valueText: String) -> WidgetGaugePresentation {
        WidgetGaugePresentation(
            value: value,
            lowerBound: 0,
            upperBound: 100,
            valueText: valueText,
            unitText: nil,
            status: .nominal,
            statusDisplayText: "Normal",
            sections: [WidgetGaugeSection(lowerBound: 0, upperBound: 100, color: .green)],
            accessibilityLabel: "Living Room gauge",
            accessibilityValue: valueText
        )
    }
}
