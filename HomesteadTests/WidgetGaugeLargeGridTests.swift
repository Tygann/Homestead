import Testing
@testable import Homestead

struct WidgetGaugeLargeGridTests {
    @Test func largeGridSelectionPreservesNineOrderedItems() {
        let items = (1...10).map { index in
            HomesteadWidgetItem(
                id: "sensor.gauge_\(index)",
                kind: .sensorGauge,
                displayName: "Gauge \(index)",
                icon: .sfSymbol("gauge.medium", provenance: .homesteadSemanticMapping),
                valueText: "\(index)",
                unitText: nil,
                isAvailable: true,
                gauge: nil,
                accessibilityLabel: "Gauge \(index)",
                accessibilityValue: "\(index)"
            )
        }

        let selected = HomesteadWidgetGridSelection.compacted(
            items.map(Optional.some),
            maximumItemCount: 9
        )

        #expect(selected.map(\.id) == items.prefix(9).map(\.id))
    }
}
