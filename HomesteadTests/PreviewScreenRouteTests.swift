import XCTest
@testable import Homestead

final class PreviewScreenRouteTests: XCTestCase {
    func testKnownPreviewRoutesUseCanonicalArguments() {
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "widgets"), .widgets)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "settings"), .settings)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "notifications"), .notifications)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "updates"), .updates)
        XCTAssertEqual(HomesteadPreviewScreen(argumentValue: "home"), .home)
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: "gauge-widget"))
    }

    func testUnknownAndMissingRoutesAreRejected() {
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: nil))
        XCTAssertNil(HomesteadPreviewScreen(argumentValue: "unknown"))
    }

    func testNotificationPreviewStatesUseCanonicalArguments() {
        XCTAssertEqual(HomesteadPreviewNotificationState(rawValue: "ready"), .ready)
        XCTAssertEqual(HomesteadPreviewNotificationState(rawValue: "needs-setup"), .needsSetup)
        XCTAssertNil(HomesteadPreviewNotificationState(rawValue: "unknown"))
    }
}
