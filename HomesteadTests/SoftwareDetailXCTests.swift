import XCTest
@testable import Homestead

final class SoftwareDetailXCTests: XCTestCase {
    func testSupervisorAppInfoDecodesDetailMetadata() throws {
        let payload = """
        {
            "name": "Matter Server",
            "slug": "core_matter_server",
            "description": "Matter support",
            "long_description": "# Home Assistant App: Matter Server\\n\\n![Supports aarch64 Architecture][aarch64-shield]\\n\\n## About\\n\\nConnect and manage Matter devices.\\n\\n[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg",
            "version": "9.1.0",
            "version_latest": "9.1.1",
            "update_available": true,
            "icon": true,
            "logo": true,
            "state": "started",
            "repository": "https://github.com/home-assistant/addons",
            "url": "https://github.com/home-assistant-libs/python-matter-server",
            "stage": "stable",
            "auto_update": false,
            "homeassistant": "2026.7.0",
            "arch": ["aarch64", "amd64"]
        }
        """

        let dto = try JSONDecoder().decode(HASupervisorAppInfoDTO.self, from: Data(payload.utf8))
        let details = HASupervisorAppDetails(dto: dto)

        XCTAssertEqual(details.app.slug, "core_matter_server")
        XCTAssertTrue(details.app.hasIcon)
        XCTAssertTrue(details.app.hasLogo)
        XCTAssertEqual(details.app.status, .running)
        XCTAssertEqual(details.longDescription, "Connect and manage Matter devices.")
        XCTAssertEqual(details.stage, "stable")
        XCTAssertEqual(details.autoUpdate, false)
        XCTAssertEqual(details.minimumHomeAssistantVersion, "2026.7.0")
        XCTAssertEqual(details.supportedArchitectures, ["aarch64", "amd64"])
    }

    @MainActor
    func testStateStoreLinksSupervisorAppByDeviceRegistryIdentifier() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "update.matter_server",
                state: "on",
                attributes: [
                    "title": .string("Matter Server"),
                    "installed_version": .string("9.1.0"),
                    "latest_version": .string("9.1.1")
                ]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "update.matter_server",
                    deviceID: "matter-server-device",
                    originalName: "Matter Server",
                    platform: "hassio"
                )
            ],
            devices: [
                HADeviceRegistryDTO(
                    id: "matter-server-device",
                    name: "Matter Server",
                    identifiers: [["hassio", "core_matter_server"]]
                )
            ]
        )

        XCTAssertEqual(
            store.supervisorAppSlug(forUpdateEntityID: "update.matter_server"),
            "core_matter_server"
        )
        XCTAssertEqual(
            store.updateEntity(forSupervisorAppSlug: "core_matter_server")?.entityID,
            "update.matter_server"
        )
    }

    @MainActor
    func testStateStoreFallsBackToHassioUpdateUniqueID() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "update.samba_share",
                state: "on",
                attributes: ["title": .string("Samba share")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "update.samba_share",
                    deviceID: nil,
                    originalName: "Samba share",
                    platform: "hassio"
                )
            ],
            devices: [],
            organization: [
                HAEntityOrganizationDTO(
                    entityID: "update.samba_share",
                    uniqueID: "core_samba_version_latest"
                )
            ]
        )

        XCTAssertEqual(
            store.supervisorAppSlug(forUpdateEntityID: "update.samba_share"),
            "core_samba"
        )
    }

    @MainActor
    func testServiceFetchesSupervisorAppDetailsThroughConnectedWebSocket() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: makeCredential())
        let webSocketClient = StubHAWebSocketClient()
        webSocketClient.supervisorAppInfo = HASupervisorAppInfoDTO(
            name: "Matter Server",
            slug: "core_matter_server",
            description: "Matter support",
            longDescription: "Connect and manage Matter devices.",
            version: "9.1.0",
            versionLatest: "9.1.1",
            updateAvailable: true,
            icon: true,
            logo: true,
            state: "started",
            repository: nil,
            url: nil,
            stage: "stable",
            autoUpdate: false,
            homeAssistant: "2026.7.0",
            architectures: ["aarch64"]
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            connectionStatus: .connected,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )

        let details = try await service.fetchSupervisorAppDetails(
            settings: settings,
            slug: "core_matter_server"
        )

        XCTAssertEqual(webSocketClient.supervisorAppInfoSlugs, ["core_matter_server"])
        XCTAssertEqual(details.app.name, "Matter Server")
        XCTAssertEqual(details.longDescription, "Connect and manage Matter devices.")
    }

    private func makeCredential() -> HAOAuthCredential {
        HAOAuthCredential(
            baseURLString: "http://homeassistant.local:8123",
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: "apps-access",
            accessTokenExpiresAt: Date(timeIntervalSince1970: 1_900_000_000),
            tokenType: "Bearer",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suiteName = "com.tyler.Homestead.software-detail-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
