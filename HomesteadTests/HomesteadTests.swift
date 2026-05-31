import Foundation
import Testing
@testable import Homestead

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping @MainActor () -> Bool
) async throws {
    let start = ContinuousClock.now

    while !condition() {
        if start.duration(to: ContinuousClock.now) >= timeout {
            Issue.record("Timed out waiting for condition.")
            return
        }

        try await Task.sleep(for: .milliseconds(10))
    }
}

private func waitUntilAsync(
    timeout: Duration = .seconds(1),
    condition: @escaping () async -> Bool
) async throws {
    let start = ContinuousClock.now

    while !(await condition()) {
        if start.duration(to: ContinuousClock.now) >= timeout {
            Issue.record("Timed out waiting for condition.")
            return
        }

        try await Task.sleep(for: .milliseconds(10))
    }
}

struct HomesteadTests {
    @Test func connectionHealthAccessoryStateAppearsOnlyForGlobalConnectionIssues() {
        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: false,
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline")
        ) == nil)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connected,
            dataFreshness: .live(.now)
        ) == nil)

        let cachedState = AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connected,
            dataFreshness: .cached(Date(timeIntervalSinceNow: -60))
        )
        #expect(cachedState?.title == "Showing cached state")
        #expect(cachedState?.message.contains("Last updated") == true)
        #expect(cachedState?.canRetry == true)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connected,
            dataFreshness: .stale("offline")
        ) == .interrupted)

        let staleWithAge = AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connected,
            dataFreshness: .stale("offline", lastUpdated: Date(timeIntervalSinceNow: -120))
        )
        #expect(staleWithAge?.message.contains("Last live update") == true)

        let disconnectedStaleWithAge = AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .disconnected,
            dataFreshness: .stale("offline", lastUpdated: Date(timeIntervalSinceNow: -120))
        )
        #expect(disconnectedStaleWithAge?.message.contains("Last live update") == true)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline")
        ) == .reconnecting)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .failed("No route to host"),
            dataFreshness: .empty
        ) == .failed)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .disconnected,
            dataFreshness: .empty
        ) == .disconnected)
    }

    @Test func appChromePresentationMapsSessionStateAndFeedbackSpacing() {
        let signedOutChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedOut,
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline"),
            serviceFeedback: HAServiceFeedback(title: "Done", message: nil, style: .success)
        )

        #expect(signedOutChrome.statusAccessoryState == nil)

        let credential = HAOAuthCredential(
            baseURLString: "http://homeassistant.local:8123",
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: "access-token",
            accessTokenExpiresAt: .distantFuture,
            tokenType: "Bearer",
            updatedAt: .now
        )
        let signedInChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline"),
            serviceFeedback: HAServiceFeedback(title: "Done", message: nil, style: .success)
        )

        #expect(signedInChrome.statusAccessoryState == .reconnecting)

        let feedbackChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .connected,
            dataFreshness: .live(.now),
            serviceFeedback: HAServiceFeedback(title: "Done", message: nil, style: .success)
        )
        #expect(feedbackChrome.statusAccessoryState?.title == "Done")
        #expect(feedbackChrome.statusAccessoryState?.style == .success)
        #expect(feedbackChrome.statusAccessoryState?.canRetry == false)
    }

    @Test func serviceFeedbackDurationMatchesOutcomeSeverity() {
        let successFeedback = HAServiceFeedback(title: "Done", message: nil, style: .success)
        let failureFeedback = HAServiceFeedback(title: "Failed", message: nil, style: .failure)

        #expect(successFeedback.displayDuration == .seconds(2))
        #expect(failureFeedback.displayDuration == .seconds(5))
    }

    @Test func webSocketEndpointUsesExpectedSchemeAndPath() throws {
        let localURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "http://homeassistant.local:8123")
        #expect(localURL.absoluteString == "ws://homeassistant.local:8123/api/websocket")

        let secureURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "https://example.com/ha")
        #expect(secureURL.absoluteString == "wss://example.com/ha/api/websocket")

        let hostOnlyURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "homeassistant.local:8123")
        #expect(hostOnlyURL.absoluteString == "ws://homeassistant.local:8123/api/websocket")
    }

    @Test func cameraSnapshotEndpointUsesHTTPBasePathAndProxyRoute() throws {
        let localURL = try HomeAssistantEndpointBuilder.cameraSnapshotURL(
            from: "ws://homeassistant.local:8123",
            entityID: "camera.driveway",
            cacheBuster: "123"
        )
        #expect(localURL.absoluteString == "http://homeassistant.local:8123/api/camera_proxy/camera.driveway?t=123")

        let nestedURL = try HomeAssistantEndpointBuilder.cameraSnapshotURL(
            from: "https://example.com/ha",
            entityID: "camera.front_door"
        )
        #expect(nestedURL.absoluteString == "https://example.com/ha/api/camera_proxy/camera.front_door")
    }

    @Test func mobileAppEndpointsUseOfficialHTTPPaths() throws {
        let registrationURL = try HomeAssistantEndpointBuilder.mobileAppRegistrationURL(
            from: "https://example.com/ha"
        )
        let webhookURL = try HomeAssistantEndpointBuilder.mobileAppWebhookURL(
            from: "http://homeassistant.local:8123",
            webhookID: "webhook-abc"
        )

        #expect(registrationURL.absoluteString == "https://example.com/ha/api/mobile_app/registrations")
        #expect(webhookURL.absoluteString == "http://homeassistant.local:8123/api/webhook/webhook-abc")
    }

    @Test func httpEndpointResolvesAbsoluteRootAndRelativePaths() throws {
        let absoluteURL = try HomeAssistantEndpointBuilder.httpURL(
            from: "https://example.com/ha",
            pathOrURL: "https://cdn.example.com/profile.jpg"
        )
        let rootRelativeURL = try HomeAssistantEndpointBuilder.httpURL(
            from: "https://example.com/ha",
            pathOrURL: "/api/image/abc?token=123"
        )
        let relativeURL = try HomeAssistantEndpointBuilder.httpURL(
            from: "https://example.com/ha",
            pathOrURL: "local/profile.jpg"
        )

        #expect(absoluteURL.absoluteString == "https://cdn.example.com/profile.jpg")
        #expect(rootRelativeURL.absoluteString == "https://example.com/api/image/abc?token=123")
        #expect(relativeURL.absoluteString == "https://example.com/ha/local/profile.jpg")
    }

    @Test func authAuthorizeURLUsesHomeAssistantOAuthShape() throws {
        let url = try HomeAssistantEndpointBuilder.authAuthorizeURL(
            from: "https://example.com/ha",
            clientID: "https://homestead.keegan.pro",
            redirectURI: "homestead://auth",
            state: "state-123"
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        #expect(components.scheme == "https")
        #expect(components.host == "example.com")
        #expect(components.path == "/ha/auth/authorize")
        #expect(queryItems["client_id"] == "https://homestead.keegan.pro")
        #expect(queryItems["redirect_uri"] == "homestead://auth")
        #expect(queryItems["state"] == "state-123")
    }

    @Test func authTokenEndpointUsesHomeAssistantOAuthPath() throws {
        let url = try HomeAssistantEndpointBuilder.authTokenURL(from: "https://example.com/ha")

        #expect(url.absoluteString == "https://example.com/ha/auth/token")
    }

    @Test func tokenExchangeRequestEncodesFormBody() throws {
        let request = HAOAuthTokenRequest(
            grant: .authorizationCode("code with space"),
            clientID: "https://homestead.keegan.pro"
        )
        let body = String(decoding: request.formEncodedBody(), as: UTF8.self)

        #expect(body.contains("grant_type=authorization_code"))
        #expect(body.contains("code=code%20with%20space"))
        #expect(body.contains("client_id=https%3A%2F%2Fhomestead.keegan.pro"))
    }

    @Test func refreshTokenRequestEncodesFormBody() throws {
        let request = HAOAuthTokenRequest(
            grant: .refreshToken("refresh-token"),
            clientID: "https://homestead.keegan.pro"
        )
        let body = String(decoding: request.formEncodedBody(), as: UTF8.self)

        #expect(body.contains("grant_type=refresh_token"))
        #expect(body.contains("refresh_token=refresh-token"))
        #expect(body.contains("client_id=https%3A%2F%2Fhomestead.keegan.pro"))
    }

    @Test func tokenResponsesDecodeHomeAssistantShape() throws {
        let exchangePayload = """
        {
            "access_token": "access-a",
            "expires_in": 1800,
            "refresh_token": "refresh-a",
            "token_type": "Bearer"
        }
        """
        let refreshPayload = """
        {
            "access_token": "access-b",
            "expires_in": 1800,
            "token_type": "Bearer"
        }
        """

        let exchange = try JSONDecoder().decode(
            HAOAuthTokenResponseDTO.self,
            from: Data(exchangePayload.utf8)
        )
        let refresh = try JSONDecoder().decode(
            HAOAuthTokenResponseDTO.self,
            from: Data(refreshPayload.utf8)
        )

        #expect(exchange.accessToken == "access-a")
        #expect(exchange.refreshToken == "refresh-a")
        #expect(exchange.expiresIn == 1800)
        #expect(refresh.accessToken == "access-b")
        #expect(refresh.refreshToken == nil)
    }

    @Test func callServiceRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.callService(
            id: 42,
            domain: "light",
            service: "turn_on",
            target: ["entity_id": .string("light.kitchen")],
            serviceData: ["brightness": .number(200)]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let target = try #require(object["target"] as? [String: Any])
        let serviceData = try #require(object["service_data"] as? [String: Any])

        #expect(object["id"] as? Int == 42)
        #expect(object["type"] as? String == "call_service")
        #expect(object["domain"] as? String == "light")
        #expect(object["service"] as? String == "turn_on")
        #expect(target["entity_id"] as? String == "light.kitchen")
        #expect(serviceData["brightness"] as? Double == 200)
    }

    @Test func coverPositionServiceRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.callService(
            id: 43,
            domain: "cover",
            service: "set_cover_position",
            target: ["entity_id": .string("cover.primary_shades")],
            serviceData: ["position": .number(72)]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let target = try #require(object["target"] as? [String: Any])
        let serviceData = try #require(object["service_data"] as? [String: Any])

        #expect(object["id"] as? Int == 43)
        #expect(object["type"] as? String == "call_service")
        #expect(object["domain"] as? String == "cover")
        #expect(object["service"] as? String == "set_cover_position")
        #expect(target["entity_id"] as? String == "cover.primary_shades")
        #expect(serviceData["position"] as? Double == 72)
    }

    @Test func climateTemperatureServiceRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.callService(
            id: 44,
            domain: "climate",
            service: "set_temperature",
            target: ["entity_id": .string("climate.downstairs")],
            serviceData: ["temperature": .number(70)]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let target = try #require(object["target"] as? [String: Any])
        let serviceData = try #require(object["service_data"] as? [String: Any])

        #expect(object["id"] as? Int == 44)
        #expect(object["type"] as? String == "call_service")
        #expect(object["domain"] as? String == "climate")
        #expect(object["service"] as? String == "set_temperature")
        #expect(target["entity_id"] as? String == "climate.downstairs")
        #expect(serviceData["temperature"] as? Double == 70)
    }

    @Test func fanAndMediaControlRequestsEncodeHomeAssistantShape() throws {
        let fanRequest = HAWebSocketRequest.callService(
            id: 45,
            domain: "fan",
            service: "set_percentage",
            target: ["entity_id": .string("fan.bedroom")],
            serviceData: ["percentage": .number(45)]
        )
        let mediaRequest = HAWebSocketRequest.callService(
            id: 46,
            domain: "media_player",
            service: "volume_set",
            target: ["entity_id": .string("media_player.living_room")],
            serviceData: ["volume_level": .number(0.42)]
        )

        let fanObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(fanRequest)) as? [String: Any])
        let fanTarget = try #require(fanObject["target"] as? [String: Any])
        let fanServiceData = try #require(fanObject["service_data"] as? [String: Any])
        let mediaObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(mediaRequest)) as? [String: Any])
        let mediaTarget = try #require(mediaObject["target"] as? [String: Any])
        let mediaServiceData = try #require(mediaObject["service_data"] as? [String: Any])

        #expect(fanObject["domain"] as? String == "fan")
        #expect(fanObject["service"] as? String == "set_percentage")
        #expect(fanTarget["entity_id"] as? String == "fan.bedroom")
        #expect(fanServiceData["percentage"] as? Double == 45)
        #expect(mediaObject["domain"] as? String == "media_player")
        #expect(mediaObject["service"] as? String == "volume_set")
        #expect(mediaTarget["entity_id"] as? String == "media_player.living_room")
        #expect(mediaServiceData["volume_level"] as? Double == 0.42)
    }

    @Test func registryCommandEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.registryCommand(
            id: 7,
            type: HAWebSocketMessageType.entityRegistryListForDisplay
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 7)
        #expect(object["type"] as? String == "config/entity_registry/list_for_display")
    }

    @Test func getServicesRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.getServices(id: 8)

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 8)
        #expect(object["type"] as? String == "get_services")
    }

    @Test func cameraCapabilitiesRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.cameraCapabilities(
            id: 9,
            entityID: "camera.driveway"
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 9)
        #expect(object["type"] as? String == "camera/capabilities")
        #expect(object["entity_id"] as? String == "camera.driveway")
    }

    @Test func serviceRegistryDecodesHomeAssistantServiceCatalog() throws {
        let payload = """
        {
            "light": {
                "turn_on": {
                    "name": "Turn on",
                    "description": "Turn on one or more lights.",
                    "fields": {
                        "brightness": {
                            "name": "Brightness",
                            "selector": {
                                "number": {
                                    "min": 0,
                                    "max": 255
                                }
                            }
                        }
                    },
                    "target": {
                        "entity": {
                            "domain": "light"
                        }
                    }
                }
            },
            "fan": {
                "set_percentage": {
                    "name": "Set percentage",
                    "fields": {
                        "percentage": {
                            "required": true
                        }
                    }
                }
            }
        }
        """

        let registry = try JSONDecoder().decode(HAServiceRegistry.self, from: Data(payload.utf8))

        #expect(registry.hasLoaded)
        #expect(registry.hasService(domain: "light", service: "turn_on"))
        #expect(registry.hasService(domain: "fan", service: "set_percentage"))
        #expect(!registry.hasService(domain: "fan", service: "set_preset_mode"))
        #expect(registry.domains["light"]?["turn_on"]?.fields["brightness"] != nil)
    }

    @Test func dataFreshnessRefreshingPreservesLastKnownUpdateDate() {
        let lastUpdated = Date(timeIntervalSince1970: 1_800_000_000)
        let freshness = HADataFreshness.refreshing(lastUpdated: lastUpdated)

        #expect(freshness.isUsable)
        #expect(freshness.lastKnownUpdateDate == lastUpdated)
    }

    @Test func cameraCapabilitiesDecodesFrontendStreamTypes() throws {
        let payload = """
        {
            "frontend_stream_types": ["webrtc", "hls"]
        }
        """

        let capabilities = try JSONDecoder().decode(HACameraCapabilities.self, from: Data(payload.utf8))

        #expect(capabilities.frontendStreamTypes == [.webRTC, .hls])
        #expect(capabilities.supportsLiveStream)
        #expect(capabilities.displayText == "WebRTC, HLS")
    }

    @Test func mobileAppRegistrationRequestEncodesHomeAssistantShape() throws {
        let request = HAMobileAppRegistrationRequestFactory.makeRequest(
            deviceID: "device-123",
            appVersion: "1.2.3",
            deviceName: "Test Phone",
            manufacturer: "Apple, Inc.",
            model: "iPhone",
            osName: "iOS",
            osVersion: "26.5"
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["device_id"] as? String == "device-123")
        #expect(object["app_id"] as? String == "com.tyler.Homestead")
        #expect(object["app_name"] as? String == "Homestead")
        #expect(object["app_version"] as? String == "1.2.3")
        #expect(object["device_name"] as? String == "Test Phone")
        #expect(object["manufacturer"] as? String == "Apple, Inc.")
        #expect(object["model"] as? String == "iPhone")
        #expect(object["os_name"] as? String == "iOS")
        #expect(object["os_version"] as? String == "26.5")
        #expect(object["supports_encryption"] as? Bool == false)
    }

    @Test func mobileAppRegistrationResponseDecodesHomeAssistantShape() throws {
        let payload = """
        {
            "cloudhook_url": "https://hooks.nabu.casa/abc",
            "remote_ui_url": "https://remote.ui",
            "secret": "optional-secret",
            "webhook_id": "webhook-123"
        }
        """

        let response = try JSONDecoder().decode(
            HAMobileAppRegistrationResponseDTO.self,
            from: Data(payload.utf8)
        )

        #expect(response.cloudhookURL == "https://hooks.nabu.casa/abc")
        #expect(response.remoteUIURL == "https://remote.ui")
        #expect(response.secret == "optional-secret")
        #expect(response.webhookID == "webhook-123")
    }

    @Test func mobileAppRegistrationStorePersistsRegistrationInfo() throws {
        let store = InMemoryHAMobileAppRegistrationStore()
        let registration = HAMobileAppRegistrationInfo(
            serverIdentifier: "server-a",
            deviceID: "device-a",
            appVersion: "1.0",
            deviceName: "Test Phone",
            webhookID: "webhook-a",
            secret: "secret-a",
            registeredAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try store.saveRegistration(registration)

        #expect(try store.readRegistration() == registration)

        try store.deleteRegistration()
        #expect(try store.readRegistration() == nil)
    }

    @Test func cameraStreamWebhookRequestEncodesMobileAppShape() throws {
        let request = HAMobileAppWebhookRequestDTO(
            type: HAMobileAppWebhookType.streamCamera,
            data: HACameraStreamRequestDTO(cameraEntityID: "camera.driveway")
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let requestData = try #require(object["data"] as? [String: Any])

        #expect(object["type"] as? String == "stream_camera")
        #expect(requestData["camera_entity_id"] as? String == "camera.driveway")
    }

    @Test func cameraStreamResponseDecodesHandoffPaths() throws {
        let payload = """
        {
            "hls_path": "/api/hls/camera.driveway/master_playlist.m3u8",
            "mjpeg_path": "/api/camera_proxy_stream/camera.driveway"
        }
        """

        let response = try JSONDecoder().decode(HACameraStreamResponseDTO.self, from: Data(payload.utf8))
        let handoff = HACameraStreamHandoff(entityID: "camera.driveway", response: response)

        #expect(handoff.entityID == "camera.driveway")
        #expect(handoff.hlsPath == "/api/hls/camera.driveway/master_playlist.m3u8")
        #expect(handoff.mjpegPath == "/api/camera_proxy_stream/camera.driveway")
        #expect(handoff.hasPlayablePath)
    }

    @Test func entityRegistryDisplayResponseDecodesCompactHomeAssistantPayload() throws {
        let payload = """
        {
            "entities": [
                {
                    "ei": "sensor.ashtons_ipad_location_permission",
                    "di": "ipad",
                    "en": "Location permission",
                    "hb": true
                }
            ]
        }
        """

        let response = try JSONDecoder().decode(
            HAEntityRegistryDisplayResponseDTO.self,
            from: Data(payload.utf8)
        )

        #expect(response.entities.first?.entityID == "sensor.ashtons_ipad_location_permission")
        #expect(response.entities.first?.deviceID == "ipad")
        #expect(response.entities.first?.originalName == "Location permission")
        #expect(response.entities.first?.hiddenBy == true)
    }

    @Test func entityRegistryDisplayResponseDecodesRawEntityArray() throws {
        let payload = """
        [
            {
                "ei": "light.kitchen",
                "di": "kitchen",
                "en": "Kitchen"
            }
        ]
        """

        let response = try JSONDecoder().decode(
            HAEntityRegistryDisplayResponseDTO.self,
            from: Data(payload.utf8)
        )

        #expect(response.entities.map(\.entityID) == ["light.kitchen"])
        #expect(response.entities.first?.deviceID == "kitchen")
    }

    @Test func areaRegistryResponseDecodesHomeAssistantAreaID() throws {
        let payload = """
        [
            {
                "area_id": "living_room",
                "name": "Living Room"
            }
        ]
        """

        let areas = try JSONDecoder().decode(
            [HAAreaRegistryDTO].self,
            from: Data(payload.utf8)
        )

        #expect(areas.first?.id == "living_room")
        #expect(areas.first?.name == "Living Room")
    }

    @Test func entityMapperMapsLightAndSensorDomainModels() {
        let lightDTO = HAEntityDTO(
            entityID: "light.kitchen_pendants",
            state: "on",
            attributes: [
                "friendly_name": .string("Kitchen Pendants"),
                "brightness": .number(128)
            ]
        )

        let sensorDTO = HAEntityDTO(
            entityID: "sensor.hallway_temperature",
            state: "72",
            attributes: [
                "friendly_name": .string("Hallway"),
                "device_class": .string("temperature"),
                "unit_of_measurement": .string("F")
            ]
        )

        let light = EntityMapper.lightEntity(from: lightDTO)
        let sensor = EntityMapper.sensorEntity(from: sensorDTO)

        #expect(light?.displayName == "Kitchen Pendants")
        #expect(light?.isOn == true)
        #expect(light?.brightness == 128)
        #expect(light?.brightnessPercentage == 50)
        #expect(sensor?.displayName == "Hallway")
        #expect(sensor?.formattedValue == "72°F")
        #expect(sensor?.unit == "F")
        #expect(sensor?.iconName == "thermometer.medium")
    }

    @Test func entityMapperMapsSceneAndScriptActionEntities() {
        let sceneDTO = HAEntityDTO(
            entityID: "scene.movie_night",
            state: "scening",
            attributes: [
                "friendly_name": .string("Movie Night")
            ]
        )
        let scriptDTO = HAEntityDTO(
            entityID: "script.good_morning",
            state: "off",
            attributes: [
                "friendly_name": .string("Good Morning")
            ]
        )

        let scene = EntityMapper.homeEntity(from: sceneDTO)
        let script = EntityMapper.homeEntity(from: scriptDTO)

        #expect(scene.domain == .scene)
        #expect(scene.displayName == "Movie Night")
        #expect(scene.iconName == "sparkles")
        #expect(script.domain == .script)
        #expect(script.displayName == "Good Morning")
        #expect(script.iconName == "play.circle")
    }

    @Test func entityMapperMapsExpandedHomeAssistantDomains() {
        let switchEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "switch.coffee", state: "on"))
        let fanEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "fan.bedroom", state: "off"))
        let lockEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "lock.front_door", state: "locked"))
        let mediaEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "media_player.living_room", state: "playing"))
        let cameraEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "camera.driveway", state: "idle"))
        let binarySensorDTO = HAEntityDTO(
            entityID: "binary_sensor.front_door",
            state: "on",
            attributes: ["device_class": .string("door")]
        )
        let binarySensorEntity = EntityMapper.homeEntity(from: binarySensorDTO)
        let binarySensor = EntityMapper.binarySensorEntity(from: binarySensorDTO)

        #expect(switchEntity.domain == .switch)
        #expect(fanEntity.domain == .fan)
        #expect(lockEntity.domain == .lock)
        #expect(mediaEntity.domain == .mediaPlayer)
        #expect(cameraEntity.domain == .camera)
        #expect(binarySensorEntity.domain == .binarySensor)
        #expect(lockEntity.iconName == "lock.fill")
        #expect(mediaEntity.iconName == "play.tv.fill")
        #expect(binarySensor?.displayKind == .door)
        #expect(binarySensor?.displaySubtitle == "Open")
    }

    @Test func entityMapperMapsCoverPositionState() throws {
        let coverDTO = HAEntityDTO(
            entityID: "cover.primary_shades",
            state: "open",
            attributes: [
                "friendly_name": .string("Primary Shades"),
                "current_position": .number(72)
            ]
        )

        let cover = try #require(EntityMapper.coverEntity(from: coverDTO))

        #expect(cover.displayName == "Primary Shades")
        #expect(cover.state == "open")
        #expect(cover.position == 72)
        #expect(cover.positionPercentage == 72)
        #expect(cover.isOpen == true)
        #expect(cover.isClosed == false)
        #expect(cover.displayState == "Open")
        #expect(cover.displaySubtitle == "Open, 72%")
    }

    @Test func entityMapperMapsFanAndMediaPlayerControls() throws {
        let fanDTO = HAEntityDTO(
            entityID: "fan.bedroom",
            state: "on",
            attributes: [
                "friendly_name": .string("Bedroom Fan"),
                "percentage": .number(45),
                "percentage_step": .number(5),
                "preset_mode": .string("normal"),
                "preset_modes": .array([.string("sleep"), .string("normal"), .string("boost")])
            ]
        )
        let mediaDTO = HAEntityDTO(
            entityID: "media_player.living_room",
            state: "playing",
            attributes: [
                "friendly_name": .string("Living Room TV"),
                "volume_level": .number(0.42),
                "source": .string("Apple TV"),
                "source_list": .array([.string("Apple TV"), .string("Music")]),
                "media_title": .string("Morning Mix"),
                "media_artist": .string("Homestead Radio")
            ]
        )

        let fan = try #require(EntityMapper.fanEntity(from: fanDTO))
        let media = try #require(EntityMapper.mediaPlayerEntity(from: mediaDTO))

        #expect(fan.displayName == "Bedroom Fan")
        #expect(fan.isOn)
        #expect(fan.percentage == 45)
        #expect(fan.percentageStep == 5)
        #expect(fan.presetMode == "normal")
        #expect(fan.presetModes == ["sleep", "normal", "boost"])
        #expect(fan.displaySubtitle == "45%")
        #expect(media.displayName == "Living Room TV")
        #expect(media.isPlaying)
        #expect(media.volumePercentage == 42)
        #expect(media.source == "Apple TV")
        #expect(media.sourceList == ["Apple TV", "Music"])
        #expect(media.nowPlayingText == "Morning Mix - Homestead Radio")
        #expect(media.displaySubtitle == "Morning Mix - Homestead Radio")
    }

    @Test func entityMapperMapsClimateControls() throws {
        let climateDTO = HAEntityDTO(
            entityID: "climate.downstairs",
            state: "heat",
            attributes: [
                "friendly_name": .string("Downstairs"),
                "current_temperature": .number(68),
                "temperature": .number(70),
                "temperature_unit": .string("°F"),
                "min_temp": .number(50),
                "max_temp": .number(90),
                "target_temp_step": .number(1),
                "hvac_modes": .array([
                    .string("off"),
                    .string("heat"),
                    .string("cool"),
                    .string("heat_cool")
                ]),
                "fan_mode": .string("auto"),
                "fan_modes": .array([.string("auto"), .string("low"), .string("high")]),
                "preset_mode": .string("home"),
                "preset_modes": .array([.string("home"), .string("away")])
            ]
        )

        let climate = try #require(EntityMapper.climateEntity(from: climateDTO))

        #expect(climate.displayName == "Downstairs")
        #expect(climate.state == "heat")
        #expect(climate.currentTemperature == 68)
        #expect(climate.targetTemperature == 70)
        #expect(climate.temperatureUnit == "°F")
        #expect(climate.hvacModes == ["off", "heat", "cool", "heat_cool"])
        #expect(climate.fanMode == "auto")
        #expect(climate.fanModes == ["auto", "low", "high"])
        #expect(climate.presetMode == "home")
        #expect(climate.presetModes == ["home", "away"])
        #expect(climate.isActive == true)
        #expect(climate.displayState == "Heat")
        #expect(climate.targetTemperatureText == "70°F")
        #expect(climate.currentTemperatureText == "68°F")
        #expect(climate.displaySubtitle == "Heat, set to 70°F")
    }

    @Test func sensorFormattingHandlesUnitsAndUnavailableStates() {
        let humidity = SensorEntity(
            entityID: "sensor.humidity",
            displayName: "Humidity",
            value: "44.2",
            unit: "%",
            deviceClass: "humidity",
            iconName: "humidity",
            lastUpdated: nil
        )
        let energy = SensorEntity(
            entityID: "sensor.energy",
            displayName: "Energy",
            value: "12.3456",
            unit: "kWh",
            deviceClass: "energy",
            iconName: "bolt.fill",
            lastUpdated: nil
        )
        let unavailable = SensorEntity(
            entityID: "sensor.unavailable",
            displayName: "Unavailable",
            value: "unavailable",
            unit: nil,
            deviceClass: nil,
            iconName: "gauge.medium",
            lastUpdated: nil
        )
        let textState = SensorEntity(
            entityID: "sensor.location_permission",
            displayName: "Location Permission",
            value: "authorized_always",
            unit: nil,
            deviceClass: nil,
            iconName: "gauge.medium",
            lastUpdated: nil
        )
        let lowBattery = SensorEntity(
            entityID: "sensor.front_door_battery",
            displayName: "Front Door Battery",
            value: "18",
            unit: "%",
            deviceClass: "battery",
            iconName: "battery.75percent",
            lastUpdated: nil
        )
        let waterClear = SensorEntity(
            entityID: "sensor.laundry_leak",
            displayName: "Laundry Leak",
            value: "off",
            unit: nil,
            deviceClass: "water",
            iconName: "drop.fill",
            lastUpdated: nil
        )
        let waterDetected = SensorEntity(
            entityID: "sensor.laundry_leak",
            displayName: "Laundry Leak",
            value: "on",
            unit: nil,
            deviceClass: "water",
            iconName: "drop.fill",
            lastUpdated: nil
        )

        #expect(humidity.formattedValue == "44%")
        #expect(humidity.valueText == "44")
        #expect(humidity.unitText == "%")
        #expect(humidity.displayKind == .humidity)
        #expect(humidity.isAlerting == false)
        #expect(humidity.displaySubtitle == "Humidity")
        #expect(energy.formattedValue == "12.35 kWh")
        #expect(energy.valueText == "12.35")
        #expect(energy.unitText == "kWh")
        #expect(energy.displayKind == .energy)
        #expect(energy.formattedDeviceClass == "Energy")
        #expect(unavailable.formattedValue == "Unavailable")
        #expect(unavailable.valueText == "Unavailable")
        #expect(unavailable.unitText == nil)
        #expect(unavailable.isAvailable == false)
        #expect(unavailable.displaySubtitle == "Sensor unavailable")
        #expect(textState.formattedValue == "Authorized Always")
        #expect(lowBattery.isAlerting == true)
        #expect(lowBattery.displaySubtitle == "Low Battery")
        #expect(waterClear.isAlerting == false)
        #expect(waterClear.displaySubtitle == "Clear")
        #expect(waterDetected.isAlerting == true)
        #expect(waterDetected.displaySubtitle == "Water Detected")
    }

    @MainActor
    @Test func stateStoreAppliesInitialStatesAndStateChangedEvents() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                attributes: ["friendly_name": .string("Kitchen")]
            )
        ])

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)

        let event = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .null,
                "new_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("on"),
                    "attributes": .object(["friendly_name": .string("Kitchen")]),
                    "last_changed": .string("2026-05-20T10:00:00.000000+00:00"),
                    "last_updated": .string("2026-05-20T10:00:00.000000+00:00")
                ])
            ])
        )

        store.apply(event: event)

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
        #expect(store.entity(for: "light.kitchen")?.state == "on")

        let offEvent = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .null,
                "new_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("off"),
                    "attributes": .object(["friendly_name": .string("Kitchen")]),
                    "last_changed": .string("2026-05-20T10:01:00.000000+00:00"),
                    "last_updated": .string("2026-05-20T10:01:00.000000+00:00")
                ])
            ])
        )

        store.apply(event: offEvent)

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)
        #expect(store.entity(for: "light.kitchen")?.state == "off")

        let pendingCommand = HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on")
        store.setPendingCommand(pendingCommand)

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)
        #expect(store.pendingCommand(for: "light.kitchen") == pendingCommand)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == pendingCommand)
    }

    @MainActor
    @Test func stateStoreTracksInitialSnapshotLoadSeparatelyFromEntityCount() {
        let store = HAStateStore()

        #expect(store.hasLoadedInitialSnapshot == false)
        #expect(store.hasEntities == false)

        store.applySnapshot([])

        #expect(store.hasLoadedInitialSnapshot == true)
        #expect(store.hasEntities == false)
    }

    @MainActor
    @Test func stateStoreDoesNotLetOlderUpdatesOverwriteNewerState() throws {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:02:00.000000+00:00"))
            )
        ])

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:01:00.000000+00:00"))
            )
        ])

        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
        #expect(store.rawEntity(for: "light.kitchen")?.state == "on")
    }

    @MainActor
    @Test func stateStoreSnapshotPreservesEntityBoxIdentity() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])
        let firstBox = store.entityBox(for: "light.kitchen")

        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        #expect(store.entityBox(for: "light.kitchen") === firstBox)
        #expect(firstBox?.lightEntity?.isOn == true)
    }

    @MainActor
    @Test func stateStoreRemovesEntityWhenStateChangedNewStateIsNull() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        let removalEvent = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("on")
                ]),
                "new_state": .null
            ])
        )

        store.apply(event: removalEvent)

        #expect(store.entity(for: "light.kitchen") == nil)
        #expect(store.entityBox(for: "light.kitchen") == nil)
        #expect(store.availableEntityIDs.contains("light.kitchen") == false)
    }

    @MainActor
    @Test func confirmedStateChangeClearsPendingCommand() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])
        store.setPendingCommand(HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on"))

        let event = HAEventDTO(
            eventType: "state_changed",
            data: .object([
                "entity_id": .string("light.kitchen"),
                "old_state": .null,
                "new_state": .object([
                    "entity_id": .string("light.kitchen"),
                    "state": .string("on")
                ])
            ])
        )

        store.apply(event: event)

        #expect(store.pendingCommand(for: "light.kitchen") == nil)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == nil)
        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
    }

    @MainActor
    @Test func staleSnapshotDoesNotClearPendingCommandUntilExpectedStateIsConfirmed() throws {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:00:00.000000+00:00"))
            )
        ])
        let pendingCommand = HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on")
        store.setPendingCommand(pendingCommand)

        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:01:00.000000+00:00"))
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == pendingCommand)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == pendingCommand)
        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)

        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:02:00.000000+00:00"))
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == nil)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == nil)
        #expect(store.lightEntity(for: "light.kitchen")?.isOn == true)
    }

    @MainActor
    @Test func pendingCommandWaitsForExpectedAttributes() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])
        let pendingCommand = HAEntityPendingCommand(
            entityID: "light.kitchen",
            expectedState: "on",
            expectedAttributes: ["brightness": .number(128)]
        )
        store.setPendingCommand(pendingCommand)

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["brightness": .number(64)]
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == pendingCommand)

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["brightness": .number(128)]
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == nil)
    }

    @MainActor
    @Test func liveStateUpdateKeepsAllEntitiesProjectionFresh() {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])

        store.applyLiveStateUpdates([
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        #expect(store.allEntities.first { $0.entityID == "light.kitchen" }?.state == "on")
        #expect(store.entitiesByDomain.first?.entities.first { $0.entityID == "light.kitchen" }?.state == "on")
    }

    @Test func oauthTokenStorePersistsRefreshTokenAndAccessMetadata() throws {
        let store = InMemoryHAOAuthTokenStore()
        let credential = testCredential(
            baseURL: "http://homeassistant.local:8123",
            accessToken: "access-a",
            refreshToken: "refresh-a",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try store.saveCredential(credential)

        #expect(try store.readCredential() == credential)

        try store.deleteCredential()
        #expect(try store.readCredential() == nil)
    }

    @Test func oauthCredentialStorageMatchesWidgetLookupContract() throws {
        let credential = testCredential(
            baseURL: "https://example.com/ha",
            accessToken: "access-a",
            refreshToken: "refresh-a",
            expiresAt: Date(timeIntervalSince1970: 1_800_001_200)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(credential)
        let widgetCredential = try decoder.decode(WidgetOAuthCredentialMirror.self, from: data)
        let json = String(decoding: data, as: UTF8.self)

        #expect(HAOAuthKeychainCredentialContract.service == "com.tyler.Homestead.homeAssistant")
        #expect(HAOAuthKeychainCredentialContract.account == "oauthCredential")
        #expect(HAOAuthKeychainCredentialContract.accessGroup == WidgetSharedStore.keychainAccessGroup)
        #expect(widgetCredential.baseURLString == "https://example.com/ha")
        #expect(widgetCredential.clientID == HAOAuthClientMetadata.clientID)
        #expect(widgetCredential.refreshToken == "refresh-a")
        #expect(widgetCredential.accessToken == "access-a")
        #expect(widgetCredential.tokenType == "Bearer")
        #expect(!json.contains("longLivedAccessToken"))
    }

    @MainActor
    @Test func connectionSettingsUsesStoredOAuthCredentialBaseURL() throws {
        let suiteName = "com.tyler.Homestead.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: "http://homeassistant.local:8123")
        )
        let settings = HAConnectionSettings(
            defaults: defaults,
            tokenStore: tokenStore
        )

        #expect(settings.baseURL == "http://homeassistant.local:8123")
        #expect(settings.hasServerURL)
    }

    @Test func oauthManagerRefreshesExpiredAccessToken() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryHAOAuthTokenStore(
            credential: testCredential(
                accessToken: "expired-access",
                refreshToken: "refresh-a",
                expiresAt: now.addingTimeInterval(-1)
            )
        )
        let client = StubHAOAuthClient(
            refreshResponse: HAOAuthTokenResponseDTO(
                accessToken: "fresh-access",
                expiresIn: 1200,
                refreshToken: nil,
                tokenType: "Bearer"
            )
        )
        let manager = HAOAuthManager(
            client: client,
            tokenStore: store,
            now: { now }
        )

        let configuration = try await manager.validConfiguration(baseURLString: "http://homeassistant.local:8123")

        #expect(configuration.accessToken == "fresh-access")
        #expect(client.lastRefreshToken == "refresh-a")
        #expect(try store.readCredential()?.accessToken == "fresh-access")
        #expect(try store.readCredential()?.accessTokenExpiresAt == now.addingTimeInterval(1200))
    }

    @MainActor
    @Test func serviceAuthStateReflectsSignedOutSignedInExpiredAndRefreshFailed() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryHAOAuthTokenStore()
        let manager = HAOAuthManager(tokenStore: store, now: { now })
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            authManager: manager
        )

        await service.refreshAuthState()
        #expect(service.authState == .signedOut)

        try store.saveCredential(testCredential(expiresAt: now.addingTimeInterval(600)))
        await service.refreshAuthState()
        if case .signedIn = service.authState {
            // Expected signed-in state.
        } else {
            Issue.record("Expected signed-in auth state.")
        }

        try store.saveCredential(testCredential(expiresAt: now.addingTimeInterval(-1)))
        await service.refreshAuthState()
        if case .accessTokenExpired = service.authState {
            // Expected expired access-token state.
        } else {
            Issue.record("Expected expired auth state.")
        }

        let failingService = HomeAssistantService(
            stateStore: HAStateStore(),
            authManager: HAOAuthManager(tokenStore: ThrowingHAOAuthTokenStore())
        )
        await failingService.refreshAuthState()
        if case .refreshFailed = failingService.authState {
            // Expected refresh-failed state.
        } else {
            Issue.record("Expected refresh-failed auth state.")
        }
    }

    @MainActor
    @Test func serviceRegistrationStateReflectsMatchingStoredMobileAppRegistration() throws {
        let configuration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let registration = HAMobileAppRegistrationInfo(
            serverIdentifier: configuration.dataSourceID,
            deviceID: "device-a",
            appVersion: "1.0",
            deviceName: "Test Phone",
            webhookID: "webhook-a"
        )
        let store = InMemoryHAMobileAppRegistrationStore(registration: registration)
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: store
        )
        let settings = HAConnectionSettings(
            baseURL: configuration.baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )

        service.refreshMobileAppRegistrationState(settings: settings)

        guard case .registered(let summary) = service.mobileAppRegistrationState else {
            Issue.record("Expected registered mobile app state.")
            return
        }
        #expect(summary.deviceName == "Test Phone")
        #expect(summary.appVersion == "1.0")
    }

    @MainActor
    @Test func serviceRegistrationStateIgnoresStoredRegistrationForDifferentServer() throws {
        let registration = HAMobileAppRegistrationInfo(
            serverIdentifier: "other-server",
            deviceID: "device-a",
            appVersion: "1.0",
            deviceName: "Test Phone",
            webhookID: "webhook-a"
        )
        let store = InMemoryHAMobileAppRegistrationStore(registration: registration)
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: store
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )

        service.refreshMobileAppRegistrationState(settings: settings)

        #expect(service.mobileAppRegistrationState == .unregistered)
    }

    @MainActor
    @Test func serviceRegisterMobileAppPersistsRegistrationAndUpdatesState() async throws {
        let store = InMemoryHAMobileAppRegistrationStore()
        let client = StubHAMobileAppClient(
            registrationResponse: HAMobileAppRegistrationResponseDTO(
                cloudhookURL: nil,
                remoteUIURL: "https://remote.ui",
                secret: nil,
                webhookID: "webhook-created"
            )
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppClient: client,
            mobileAppRegistrationStore: store,
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(
                    credential: testCredential(accessToken: "token-a")
                )
            )
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )

        await service.registerMobileApp(settings: settings)

        let savedRegistration = try #require(try store.readRegistration())
        #expect(savedRegistration.webhookID == "webhook-created")
        #expect(savedRegistration.serverIdentifier == HAConnectionConfiguration(
            baseURLString: settings.baseURL,
            accessToken: "token-a"
        ).dataSourceID)

        guard case .registered(let summary) = service.mobileAppRegistrationState else {
            Issue.record("Expected registered mobile app state.")
            return
        }
        #expect(summary.deviceName == savedRegistration.deviceName)
    }

    @MainActor
    @Test func serviceConnectionUsesRefreshedAccessToken() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "expired-access", expiresAt: now.addingTimeInterval(-1))
        )
        let oauthClient = StubHAOAuthClient(
            refreshResponse: HAOAuthTokenResponseDTO(
                accessToken: "fresh-access",
                expiresIn: 1200,
                refreshToken: nil,
                tokenType: "Bearer"
            )
        )
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                client: oauthClient,
                tokenStore: tokenStore,
                now: { now }
            )
        )

        await service.refreshAuthState()
        await service.connect(baseURLString: "http://homeassistant.local:8123")

        #expect(webSocketClient.lastConnectConfiguration?.accessToken == "fresh-access")
        #expect(try tokenStore.readCredential()?.accessToken == "fresh-access")
        #expect(service.connectionStatus == .connected)
    }

    @MainActor
    @Test func serviceRefreshLoadsHomeAssistantServiceRegistry() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "service-catalog-access"))
        let webSocketClient = StubHAWebSocketClient()
        webSocketClient.serviceRegistry = HAServiceRegistry(domains: [
            "fan": [
                "set_percentage": HAServiceDescription(name: "Set percentage")
            ],
            "media_player": [
                "volume_set": HAServiceDescription(name: "Set volume")
            ]
        ])
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        await service.refreshStates()
        try await waitUntil {
            service.serviceRegistry.hasLoaded
        }

        #expect(service.serviceRegistry.hasLoaded)
        #expect(service.serviceActionAvailable(domain: "fan", service: "set_percentage"))
        #expect(service.serviceActionAvailable(domain: "media_player", service: "volume_set"))
        #expect(!service.serviceActionAvailable(domain: "fan", service: "set_preset_mode"))
    }

    @MainActor
    @Test func startupSyncMarksEntityStateLiveBeforeOptionalMetadataCompletes() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "startup-access"))
        let stateStore = HAStateStore()
        let webSocketClient = StubHAWebSocketClient(states: [
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])
        webSocketClient.fetchServicesDelay = .milliseconds(250)
        webSocketClient.serviceRegistry = HAServiceRegistry(domains: [
            "light": [
                "turn_on": HAServiceDescription(name: "Turn on")
            ]
        ])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil {
            stateStore.hasLoadedInitialSnapshot
        }

        if case .live = service.dataFreshness {
            // Expected: entity state is usable before optional service metadata finishes.
        } else {
            Issue.record("Expected live data freshness after entity state sync.")
        }
        #expect(service.serviceRegistry.hasLoaded == false)

        try await waitUntil(timeout: .seconds(2)) {
            service.serviceRegistry.hasLoaded
        }
        #expect(service.serviceActionAvailable(domain: "light", service: "turn_on"))
    }

    @MainActor
    @Test func startupSyncPersistsLiveStateBeforeOptionalMetadataCompletes() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadImmediateLiveCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = HAStateCache(directoryURL: cacheDirectory)
        let baseURLString = "http://homeassistant.local:8123"
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(baseURL: baseURLString, accessToken: "startup-access"))
        let stateStore = HAStateStore()
        let webSocketClient = StubHAWebSocketClient(states: [
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])
        webSocketClient.fetchServicesDelay = .milliseconds(400)
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            stateCache: cache,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.connect(baseURLString: baseURLString)
        try await waitUntil {
            stateStore.hasLoadedInitialSnapshot
        }

        let configuration = HAConnectionConfiguration(
            baseURLString: baseURLString,
            accessToken: "startup-access"
        )
        try await waitUntilAsync {
            await cache.load(for: configuration)?.entities.map(\.entityID) == ["light.kitchen"]
        }

        #expect(service.serviceRegistry.hasLoaded == false)
    }

    @MainActor
    @Test func serviceRegistryFailureDoesNotPreventLiveEntityState() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "startup-access"))
        let stateStore = HAStateStore()
        let webSocketClient = StubHAWebSocketClient(states: [
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])
        webSocketClient.fetchServicesError = HAWebSocketError.requestFailed("Service registry unavailable")
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil {
            stateStore.hasLoadedInitialSnapshot
        }
        try await Task.sleep(for: .milliseconds(30))

        #expect(stateStore.entity(for: "light.kitchen")?.state == "on")
        if case .live = service.dataFreshness {
            // Expected: optional metadata failure should not stale otherwise live state.
        } else {
            Issue.record("Expected live data freshness despite service registry failure.")
        }
        #expect(service.serviceRegistry.hasLoaded == false)
    }

    @MainActor
    @Test func transientServiceActionSetsPendingCommandAndSuccessFeedback() async throws {
        let scene = HAEntityDTO(
            entityID: "scene.movie_night",
            state: "scening",
            attributes: ["friendly_name": .string("Movie Night")]
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([scene])
        let webSocketClient = StubHAWebSocketClient(states: [scene])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "scene-access"))
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        stateStore.applySnapshot([scene])

        await service.activateScene(entityID: "scene.movie_night")

        #expect(stateStore.pendingCommand(for: "scene.movie_night") != nil)
        #expect(service.serviceFeedback?.title == "Scene activated")
        #expect(webSocketClient.callServiceInvocations.last?.domain == "scene")
        #expect(webSocketClient.callServiceInvocations.last?.service == "turn_on")
    }

    @MainActor
    @Test func transientServiceActionDoesNotCallHomeAssistantWhenEntityUnavailable() async throws {
        let unavailableScript = HAEntityDTO(
            entityID: "script.good_morning",
            state: "unavailable",
            attributes: ["friendly_name": .string("Good Morning")]
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([unavailableScript])
        let webSocketClient = StubHAWebSocketClient(states: [unavailableScript])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "script-access"))
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        stateStore.applySnapshot([unavailableScript])

        await service.runScript(entityID: "script.good_morning")

        #expect(webSocketClient.callServiceInvocations.isEmpty)
        #expect(stateStore.pendingCommand(for: "script.good_morning") == nil)
        #expect(service.serviceFeedback?.title == "Action unavailable")
    }

    @MainActor
    @Test func refreshOrReconnectRetriesImmediatelyWhileReconnecting() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "retry-access"))
        let storedCredential = try tokenStore.readCredential()
        let credential = try #require(storedCredential)
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            connectionStatus: .reconnecting,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )

        await service.refreshOrReconnect(settings: settings)

        #expect(webSocketClient.lastConnectConfiguration?.accessToken == "retry-access")
        #expect(service.connectionStatus == .connected)
    }

    @MainActor
    @Test func serviceFailureFeedbackExplainsReconnectRecovery() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "service-access"))
        let stateStore = HAStateStore()
        let light = HAEntityDTO(
            entityID: "light.kitchen",
            state: "off",
            attributes: [
                "friendly_name": .string("Kitchen Light")
            ]
        )
        stateStore.applySnapshot([light])
        let webSocketClient = StubHAWebSocketClient(states: [light])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        stateStore.applySnapshot([light])
        webSocketClient.callServiceError = HAWebSocketError.requestTimedOut

        await service.turnOnLight(entityID: "light.kitchen")

        #expect(service.connectionStatus == .reconnecting)
        #expect(webSocketClient.didDisconnect)
        #expect(service.serviceFeedback?.title == "Action failed, reconnecting")
        #expect(service.serviceFeedback?.message?.contains("Kitchen Light") == true)
        #expect(service.serviceFeedback?.message?.contains("Homestead is reconnecting") == true)
    }

    @MainActor
    @Test func oauthSignInConnectsAndRegistersMobileAppAutomatically() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore()
        let registrationStore = InMemoryHAMobileAppRegistrationStore()
        let webSocketClient = StubHAWebSocketClient()
        let mobileAppClient = StubHAMobileAppClient(
            registrationResponse: HAMobileAppRegistrationResponseDTO(
                cloudhookURL: nil,
                remoteUIURL: nil,
                secret: nil,
                webhookID: "webhook-oauth"
            )
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: mobileAppClient,
            mobileAppRegistrationStore: registrationStore,
            authManager: HAOAuthManager(
                client: StubHAOAuthClient(
                    exchangeResponse: HAOAuthTokenResponseDTO(
                        accessToken: "oauth-access",
                        expiresIn: 1200,
                        refreshToken: "oauth-refresh",
                        tokenType: "Bearer"
                    )
                ),
                tokenStore: tokenStore
            ),
            oauthAuthorizer: StubHAOAuthAuthorizer(authorizationCode: "auth-code")
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )

        await service.signInWithHomeAssistant(settings: settings)

        #expect(try tokenStore.readCredential()?.refreshToken == "oauth-refresh")
        #expect(webSocketClient.lastConnectConfiguration?.accessToken == "oauth-access")
        #expect(try registrationStore.readRegistration()?.webhookID == "webhook-oauth")
        if case .registered = service.mobileAppRegistrationState {
            // Expected automatic registration after OAuth sign-in.
        } else {
            Issue.record("Expected automatic mobile-app registration.")
        }
    }

    @MainActor
    @Test func profileImageRequestUsesOnlyPersonEntityLinkedToCurrentUser() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "profile-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "person.other",
                state: "home",
                attributes: [
                    "user_id": .string("other-user"),
                    "entity_picture": .string("/api/image/other")
                ]
            ),
            HAEntityDTO(
                entityID: "person.current",
                state: "home",
                attributes: [
                    "user_id": .string("current-user"),
                    "entity_picture": .string("/api/image/current")
                ]
            )
        ])
        let webSocketClient = StubHAWebSocketClient(
            currentUser: HACurrentUserDTO(id: "current-user", name: "Current", isOwner: nil, isAdmin: nil),
            states: stateStore.rawEntitySnapshot()
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )

        await service.connect(baseURLString: settings.baseURL)
        stateStore.applySnapshot(webSocketClient.states)

        let request = try #require(await service.homeAssistantProfileImageRequest(settings: settings))
        #expect(request.url?.absoluteString == "http://homeassistant.local:8123/api/image/current")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer profile-access")
    }

    @MainActor
    @Test func profileImageRequestDoesNotUseUnrelatedFirstPersonEntity() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "profile-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "person.other",
                state: "home",
                attributes: [
                    "user_id": .string("other-user"),
                    "entity_picture": .string("/api/image/other")
                ]
            )
        ])
        let webSocketClient = StubHAWebSocketClient(
            currentUser: HACurrentUserDTO(id: "current-user", name: "Current", isOwner: nil, isAdmin: nil),
            states: stateStore.rawEntitySnapshot()
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )

        await service.connect(baseURLString: settings.baseURL)
        stateStore.applySnapshot(webSocketClient.states)

        #expect(await service.homeAssistantProfileImageRequest(settings: settings) == nil)
    }

    @MainActor
    @Test func signOutClearsOAuthCredentialAndMobileAppRegistration() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential())
        let registrationStore = InMemoryHAMobileAppRegistrationStore(
            registration: HAMobileAppRegistrationInfo(
                serverIdentifier: "server-a",
                deviceID: "device-a",
                appVersion: "1.0",
                deviceName: "Test Phone",
                webhookID: "webhook-a"
            )
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppRegistrationStore: registrationStore,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.refreshAuthState()
        await service.signOut()

        #expect(try tokenStore.readCredential() == nil)
        #expect(try registrationStore.readRegistration() == nil)
        #expect(service.authState == .signedOut)
        #expect(service.mobileAppRegistrationState == .unregistered)
    }

    @MainActor
    @Test func dashboardConfigurationResetSeedsEntityItems() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.reset(using: dashboardTestEntities)

        #expect(configuration.items.map(\.type) == [.entity, .entity])
        #expect(configuration.items.map(\.entityID) == ["light.kitchen", "sensor.hallway_temperature"])
        #expect(configuration.items.map(\.resolvedCardSize) == [.compact, .compact])
    }

    @MainActor
    @Test func dashboardConfigurationResetSeedsTenSuggestedEntityItems() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let entities = (0..<14).map { index in
            HomeEntity(
                entityID: "sensor.test_\(index)",
                domain: .sensor,
                displayName: String(format: "Test %02d", index),
                state: "\(index)",
                iconName: "sensor",
                isAvailable: true,
                lastUpdated: nil
            )
        }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.reset(using: entities)

        #expect(configuration.items.count == 10)
        #expect(configuration.items.map(\.entityID) == (0..<10).map { "sensor.test_\($0)" })
    }

    @MainActor
    @Test func dashboardConfigurationAddEntityItemPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.entity])
        #expect(restoredConfiguration.items.map(\.entityID) == ["light.kitchen"])
    }

    @MainActor
    @Test func dashboardConfigurationRemoveEntityItemPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")
        configuration.remove("light.kitchen")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.isEmpty)
    }

    @MainActor
    @Test func dashboardConfigurationCardSizeChangesPersistOnEntityItem() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let itemID = configuration.add("sensor.hallway_temperature")
        configuration.setCardSize(.wide, forItemID: itemID)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.entityID == "sensor.hallway_temperature")
        #expect(restoredConfiguration.items.first?.resolvedCardSize == .wide)
    }

    @MainActor
    @Test func dashboardConfigurationDisplayNameOverridePersistsOnEntityItem() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let itemID = configuration.add("sensor.hallway_temperature")
        configuration.renameEntityItem(id: itemID, displayNameOverride: "Hallway")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.displayNameOverride == "Hallway")
        #expect(restoredConfiguration.items.first?.resolvedDisplayName(default: "Hallway Temperature") == "Hallway")

        restoredConfiguration.renameEntityItem(id: itemID, displayNameOverride: " ")
        #expect(restoredConfiguration.items.first?.displayNameOverride == nil)
    }

    @MainActor
    @Test func dashboardConfigurationVisibleItemsPreserveAllConfiguredSizes() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let miniID = configuration.add("sensor.mini")
        let rowID = configuration.add("sensor.row")
        let largeID = configuration.add("sensor.large")
        configuration.setCardSize(.mini, forItemID: miniID)
        configuration.setCardSize(.row, forItemID: rowID)
        configuration.setCardSize(.large, forItemID: largeID)

        let visibleItems = configuration.visibleItems(
            fromAvailableEntityIDs: ["sensor.mini", "sensor.row", "sensor.large"]
        )

        #expect(visibleItems.map(\.resolvedCardSize) == [.mini, .row, .large])
        #expect(visibleItems.map(\.layoutMetadata) == [
            DashboardCardSize.mini.layoutMetadata,
            DashboardCardSize.row.layoutMetadata,
            DashboardCardSize.large.layoutMetadata
        ])
    }

    @MainActor
    @Test func dashboardConfigurationMigratesLegacyLargeCardSizeToSquare() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyItem = DashboardItemConfiguration.entity(
            entityID: "sensor.hallway_temperature",
            size: .large
        )
        defaults.set(try JSONEncoder().encode([legacyItem]), forKey: "dashboardItems")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.resolvedCardSize == .square)
        #expect(defaults.integer(forKey: "dashboardItems.layoutVersion") == 2)
    }

    @MainActor
    @Test func dashboardConfigurationPersistsNewLargeCardSizeAfterMigrationVersion() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let itemID = configuration.add("sensor.hallway_temperature")
        configuration.setCardSize(.large, forItemID: itemID)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.resolvedCardSize == .large)
    }

    @MainActor
    @Test func dashboardCardSizesExposeFourColumnLayoutMetadata() {
        #expect(DashboardCardSize.mini.layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 1, rowSpan: 1))
        #expect(DashboardCardSize.compact.layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 2, rowSpan: 1))
        #expect(DashboardCardSize.row.layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 1))
        #expect(DashboardCardSize.square.layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 2, rowSpan: 2))
        #expect(DashboardCardSize.wide.layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 2))
        #expect(DashboardCardSize.large.layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 4))
    }

    @MainActor
    @Test func dashboardCardSizeLabelsExposeLayoutSpans() {
        #expect(DashboardCardSize.mini.displayName == "Mini 1x1")
        #expect(DashboardCardSize.compact.displayName == "Compact 2x1")
        #expect(DashboardCardSize.row.displayName == "Row 4x1")
        #expect(DashboardCardSize.square.displayName == "Square 2x2")
        #expect(DashboardCardSize.wide.displayName == "Wide 4x2")
        #expect(DashboardCardSize.large.displayName == "Large 4x4")
    }

    @MainActor
    @Test func dashboardHeaderItemsExposeFullWidthRowLayoutMetadata() {
        let header = DashboardItemConfiguration.header(title: "Downstairs")
        #expect(header.layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 1))
    }

    @MainActor
    @Test func dashboardChipItemsPersistAsSeparateDashboardComponents() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let summaryID = configuration.addSummaryChip(kind: .lights)
        let entityID = configuration.addEntityChip(entityID: "sensor.hallway_temperature")
        configuration.renameDisplayItem(id: summaryID, displayNameOverride: "Lighting")
        configuration.setIconNameOverride("lamp.table", forItemID: entityID)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.chip, .chip])
        #expect(restoredConfiguration.items.first?.chipKind == .summary)
        #expect(restoredConfiguration.items.first?.summaryKind == .lights)
        #expect(restoredConfiguration.items.first?.resolvedDisplayName(default: "Lights") == "Lighting")
        #expect(restoredConfiguration.items.last?.chipKind == .entity)
        #expect(restoredConfiguration.items.last?.entityID == "sensor.hallway_temperature")
        #expect(restoredConfiguration.items.last?.resolvedIconName(default: "gauge.medium") == "lamp.table")
        #expect(restoredConfiguration.items.map(\.layoutMetadata) == [
            DashboardCardLayoutMetadata(columnSpan: 2, rowSpan: 1),
            DashboardCardLayoutMetadata(columnSpan: 2, rowSpan: 1)
        ])
    }

    @MainActor
    @Test func dashboardConfigurationAddHeaderPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.addHeader(title: "Downstairs")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.header])
        #expect(restoredConfiguration.items.first?.resolvedTitle == "Downstairs")
    }

    @MainActor
    @Test func dashboardConfigurationRenameHeaderPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let headerID = configuration.addHeader(title: "Downstairs")
        configuration.renameHeader(id: headerID, title: "Main Floor")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.resolvedTitle == "Main Floor")
    }

    @MainActor
    @Test func dashboardConfigurationRemoveHeaderPersists() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let headerID = configuration.addHeader(title: "Downstairs")
        configuration.removeItem(id: headerID)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.isEmpty)
    }

    @MainActor
    @Test func dashboardConfigurationReconcilePreservesTemporarilyMissingEntitiesAndHeaders() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")
        configuration.addHeader(title: "Sensors")
        configuration.add("sensor.removed")

        configuration.reconcile(with: dashboardTestEntities)

        #expect(configuration.items.map(\.type) == [.entity, .header, .entity])
        #expect(configuration.items.first?.entityID == "light.kitchen")
        #expect(configuration.items[1].resolvedTitle == "Sensors")
        #expect(configuration.items.last?.entityID == "sensor.removed")
        #expect(configuration.visibleEntityIDs(from: dashboardTestEntities) == ["light.kitchen"])
    }

    @MainActor
    @Test func dashboardConfigurationAddableEntityIDsExcludeAddedAndIncludeRemoved() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let availableEntityIDs = Set(dashboardTestEntities.map(\.entityID))
        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("light.kitchen")

        #expect(configuration.addableEntityIDs(fromAvailableEntityIDs: availableEntityIDs) == ["sensor.hallway_temperature"])

        configuration.remove("light.kitchen")
        #expect(configuration.addableEntityIDs(fromAvailableEntityIDs: availableEntityIDs) == availableEntityIDs)
    }

    @MainActor
    @Test func dashboardConfigurationMovesMixedItemsAndPersistsOrder() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.addHeader(title: "Downstairs")
        configuration.add("light.kitchen")
        configuration.add("sensor.hallway_temperature")

        configuration.move(from: IndexSet(integer: 0), to: 3)

        #expect(configuration.items.map(\.type) == [.entity, .entity, .header])
        #expect(configuration.items.map(\.entityID) == ["light.kitchen", "sensor.hallway_temperature", nil])
        #expect(configuration.items.last?.resolvedTitle == "Downstairs")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.entity, .entity, .header])
        #expect(restoredConfiguration.items.map(\.entityID) == ["light.kitchen", "sensor.hallway_temperature", nil])
        #expect(restoredConfiguration.items.last?.resolvedTitle == "Downstairs")
    }

    @MainActor
    @Test func dashboardLayoutBuilderPreservesHeadersEntityOverridesAndSizes() throws {
        let headerID = UUID()
        let lightID = UUID()
        let sensorID = UUID()
        let chipID = UUID()
        let items = [
            DashboardItemConfiguration.header(title: "Downstairs", id: headerID),
            DashboardItemConfiguration(
                id: lightID,
                type: .entity,
                entityID: "light.kitchen",
                title: nil,
                displayNameOverride: "Counter",
                iconNameOverride: "lamp.table",
                size: .row,
                chipKind: nil,
                summaryKind: nil
            ),
            DashboardItemConfiguration(
                id: sensorID,
                type: .entity,
                entityID: "sensor.temperature",
                title: nil,
                displayNameOverride: nil,
                iconNameOverride: nil,
                size: .large,
                chipKind: nil,
                summaryKind: nil
            ),
            DashboardItemConfiguration.summaryChip(kind: .security, id: chipID)
        ]

        let layoutItems = DashboardLayoutItemBuilder.makeItems(from: items)

        #expect(layoutItems.count == 4)
        #expect(layoutItems[0].id == "header-\(headerID)")
        #expect(layoutItems[0].layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 4, rowSpan: 1))

        guard case .card(let lightCard) = layoutItems[1].kind else {
            Issue.record("Expected light card layout item.")
            return
        }
        #expect(lightCard.id == lightID)
        #expect(lightCard.entityID == "light.kitchen")
        #expect(lightCard.displayNameOverride == "Counter")
        #expect(lightCard.iconNameOverride == "lamp.table")
        #expect(lightCard.size == .row)
        #expect(layoutItems[1].layoutMetadata == DashboardCardSize.row.layoutMetadata)

        guard case .card(let sensorCard) = layoutItems[2].kind else {
            Issue.record("Expected sensor card layout item.")
            return
        }
        #expect(sensorCard.id == sensorID)
        #expect(sensorCard.entityID == "sensor.temperature")
        #expect(sensorCard.size == .large)
        #expect(layoutItems[2].layoutMetadata == DashboardCardSize.large.layoutMetadata)

        guard case .chip(let chip) = layoutItems[3].kind else {
            Issue.record("Expected chip layout item.")
            return
        }
        #expect(chip.id == chipID)
        #expect(chip.chipKind == .summary)
        #expect(chip.summaryKind == .security)
        #expect(layoutItems[3].layoutMetadata == DashboardCardLayoutMetadata(columnSpan: 2, rowSpan: 1))
    }

    @Test func stateCacheRoundTripsEntitySnapshotsAndScopesByConnection() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadStateCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = HAStateCache(directoryURL: cacheDirectory)
        let primaryConfiguration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let otherConfiguration = HAConnectionConfiguration(
            baseURLString: "http://other-home.local:8123",
            accessToken: "token-a"
        )
        let entities = [
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:00:00.000000+00:00"))
            )
        ]
        let registryMetadata = HARegistryMetadataSnapshot(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.kitchen",
                    deviceID: "kitchen-device",
                    originalName: "Kitchen"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "kitchen-device", name: "Kitchen Lamp", areaID: "kitchen")
            ],
            areas: [
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen")
            ]
        )

        await cache.save(entities, registryMetadata: registryMetadata, for: primaryConfiguration)

        let restoredSnapshot = try #require(await cache.load(for: primaryConfiguration))
        let metadata = try #require(await cache.metadata(for: primaryConfiguration))
        #expect(restoredSnapshot.entities == entities)
        #expect(restoredSnapshot.registryMetadata == registryMetadata)
        #expect(metadata.entityCount == 1)
        #expect(metadata.entityRegistryCount == 1)
        #expect(metadata.deviceRegistryCount == 1)
        #expect(metadata.areaRegistryCount == 1)
        #expect(metadata.shortScopeIdentifier.count == 8)
        #expect(await cache.load(for: otherConfiguration) == nil)
        #expect(await cache.metadata(for: otherConfiguration) == nil)
        #expect(HAStateCache.cacheFileName(for: primaryConfiguration) != HAStateCache.cacheFileName(for: otherConfiguration))
    }

    @Test func stateCacheLoadsLegacyEntityOnlySnapshots() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadLegacyStateCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = HAStateCache(directoryURL: cacheDirectory)
        let configuration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let cacheURL = cacheDirectory.appendingPathComponent(HAStateCache.cacheFileName(for: configuration))
        let legacyJSON = """
        {
          "savedAt": "2026-05-20T10:00:00Z",
          "entities": [
            {
              "entity_id": "light.kitchen",
              "state": "on",
              "attributes": {
                "friendly_name": "Kitchen"
              }
            }
          ]
        }
        """
        let legacyData = try #require(legacyJSON.data(using: .utf8))
        try legacyData.write(to: cacheURL)

        let restoredSnapshot = try #require(await cache.load(for: configuration))
        #expect(restoredSnapshot.entities.map(\.entityID) == ["light.kitchen"])
        #expect(restoredSnapshot.registryMetadata == nil)
    }

    @Test func stateCacheKeyNormalizesEquivalentHomeAssistantURLs() {
        let hostOnlyConfiguration = HAConnectionConfiguration(
            baseURLString: "homeassistant.local:8123",
            accessToken: "token-a"
        )
        let httpConfiguration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123/",
            accessToken: "token-a"
        )
        let webSocketConfiguration = HAConnectionConfiguration(
            baseURLString: "ws://homeassistant.local:8123/api/websocket",
            accessToken: "token-a"
        )

        #expect(HAStateCache.cacheFileName(for: hostOnlyConfiguration) == HAStateCache.cacheFileName(for: httpConfiguration))
        #expect(HAStateCache.cacheFileName(for: httpConfiguration) == HAStateCache.cacheFileName(for: webSocketConfiguration))
    }

    @MainActor
    @Test func homeAssistantServiceCanApplyCachedStatesBeforeConnecting() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadServiceCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = HAStateCache(directoryURL: cacheDirectory)
        let configuration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let entities = [
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try #require(HADateParser.date(from: "2026-05-20T10:00:00.000000+00:00"))
            )
        ]
        let registryMetadata = HARegistryMetadataSnapshot(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.kitchen",
                    deviceID: "kitchen-device",
                    originalName: "Kitchen"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "kitchen-device", name: "Kitchen Lamp", areaID: "kitchen")
            ],
            areas: [
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen")
            ]
        )

        await cache.save(entities, registryMetadata: registryMetadata, for: configuration)

        let store = HAStateStore()
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: "homeassistant.local:8123", accessToken: "token-a")
        )
        let service = HomeAssistantService(
            stateStore: store,
            stateCache: cache,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "homeassistant.local:8123",
            tokenStore: tokenStore
        )

        await service.loadCachedStatesIfPossible(settings: settings)

        #expect(store.hasLoadedInitialSnapshot == true)
        #expect(store.entity(for: "light.kitchen")?.state == "on")
        #expect(store.areaName(for: "light.kitchen") == "Kitchen")
        #expect(service.stateCacheMetadata?.entityCount == 1)
        #expect(service.stateCacheMetadata?.areaRegistryCount == 1)
        if case .cached = service.dataFreshness {
            // Expected cached-first launch state.
        } else {
            Issue.record("Expected cached data freshness after applying the saved snapshot.")
        }
    }

    @MainActor
    @Test func stateStoreScopesSnapshotsByConnectionDataSource() throws {
        let store = HAStateStore()
        let firstConfiguration = HAConnectionConfiguration(
            baseURLString: "http://first-home.local:8123",
            accessToken: "token-a"
        )
        let secondConfiguration = HAConnectionConfiguration(
            baseURLString: "http://second-home.local:8123",
            accessToken: "token-a"
        )

        store.applySnapshot([
            HAEntityDTO(entityID: "light.first_home", state: "on")
        ], dataSourceID: firstConfiguration.dataSourceID)

        #expect(store.dataSourceID == firstConfiguration.dataSourceID)
        #expect(store.entity(for: "light.first_home") != nil)

        store.replaceDataSourceIfNeeded(secondConfiguration.dataSourceID)

        #expect(store.dataSourceID == secondConfiguration.dataSourceID)
        #expect(store.hasLoadedInitialSnapshot == false)
        #expect(store.entity(for: "light.first_home") == nil)
        #expect(store.hasEntities == false)
    }

    @MainActor
    @Test func dashboardConfigurationReplacesSeparatePinnedEntityStateForDeviceFavorites() throws {
        let suiteName = "com.tyler.Homestead.dashboard.favorite.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.setEntity("light.kitchen", isVisible: true)
        configuration.setEntity("sensor.missing", isVisible: true)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.entityIDs == ["light.kitchen", "sensor.missing"])
        #expect(restoredConfiguration.contains("light.kitchen"))
    }

    @MainActor
    @Test func areaBuilderGroupsEntitiesAndCountsActivePresentations() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen Pendants")]
            ),
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "72",
                attributes: ["friendly_name": .string("Kitchen Temperature")]
            ),
            HAEntityDTO(
                entityID: "light.office_lamp",
                state: "unavailable",
                attributes: ["friendly_name": .string("Office Lamp")]
            )
        ])
        let areaNames = [
            "light.kitchen": "Kitchen",
            "sensor.kitchen_temperature": "Kitchen",
            "light.office_lamp": "Office"
        ]

        let areas = DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaNameForEntityID: { areaNames[$0] }
        )
        let kitchen = areas.first { $0.name == "Kitchen" }
        let office = areas.first { $0.name == "Office" }

        #expect(kitchen?.entityIDs == ["light.kitchen", "sensor.kitchen_temperature"])
        #expect(kitchen?.activeCount == 1)
        #expect(kitchen?.domainCounts[.light] == 1)
        #expect(kitchen?.domainCounts[.sensor] == 1)
        #expect(kitchen?.topDomains == [.light, .sensor])
        #expect(office?.unavailableCount == 1)
    }

    @MainActor
    @Test func areaBuilderUsesRegistryAreaNamesAndLeavesMissingAreasUnassigned() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.random_name",
                state: "on",
                attributes: ["friendly_name": .string("Lamp")]
            ),
            HAEntityDTO(
                entityID: "light.kitchen_counter",
                state: "off",
                attributes: ["friendly_name": .string("Kitchen Counter")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.random_name",
                    deviceID: "lamp-device",
                    originalName: "Lamp"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "lamp-device", name: "Lamp", areaID: "den")
            ],
            areas: [
                HAAreaRegistryDTO(id: "den", name: "Den")
            ]
        )

        let areas = DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaNameForEntityID: store.areaName(for:)
        )

        #expect(areas.map(\.name) == ["Den", "Unassigned"])
    }

    @MainActor
    @Test func entityPresentationCentralizesDomainActionsAndDetails() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on"),
            HAEntityDTO(entityID: "cover.shades", state: "open"),
            HAEntityDTO(entityID: "scene.movie_night", state: "scening"),
            HAEntityDTO(entityID: "script.good_morning", state: "off"),
            HAEntityDTO(entityID: "sensor.temperature", state: "72")
        ])

        let lightPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "light.kitchen"))
        )
        let coverPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "cover.shades"))
        )
        let scenePresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "scene.movie_night"))
        )
        let sensorPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "sensor.temperature"))
        )
        let scriptPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "script.good_morning"))
        )

        #expect(lightPresentation.primaryAction == .toggleLight)
        #expect(lightPresentation.primaryServiceIntent == .stateToggle(domain: "light", onService: "turn_on", offService: "turn_off"))
        #expect(lightPresentation.accessibilityDetailLabel == "Open Kitchen details")
        #expect(lightPresentation.primaryActionAccessibilityLabel == "Turn off Kitchen")
        #expect(lightPresentation.cardStyle == .control)
        #expect(lightPresentation.secondaryActions == [.setBrightness])
        #expect(lightPresentation.detailKind == .light)
        #expect(coverPresentation.primaryAction == .toggleCover)
        #expect(coverPresentation.primaryServiceIntent == .coverToggle)
        #expect(coverPresentation.primaryActionAccessibilityLabel == "Close Shades")
        #expect(coverPresentation.secondaryActions == [.openCover, .closeCover, .stopCover, .setCoverPosition])
        #expect(coverPresentation.detailKind == .cover)
        #expect(scenePresentation.primaryAction == .activateScene)
        #expect(scenePresentation.primaryServiceIntent == .call(domain: "scene", service: "turn_on"))
        #expect(scenePresentation.primaryActionAccessibilityLabel == "Activate Movie Night")
        #expect(scenePresentation.cardStyle == .action)
        #expect(scenePresentation.detailKind == .action)
        #expect(scriptPresentation.primaryAction == .runScript)
        #expect(scriptPresentation.primaryServiceIntent == .call(domain: "script", service: "turn_on"))
        #expect(scriptPresentation.primaryActionAccessibilityLabel == "Run Good Morning")
        #expect(scriptPresentation.cardStyle == .action)
        #expect(scriptPresentation.detailKind == .action)
        #expect(sensorPresentation.primaryAction == nil)
        #expect(sensorPresentation.primaryServiceIntent == nil)
        #expect(sensorPresentation.cardStyle == .value)
        #expect(sensorPresentation.detailKind == .sensor)
    }

    @MainActor
    @Test func entityPresentationSupportsExpandedDomainActions() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "switch.coffee", state: "on"),
            HAEntityDTO(
                entityID: "fan.bedroom",
                state: "on",
                attributes: [
                    "percentage": .number(45),
                    "preset_modes": .array([.string("sleep"), .string("boost")])
                ]
            ),
            HAEntityDTO(entityID: "lock.front_door", state: "locked"),
            HAEntityDTO(
                entityID: "media_player.living_room",
                state: "playing",
                attributes: [
                    "media_title": .string("Morning Mix"),
                    "volume_level": .number(0.42),
                    "source_list": .array([.string("Apple TV"), .string("Music")])
                ]
            ),
            HAEntityDTO(entityID: "camera.driveway", state: "idle"),
            HAEntityDTO(entityID: "binary_sensor.front_door", state: "on")
        ])

        let switchPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "switch.coffee")))
        let fanPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "fan.bedroom")))
        let lockPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "lock.front_door")))
        let mediaPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "media_player.living_room")))
        let cameraPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "camera.driveway")))
        let binarySensorPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "binary_sensor.front_door")))

        #expect(switchPresentation.primaryAction == .toggleSwitch)
        #expect(switchPresentation.detailKind == .toggle)
        #expect(switchPresentation.isActive == true)
        #expect(fanPresentation.primaryAction == .toggleFan)
        #expect(fanPresentation.detailKind == .fan)
        #expect(fanPresentation.secondaryActions == [.setFanPercentage, .setFanPresetMode])
        #expect(fanPresentation.subtitle == "45%")
        #expect(fanPresentation.isActive == true)
        #expect(lockPresentation.primaryAction == nil)
        #expect(lockPresentation.primaryServiceIntent == nil)
        #expect(lockPresentation.detailKind == .lock)
        #expect(lockPresentation.subtitle == "Locked")
        #expect(mediaPresentation.primaryAction == nil)
        #expect(mediaPresentation.cardStyle == .media)
        #expect(mediaPresentation.secondaryActions == [.playPause, .setMediaVolume, .selectMediaSource])
        #expect(mediaPresentation.subtitle == "Morning Mix")
        #expect(mediaPresentation.isActive == true)
        #expect(cameraPresentation.primaryAction == nil)
        #expect(cameraPresentation.cardStyle == .camera)
        #expect(binarySensorPresentation.subtitle == "Detected")
        #expect(binarySensorPresentation.primaryAction == nil)
        #expect(binarySensorPresentation.detailKind == .sensor)
    }

    @MainActor
    @Test func entityDomainRegistryDefinesCommonDomainPresentationCapabilities() throws {
        let expected: [EntityDomain: (
            DashboardEntityCardStyle,
            DashboardEntityPrimaryAction?,
            DashboardEntityDetailKind
        )] = [
            .light: (.control, .toggleLight, .light),
            .switch: (.control, .toggleSwitch, .toggle),
            .fan: (.control, .toggleFan, .fan),
            .lock: (.control, nil, .lock),
            .cover: (.control, .toggleCover, .cover),
            .climate: (.status, nil, .climate),
            .sensor: (.value, nil, .sensor),
            .binarySensor: (.status, nil, .sensor),
            .mediaPlayer: (.media, nil, .mediaPlayer),
            .camera: (.camera, nil, .camera),
            .scene: (.action, .activateScene, .action),
            .script: (.action, .runScript, .action),
            .vacuum: (.status, nil, .vacuum),
            .other: (.generic, nil, .entity)
        ]

        for domain in EntityDomain.allCases {
            let capability = DashboardEntityDomainRegistry.capability(for: domain)
            let expectation = try #require(expected[domain])

            #expect(capability.domain == domain)
            #expect(capability.cardStyle == expectation.0)
            #expect(capability.primaryAction == expectation.1)
            #expect(capability.detailKind == expectation.2)
            #expect(capability.primaryServiceIntent == expectation.1?.serviceIntent)
        }
    }

    @MainActor
    @Test func mediaCameraAndVacuumHaveStructuralPresentationWithoutUnsafePrimaryActions() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "media_player.living_room", state: "playing"),
            HAEntityDTO(entityID: "camera.driveway", state: "idle"),
            HAEntityDTO(entityID: "vacuum.downstairs", state: "cleaning")
        ])

        let media = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "media_player.living_room")))
        let camera = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "camera.driveway")))
        let vacuum = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "vacuum.downstairs")))

        #expect(media.primaryAction == nil)
        #expect(media.detailKind == .mediaPlayer)
        #expect(media.cardStyle == .media)
        #expect(media.isActive == true)
        #expect(media.secondaryActions == [.playPause, .setMediaVolume, .selectMediaSource])
        #expect(camera.primaryAction == nil)
        #expect(camera.detailKind == .camera)
        #expect(camera.cardStyle == .camera)
        #expect(vacuum.primaryAction == nil)
        #expect(vacuum.detailKind == .vacuum)
        #expect(vacuum.cardStyle == .status)
        #expect(vacuum.secondaryActions == [.startCleaning, .stopCleaning, .returnToBase])
    }

    @MainActor
    @Test func wideAndLargeCardContentModelsExposeDomainSpecificMetrics() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "fan.bedroom",
                state: "on",
                attributes: [
                    "friendly_name": .string("Bedroom Fan"),
                    "percentage": .number(45)
                ]
            ),
            HAEntityDTO(
                entityID: "climate.downstairs",
                state: "cool",
                attributes: [
                    "friendly_name": .string("Downstairs"),
                    "temperature": .number(72),
                    "current_temperature": .number(74),
                    "temperature_unit": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "scene.movie_night",
                state: "scening",
                attributes: ["friendly_name": .string("Movie Night")]
            )
        ])

        let fanPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "fan.bedroom")))
        let fanWide = DashboardEntityCardContentModel.make(presentation: fanPresentation, size: .wide)
        let fanLarge = DashboardEntityCardContentModel.make(presentation: fanPresentation, size: .large)
        #expect(fanWide.metrics.map(\.title) == ["Status"])
        #expect(fanWide.metrics.map(\.value) == ["On"])
        #expect(fanLarge.metrics.contains(DashboardEntityCardMetric(title: "Level", value: "45%", systemImage: "fan")))
        #expect(fanLarge.metrics.contains(DashboardEntityCardMetric(title: "Action", value: "Turn off Bedroom Fan", systemImage: "hand.tap")))

        let climatePresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "climate.downstairs")))
        let climateLarge = DashboardEntityCardContentModel.make(presentation: climatePresentation, size: .large)
        #expect(climateLarge.metrics.first == DashboardEntityCardMetric(title: "Mode", value: "Cool, set to 72°F", systemImage: "thermometer.medium"))
        #expect(climateLarge.metrics.contains(DashboardEntityCardMetric(title: "Setpoint", value: "72°F", systemImage: "target")))
        #expect(climateLarge.metrics.contains(DashboardEntityCardMetric(title: "Action", value: "Open details", systemImage: "hand.tap")))

        let scenePresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "scene.movie_night")))
        let sceneCompact = DashboardEntityCardContentModel.make(presentation: scenePresentation, size: .compact)
        let sceneLarge = DashboardEntityCardContentModel.make(presentation: scenePresentation, size: .large)
        #expect(sceneCompact.metrics.isEmpty)
        #expect(sceneLarge.metrics.contains(DashboardEntityCardMetric(title: "Action", value: "Activate Movie Night", systemImage: "hand.tap")))
    }

    @MainActor
    @Test func dashboardSummaryProviderBuildsGlanceableChipPresentations() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on"),
            HAEntityDTO(entityID: "light.pantry", state: "off"),
            HAEntityDTO(entityID: "lock.front_door", state: "locked"),
            HAEntityDTO(
                entityID: "binary_sensor.back_door",
                state: "on",
                attributes: ["device_class": .string("door")]
            ),
            HAEntityDTO(entityID: "cover.garage_door", state: "open"),
            HAEntityDTO(entityID: "camera.driveway", state: "idle"),
            HAEntityDTO(
                entityID: "climate.downstairs",
                state: "heat_cool",
                attributes: [
                    "current_temperature": .number(74.5),
                    "temperature_unit": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "12",
                attributes: [
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(entityID: "media_player.living_room", state: "playing")
        ])

        let boxes = store.allEntityBoxes()
        let lights = try #require(DashboardSummaryProvider.makeSummary(kind: .lights, entityBoxes: boxes))
        let security = try #require(DashboardSummaryProvider.makeSummary(kind: .security, entityBoxes: boxes))
        let climate = try #require(DashboardSummaryProvider.makeSummary(kind: .climate, entityBoxes: boxes))
        let batteries = try #require(DashboardSummaryProvider.makeSummary(kind: .batteries, entityBoxes: boxes))
        let media = try #require(DashboardSummaryProvider.makeSummary(kind: .media, entityBoxes: boxes))

        #expect(lights.value == "1 on")
        #expect(lights.isActive)
        #expect(security.title == "Security")
        #expect(security.value == "2 open")
        #expect(security.systemImage == "shield.fill")
        #expect(climate.value == "74.5°F")
        #expect(batteries.value == "1 low")
        #expect(media.value == "1 playing")
        #expect(DashboardSummaryKind.allCases == [.lights, .security, .climate, .batteries, .media])

        let lightChip = DashboardSummaryProvider.makeEntityChip(
            entityBox: try #require(store.entityBox(for: "light.kitchen")),
            titleOverride: "Counter",
            iconNameOverride: "lamp.table"
        )
        #expect(lightChip.title == "Counter")
        #expect(lightChip.systemImage == "lamp.table")
        #expect(lightChip.isActive)
    }

    @MainActor
    @Test func dashboardSummaryProviderBuildsFilteredSummaryDetailSections() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on"),
            HAEntityDTO(entityID: "light.bedroom", state: "off"),
            HAEntityDTO(
                entityID: "binary_sensor.back_door",
                state: "on",
                attributes: ["device_class": .string("door")]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.doorbell_ding",
                state: "on",
                attributes: ["device_class": .string("sound")]
            ),
            HAEntityDTO(entityID: "lock.front_door", state: "unlocked"),
            HAEntityDTO(entityID: "cover.garage_door", state: "closed"),
            HAEntityDTO(entityID: "camera.driveway", state: "idle"),
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "12",
                attributes: [
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.wall_remote_battery",
                state: "84",
                attributes: [
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            )
        ])

        let boxes = store.allEntityBoxes()
        let areaNames = [
            "binary_sensor.back_door": "Entryway",
            "binary_sensor.doorbell_ding": "Entryway",
            "lock.front_door": "Entryway",
            "camera.driveway": "Entryway",
            "cover.garage_door": "Garage",
            "sensor.remote_battery": "Entryway",
            "sensor.wall_remote_battery": "Garage"
        ]
        let securityDetail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .security,
            entityBoxes: boxes,
            areaNameForEntityID: { areaNames[$0] }
        ))
        #expect(securityDetail.summary.value == "1 unlocked")
        #expect(securityDetail.sections.map(\.title) == ["Entryway", "Garage"])
        #expect(securityDetail.sections.first?.items.map(\.entityID) == [
            "lock.front_door",
            "binary_sensor.back_door",
            "camera.driveway"
        ])
        #expect(securityDetail.sections.first?.items.contains { $0.entityID == "binary_sensor.doorbell_ding" } == false)
        #expect(securityDetail.sections.first?.items.first { $0.entityID == "camera.driveway" }?.visualStyle == .camera)

        let batteryDetail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .batteries,
            entityBoxes: boxes,
            areaNameForEntityID: { areaNames[$0] }
        ))
        #expect(batteryDetail.sections.map(\.title) == ["Entryway", "Garage"])
        #expect(batteryDetail.sections.first?.items.map(\.entityID) == ["sensor.remote_battery"])
    }

    private var dashboardTestEntities: [HomeEntity] {
        [
            HomeEntity(
                entityID: "sensor.hallway_temperature",
                domain: .sensor,
                displayName: "Hallway Temperature",
                state: "72",
                iconName: "thermometer.medium",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "light.kitchen",
                domain: .light,
                displayName: "Kitchen",
                state: "on",
                iconName: "lightbulb",
                isAvailable: true,
                lastUpdated: nil
            )
        ]
    }

    @MainActor
    @Test func stateStoreGroupsEntitiesByDomainPriority() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "sensor.temperature", state: "72"),
            HAEntityDTO(entityID: "cover.shades", state: "open"),
            HAEntityDTO(entityID: "light.lamp", state: "on")
        ])

        #expect(store.entitiesByDomain.map(\.domain) == [.light, .cover, .sensor])
    }

    @MainActor
    @Test func stateStoreGroupsEntitiesByDeviceRegistryMetadata() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "sensor.ashtons_ipad_battery_level", state: "72"),
            HAEntityDTO(entityID: "sensor.ashtons_ipad_location_permission", state: "authorized_always"),
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])

        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.ashtons_ipad_battery_level",
                    deviceID: "ipad",
                    originalName: "Battery Level"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.ashtons_ipad_location_permission",
                    deviceID: "ipad",
                    originalName: "Location permission"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "ipad", name: "Ashton's iPad")
            ]
        )

        #expect(store.entityIDGroupsByDevice.map(\.title) == ["Ashton's iPad", "Other Entities"])
        #expect(store.displayNameForDeviceGroupedEntity(entityID: "sensor.ashtons_ipad_location_permission") == "Location permission")
    }

    private func testCredential(
        baseURL: String = "http://homeassistant.local:8123",
        accessToken: String = "access-token",
        refreshToken: String = "refresh-token",
        expiresAt: Date = Date(timeIntervalSince1970: 1_900_000_000)
    ) -> HAOAuthCredential {
        HAOAuthCredential(
            baseURLString: baseURL,
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: refreshToken,
            accessToken: accessToken,
            accessTokenExpiresAt: expiresAt,
            tokenType: "Bearer",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suiteName = "com.tyler.Homestead.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

struct ThrowingHAOAuthTokenStore: HAOAuthTokenStore {
    func readCredential() throws -> HAOAuthCredential? {
        throw HAOAuthTokenStoreError.unreadableCredential
    }

    func saveCredential(_ credential: HAOAuthCredential) throws {
        throw HAOAuthTokenStoreError.unreadableCredential
    }

    func deleteCredential() throws {
        throw HAOAuthTokenStoreError.unreadableCredential
    }
}

private struct WidgetOAuthCredentialMirror: Decodable {
    let baseURLString: String
    let clientID: String
    let refreshToken: String
    let accessToken: String
    let tokenType: String
}

final class StubHAOAuthClient: HAOAuthClientProtocol {
    var exchangeResponse: HAOAuthTokenResponseDTO
    var refreshResponse: HAOAuthTokenResponseDTO
    private(set) var lastExchangeCode: String?
    private(set) var lastRefreshToken: String?

    init(
        exchangeResponse: HAOAuthTokenResponseDTO = HAOAuthTokenResponseDTO(
            accessToken: "exchange-access",
            expiresIn: 1200,
            refreshToken: "exchange-refresh",
            tokenType: "Bearer"
        ),
        refreshResponse: HAOAuthTokenResponseDTO = HAOAuthTokenResponseDTO(
            accessToken: "refresh-access",
            expiresIn: 1200,
            refreshToken: nil,
            tokenType: "Bearer"
        )
    ) {
        self.exchangeResponse = exchangeResponse
        self.refreshResponse = refreshResponse
    }

    func exchangeAuthorizationCode(
        baseURLString: String,
        code: String,
        clientID: String
    ) async throws -> HAOAuthTokenResponseDTO {
        lastExchangeCode = code
        return exchangeResponse
    }

    func refreshAccessToken(
        baseURLString: String,
        refreshToken: String,
        clientID: String
    ) async throws -> HAOAuthTokenResponseDTO {
        lastRefreshToken = refreshToken
        return refreshResponse
    }
}

@MainActor
final class StubHAOAuthAuthorizer: HAOAuthAuthorizing {
    let authorizationCode: String
    private(set) var lastAuthorizationURL: URL?

    init(authorizationCode: String) {
        self.authorizationCode = authorizationCode
    }

    func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        lastAuthorizationURL = authorizationURL
        let components = URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false)
        let state = components?.queryItems?.first { $0.name == "state" }?.value ?? ""
        return try #require(URL(string: "\(callbackScheme)://auth?code=\(authorizationCode)&state=\(state)"))
    }
}

