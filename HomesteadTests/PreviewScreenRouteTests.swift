import XCTest
@testable import Homestead

final class PreviewScreenRouteTests: XCTestCase {
    func testKnownPreviewRoutesUseCanonicalArguments() {
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "widgets"), .widgets)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "settings"), .settings)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "updates"), .updates)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "home"), .home)
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: "gauge-widget"))
    }

    func testUnknownAndMissingRoutesAreRejected() {
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: nil))
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: "unknown"))
    }
}
