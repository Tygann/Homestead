import XCTest
@testable import Homestead

final class SharedFeaturePresentationTests: XCTestCase {
    func testWidgetKindsAreStableAndUnique() {
        let kinds = HomesteadWidgetKind.allCases.map(\.rawValue)

        XCTAssertEqual(kinds.count, 7)
        XCTAssertEqual(Set(kinds).count, kinds.count)
        XCTAssertEqual(HomesteadWidgetKind.sensor.rawValue, "HomesteadSensorGraphWidget")
        XCTAssertEqual(HomesteadWidgetKind.sensorBoard.rawValue, "HomesteadSensorBoardWidget")
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

    func testFeatureDescriptorsCoverEveryWidgetKind() {
        let descriptors = SharedFeatureCatalog.widgetDescriptors
        let kinds = descriptors.map(\.kind)

        XCTAssertEqual(Set(kinds).count, HomesteadWidgetKind.allCases.count)
        XCTAssertEqual(Set(kinds), Set(HomesteadWidgetKind.allCases))
        XCTAssertTrue(descriptors.allSatisfy { !$0.displayName.isEmpty && !$0.description.isEmpty })
    }

    @MainActor
    func testDashboardDescriptorsDeclareSharedFeatureRelationships() {
        let dashboardDescriptors = DashboardPresentationCatalog.descriptors

        for descriptor in dashboardDescriptors {
            guard let sharedFeatureID = descriptor.sharedFeatureID else { continue }
            XCTAssertNotNil(SharedFeatureCatalog.descriptor(id: sharedFeatureID))
        }
    }

    func testControlAndActionSnapshotsExposeSharedDefaults() {
        let light = WidgetLightSnapshot(
            entityID: "light.kitchen",
            displayName: "Kitchen Light",
            isOn: true,
            brightnessPercentage: 60,
            areaName: "Kitchen",
            deviceName: "Kitchen Lights"
        )
        let action = WidgetActionSnapshot(
            entityID: "scene.movie_time",
            displayName: "Movie Time",
            domain: "scene",
            systemImage: "sparkles",
            areaName: nil,
            deviceName: nil
        )

        XCTAssertEqual(light.sharedPresentation.subjectKind, .control)
        XCTAssertEqual(light.sharedPresentation.title, "Kitchen Light")
        XCTAssertTrue(light.sharedPresentation.affordances.contains(.primaryAction))
        XCTAssertEqual(action.sharedPresentation.subjectKind, .action)
        XCTAssertEqual(action.sharedPresentation.title, "Movie Time")
        XCTAssertTrue(action.sharedPresentation.affordances.contains(.primaryAction))
    }
}