final class StubHAWebSocketClient: HAWebSocketClientProtocol {
    private(set) var lastConnectConfiguration: HAConnectionConfiguration?
    private(set) var didDisconnect = false
    private(set) var disconnectCount = 0
    private(set) var callServiceInvocations: [(domain: String, service: String, entityID: String?, serviceData: [String: JSONValue])] = []
    var callServiceError: Error?
    var currentUser: HACurrentUserDTO?
    var states: [HAEntityDTO]
    var serviceRegistry: HAServiceRegistry = .empty
    var fetchServicesDelay: Duration?
    var fetchServicesError: Error?

    init(currentUser: HACurrentUserDTO? = nil, states: [HAEntityDTO] = []) {
        self.currentUser = currentUser
        self.states = states
    }

    func setEventHandler(_ handler: (@Sendable (HAEventDTO) async -> Void)?) async {}

    func setDisconnectHandler(_ handler: (@MainActor @Sendable (Error) -> Void)?) async {}

    func connect(configuration: HAConnectionConfiguration) async throws {
        lastConnectConfiguration = configuration
    }

    func disconnect() async {
        didDisconnect = true
        disconnectCount += 1
    }

    func fetchCurrentUser() async throws -> HACurrentUserDTO {
        guard let currentUser else {
            throw HAWebSocketError.missingResult
        }
        return currentUser
    }

