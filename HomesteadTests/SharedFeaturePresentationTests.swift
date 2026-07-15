import XCTest
@testable import Homestead

final class SharedFeaturePresentationTests: XCTestCase {
    func testWidgetKindsAreStableAndUnique() {
        let kinds = HomesteadWidgetKind.allCases.map(\.rawValue)

        XCTAssertEqual(kinds.count, 6)
        XCTAssertEqual(Set(kinds).count, kinds.count)
        XCTAssertEqual(HomesteadWidgetKind.sensor.rawValue, "HomesteadSensorGraphWidget")
        XCTAssertEqual(HomesteadWidgetKind.gaugeGrid.rawValue, "HomesteadGaugeGridWidget")
    }

    func testSharedCatalogContainsCrossSurfaceSensorGaugeDescriptor() {
        let descriptor = SharedFeatureCatalog.descriptor(id: "sensor-gauge")

        XCTAssertEqual(descriptor?.subjectKind, .sensor)
        XCTAssertEqual(descriptor?.category, .sensors)
        XCTAssertEqual(descriptor?.supportsDashboard, true)
        XCTAssertEqual(descriptor?.supportsWidget, true)
    }

    func testSharedPresentationTitleOverrideIsSurfaceLocalValue() {
        let presentation = SharedFeaturePresentation(
            subjectID: "sensor.kitchen_temperature",
            subjectKind: .sensor,
            title: "Kitchen Temperature",
            subtitle: "Temperature",
            valueText: "72°F",
            statusText: "Temperature",
            icon: .sfSymbol("thermometer.medium", provenance: .homesteadSemanticMapping),
            availability: .available,
            affordances: [.read, .gauge],
            accessibilityLabel: "Kitchen Temperature sensor",
            accessibilityValue: "72°F"
        )

        let dashboardPresentation = presentation.applyingTitleOverride("Dashboard Temperature")
        let widgetPresentation = presentation.applyingTitleOverride("Widget Temperature")

        XCTAssertEqual(presentation.title, "Kitchen Temperature")
        XCTAssertEqual(dashboardPresentation.title, "Dashboard Temperature")
        XCTAssertEqual(widgetPresentation.title, "Widget Temperature")
        XCTAssertEqual(dashboardPresentation.subjectID, widgetPresentation.subjectID)
        XCTAssertEqual(dashboardPresentation.valueText, widgetPresentation.valueText)
    }
}
