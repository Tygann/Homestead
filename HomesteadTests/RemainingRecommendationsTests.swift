import XCTest
import UserNotifications
@testable import Homestead

@MainActor
final class RemainingRecommendationsTests: XCTestCase {
    func testCapabilitiesRequireDirectionalFeatureStateAttributesAndService() {
        func allowed(_ domain: String, _ service: String, _ features: Int, state: String = "on", attributes: [String: Any] = [:], available: Bool = true) -> Bool {
            EntityControlCapabilities.allows(domain: domain, service: service, state: state, features: features,
                attributes: attributes, serviceAvailable: available)
        }
        XCTAssertTrue(allowed("cover", "open_cover", 1, state: "closed"))
        XCTAssertFalse(allowed("cover", "close_cover", 1, state: "open"))
        XCTAssertFalse(allowed("cover", "stop_cover", 3))
        XCTAssertTrue(allowed("cover", "stop_cover", 8, state: "opening"))
        XCTAssertFalse(allowed("cover", "set_cover_position", 4))
        XCTAssertTrue(allowed("cover", "set_cover_position", 4, attributes: ["current_position": 50]))
        XCTAssertFalse(allowed("fan", "turn_on", 16, state: "off"))
        XCTAssertTrue(allowed("fan", "turn_off", 16))
        XCTAssertFalse(allowed("fan", "set_percentage", 0, attributes: ["percentage": 50]))
        XCTAssertTrue(allowed("fan", "set_percentage", 1, attributes: ["percentage": 50]))
        XCTAssertFalse(allowed("fan", "set_percentage", 1, attributes: ["percentage": Double.nan]))
        XCTAssertFalse(allowed("climate", "set_temperature", 2, state: "heat", attributes: ["temperature": 20]))
        XCTAssertTrue(allowed("climate", "set_temperature", 2, state: "heat_cool", attributes: ["target_temp_low": 18, "target_temp_high": 24]))
        XCTAssertTrue(allowed("climate", "set_hvac_mode", 0, state: "heat", attributes: ["hvac_modes": ["heat", "off"]]))
        for state in ["unknown", "unavailable", ""] {
            XCTAssertFalse(allowed("cover", "open_cover", 1, state: state))
        }
        XCTAssertFalse(allowed("cover", "open_cover", 1, available: false))
    }