    func fetchStates() async throws -> [HAEntityDTO] {
        states
    }

    func fetchEntityRegistryForDisplay() async throws -> HAEntityRegistryDisplayResponseDTO {
        HAEntityRegistryDisplayResponseDTO(entities: [])
    }

    func fetchDeviceRegistry() async throws -> [HADeviceRegistryDTO] {
        []
    }

    func fetchAreaRegistry() async throws -> [HAAreaRegistryDTO] {
        []
    }

    func fetchServices() async throws -> HAServiceRegistry {
        if let fetchServicesDelay {
            try await Task.sleep(for: fetchServicesDelay)
        }

        if let fetchServicesError {
            throw fetchServicesError
        }

        return serviceRegistry
    }

    func fetchCameraCapabilities(entityID: String) async throws -> HACameraCapabilities {
        HACameraCapabilities(frontendStreamTypes: [])
    }

    func subscribeToStateChanges() async throws {}

    func unsubscribeFromStateChanges() async throws {}

    func callService(
        domain: String,
        service: String,
        entityID: String?,
        serviceData: [String: JSONValue]
    ) async throws {
        callServiceInvocations.append((domain, service, entityID, serviceData))

        if let callServiceError {
            throw callServiceError
        }
    }
}

final class StubHAMobileAppClient: HAMobileAppClientProtocol {
    var registrationResponse: HAMobileAppRegistrationResponseDTO
    var cameraStreamResponse: HACameraStreamResponseDTO
    private(set) var lastRegistrationRequest: HAMobileAppRegistrationRequestDTO?
    private(set) var lastCameraStreamEntityID: String?

    init(
        registrationResponse: HAMobileAppRegistrationResponseDTO = HAMobileAppRegistrationResponseDTO(
            cloudhookURL: nil,
            remoteUIURL: nil,
            secret: nil,
            webhookID: "webhook-stub"
        ),
        cameraStreamResponse: HACameraStreamResponseDTO = HACameraStreamResponseDTO(
            hlsPath: "/api/hls/camera.driveway/master_playlist.m3u8",
            mjpegPath: nil
        )
    ) {
        self.registrationResponse = registrationResponse
        self.cameraStreamResponse = cameraStreamResponse
    }

    func register(
        configuration: HAConnectionConfiguration,
        request: HAMobileAppRegistrationRequestDTO
    ) async throws -> HAMobileAppRegistrationResponseDTO {
        lastRegistrationRequest = request
        return registrationResponse
    }

    func requestCameraStream(
        configuration: HAConnectionConfiguration,
        registration: HAMobileAppRegistrationInfo,
        entityID: String
    ) async throws -> HACameraStreamResponseDTO {
        lastCameraStreamEntityID = entityID
        return cameraStreamResponse
    }
}
