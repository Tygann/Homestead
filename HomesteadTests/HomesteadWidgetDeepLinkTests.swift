import Foundation
import Testing
@testable import Homestead

struct HomesteadWidgetDeepLinkTests {
    @Test
    func entityURLsRoundTrip() {
        let reference = EntityPresentationReference(
            profileID: UUID(uuidString: "8F683A67-8FD8-43AA-A499-BB46739CA6E3")!,
            entityID: "sensor.living_room_temperature"
        )
        let url = HomesteadWidgetDeepLink.entityURL(entityID: reference.encodedID)

        #expect(HomesteadWidgetDeepLink.entityID(from: url) == reference.encodedID)
        #expect(HomesteadWidgetDeepLink.entityReference(from: url) == reference)
    }

    @Test
    func rawLegacyEntityURLDoesNotSilentlyAdoptTheActiveServer() {
        let url = HomesteadWidgetDeepLink.entityURL(entityID: "sensor.legacy")

        #expect(HomesteadWidgetDeepLink.entityReference(from: url) == nil)
    }

    @Test
    func unrelatedURLsAreIgnored() {
        #expect(HomesteadWidgetDeepLink.entityID(from: URL(string: "homestead://oauth/callback")!) == nil)
        #expect(HomesteadWidgetDeepLink.entityID(from: URL(string: "https://example.com/entity/sensor.test")!) == nil)
        #expect(HomesteadWidgetDeepLink.entityID(from: URL(string: "homestead://entity")!) == nil)
    }
}
