import XCTest
@testable import Homestead

final class NativeNotificationRegistrationTests: XCTestCase {
    @MainActor
    func testActiveOrCompletedRemoteRegistrationIsNotRestarted() async {
        let allowedStatus = NativeNotificationStatusSnapshot(
            authorizationStatus: .authorized,
            alertSetting: .enabled,
            soundSetting: .enabled,
            badgeSetting: .enabled
        )
        let remoteClient = StubNativeRemoteNotificationRegistrationClient()
        let service = NativeNotificationService(
            client: StubNativeNotificationPermissionClient(currentStatus: allowedStatus),
            remoteRegistrationClient: remoteClient,
            pushRegistrationClient: StubHomesteadPushTokenRegistrationClient(),
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token")
        )

        await service.refreshAuthorizationStatus()
        await service.registerForRemoteNotificationsIfAllowed()
        await service.registerForRemoteNotificationsIfAllowed()

        XCTAssertEqual(remoteClient.registerCallCount, 1)
        XCTAssertEqual(service.remoteRegistrationState, .registeringWithAPNS)

        await service.handleRemoteNotificationDeviceToken(Data([0xab]))
        await service.registerForRemoteNotificationsIfAllowed()

        XCTAssertEqual(remoteClient.registerCallCount, 1)
        XCTAssertTrue(service.remoteRegistrationState.isRegistered)
    }
}