    func testMappingAndFeatureChangesReachSharedServiceGate() async throws {
        let store = HAStateStore()
        let client = StubHAWebSocketClient()
        let registry = try JSONDecoder().decode(HAServiceRegistry.self, from: Data(#"{"cover":{"open_cover":{},"close_cover":{}}}"#.utf8))
        let service = HomeAssistantService(stateStore: store, client: client, serviceRegistry: registry)
        func entity(_ features: Int, state: String = "closed") throws -> HAEntityDTO {
            try JSONDecoder().decode(HAEntityDTO.self, from: Data("{\"entity_id\":\"cover.hall\",\"state\":\"\(state)\",\"attributes\":{\"supported_features\":\(features)}}".utf8))
        }
        store.applySnapshot([try entity(1)])
        XCTAssertEqual(store.coverEntity(for: "cover.hall")?.supportedFeatures, 1)
        XCTAssertTrue(service.entityServiceAvailable(domain: "cover", service: "open_cover", entityID: "cover.hall"))
        XCTAssertFalse(service.entityServiceAvailable(domain: "cover", service: "close_cover", entityID: "cover.hall"))
        store.applySnapshot([try entity(2)])
        XCTAssertFalse(service.entityServiceAvailable(domain: "cover", service: "open_cover", entityID: "cover.hall"))
        let result = await service.callService(domain: "cover", service: "open_cover", entityID: "cover.hall")
        XCTAssertFalse(result)
        store.applySnapshot([try entity(3, state: "unavailable")])
        XCTAssertFalse(service.entityServiceAvailable(domain: "cover", service: "open_cover", entityID: "cover.hall"))
    }

    func testRegistrationFreshnessPersistsAllUpdateFieldsAndClearsRemovedRoutes() throws {
        let request = HAMobileAppRegistrationRequestFactory.makeRequest(deviceID: "device", appVersion: "1", deviceName: "Phone", manufacturer: "Apple", model: "iPhone", osVersion: "26", pushRelayToken: "relay")
        let info = HAMobileAppRegistrationInfo(serverIdentifier: "server", request: request,
            response: HAMobileAppRegistrationResponseDTO(cloudhookURL: "https://cloud.example", remoteUIURL: "https://remote.example", secret: "secret", webhookID: "webhook"))
        let roundtrip = try JSONDecoder().decode(HAMobileAppRegistrationInfo.self, from: JSONEncoder().encode(info))
        XCTAssertEqual(roundtrip.registrationUpdate?.osVersion, "26")
        let changed = HAMobileAppRegistrationRequestFactory.makeUpdate(appVersion: "1", deviceName: "Phone", manufacturer: "Apple", model: "iPhone", osVersion: "27", pushRelayToken: "relay")
        XCTAssertNotEqual(roundtrip.registrationUpdate, changed)
        let cleared = roundtrip.replacingRoutes(try JSONDecoder().decode(HAMobileAppConfigDTO.self, from: Data("{}".utf8)))
        XCTAssertNil(cleared.cloudhookURL)
        XCTAssertNil(cleared.remoteUIURL)
        XCTAssertEqual(cleared.webhookID, info.webhookID)
        XCTAssertEqual(cleared.secret, "secret")
        XCTAssertEqual(cleared.registrationUpdate, info.registrationUpdate)
    }

    func testOfflineRenamePreservesDashboardIdentitySettingsSelectionAndServerIsolation() throws {
        let suite = "RenameTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = UUID()
        let dashboards = DashboardConfiguration(defaults: defaults, profileID: profile)
        let card = try XCTUnwrap(dashboards.add(source: .entity("sensor.before"), presentation: .card(.status(layout: .compact))))
        dashboards.renameDisplayItem(id: card, displayNameOverride: "Custom title")
        _ = dashboards.add(source: .entity("sensor.before"), presentation: .chip)
        let selected = dashboards.selectedDashboardID
        let original = dashboards.dashboards
        // Exercise existing saved sources without manufacturing a different persistence format.
        let old: String? = "sensor.before"
        dashboards.reconcileRegistryIdentities(["stable": old ?? "sensor.before"], profileID: profile)
        dashboards.reconcileRegistryIdentities(["stable": "sensor.after"], profileID: UUID())
        XCTAssertEqual(dashboards.dashboards, original)
        if let old {
            let domain = old.split(separator: ".").first!
            dashboards.reconcileRegistryIdentities(["stable": "\(domain).after"], profileID: profile)
            XCTAssertEqual(dashboards.dashboards.map(\.id), original.map(\.id))
            XCTAssertEqual(dashboards.dashboards.flatMap(\.items).map(\.id), original.flatMap(\.items).map(\.id))
            XCTAssertEqual(dashboards.dashboards.flatMap(\.items).map(\.customization), original.flatMap(\.items).map(\.customization))
            XCTAssertFalse(dashboards.dashboards.flatMap(\.items).compactMap(\.entityID).contains(old))
        }
        XCTAssertEqual(dashboards.selectedDashboardID, selected)
        dashboards.reconcileRegistryIdentities([:], profileID: profile)
        XCTAssertEqual(dashboards.selectedDashboardID, selected)
    }

    func testNewCardsBindImmediatelyAndRenamesSurviveRelaunchAndReusedIDs() throws {
        let suite = "RenameBinding-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = UUID()
        let store = DashboardConfiguration(defaults: defaults, profileID: profile)
        store.reconcileRegistryIdentities(["original": "sensor.before"], profileID: profile)
        let item = try XCTUnwrap(store.add(source: .entity("sensor.before"), presentation: .card(.status(layout: .compact))))
        let reopened = DashboardConfiguration(defaults: defaults, profileID: profile)
        reopened.reconcileRegistryIdentities(["original": "sensor.after", "replacement": "sensor.before"], profileID: profile)
        XCTAssertEqual(reopened.items.first(where: { $0.id == item })?.entityID, "sensor.after")
        reopened.applyEntityRenames(["sensor.after": "sensor.before"], profileID: profile)
        XCTAssertEqual(reopened.items.first(where: { $0.id == item })?.entityID, "sensor.before")
        reopened.applyEntityRenames(["sensor.before": "sensor.after"], profileID: profile)
        reopened.applyEntityRenames(["sensor.after": "sensor.final"], profileID: profile)
        XCTAssertEqual(reopened.items.first(where: { $0.id == item })?.entityID, "sensor.final")
    }

    func testManualReplacementIsNotReboundByUnrelatedLiveRename() throws {
        let suite = "RenameReplacement-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let profile = UUID()
        let store = DashboardConfiguration(defaults: defaults, profileID: profile)
        let item = try XCTUnwrap(store.add(source: .entity("sensor.a"), presentation: .chip))
        _ = store.add(source: .entity("sensor.c"), presentation: .chip)
        store.reconcileRegistryIdentities(["a": "sensor.a", "c": "sensor.c", "z": "sensor.z"], profileID: profile)
        let reference = DashboardItemReference(dashboardID: store.selectedDashboardID, itemID: item)
        XCTAssertTrue(store.applyChipUpdate(DashboardChipUpdate(entityID: "sensor.z", displayNameOverride: nil, iconNameOverride: nil), for: reference))
        store.applyEntityRenames(["sensor.c": "sensor.d"], profileID: profile)
        store.reconcileRegistryIdentities(["a": "sensor.renamed_a", "c": "sensor.d", "z": "sensor.z"], profileID: profile)
        XCTAssertEqual(store.item(for: reference)?.entityID, "sensor.z")
    }

    func testNotificationOriginNeverFallsThroughToActiveOrRemovedServerAndQueuesColdTap() throws {
        let suite = "NotificationOrigin-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = HAConnectionSettings(baseURL: "https://one.example", defaults: defaults,
            tokenStore: InMemoryHAOAuthTokenStore())
        let first = settings.activeProfileID
        let second = settings.profileStore.addProfile(baseURL: "https://two.example")
        let firstStore = InMemoryHAMobileAppRegistrationStore(registration: HAMobileAppRegistrationInfo(
            serverIdentifier: "profile-" + first.uuidString.lowercased(), deviceID: "device", appVersion: "1", deviceName: "Phone", webhookID: "one"))
        let secondStore = InMemoryHAMobileAppRegistrationStore(registration: HAMobileAppRegistrationInfo(
            serverIdentifier: "profile-" + second.uuidString.lowercased(), deviceID: "device", appVersion: "1", deviceName: "Phone", webhookID: "two"))
        let service = HomeAssistantService(stateStore: HAStateStore(), client: StubHAWebSocketClient(),
            mobileAppRegistrationStoreProvider: { $0 == first ? firstStore : secondStore })
        let interaction = try XCTUnwrap(NotificationInteraction(userInfo: ["webhook_id": "two", "profile_id": first.uuidString,
            "data": ["url": "/lovelace/home"]], actionIdentifier: UNNotificationDefaultActionIdentifier))
        XCTAssertEqual(service.notificationOrigin(interaction, settings: settings), second)
        let notifications = NativeNotificationService(client: StubNativeNotificationPermissionClient(currentStatus: .unknown))
        notifications.enqueue(interaction)
        XCTAssertEqual(notifications.pendingInteractions.first?.id, interaction.id)
        notifications.finishInteraction(id: interaction.id)
        XCTAssertTrue(notifications.pendingInteractions.isEmpty)
        _ = settings.profileStore.removeProfile(id: second)
        XCTAssertNil(service.notificationOrigin(interaction, settings: settings))
    }

    func testNotificationURLsActionsRepliesCancellationAndOriginArePreserved() throws {
        let profile = UUID()
        let info: [AnyHashable: Any] = ["webhook_id": "origin", "homestead_profile_id": profile.uuidString,
            "data": ["url": "/lovelace/home", "action_data": ["key": "value"],
                     "actions": [["action": "REPLY", "title": "Reply", "authenticationRequired": true, "destructive": true]]]]
        let tap = try XCTUnwrap(NotificationInteraction(userInfo: info, actionIdentifier: UNNotificationDefaultActionIdentifier))
        XCTAssertEqual(tap.url, "/lovelace/home")
        XCTAssertEqual(tap.webhookID, "origin")
        XCTAssertEqual(tap.profileID, profile)
        XCTAssertNil(tap.action)
        let reply = try XCTUnwrap(NotificationInteraction(userInfo: info, actionIdentifier: "REPLY", reply: "Hello"))
        XCTAssertEqual(reply.reply, "Hello")
        XCTAssertTrue(reply.action?.textInput == true)
        XCTAssertTrue(reply.action?.nativeAction.options.contains(.authenticationRequired) == true)
        XCTAssertTrue(reply.action?.nativeAction.options.contains(.destructive) == true)
        XCTAssertEqual(reply.actionData, .object(["key": .string("value")]))
        XCTAssertNil(NotificationInteraction(userInfo: info, actionIdentifier: UNNotificationDismissActionIdentifier))
        XCTAssertNil(NotificationInteraction(userInfo: info, actionIdentifier: "unknown"))
        XCTAssertEqual(NotificationLinkDestination.resolve("entityId:light.hall", baseURL: "https://one.example"), .entity("light.hall"))
        XCTAssertEqual(NotificationLinkDestination.resolve("/lovelace/home#more-info=light.hall", baseURL: "https://one.example"), .entity("light.hall"))
        XCTAssertEqual(NotificationLinkDestination.resolve("/lovelace/home", baseURL: "https://two.example"), .web(URL(string: "https://two.example/lovelace/home")!))
        for unsafe in ["javascript:alert(1)", "file:///tmp/test", "//wrong.example/path", "https://user:password@example.com", "entityId:bad"] {
            XCTAssertNil(NotificationLinkDestination.resolve(unsafe, baseURL: "https://one.example"))
        }
    }
}

final class WidgetTargetedStateTests: XCTestCase {
    func testSelectedInitialSnapshotOrderingMissingEntitiesAndCleanup() async throws {
        let socket = WidgetStateFixture([
            #"{"id":1,"type":"result","success":true}"#,
            #"{"id":1,"type":"event","event":{"a":{"sensor.one":{"s":"21","a":{"unit_of_measurement":"°C"}},"sensor.unrequested":{"s":"0"}}}}"#,
            #"{"id":1,"type":"event","event":{"c":{}}}"#,
            #"{"id":2,"type":"result","success":true}"#])
        let states = try await WidgetEntityStateRequest.fetch(entityIDs: ["sensor.one", "sensor.missing"], over: socket)
        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states.first?["entity_id"] as? String, "sensor.one")
        let requests = await socket.requests
        XCTAssertEqual(requests.map { $0["type"] as? String }, ["subscribe_entities", "unsubscribe_events"])
        XCTAssertEqual(requests.first?["entity_ids"] as? [String], ["sensor.missing", "sensor.one"])
    }

    func testEmptySelectionMakesNoRequestAndEmptySnapshotIsValid() async throws {
        let empty = WidgetStateFixture([])
        let states = try await WidgetEntityStateRequest.fetch(entityIDs: [], over: empty)
        XCTAssertTrue(states.isEmpty)
        let requests = await empty.requests
        XCTAssertTrue(requests.isEmpty)
        let socket = WidgetStateFixture([#"{"id":1,"type":"result","success":true}"#, #"{"id":1,"type":"event","event":{"a":{}}}"#, #"{"id":2,"type":"result","success":true}"#])
        let missing = try await WidgetEntityStateRequest.fetch(entityIDs: ["sensor.missing"], over: socket)
        XCTAssertTrue(missing.isEmpty)
    }

    func testUnsupportedFallbackAndOtherFailuresDoNotDownloadEverything() async throws {
        let legacy = WidgetStateFixture([#"{"id":1,"type":"result","success":false,"error":{"code":"unknown_command"}}"#, #"{"id":2,"type":"result","success":true,"result":[{"entity_id":"sensor.one","state":"1"},{"entity_id":"sensor.other","state":"2"}]}"#])
        let states = try await WidgetEntityStateRequest.fetch(entityIDs: ["sensor.one"], over: legacy)
        XCTAssertEqual(states.count, 1)
        let denied = WidgetStateFixture([#"{"id":1,"type":"result","success":false,"error":{"code":"unauthorized"}}"#])
        do { _ = try await WidgetEntityStateRequest.fetch(entityIDs: ["sensor.one"], over: denied); XCTFail("Expected error") } catch {}
        let requests = await denied.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(denied.cancellation.isCancelled)
    }

    func testProtocolOrderingAndReceiveFailureCloseSocket() async throws {
        for frames in [[#"{"id":1,"type":"event","event":{"a":{}}}"#], [#"{"id":1,"type":"result","success":true}"#]] {
            let socket = WidgetStateFixture(frames)
            do { _ = try await WidgetEntityStateRequest.fetch(entityIDs: ["sensor.one"], over: socket); XCTFail("Expected failure") } catch {}
            XCTAssertTrue(socket.cancellation.isCancelled)
        }
    }

    func testSeparateServerSocketsNeverShareEntityState() async throws {
        func fixture(_ value: String) -> WidgetStateFixture {
            WidgetStateFixture([#"{"id":1,"type":"result","success":true}"#,
                "{\"id\":1,\"type\":\"event\",\"event\":{\"a\":{\"sensor.same\":{\"s\":\"\(value)\"}}}}",
                #"{"id":2,"type":"result","success":true}"#])
        }
        let first = try await WidgetEntityStateRequest.fetch(entityIDs: ["sensor.same"], over: fixture("first"))
        let second = try await WidgetEntityStateRequest.fetch(entityIDs: ["sensor.same"], over: fixture("second"))
        XCTAssertEqual(first.first?["state"] as? String, "first")
        XCTAssertEqual(second.first?["state"] as? String, "second")
    }
}

private actor WidgetStateFixture: WidgetStateSocket {
    nonisolated let cancellation = WidgetCancellationFlag()
    nonisolated func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) { cancellation.mark() }

    var requests: [[String: Any]] = []
    private var frames: [String]
    init(_ frames: [String]) { self.frames = frames }
    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        if case .string(let string) = message {
            requests.append(try JSONSerialization.jsonObject(with: Data(string.utf8)) as! [String: Any])
        }
    }
    func receive() async throws -> URLSessionWebSocketTask.Message {
        guard !frames.isEmpty else { throw URLError(.networkConnectionLost) }
        return .string(frames.removeFirst())
    }
}

private nonisolated final class WidgetCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func mark() { lock.withLock { value = true } }
    var isCancelled: Bool { lock.withLock { value } }
}
