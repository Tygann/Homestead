import XCTest
@testable import Homestead

final class RegistryResilienceXCTests: XCTestCase {
    func testDeviceRegistryDropsMalformedIdentifiersWithoutRejectingDeviceMetadata() throws {
        let payload = """
        {
            "id": "matter-server-device",
            "name": "Matter Server",
            "area_id": "server",
            "identifiers": [
                ["hassio", "core_matter_server"],
                ["custom", 42],
                null,
                ["missing-value"],
                ["extra", "usable", "ignored"]
            ]
        }
        """

        let device = try JSONDecoder().decode(HADeviceRegistryDTO.self, from: Data(payload.utf8))

        XCTAssertEqual(device.id, "matter-server-device")
        XCTAssertEqual(device.areaID, "server")
        XCTAssertEqual(device.identifiers, [
            ["hassio", "core_matter_server"],
            ["extra", "usable"]
        ])
    }

    @MainActor
    func testFailedRegistrySectionsPreserveLastKnownGoodAreaMetadata() async throws {
        let stateStore = HAStateStore()
        stateStore.applyInitialStates(
            [HAEntityDTO(entityID: "light.kitchen", state: "on")],
            dataSourceID: HAConnectionConfiguration(
                baseURLString: "http://homeassistant.local:8123",
                accessToken: ""
            ).dataSourceID
        )
        stateStore.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.kitchen",
                    deviceID: "kitchen-device",
                    originalName: "Kitchen Light"
                )
            ],
            devices: [
                HADeviceRegistryDTO(
                    id: "kitchen-device",
                    name: "Kitchen Light",
                    areaID: "kitchen"
                )
            ],
            areas: [
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen")
            ]
        )
        let webSocketClient = StubHAWebSocketClient(states: [
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])
        webSocketClient.entityRegistryEntities = [
            HAEntityRegistryDisplayDTO(
                entityID: "light.kitchen",
                deviceID: "kitchen-device",
                originalName: "Kitchen Light"
            )
        ]
        webSocketClient.deviceRegistryError = HAWebSocketError.requestFailed("Malformed device metadata")
        webSocketClient.areaRegistryError = HAWebSocketError.requestFailed("Area request unavailable")
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(
                    credential: testCredential(accessToken: "registry-fallback-access")
                )
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil {
            webSocketClient.entityRegistryFetchCount >= 1
        }

        XCTAssertEqual(stateStore.areaName(for: "light.kitchen"), "Kitchen")
    }

    private func testCredential(
        baseURL: String = "http://homeassistant.local:8123",
        accessToken: String
    ) -> HAOAuthCredential {
        HAOAuthCredential(
            baseURLString: baseURL,
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: accessToken,
            accessTokenExpiresAt: Date(timeIntervalSince1970: 1_900_000_000),
            tokenType: "Bearer",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
