import Foundation
import Testing
@testable import Homestead

struct HomesteadWidgetDeepLinkTests {
    @Test
    func entityURLsRoundTrip() {
        let entityID = "sensor.living_room_temperature"
        let url = HomesteadWidgetDeepLink.entityURL(entityID: entityID)

        #expect(HomesteadWidgetDeepLink.entityID(from: url) == entityID)
    }

    @Test
    func unrelatedURLsAreIgnored() {
        #expect(HomesteadWidgetDeepLink.entityID(from: URL(string: "homestead://oauth/callback")!) == nil)
        #expect(HomesteadWidgetDeepLink.entityID(from: URL(string: "https://example.com/entity/sensor.test")!) == nil)
        #expect(HomesteadWidgetDeepLink.entityID(from: URL(string: "homestead://entity")!) == nil)
    }
}
