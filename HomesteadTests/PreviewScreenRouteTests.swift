import XCTest
@testable import Homestead

final class PreviewScreenRouteTests: XCTestCase {
    func testWidgetReferenceGalleryUsesCanonicalWidgetsRoute() {
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "widgets"), .widgets)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "settings"), .settings)
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: "gauge-widget"))
    }

    func testUnknownAndMissingRoutesAreRejected() {
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: nil))
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: "unknown"))
    }
}
