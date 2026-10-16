import XCTest
@testable import Homestead

@MainActor
final class HAMetadataRefreshTests: XCTestCase {
    func testServicesAndCoreConfigurationRefreshWithoutReconnect() async throws {
        let client = StubHAWebSocketClient(states: [HAEntityDTO(entityID: "light.kitchen", state: "on")])
        client.serviceRegistry = try JSONDecoder().decode(HAServiceRegistry.self, from: Data(#"{"light":{"turn_on":{"fields":{}}}}"#.utf8))
        let service = makeService(client)
        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil { service.serviceRegistry.hasLoaded }
        XCTAssertTrue(service.serviceActionAvailable(domain: "light", service: "turn_on"))
        await client.emitEvent(HAEventDTO(eventType: "service_removed", data: .object([
            "domain": .string("light"), "service": .string("turn_on")
        ])))
        XCTAssertFalse(service.serviceActionAvailable(domain: "light", service: "turn_on"))
        client.serviceRegistry = try JSONDecoder().decode(HAServiceRegistry.self, from: Data(#"{"light":{"turn_off":{"fields":{}}}}"#.utf8))
        await client.emitEvent(HAEventDTO(eventType: "service_registered", data: .object([:])))
        try await waitUntil { service.serviceActionAvailable(domain: "light", service: "turn_off") }
        XCTAssertFalse(service.serviceActionAvailable(domain: "light", service: "turn_on"))
        client.config = HAConfigDTO(version: "2026.10.1", locationName: "Renamed Home", timeZone: nil,
                                   internalURL: nil, externalURL: nil, state: "RUNNING", configSource: nil, unitSystem: nil)
        await client.emitEvent(HAEventDTO(eventType: "core_config_updated", data: .object([:])))
        try await waitUntil { service.serverConfiguration?.locationName == "Renamed Home" }
        XCTAssertEqual(client.connectConfigurations.count, 1)
        await service.disconnect()
    }

    func testLabelAndCategoryEventsTriggerCoalescedRegistryRefresh() async throws {
        let client = StubHAWebSocketClient(states: [HAEntityDTO(entityID: "light.kitchen", state: "on")])
        let service = makeService(client)
        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil { client.entityRegistryFetchCount >= 1 }
        for type in ["label_registry_updated", "category_registry_updated", "label_registry_updated"] {
            let event = HAEventDTO(eventType: type, data: .object([:]))
            XCTAssertTrue(event.isRegistryMetadataChanged)
            await client.emitEvent(event)
        }
        try await waitUntil { client.entityRegistryFetchCount == 2 }
        XCTAssertEqual(client.connectConfigurations.count, 1)
        await service.disconnect()
    }

    func testReplacedConnectionRejectsQueuedOldStateCallback() async throws {
        let store = HAStateStore()
        let client = StubHAWebSocketClient(states: [HAEntityDTO(entityID: "light.kitchen", state: "on")])
        let service = makeService(client, stateStore: store)
        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil { store.entity(for: "light.kitchen")?.state == "on" }
        let oldHandler = try XCTUnwrap(client.capturedEventHandler())
        client.states = [HAEntityDTO(entityID: "light.kitchen", state: "off")]
        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil { store.entity(for: "light.kitchen")?.state == "off" }
        await oldHandler(HAEventDTO(stateChange: HAStateChangedEventDTO(
            entityID: "light.kitchen", oldState: nil,
            newState: HAEntityDTO(entityID: "light.kitchen", state: "on")
        )))
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(store.entity(for: "light.kitchen")?.state, "off")
        await service.disconnect()
    }

    private func makeService(_ client: StubHAWebSocketClient, stateStore: HAStateStore? = nil) -> HomeAssistantService {
        let credential = HAOAuthCredential(baseURLString: "http://homeassistant.local:8123",
            clientID: HAOAuthClientMetadata.clientID, refreshToken: "refresh", accessToken: "access",
            accessTokenExpiresAt: .distantFuture, tokenType: "Bearer", updatedAt: Date())
        return HomeAssistantService(stateStore: stateStore ?? HAStateStore(), client: client,
            authManager: HAOAuthManager(tokenStore: InMemoryHAOAuthTokenStore(credential: credential)),
            automaticallyRegistersMobileApp: false)
    }
}
