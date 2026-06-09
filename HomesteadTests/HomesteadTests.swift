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

private enum TestDateError: Error {
    case invalid(String)
}

private func testDate(_ value: String) throws -> Date {
    guard let date = HADateParser.date(from: value) else {
        throw TestDateError.invalid(value)
    }

    return date
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

        let failedState = AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .failed("No route to host"),
            dataFreshness: .empty
        )
        #expect(failedState?.title == "Connection failed")
        #expect(failedState?.message.contains("Tap to retry") == true)
        #expect(failedState?.message.contains("No route to host") == true)

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

        let failureDuringReconnectChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline"),
            serviceFeedback: HAServiceFeedback(title: "Action failed, reconnecting", message: "Try again soon.", style: .failure)
        )
        #expect(failureDuringReconnectChrome.statusAccessoryState?.title == "Action failed, reconnecting")
        #expect(failureDuringReconnectChrome.statusAccessoryState?.style == .failure)
    }

    @Test func serviceFeedbackDurationMatchesOutcomeSeverity() {
        let successFeedback = HAServiceFeedback(title: "Done", message: nil, style: .success)
        let failureFeedback = HAServiceFeedback(title: "Failed", message: nil, style: .failure)

        #expect(successFeedback.displayDuration == .seconds(2))
        #expect(failureFeedback.displayDuration == .seconds(5))
    }

    @Test func companionNotificationSetupPromptRequiresRegisteredRequestableNotifications() {
        let credential = HAOAuthCredential(
            baseURLString: "http://homeassistant.local:8123",
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: "access-token",
            accessTokenExpiresAt: .distantFuture,
            tokenType: "Bearer",
            updatedAt: .now
        )
        let signedInState = HAAuthState.signedIn(HAAuthSessionSummary(credential: credential))
        let registeredState = HAMobileAppRegistrationState.registered(
            HAMobileAppRegistrationSummary(
                info: HAMobileAppRegistrationInfo(
                    serverIdentifier: "homeassistant.local",
                    deviceID: "device-a",
                    appVersion: "1.0",
                    deviceName: "Test Phone",
                    webhookID: "webhook-a"
                )
            )
        )

        #expect(CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: true,
            authState: signedInState,
            mobileAppRegistrationState: registeredState,
            notificationStatus: .notDetermined,
            hasHandledPrompt: false,
            isShowingSettings: false
        ))

        #expect(!CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: true,
            authState: .signedOut,
            mobileAppRegistrationState: registeredState,
            notificationStatus: .notDetermined,
            hasHandledPrompt: false,
            isShowingSettings: false
        ))

        #expect(!CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: true,
            authState: signedInState,
            mobileAppRegistrationState: .unregistered,
            notificationStatus: .notDetermined,
            hasHandledPrompt: false,
            isShowingSettings: false
        ))

        #expect(!CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: true,
            authState: signedInState,
            mobileAppRegistrationState: registeredState,
            notificationStatus: .authorized,
            hasHandledPrompt: false,
            isShowingSettings: false
        ))

        #expect(!CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: true,
            authState: signedInState,
            mobileAppRegistrationState: registeredState,
            notificationStatus: .notDetermined,
            hasHandledPrompt: true,
            isShowingSettings: false
        ))

        #expect(!CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: true,
            authState: signedInState,
            mobileAppRegistrationState: registeredState,
            notificationStatus: .notDetermined,
            hasHandledPrompt: false,
            isShowingSettings: true
        ))
    }

    @Test func companionNotificationSetupPromptRefreshesUnknownStatusOnlyWhenEligible() {
        let credential = HAOAuthCredential(
            baseURLString: "http://homeassistant.local:8123",
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: "access-token",
            accessTokenExpiresAt: .distantFuture,
            tokenType: "Bearer",
            updatedAt: .now
        )
        let registeredState = HAMobileAppRegistrationState.registered(
            HAMobileAppRegistrationSummary(
                info: HAMobileAppRegistrationInfo(
                    serverIdentifier: "homeassistant.local",
                    deviceID: "device-a",
                    appVersion: "1.0",
                    deviceName: "Test Phone",
                    webhookID: "webhook-a"
                )
            )
        )

        #expect(CompanionNotificationSetupPromptPresentation.shouldRefreshNotificationStatus(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            mobileAppRegistrationState: registeredState,
            notificationStatus: .unknown,
            hasHandledPrompt: false
        ))

        #expect(!CompanionNotificationSetupPromptPresentation.shouldRefreshNotificationStatus(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            mobileAppRegistrationState: registeredState,
            notificationStatus: .notDetermined,
            hasHandledPrompt: false
        ))

        #expect(!CompanionNotificationSetupPromptPresentation.shouldRefreshNotificationStatus(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            mobileAppRegistrationState: registeredState,
            notificationStatus: .unknown,
            hasHandledPrompt: true
        ))
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

    @Test func logbookEndpointUsesOfficialHTTPPathAndDocumentedQueryItems() throws {
        let startDate = try testDate("2026-06-05T15:30:00Z")
        let endDate = try testDate("2026-06-05T16:45:00Z")

        let url = try HomeAssistantEndpointBuilder.logbookURL(
            from: "https://example.com/ha",
            startDate: startDate,
            endDate: endDate,
            entityID: "light.kitchen"
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        #expect(components.scheme == "https")
        #expect(components.host == "example.com")
        #expect(components.path == "/ha/api/logbook/2026-06-05T15:30:00Z")
        #expect(queryItems["end_time"] == "2026-06-05T16:45:00Z")
        #expect(queryItems["entity"] == "light.kitchen")
    }

    @Test func historyEndpointUsesOfficialHTTPPathAndDocumentedQueryItems() throws {
        let startDate = try testDate("2026-06-05T15:30:00Z")
        let endDate = try testDate("2026-06-05T16:45:00Z")
        let request = HAHistoryRequest(
            startDate: startDate,
            endDate: endDate,
            entityID: " sensor.kitchen_temperature ",
            minimalResponse: true,
            noAttributes: true,
            significantChangesOnly: true
        )

        let url = try HomeAssistantEndpointBuilder.historyURL(
            from: "https://example.com/ha",
            request: request
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []
        let queryValues = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        let queryNames = Set(queryItems.map(\.name))

        #expect(components.scheme == "https")
        #expect(components.host == "example.com")
        #expect(components.path == "/ha/api/history/period/2026-06-05T15:30:00Z")
        #expect(queryValues["filter_entity_id"] == "sensor.kitchen_temperature")
        #expect(queryValues["end_time"] == "2026-06-05T16:45:00Z")
        #expect(queryNames.contains("minimal_response"))
        #expect(queryNames.contains("no_attributes"))
        #expect(queryNames.contains("significant_changes_only"))
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

        let rangeRequest = HAWebSocketRequest.callService(
            id: 45,
            domain: "climate",
            service: "set_temperature",
            target: ["entity_id": .string("climate.downstairs")],
            serviceData: [
                "target_temp_low": .number(68),
                "target_temp_high": .number(76)
            ]
        )

        let rangeData = try JSONEncoder().encode(rangeRequest)
        let rangeObject = try #require(JSONSerialization.jsonObject(with: rangeData) as? [String: Any])
        let rangeServiceData = try #require(rangeObject["service_data"] as? [String: Any])

        #expect(rangeObject["id"] as? Int == 45)
        #expect(rangeObject["domain"] as? String == "climate")
        #expect(rangeObject["service"] as? String == "set_temperature")
        #expect(rangeServiceData["target_temp_low"] as? Double == 68)
        #expect(rangeServiceData["target_temp_high"] as? Double == 76)
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

    @Test func nativeControlDomainRequestsEncodeHomeAssistantShape() throws {
        let buttonRequest = HAWebSocketRequest.callService(
            id: 47,
            domain: "button",
            service: "press",
            target: ["entity_id": .string("button.restart_router")],
            serviceData: [:]
        )
        let selectRequest = HAWebSocketRequest.callService(
            id: 48,
            domain: "select",
            service: "select_option",
            target: ["entity_id": .string("select.house_mode")],
            serviceData: ["option": .string("Away")]
        )
        let numberRequest = HAWebSocketRequest.callService(
            id: 49,
            domain: "number",
            service: "set_value",
            target: ["entity_id": .string("number.target_humidity")],
            serviceData: ["value": .number(45)]
        )
        let alarmRequest = HAWebSocketRequest.callService(
            id: 50,
            domain: "alarm_control_panel",
            service: "alarm_arm_home",
            target: ["entity_id": .string("alarm_control_panel.home")],
            serviceData: ["code": .string("1234")]
        )

        let buttonObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(buttonRequest)) as? [String: Any])
        let buttonTarget = try #require(buttonObject["target"] as? [String: Any])
        let selectObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(selectRequest)) as? [String: Any])
        let selectTarget = try #require(selectObject["target"] as? [String: Any])
        let selectServiceData = try #require(selectObject["service_data"] as? [String: Any])
        let numberObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(numberRequest)) as? [String: Any])
        let numberTarget = try #require(numberObject["target"] as? [String: Any])
        let numberServiceData = try #require(numberObject["service_data"] as? [String: Any])
        let alarmObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(alarmRequest)) as? [String: Any])
        let alarmTarget = try #require(alarmObject["target"] as? [String: Any])
        let alarmServiceData = try #require(alarmObject["service_data"] as? [String: Any])

        #expect(buttonObject["domain"] as? String == "button")
        #expect(buttonObject["service"] as? String == "press")
        #expect(buttonTarget["entity_id"] as? String == "button.restart_router")
        #expect(selectObject["domain"] as? String == "select")
        #expect(selectObject["service"] as? String == "select_option")
        #expect(selectTarget["entity_id"] as? String == "select.house_mode")
        #expect(selectServiceData["option"] as? String == "Away")
        #expect(numberObject["domain"] as? String == "number")
        #expect(numberObject["service"] as? String == "set_value")
        #expect(numberTarget["entity_id"] as? String == "number.target_humidity")
        #expect(numberServiceData["value"] as? Double == 45)
        #expect(alarmObject["domain"] as? String == "alarm_control_panel")
        #expect(alarmObject["service"] as? String == "alarm_arm_home")
        #expect(alarmTarget["entity_id"] as? String == "alarm_control_panel.home")
        #expect(alarmServiceData["code"] as? String == "1234")
    }

    @Test func updateServiceRequestsEncodeHomeAssistantShape() throws {
        let installRequest = HAWebSocketRequest.callService(
            id: 51,
            domain: "update",
            service: "install",
            target: ["entity_id": .string("update.home_assistant_core_update")],
            serviceData: [
                "backup": .bool(true),
                "version": .string("2026.6.1")
            ]
        )
        let skipRequest = HAWebSocketRequest.callService(
            id: 52,
            domain: "update",
            service: "skip",
            target: ["entity_id": .string("update.home_assistant_core_update")],
            serviceData: [:]
        )
        let clearSkippedRequest = HAWebSocketRequest.callService(
            id: 53,
            domain: "update",
            service: "clear_skipped",
            target: ["entity_id": .string("update.home_assistant_core_update")],
            serviceData: [:]
        )

        let installObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(installRequest)) as? [String: Any])
        let installTarget = try #require(installObject["target"] as? [String: Any])
        let installServiceData = try #require(installObject["service_data"] as? [String: Any])
        let skipObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(skipRequest)) as? [String: Any])
        let clearSkippedObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(clearSkippedRequest)) as? [String: Any])

        #expect(installObject["domain"] as? String == "update")
        #expect(installObject["service"] as? String == "install")
        #expect(installTarget["entity_id"] as? String == "update.home_assistant_core_update")
        #expect(installServiceData["backup"] as? Bool == true)
        #expect(installServiceData["version"] as? String == "2026.6.1")
        #expect(skipObject["domain"] as? String == "update")
        #expect(skipObject["service"] as? String == "skip")
        #expect((skipObject["service_data"] as? [String: Any])?.isEmpty == true)
        #expect(clearSkippedObject["domain"] as? String == "update")
        #expect(clearSkippedObject["service"] as? String == "clear_skipped")
        #expect((clearSkippedObject["service_data"] as? [String: Any])?.isEmpty == true)
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

    @Test func getConfigRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.getConfig(id: 10)

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 10)
        #expect(object["type"] as? String == "get_config")
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

    @Test func mobileAppPushNotificationRequestsEncodeHomeAssistantShape() throws {
        let subscribe = HAWebSocketRequest.mobileAppPushNotificationChannel(
            id: 12,
            webhookID: "webhook-abc",
            supportConfirm: true
        )
        let confirm = HAWebSocketRequest.mobileAppPushNotificationConfirm(
            id: 13,
            webhookID: "webhook-abc",
            confirmID: "confirm-123"
        )

        let subscribeObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(subscribe)) as? [String: Any])
        #expect(subscribeObject["id"] as? Int == 12)
        #expect(subscribeObject["type"] as? String == "mobile_app/push_notification_channel")
        #expect(subscribeObject["webhook_id"] as? String == "webhook-abc")
        #expect(subscribeObject["support_confirm"] as? Bool == true)

        let confirmObject = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(confirm)) as? [String: Any])
        #expect(confirmObject["id"] as? Int == 13)
        #expect(confirmObject["type"] as? String == "mobile_app/push_notification_confirm")
        #expect(confirmObject["webhook_id"] as? String == "webhook-abc")
        #expect(confirmObject["confirm_id"] as? String == "confirm-123")
    }

    @Test func mobileAppPushNotificationEventDecodesFromWebSocketEventEnvelope() throws {
        let payload = """
        {
            "id": 12,
            "type": "event",
            "event": {
                "title": "Laundry",
                "message": "Washer finished",
                "hass_confirm_id": "confirm-123",
                "data": {
                    "tag": "laundry"
                }
            }
        }
        """

        let message = try JSONDecoder().decode(HAWebSocketIncomingMessage.self, from: Data(payload.utf8))

        #expect(message.event == nil)
        #expect(message.mobileAppPushNotificationEvent?.title == "Laundry")
        #expect(message.mobileAppPushNotificationEvent?.message == "Washer finished")
        #expect(message.mobileAppPushNotificationEvent?.hassConfirmID == "confirm-123")
    }

    @Test func mobileAppPushNotificationEventDecodesNestedDataPayload() throws {
        let payload = """
        {
            "id": 12,
            "type": "event",
            "event": {
                "data": {
                    "title": "Laundry",
                    "message": "Washer finished",
                    "hass_confirm_id": "confirm-123",
                    "data": {
                        "tag": "laundry"
                    }
                }
            }
        }
        """

        let message = try JSONDecoder().decode(HAWebSocketIncomingMessage.self, from: Data(payload.utf8))

        #expect(message.event == nil)
        #expect(message.mobileAppPushNotificationEvent?.title == "Laundry")
        #expect(message.mobileAppPushNotificationEvent?.message == "Washer finished")
        #expect(message.mobileAppPushNotificationEvent?.hassConfirmID == "confirm-123")
        #expect(message.mobileAppPushNotificationEvent?.data?.objectValue?["tag"]?.stringValue == "laundry")
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

    @Test func serverConfigurationDecodesOfficialConfigFields() throws {
        let payload = """
        {
            "version": "2026.6.0",
            "location_name": "Home",
            "time_zone": "America/Chicago",
            "internal_url": "http://homeassistant.local:8123",
            "external_url": "https://home.example.com",
            "state": "RUNNING",
            "config_source": "storage",
            "unit_system": {
                "temperature": "F",
                "length": "mi",
                "mass": "lb",
                "volume": "gal"
            }
        }
        """

        let config = try JSONDecoder().decode(HAConfigDTO.self, from: Data(payload.utf8))
        let snapshot = HAServerConfigurationSnapshot(
            dto: config,
            loadedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        #expect(snapshot.homeAssistantVersion == "2026.6.0")
        #expect(snapshot.locationName == "Home")
        #expect(snapshot.timeZone == "America/Chicago")
        #expect(snapshot.internalURL == "http://homeassistant.local:8123")
        #expect(snapshot.externalURL == "https://home.example.com")
        #expect(snapshot.state == "RUNNING")
        #expect(snapshot.configSource == "storage")
        #expect(snapshot.unitSystemSummary == "Temp F, Length mi, Mass lb, Volume gal")
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
        #expect(capabilities.supportsHLSStream)
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
        let appData = try #require(object["app_data"] as? [String: Any])
        #expect(appData["push_websocket_channel"] as? Bool == true)
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

    @Test func logbookEntriesDecodeAndMapToActivityRows() throws {
        let payload = """
        [
            {
                "when": "2026-06-05T15:30:00.000000+00:00",
                "name": "Kitchen",
                "message": "turned on",
                "domain": "light",
                "entity_id": "light.kitchen",
                "context_user_id": "user-123"
            },
            {
                "when": "2026-06-05T15:35:00+00:00",
                "name": "Automation",
                "message": "triggered",
                "domain": "automation"
            }
        ]
        """

        let entries = try JSONDecoder().decode([HALogbookEntryDTO].self, from: Data(payload.utf8))
        let rows = HAActivityRow.makeRows(from: entries) { entityID in
            entityID == "light.kitchen" ? "Kitchen Pendant" : nil
        }

        #expect(entries.count == 2)
        #expect(rows[0].title == "Kitchen Pendant")
        #expect(rows[0].message == "turned on")
        #expect(rows[0].entityID == "light.kitchen")
        #expect(rows[0].entityDomain == .light)
        #expect(rows[0].sourceDomain == "light")
        #expect(rows[0].contextUserID == "user-123")
        #expect(rows[0].iconSystemName == EntityDomain.light.systemImage)
        #expect(rows[0].matches(query: "pendant"))
        #expect(rows[1].title == "Automation")
        #expect(rows[1].iconSystemName == "list.bullet.clipboard")
    }

    @Test func logbookPresentationFiltersByDomainAndSearchText() throws {
        let lightTime = try testDate("2026-06-05T15:30:00Z")
        let sensorTime = try testDate("2026-06-04T15:30:00Z")
        let rows = HAActivityRow.makeRows(
            from: [
                HALogbookEntryDTO(
                    when: lightTime,
                    name: "Kitchen",
                    message: "turned on",
                    domain: "light",
                    entityID: "light.kitchen"
                ),
                HALogbookEntryDTO(
                    when: sensorTime,
                    name: "Temperature",
                    message: "changed to 72",
                    domain: "sensor",
                    entityID: "sensor.kitchen_temperature"
                )
            ],
            entityDisplayName: { $0 }
        )
        let presentation = HALogbookPresentation.make(
            rows: rows,
            searchText: "kitchen",
            selectedDomain: .sensor,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(presentation.visibleRowCount == 1)
        #expect(presentation.sections.count == 1)
        #expect(presentation.sections.first?.rows.first?.entityID == "sensor.kitchen_temperature")
    }

    @Test func historyResponseDecodesMinimalStateRowsAndMapsNumericSamples() throws {
        let payload = """
        [
            [
                {
                    "entity_id": "sensor.kitchen_temperature",
                    "state": "70.5",
                    "last_changed": "2026-06-05T15:30:00.000000+00:00",
                    "last_updated": "2026-06-05T15:30:00+00:00",
                    "attributes": {
                        "unit_of_measurement": "°F"
                    }
                },
                {
                    "state": "71.2",
                    "last_changed": "2026-06-05T15:45:00+00:00"
                }
            ]
        ]
        """
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let request = HAHistoryRequest(
            startDate: startDate,
            endDate: endDate,
            entityID: "sensor.kitchen_temperature"
        )

        let response = try JSONDecoder().decode(HAHistoryResponseDTO.self, from: Data(payload.utf8))
        let series = HAHistoryChartSeries.make(
            response: response,
            request: request,
            displayName: "Kitchen Temperature",
            unit: "°F",
            range: .oneHour
        )

        #expect(response.series.count == 1)
        #expect(response.series[0][0].attributes?["unit_of_measurement"] == .string("°F"))
        #expect(response.series[0][1].entityID == nil)
        #expect(series.displayName == "Kitchen Temperature")
        #expect(series.samples.map(\.value) == [70.5, 71.2])
        #expect(series.summaryText.contains("Now 71.2°F"))
    }

    @Test func historyNumericSamplesFilterEntityRangeAndNonNumericStates() throws {
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let middleDate = try testDate("2026-06-05T15:30:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let outsideDate = try testDate("2026-06-05T16:30:00Z")
        let samples = HAHistoryChartSeries.numericSamples(
            from: [
                HAHistoryStateDTO(entityID: "sensor.kitchen_temperature", state: "unknown", lastChanged: startDate),
                HAHistoryStateDTO(entityID: "sensor.other", state: "1", lastChanged: middleDate),
                HAHistoryStateDTO(state: "70", lastChanged: middleDate),
                HAHistoryStateDTO(entityID: "sensor.kitchen_temperature", state: "71", lastChanged: endDate),
                HAHistoryStateDTO(entityID: "sensor.kitchen_temperature", state: "72", lastChanged: outsideDate)
            ],
            fallbackEntityID: "sensor.kitchen_temperature",
            matching: "sensor.kitchen_temperature",
            interval: DateInterval(start: startDate, end: endDate)
        )

        #expect(samples.map(\.value) == [70, 71])
        #expect(samples.map(\.occurredAt) == [middleDate, endDate])
    }

    @Test func historyTimelineMapsBinarySensorStatesIntoActivityEntries() throws {
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let openDate = try testDate("2026-06-05T15:10:00Z")
        let closedDate = try testDate("2026-06-05T15:40:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let request = HAHistoryRequest(
            startDate: startDate,
            endDate: endDate,
            entityID: "binary_sensor.front_door"
        )

        let timeline = HAHistoryTimeline.makeBinarySensorTimeline(
            response: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(entityID: "binary_sensor.front_door", state: "on", lastChanged: openDate),
                    HAHistoryStateDTO(state: "off", lastChanged: closedDate)
                ]
            ]),
            request: request,
            displayName: "Front Door",
            deviceClass: "door",
            range: .oneHour
        )

        #expect(timeline.displayName == "Front Door")
        #expect(timeline.entries.map(\.title) == ["Opened", "Closed"])
        #expect(timeline.entries.map(\.systemImage) == ["door.left.hand.open", "door.left.hand.closed"])
        #expect(timeline.entries.map(\.tone) == [.active, .inactive])
        #expect(timeline.summaryText == "2 changes • Now Closed")
    }

    @Test func historyTimelineFiltersRangeEntityUnsupportedStatesAndDuplicateStates() throws {
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let firstDate = try testDate("2026-06-05T15:10:00Z")
        let duplicateDate = try testDate("2026-06-05T15:20:00Z")
        let unknownDate = try testDate("2026-06-05T15:30:00Z")
        let unavailableDate = try testDate("2026-06-05T15:40:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let outsideDate = try testDate("2026-06-05T16:30:00Z")

        let entries = HAHistoryTimeline.binarySensorEntries(
            from: [
                HAHistoryStateDTO(entityID: "binary_sensor.motion", state: "on", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "binary_sensor.motion", state: "on", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "binary_sensor.other", state: "off", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "binary_sensor.motion", state: "dim", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "binary_sensor.motion", state: "unknown", lastChanged: unknownDate),
                HAHistoryStateDTO(state: "unavailable", lastChanged: unavailableDate),
                HAHistoryStateDTO(entityID: "binary_sensor.motion", state: "off", lastChanged: outsideDate)
            ],
            fallbackEntityID: "binary_sensor.motion",
            matching: "binary_sensor.motion",
            interval: DateInterval(start: startDate, end: endDate),
            displayKind: .motion
        )

        #expect(entries.map(\.state) == ["on", "unknown", "unavailable"])
        #expect(entries.map(\.title) == ["Detected", "Unknown", "Unavailable"])
        #expect(entries.map(\.tone) == [.active, .unavailable, .unavailable])
    }

    @Test func historyTimelineMapsLockStatesIntoActivityEntries() throws {
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let lockedDate = try testDate("2026-06-05T15:10:00Z")
        let unlockingDate = try testDate("2026-06-05T15:20:00Z")
        let unlockedDate = try testDate("2026-06-05T15:30:00Z")
        let jammedDate = try testDate("2026-06-05T15:40:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let request = HAHistoryRequest(
            startDate: startDate,
            endDate: endDate,
            entityID: "lock.front_door"
        )

        let timeline = HAHistoryTimeline.makeLockTimeline(
            response: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(entityID: "lock.front_door", state: "locked", lastChanged: lockedDate),
                    HAHistoryStateDTO(entityID: "lock.front_door", state: "unlocking", lastChanged: unlockingDate),
                    HAHistoryStateDTO(state: "unlocked", lastChanged: unlockedDate),
                    HAHistoryStateDTO(entityID: "lock.front_door", state: "jammed", lastChanged: jammedDate)
                ]
            ]),
            request: request,
            displayName: "Front Door",
            range: .oneHour
        )

        #expect(timeline.displayName == "Front Door")
        #expect(timeline.entries.map(\.title) == ["Locked", "Unlocking", "Unlocked", "Jammed"])
        #expect(timeline.entries.map(\.systemImage) == ["lock.fill", "lock.open.fill", "lock.open.fill", "exclamationmark.triangle.fill"])
        #expect(timeline.entries.map(\.tone) == [.inactive, .active, .active, .unavailable])
        #expect(timeline.summaryText == "4 changes • Now Jammed")
    }

    @Test func historyTimelineFiltersLockRangeEntityUnsupportedStatesAndDuplicateStates() throws {
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let firstDate = try testDate("2026-06-05T15:10:00Z")
        let duplicateDate = try testDate("2026-06-05T15:20:00Z")
        let unknownDate = try testDate("2026-06-05T15:30:00Z")
        let unavailableDate = try testDate("2026-06-05T15:40:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let outsideDate = try testDate("2026-06-05T16:30:00Z")

        let entries = HAHistoryTimeline.lockEntries(
            from: [
                HAHistoryStateDTO(entityID: "lock.front_door", state: "locked", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "lock.front_door", state: "locked", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "lock.back_door", state: "unlocked", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "lock.front_door", state: "open", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "lock.front_door", state: "unknown", lastChanged: unknownDate),
                HAHistoryStateDTO(state: "unavailable", lastChanged: unavailableDate),
                HAHistoryStateDTO(entityID: "lock.front_door", state: "unlocked", lastChanged: outsideDate)
            ],
            fallbackEntityID: "lock.front_door",
            matching: "lock.front_door",
            interval: DateInterval(start: startDate, end: endDate)
        )

        #expect(entries.map(\.state) == ["locked", "unknown", "unavailable"])
        #expect(entries.map(\.title) == ["Locked", "Unknown", "Unavailable"])
        #expect(entries.map(\.tone) == [.inactive, .unavailable, .unavailable])
    }

    @Test func historyTimelineMapsDiscreteDetailDomainsIntoActivityEntries() throws {
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let firstDate = try testDate("2026-06-05T15:10:00Z")
        let secondDate = try testDate("2026-06-05T15:20:00Z")
        let thirdDate = try testDate("2026-06-05T15:30:00Z")
        let fourthDate = try testDate("2026-06-05T15:40:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let interval = DateInterval(start: startDate, end: endDate)

        let switchEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "switch.coffee", state: "off", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "switch.coffee", state: "on", lastChanged: secondDate)
            ],
            fallbackEntityID: "switch.coffee",
            matching: "switch.coffee",
            interval: interval,
            domain: .switch
        )
        #expect(switchEntries.map(\.title) == ["Turned Off", "Turned On"])
        #expect(switchEntries.map(\.systemImage) == ["lightswitch.off.fill", "lightswitch.on.fill"])
        #expect(switchEntries.map(\.tone) == [.inactive, .active])

        let automationEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "automation.morning", state: "on", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "automation.morning", state: "off", lastChanged: secondDate)
            ],
            fallbackEntityID: "automation.morning",
            matching: "automation.morning",
            interval: interval,
            domain: .automation
        )
        #expect(automationEntries.map(\.title) == ["Enabled", "Disabled"])
        #expect(automationEntries.map(\.tone) == [.active, .inactive])

        let coverEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "cover.garage", state: "opening", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "cover.garage", state: "open", lastChanged: secondDate),
                HAHistoryStateDTO(entityID: "cover.garage", state: "closing", lastChanged: thirdDate),
                HAHistoryStateDTO(entityID: "cover.garage", state: "closed", lastChanged: fourthDate)
            ],
            fallbackEntityID: "cover.garage",
            matching: "cover.garage",
            interval: interval,
            domain: .cover(deviceClass: "garage")
        )
        #expect(coverEntries.map(\.title) == ["Opening", "Opened", "Closing", "Closed"])
        #expect(coverEntries.map(\.systemImage) == ["door.garage.open", "door.garage.open", "door.garage.closed", "door.garage.closed"])
        #expect(coverEntries.map(\.tone) == [.active, .active, .inactive, .inactive])

        let personEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "person.tyler", state: "not_home", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "person.tyler", state: "work", lastChanged: secondDate),
                HAHistoryStateDTO(entityID: "person.tyler", state: "home", lastChanged: thirdDate)
            ],
            fallbackEntityID: "person.tyler",
            matching: "person.tyler",
            interval: interval,
            domain: .person
        )
        #expect(personEntries.map(\.title) == ["Away", "At Work", "Home"])
        #expect(personEntries.map(\.systemImage) == ["person", "mappin.and.ellipse", "person.fill"])
        #expect(personEntries.map(\.tone) == [.inactive, .active, .active])

        let trackerEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "device_tracker.phone", state: "home", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "device_tracker.phone", state: "not_home", lastChanged: secondDate),
                HAHistoryStateDTO(entityID: "device_tracker.phone", state: "unknown", lastChanged: thirdDate)
            ],
            fallbackEntityID: "device_tracker.phone",
            matching: "device_tracker.phone",
            interval: interval,
            domain: .deviceTracker
        )
        #expect(trackerEntries.map(\.title) == ["Home", "Away", "Unknown"])
        #expect(trackerEntries.map(\.systemImage) == ["location.fill", "location", "questionmark.circle"])
        #expect(trackerEntries.map(\.tone) == [.active, .inactive, .unavailable])
    }

    @Test func historyTimelineFiltersDiscreteDomainsByRangeEntityUnsupportedStatesAndDuplicateStates() throws {
        let startDate = try testDate("2026-06-05T15:00:00Z")
        let firstDate = try testDate("2026-06-05T15:10:00Z")
        let duplicateDate = try testDate("2026-06-05T15:20:00Z")
        let unavailableDate = try testDate("2026-06-05T15:30:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let outsideDate = try testDate("2026-06-05T16:30:00Z")

        let entries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "switch.coffee", state: "on", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "switch.coffee", state: "on", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "switch.other", state: "off", lastChanged: duplicateDate),
                HAHistoryStateDTO(entityID: "switch.coffee", state: "standby", lastChanged: duplicateDate),
                HAHistoryStateDTO(state: "unavailable", lastChanged: unavailableDate),
                HAHistoryStateDTO(entityID: "switch.coffee", state: "off", lastChanged: outsideDate)
            ],
            fallbackEntityID: "switch.coffee",
            matching: "switch.coffee",
            interval: DateInterval(start: startDate, end: endDate),
            domain: .switch
        )

        #expect(entries.map(\.state) == ["on", "unavailable"])
        #expect(entries.map(\.title) == ["Turned On", "Unavailable"])
        #expect(entries.map(\.tone) == [.active, .unavailable])
    }

    @Test func historyRangePresetBuildsFixedIntervals() throws {
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let expectedHourStart = try testDate("2026-06-05T15:00:00Z")
        let expectedSixHourStart = try testDate("2026-06-05T10:00:00Z")
        let expectedDayStart = try testDate("2026-06-04T16:00:00Z")
        let hour = HAHistoryRangePreset.oneHour.interval(endingAt: endDate)
        let sixHours = HAHistoryRangePreset.sixHours.interval(endingAt: endDate)
        let day = HAHistoryRangePreset.day.interval(endingAt: endDate)

        #expect(hour.end == endDate)
        #expect(hour.start == expectedHourStart)
        #expect(sixHours.start == expectedSixHourStart)
        #expect(day.start == expectedDayStart)
    }

    @MainActor
    @Test func dashboardHistoryCardsAreEligibleOnlyForNumericSensorChartLayouts() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "71.2",
                attributes: [
                    "friendly_name": .string("Kitchen Temperature"),
                    "unit_of_measurement": .string("F"),
                    "device_class": .string("temperature")
                ]
            ),
            HAEntityDTO(entityID: "sensor.mode", state: "auto"),
            HAEntityDTO(entityID: "binary_sensor.front_door", state: "off")
        ])

        let numericSensor = try #require(store.entityBox(for: "sensor.kitchen_temperature"))
        let textSensor = try #require(store.entityBox(for: "sensor.mode"))
        let binarySensor = try #require(store.entityBox(for: "binary_sensor.front_door"))

        #expect(DashboardHistoryCardPresentation.isEligible(entityBox: numericSensor, size: .square))
        #expect(DashboardHistoryCardPresentation.isEligible(entityBox: numericSensor, size: .wide))
        #expect(DashboardHistoryCardPresentation.isEligible(entityBox: numericSensor, size: .large))
        #expect(!DashboardHistoryCardPresentation.isEligible(entityBox: numericSensor, size: .compact))
        #expect(!DashboardHistoryCardPresentation.isEligible(entityBox: textSensor, size: .wide))
        #expect(!DashboardHistoryCardPresentation.isEligible(entityBox: binarySensor, size: .wide))
    }

    @MainActor
    @Test func dashboardHistoryRequestUsesDefaultSixHourRangeForEligibleCards() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "sensor.kitchen_temperature", state: "71.2")
        ])
        let sensor = try #require(store.entityBox(for: "sensor.kitchen_temperature"))
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let expectedStartDate = try testDate("2026-06-05T10:00:00Z")

        let request = try #require(DashboardHistoryCardPresentation.request(
            for: sensor,
            size: .square,
            endingAt: endDate
        ))

        #expect(request.entityID == "sensor.kitchen_temperature")
        #expect(request.startDate == expectedStartDate)
        #expect(request.endDate == endDate)
        #expect(request.minimalResponse)
        #expect(request.noAttributes)
        #expect(!request.significantChangesOnly)
        #expect(DashboardHistoryCardPresentation.request(for: sensor, size: .compact, endingAt: endDate) == nil)
    }

    @Test func dashboardHistoryPresentationMapsChartSeriesForCards() throws {
        let startDate = try testDate("2026-06-05T10:00:00Z")
        let middleDate = try testDate("2026-06-05T13:00:00Z")
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let request = HAHistoryRequest(
            startDate: startDate,
            endDate: endDate,
            entityID: "sensor.kitchen_temperature"
        )
        let series = HAHistoryChartSeries.make(
            response: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(entityID: "sensor.kitchen_temperature", state: "70", lastChanged: startDate),
                    HAHistoryStateDTO(entityID: "sensor.kitchen_temperature", state: "71.5", lastChanged: middleDate),
                    HAHistoryStateDTO(entityID: "sensor.kitchen_temperature", state: "72", lastChanged: endDate)
                ]
            ]),
            request: request,
            displayName: "Kitchen Temperature",
            unit: "°F",
            range: .sixHours
        )

        let presentation = DashboardHistoryCardPresentation(series: series)

        #expect(presentation.entityID == "sensor.kitchen_temperature")
        #expect(presentation.displayName == "Kitchen Temperature")
        #expect(presentation.range == .sixHours)
        #expect(presentation.samples.map(\.value) == [70, 71.5, 72])
        #expect(presentation.latestValueText == "72°F")
        #expect(presentation.latestTimeText?.isEmpty == false)
        #expect(presentation.summaryText.contains("Now 72°F"))
        #expect(presentation.accessibilityLabel == "Kitchen Temperature dashboard history")
        #expect(presentation.accessibilityValue == presentation.summaryText)
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
                    "hb": true,
                    "ec": 1
                }
            ],
            "entity_categories": {
                "1": "diagnostic"
            }
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
        #expect(response.entities.first?.entityCategory == "diagnostic")
        #expect(response.entities.first?.entityCategoryIndex == 1)
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
                "name": "Living Room",
                "floor_id": "main_floor",
                "temperature_entity_id": "sensor.living_room_temperature",
                "humidity_entity_id": "sensor.living_room_humidity"
            }
        ]
        """

        let areas = try JSONDecoder().decode(
            [HAAreaRegistryDTO].self,
            from: Data(payload.utf8)
        )

        #expect(areas.first?.id == "living_room")
        #expect(areas.first?.name == "Living Room")
        #expect(areas.first?.floorID == "main_floor")
        #expect(areas.first?.temperatureEntityID == "sensor.living_room_temperature")
        #expect(areas.first?.humidityEntityID == "sensor.living_room_humidity")
    }

    @Test func floorRegistryResponseDecodesHomeAssistantFloorID() throws {
        let payload = """
        [
            {
                "floor_id": "main_floor",
                "name": "Main Floor",
                "level": 0,
                "icon": "mdi:home-floor-0"
            }
        ]
        """

        let floors = try JSONDecoder().decode(
            [HAFloorRegistryDTO].self,
            from: Data(payload.utf8)
        )

        #expect(floors.first?.id == "main_floor")
        #expect(floors.first?.name == "Main Floor")
        #expect(floors.first?.level == 0)
        #expect(floors.first?.icon == "mdi:home-floor-0")
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
        #expect(light?.supportsBrightness == true)
        #expect(light?.brightnessPercentage == 50)
        #expect(light?.iconName == "lightbulb.fill")
        #expect(sensor?.displayName == "Hallway")
        #expect(sensor?.formattedValue == "72°F")
        #expect(sensor?.unit == "F")
        #expect(sensor?.iconName == "thermometer.medium")
    }

    @Test func entityMapperMapsHomeAssistantWeatherEntities() throws {
        let weatherDTO = HAEntityDTO(
            entityID: "weather.home",
            state: "partlycloudy",
            attributes: [
                "friendly_name": .string("Home Weather"),
                "temperature": .number(72.6),
                "temperature_unit": .string("F"),
                "humidity": .number(55),
                "wind_speed": .number(8.4),
                "wind_speed_unit": .string("mph"),
                "wind_bearing": .number(225),
                "forecast": .array([
                    .object(["condition": .string("rainy")]),
                    .object(["condition": .string("sunny")])
                ]),
                "attribution": .string("Weather Provider")
            ],
            lastUpdated: Date(timeIntervalSince1970: 100)
        )

        let weather = try #require(EntityMapper.weatherEntity(from: weatherDTO))

        #expect(weather.entityID == "weather.home")
        #expect(weather.displayName == "Home Weather")
        #expect(weather.condition == .partlyCloudy)
        #expect(weather.displaySubtitle == "Partly Cloudy")
        #expect(weather.temperatureText == "72.6°F")
        #expect(weather.humidityText == "55%")
        #expect(weather.windDirectionText == "SW")
        #expect(weather.windText == "SW 8.4 mph")
        #expect(weather.hasForecast == true)
        #expect(weather.forecastAvailabilityText == "2 forecast items")
        #expect(weather.attributionText == "Weather Provider")
        #expect(weather.iconName == "cloud.sun.fill")
    }

    @Test func entityMapperMapsLightBrightnessSupportForOffDimmableLights() {
        let dimmableLightDTO = HAEntityDTO(
            entityID: "light.bed_lamp",
            state: "off",
            attributes: [
                "supported_color_modes": .array([.string("brightness")])
            ]
        )
        let toggleOnlyLightDTO = HAEntityDTO(
            entityID: "light.closet",
            state: "off",
            attributes: [
                "supported_color_modes": .array([.string("onoff")])
            ]
        )

        #expect(EntityMapper.lightEntity(from: dimmableLightDTO)?.supportsBrightness == true)
        #expect(EntityMapper.lightEntity(from: toggleOnlyLightDTO)?.supportsBrightness == false)
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
        let outletSwitchEntity = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "switch.fish_light",
            state: "on",
            attributes: ["device_class": .string("outlet")]
        ))
        let wallSwitchEntity = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "switch.curio_strip_china_cabinet",
            state: "off",
            attributes: ["device_class": .string("switch")]
        ))
        let fanEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "fan.bedroom", state: "off"))
        let lockEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "lock.front_door", state: "locked"))
        let mediaEntity = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "media_player.living_room",
            state: "playing",
            attributes: ["device_class": .string("tv")]
        ))
        let cameraEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "camera.driveway", state: "idle"))
        let automationEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "automation.good_night", state: "on"))
        let remoteEntity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "remote.ashtons_tv", state: "off"))
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
        #expect(automationEntity.domain == .automation)
        #expect(remoteEntity.domain == .remote)
        #expect(remoteEntity.domain != .other)
        #expect(remoteEntity.iconName == "appletvremote.gen4.fill")
        #expect(remoteEntity.domain.displayName == "Remotes")
        #expect(binarySensorEntity.domain == .binarySensor)
        #expect(switchEntity.iconName == "lightswitch.on.fill")
        #expect(outletSwitchEntity.iconName == "poweroutlet.type.b.fill")
        #expect(wallSwitchEntity.iconName == "lightswitch.off.fill")
        #expect(fanEntity.iconName == "fan.fill")
        #expect(lockEntity.iconName == "lock.fill")
        #expect(mediaEntity.iconName == "tv.fill")
        #expect(automationEntity.iconName == "calendar.badge.clock")
        #expect(binarySensor?.displayKind == .door)
        #expect(binarySensor?.displaySubtitle == "Open")
    }

    @MainActor
    @Test func entityMapperRecognizesCommonHomeAssistantDomainsAndKeepsUnknownsGeneric() {
        let examples: [(String, EntityDomain, String)] = [
            ("button.identify", .button, "button.programmable"),
            ("select.hvac_mode", .select, "filemenu.and.selection"),
            ("number.target_humidity", .number, "gauge.medium"),
            ("text.status_message", .text, "text.cursor"),
            ("date.vacation_start", .date, "calendar"),
            ("time.wakeup", .time, "clock"),
            ("datetime.irrigation_start", .datetime, "calendar.badge.clock"),
            ("device_tracker.phone", .deviceTracker, "location"),
            ("person.ashton", .person, "person"),
            ("update.router_firmware", .update, "checkmark.circle"),
            ("alarm_control_panel.home", .alarmControlPanel, "shield.lefthalf.filled"),
            ("humidifier.primary", .humidifier, "humidifier.fill"),
            ("water_heater.tank", .waterHeater, "water.waves"),
            ("lawn_mower.back_yard", .lawnMower, "leaf"),
            ("valve.sprinkler", .valve, "pipe.and.drop"),
            ("siren.garage", .siren, "megaphone"),
            ("weather.home", .weather, "cloud.sun.fill"),
            ("calendar.family", .calendar, "calendar"),
            ("todo.groceries", .todo, "checklist"),
            ("event.front_door", .event, "sensor.tag.radiowaves.forward.fill"),
            ("image.doorbell_last_motion", .image, "photo.fill"),
            ("image_processing.driveway", .imageProcessing, "viewfinder"),
            ("air_quality.home", .airQuality, "aqi.medium")
        ]

        for (entityID, domain, iconName) in examples {
            let entity = EntityMapper.homeEntity(from: HAEntityDTO(entityID: entityID, state: "off"))
            #expect(entity.domain == domain)
            #expect(entity.iconName == iconName)
            #expect(entity.domain != .other)
        }

        let unsupported = EntityMapper.homeEntity(from: HAEntityDTO(entityID: "moon_phase.home", state: "full_moon"))
        #expect(unsupported.domain == .other)
        #expect(unsupported.iconName == "circle.hexagongrid")
    }

    @Test func entityMapperMapsHomeAssistantUpdateEntities() throws {
        let updateDTO = HAEntityDTO(
            entityID: "update.home_assistant_core_update",
            state: "on",
            attributes: [
                "friendly_name": .string("Home Assistant Core Update"),
                "title": .string("Home Assistant Core 2026.6.1"),
                "installed_version": .string("2026.6.0"),
                "latest_version": .string("2026.6.1"),
                "release_summary": .string("Fixes and polish."),
                "release_url": .string("https://www.home-assistant.io/blog/2026/06/01/release-20266/"),
                "device_class": .string("firmware")
            ],
            lastUpdated: Date(timeIntervalSince1970: 100)
        )

        let update = try #require(EntityMapper.updateEntity(
            from: updateDTO,
            deviceID: "device-core",
            deviceName: "Home Assistant",
            areaID: "server",
            areaName: "Server Closet",
            floorID: "basement",
            floorName: "Basement"
        ))

        #expect(update.entityID == "update.home_assistant_core_update")
        #expect(update.name == "Home Assistant Core Update")
        #expect(update.title == "Home Assistant Core 2026.6.1")
        #expect(update.installedVersion == "2026.6.0")
        #expect(update.latestVersion == "2026.6.1")
        #expect(update.releaseSummary == "Fixes and polish.")
        #expect(update.releaseURLString?.contains("release-20266") == true)
        #expect(update.status == .available)
        #expect(update.iconSystemName == "memorychip.fill")
        #expect(update.versionSummary == "2026.6.0 -> 2026.6.1")
        #expect(update.context.areaName == "Server Closet")
        #expect(update.context.deviceName == "Home Assistant")
    }

    @Test func updateEntityStatusReflectsSkippedInProgressAndUnavailableState() throws {
        let skipped = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.router",
            state: "off",
            attributes: [
                "friendly_name": .string("Router"),
                "installed_version": .string("1.0"),
                "latest_version": .string("1.1"),
                "skipped_version": .string("1.1")
            ]
        )))
        let inProgress = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.bridge",
            state: "on",
            attributes: [
                "friendly_name": .string("Bridge"),
                "in_progress": .number(42)
            ]
        )))
        let unavailable = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.add_on",
            state: "unavailable"
        )))

        #expect(skipped.status == .skipped)
        #expect(skipped.skippedVersion == "1.1")
        #expect(inProgress.status == .inProgress)
        #expect(inProgress.progress == 42)
        #expect(unavailable.status == .unavailable)
        #expect(!unavailable.isAvailable)
    }

    @Test func updatePresentationFiltersSearchesAndGroupsRows() throws {
        let core = try #require(EntityMapper.updateEntity(
            from: HAEntityDTO(
                entityID: "update.home_assistant_core_update",
                state: "on",
                attributes: [
                    "friendly_name": .string("Home Assistant Core"),
                    "latest_version": .string("2026.6.1")
                ]
            ),
            deviceName: "Home Assistant",
            areaName: "Server Closet"
        ))
        let router = try #require(EntityMapper.updateEntity(
            from: HAEntityDTO(
                entityID: "update.router_firmware",
                state: "off",
                attributes: [
                    "friendly_name": .string("Router Firmware"),
                    "skipped_version": .string("7.2")
                ]
            ),
            deviceName: "Router",
            areaName: "Network Closet"
        ))
        let bridge = try #require(EntityMapper.updateEntity(
            from: HAEntityDTO(
                entityID: "update.bridge",
                state: "off",
                attributes: ["friendly_name": .string("Bridge")]
            ),
            deviceName: "Bridge",
            areaName: "Living Room"
        ))

        let availablePresentation = HAUpdatePresentation.make(
            updates: [router, bridge, core],
            searchText: "core",
            filter: .available,
            grouping: .status
        )
        let areaPresentation = HAUpdatePresentation.make(
            updates: [router, bridge, core],
            searchText: "",
            filter: .all,
            grouping: .area
        )

        #expect(availablePresentation.visibleCount == 1)
        #expect(availablePresentation.sections.first?.id == HAUpdateStatus.available.rawValue)
        #expect(availablePresentation.sections.first?.updates.map(\.entityID) == ["update.home_assistant_core_update"])
        #expect(availablePresentation.summary.availableCount == 1)
        #expect(availablePresentation.summary.skippedCount == 1)
        #expect(areaPresentation.sections.map(\.title) == ["Living Room", "Network Closet", "Server Closet"])
    }

    @MainActor
    @Test func entityDomainGroupsNewDomainsPredictablyAndLeavesUnsupportedLast() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "update.router", state: "on"),
            HAEntityDTO(entityID: "remote.ashtons_tv", state: "off"),
            HAEntityDTO(entityID: "button.identify", state: "unknown"),
            HAEntityDTO(entityID: "moon_phase.home", state: "full_moon"),
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        #expect(store.entityIDGroupsByDomain.map(\.domain) == [.light, .remote, .button, .update, .other])
        #expect(EntityDomain.other.dashboardPriority > EntityDomain.update.dashboardPriority)
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
        #expect(cover.deviceClass == nil)
        #expect(cover.iconName == "blinds.horizontal.open")
        #expect(cover.isOpen == true)
        #expect(cover.isClosed == false)
        #expect(cover.displayState == "Open")
        #expect(cover.displaySubtitle == "Open • 72%")

        let closedCover = try #require(EntityMapper.coverEntity(from: HAEntityDTO(
            entityID: "cover.garage_door",
            state: "closed",
            attributes: ["current_position": .number(0)]
        )))
        #expect(closedCover.displaySubtitle == "Closed")

        let garageDTO = HAEntityDTO(
            entityID: "cover.garage_door",
            state: "closed",
            attributes: [
                "friendly_name": .string("Garage Door"),
                "device_class": .string("garage"),
                "current_position": .number(0)
            ]
        )
        let garageCover = try #require(EntityMapper.coverEntity(from: garageDTO))
        let garageHomeEntity = EntityMapper.homeEntity(from: garageDTO)

        #expect(garageCover.deviceClass == "garage")
        #expect(garageCover.iconName == "door.garage.closed")
        #expect(garageHomeEntity.iconName == "door.garage.closed")

        let curtainCover = try #require(EntityMapper.coverEntity(from: HAEntityDTO(
            entityID: "cover.living_room_curtains",
            state: "open",
            attributes: ["device_class": .string("curtain")]
        )))
        let gateCover = try #require(EntityMapper.coverEntity(from: HAEntityDTO(
            entityID: "cover.side_gate",
            state: "closed",
            attributes: ["device_class": .string("gate")]
        )))
        let shadeCover = try #require(EntityMapper.coverEntity(from: HAEntityDTO(
            entityID: "cover.office_shade",
            state: "closed",
            attributes: ["device_class": .string("shade")]
        )))

        #expect(curtainCover.iconName == "curtains.open")
        #expect(gateCover.iconName == "pedestrian.gate.closed")
        #expect(shadeCover.iconName == "window.shade.closed")
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
                "media_artist": .string("Homestead Radio"),
                "device_class": .string("speaker")
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
        #expect(media.deviceClass == "speaker")
        #expect(media.iconName == "speaker.wave.2.fill")
    }

    @Test func entityMapperMapsExpandedBinarySensorDeviceClasses() throws {
        let carbonMonoxideDTO = HAEntityDTO(
            entityID: "binary_sensor.hallway_co",
            state: "on",
            attributes: ["device_class": .string("carbon_monoxide")]
        )
        let batteryChargingDTO = HAEntityDTO(
            entityID: "binary_sensor.remote_charging",
            state: "off",
            attributes: ["device_class": .string("battery_charging")]
        )
        let vibrationDTO = HAEntityDTO(
            entityID: "binary_sensor.window_vibration",
            state: "on",
            attributes: ["device_class": .string("vibration")]
        )
        let updateDTO = HAEntityDTO(
            entityID: "binary_sensor.router_update",
            state: "on",
            attributes: ["device_class": .string("update")]
        )

        let carbonMonoxide = try #require(EntityMapper.binarySensorEntity(from: carbonMonoxideDTO))
        let batteryCharging = try #require(EntityMapper.binarySensorEntity(from: batteryChargingDTO))
        let vibration = try #require(EntityMapper.binarySensorEntity(from: vibrationDTO))
        let update = try #require(EntityMapper.binarySensorEntity(from: updateDTO))

        #expect(carbonMonoxide.displayKind == .carbonMonoxide)
        #expect(carbonMonoxide.displaySubtitle == "CO Detected")
        #expect(carbonMonoxide.iconName == "carbon.monoxide.cloud.fill")
        #expect(carbonMonoxide.isSecurityRelevant)
        #expect(batteryCharging.displayKind == .batteryCharging)
        #expect(batteryCharging.displaySubtitle == "Not Charging")
        #expect(batteryCharging.iconName == "battery.100percent")
        #expect(vibration.displayKind == .vibration)
        #expect(vibration.displaySubtitle == "Vibration Detected")
        #expect(vibration.iconName == "waveform.path")
        #expect(vibration.isSecurityRelevant)
        #expect(update.displayKind == .update)
        #expect(update.displaySubtitle == "Update Available")
        #expect(update.iconName == "arrow.trianglehead.2.clockwise")
        #expect(update.isSecurityRelevant == false)
    }

    @Test func entityMapperMapsClimateControls() throws {
        let climateDTO = HAEntityDTO(
            entityID: "climate.downstairs",
            state: "heat",
            attributes: [
                "friendly_name": .string("Downstairs"),
                "current_temperature": .number(68),
                "temperature": .number(70),
                "target_temp_low": .number(66),
                "target_temp_high": .number(76),
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
        #expect(climate.targetTemperatureLow == 66)
        #expect(climate.targetTemperatureHigh == 76)
        #expect(climate.temperatureUnit == "°F")
        #expect(climate.hvacModes == ["off", "heat", "cool", "heat_cool"])
        #expect(climate.fanMode == "auto")
        #expect(climate.fanModes == ["auto", "low", "high"])
        #expect(climate.presetMode == "home")
        #expect(climate.presetModes == ["home", "away"])
        #expect(climate.isActive == true)
        #expect(climate.displayState == "Heat")
        #expect(climate.targetTemperatureText == "70°F")
        #expect(climate.targetTemperatureRangeText == "66°F-76°F")
        #expect(climate.currentTemperatureText == "68°F")
        #expect(climate.displaySubtitle == "Heat, set to 70°F")

        let autoClimateDTO = HAEntityDTO(
            entityID: "climate.downstairs",
            state: "heat_cool",
            attributes: [
                "target_temp_low": .number(66),
                "target_temp_high": .number(76),
                "temperature_unit": .string("°F")
            ]
        )
        let autoClimate = try #require(EntityMapper.climateEntity(from: autoClimateDTO))
        #expect(autoClimate.usesTemperatureRange)
        #expect(autoClimate.displaySubtitle == "Auto, 66°F-76°F")
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

    @Test func entityMapperMapsExpandedSensorDeviceClasses() throws {
        let carbonDioxide = try #require(EntityMapper.sensorEntity(from: HAEntityDTO(
            entityID: "sensor.living_room_co2",
            state: "842.4",
            attributes: [
                "device_class": .string("carbon_dioxide"),
                "unit_of_measurement": .string("ppm")
            ]
        )))
        let particulateMatter = try #require(EntityMapper.sensorEntity(from: HAEntityDTO(
            entityID: "sensor.office_pm25",
            state: "3.456",
            attributes: [
                "device_class": .string("pm25"),
                "unit_of_measurement": .string("µg/m³")
            ]
        )))
        let timestamp = try #require(EntityMapper.sensorEntity(from: HAEntityDTO(
            entityID: "sensor.last_seen",
            state: "2026-06-01T12:00:00Z",
            attributes: ["device_class": .string("timestamp")]
        )))
        let carbonMonoxide = try #require(EntityMapper.sensorEntity(from: HAEntityDTO(
            entityID: "sensor.hallway_co",
            state: "unsafe",
            attributes: ["device_class": .string("carbon_monoxide")]
        )))
        let atmosphericPressure = try #require(EntityMapper.sensorEntity(from: HAEntityDTO(
            entityID: "sensor.outdoor_pressure",
            state: "29.92",
            attributes: [
                "device_class": .string("atmospheric_pressure"),
                "unit_of_measurement": .string("inHg")
            ]
        )))
        let reactivePower = try #require(EntityMapper.sensorEntity(from: HAEntityDTO(
            entityID: "sensor.inverter_reactive_power",
            state: "1.234",
            attributes: [
                "device_class": .string("reactive_power"),
                "unit_of_measurement": .string("var")
            ]
        )))
        let windSpeed = try #require(EntityMapper.sensorEntity(from: HAEntityDTO(
            entityID: "sensor.wind_speed",
            state: "8.2",
            attributes: [
                "device_class": .string("wind_speed"),
                "unit_of_measurement": .string("mph")
            ]
        )))

        #expect(carbonDioxide.displayKind == .carbonDioxide)
        #expect(carbonDioxide.iconName == "carbon.dioxide.cloud.fill")
        #expect(carbonDioxide.formattedValue == "842.4 ppm")
        #expect(particulateMatter.displayKind == .particulateMatter)
        #expect(particulateMatter.iconName == "aqi.medium")
        #expect(particulateMatter.formattedValue == "3.46 µg/m³")
        #expect(timestamp.displayKind == .date)
        #expect(timestamp.iconName == "calendar")
        #expect(timestamp.formattedValue == "2026-06-01T12:00:00Z")
        #expect(carbonMonoxide.displayKind == .carbonMonoxide)
        #expect(carbonMonoxide.iconName == "carbon.monoxide.cloud.fill")
        #expect(carbonMonoxide.isAlerting)
        #expect(carbonMonoxide.displaySubtitle == "CO Detected")
        #expect(atmosphericPressure.displayKind == .pressure)
        #expect(atmosphericPressure.iconName == "barometer")
        #expect(atmosphericPressure.formattedValue == "29.9 inHg")
        #expect(reactivePower.displayKind == .reactivePower)
        #expect(reactivePower.iconName == "bolt.fill")
        #expect(reactivePower.formattedValue == "1.23 var")
        #expect(windSpeed.displayKind == .speed)
        #expect(windSpeed.iconName == "speedometer")
    }

    @Test func entityMapperUsesDocumentedDeviceClassesForGenericDomainIcons() {
        let projector = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "media_player.theater",
            state: "playing",
            attributes: ["device_class": .string("projector")]
        ))
        let restartButton = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "button.router_restart",
            state: "unknown",
            attributes: ["device_class": .string("restart")]
        ))
        let gasValve = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "valve.gas_line",
            state: "closed",
            attributes: ["device_class": .string("gas")]
        ))
        let firmwareUpdate = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "update.router_firmware",
            state: "on",
            attributes: ["device_class": .string("firmware")]
        ))
        let doorbellEvent = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "event.front_door_ding",
            state: "2026-06-02T08:00:00Z",
            attributes: ["device_class": .string("doorbell")]
        ))
        let faceProcessing = EntityMapper.homeEntity(from: HAEntityDTO(
            entityID: "image_processing.porch_face",
            state: "1",
            attributes: ["device_class": .string("face")]
        ))

        #expect(projector.iconName == "videoprojector.fill")
        #expect(restartButton.iconName == "arrow.trianglehead.2.clockwise")
        #expect(gasValve.iconName == "flame.fill")
        #expect(firmwareUpdate.iconName == "memorychip.fill")
        #expect(doorbellEvent.iconName == "bell.and.waves.left.and.right.fill")
        #expect(faceProcessing.iconName == "face.smiling")
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
                lastUpdated: try testDate("2026-05-20T10:02:00.000000+00:00")
            )
        ])

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                attributes: ["friendly_name": .string("Kitchen")],
                lastUpdated: try testDate("2026-05-20T10:01:00.000000+00:00")
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
    @Test func stateStorePublishesTypedWeatherEntitiesThroughEntityBoxes() throws {
        let store = HAStateStore()
        store.applySnapshot([
            HAEntityDTO(
                entityID: "weather.home",
                state: "rainy",
                attributes: [
                    "friendly_name": .string("Home Weather"),
                    "temperature": .number(61),
                    "temperature_unit": .string("F"),
                    "humidity": .number(84),
                    "wind_speed": .number(12),
                    "wind_speed_unit": .string("mph")
                ]
            )
        ])

        let weather = try #require(store.weatherEntity(for: "weather.home"))
        let entityBox = try #require(store.entityBox(for: "weather.home"))

        #expect(weather.temperatureText == "61°F")
        #expect(weather.humidityText == "84%")
        #expect(entityBox.weatherEntity == weather)
        #expect(entityBox.homeEntity.domain == .weather)
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
                lastUpdated: try testDate("2026-05-20T10:00:00.000000+00:00")
            )
        ])
        let pendingCommand = HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on")
        store.setPendingCommand(pendingCommand)

        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "off",
                lastUpdated: try testDate("2026-05-20T10:01:00.000000+00:00")
            )
        ])

        #expect(store.pendingCommand(for: "light.kitchen") == pendingCommand)
        #expect(store.entityBox(for: "light.kitchen")?.pendingCommand == pendingCommand)
        #expect(store.lightEntity(for: "light.kitchen")?.isOn == false)

        store.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                lastUpdated: try testDate("2026-05-20T10:02:00.000000+00:00")
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

    @Test func widgetSharedStoreBuildsCompactSnapshots() {
        let lights = [
            LightEntity(
                entityID: "light.z_lamp",
                displayName: "Z Lamp",
                isOn: false,
                brightness: nil,
                supportsBrightness: false,
                iconName: "lightbulb.fill",
                lastUpdated: nil
            ),
            LightEntity(
                entityID: "light.a_lamp",
                displayName: "A Lamp",
                isOn: true,
                brightness: 128,
                supportsBrightness: true,
                iconName: "lightbulb.fill",
                lastUpdated: nil
            )
        ]
        let sensors = [
            SensorEntity(
                entityID: "sensor.temperature",
                displayName: "Temperature",
                value: "72.4",
                unit: "F",
                deviceClass: "temperature",
                iconName: "thermometer.medium",
                lastUpdated: nil
            ),
            SensorEntity(
                entityID: "sensor.battery",
                displayName: "Battery",
                value: "18",
                unit: "%",
                deviceClass: "battery",
                iconName: "battery.75percent",
                lastUpdated: nil
            )
        ]
        let covers = [
            CoverEntity(
                entityID: "cover.living_room_shades",
                displayName: "Living Room Shades",
                state: "open",
                position: 70,
                deviceClass: "shade",
                iconName: "window.shade.open"
            ),
            CoverEntity(
                entityID: "cover.garage_door",
                displayName: "Garage Door",
                state: "closed",
                position: 0,
                deviceClass: "garage",
                iconName: "door.garage.closed"
            )
        ]
        let fans = [
            FanEntity(
                entityID: "fan.office",
                displayName: "Office Fan",
                state: "off",
                percentage: nil,
                percentageStep: nil,
                presetMode: nil,
                presetModes: []
            ),
            FanEntity(
                entityID: "fan.bedroom",
                displayName: "Bedroom Fan",
                state: "on",
                percentage: 50,
                percentageStep: 1,
                presetMode: nil,
                presetModes: []
            )
        ]
        let entities = [
            HomeEntity(
                entityID: "sensor.temperature",
                domain: .sensor,
                displayName: "Temperature",
                state: "72",
                iconName: "thermometer.medium",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "person.guest",
                domain: .person,
                displayName: "Guest",
                state: "not_home",
                iconName: "person",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "person.tyler",
                domain: .person,
                displayName: "Tyler",
                state: "home",
                iconName: "person.fill",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "scene.movie_time",
                domain: .scene,
                displayName: "Movie Time",
                state: "scening",
                iconName: "sparkles",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "script.good_night",
                domain: .script,
                displayName: "Good Night",
                state: "off",
                iconName: "play.circle",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "lock.front_door",
                domain: .lock,
                displayName: "Front Door",
                state: "locked",
                iconName: "lock.fill",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "lock.garage_entry",
                domain: .lock,
                displayName: "Garage Entry",
                state: "unlocked",
                iconName: "lock.open.fill",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "switch.coffee",
                domain: .switch,
                displayName: "Coffee",
                state: "on",
                iconName: "lightswitch.on.fill",
                isAvailable: true,
                lastUpdated: nil
            ),
            HomeEntity(
                entityID: "switch.fan",
                domain: .switch,
                displayName: "Fan",
                state: "off",
                iconName: "lightswitch.off.fill",
                isAvailable: true,
                lastUpdated: nil
            )
        ]

        #expect(WidgetSharedStore.lightSnapshots(from: lights) == [
            WidgetLightSnapshot(
                entityID: "light.a_lamp",
                displayName: "A Lamp",
                isOn: true,
                brightnessPercentage: 50,
                areaName: nil,
                deviceName: nil
            ),
            WidgetLightSnapshot(
                entityID: "light.z_lamp",
                displayName: "Z Lamp",
                isOn: false,
                brightnessPercentage: nil,
                areaName: nil,
                deviceName: nil
            )
        ])

        #expect(WidgetSharedStore.switchSnapshots(from: entities) == [
            WidgetSwitchSnapshot(
                entityID: "switch.coffee",
                displayName: "Coffee",
                isOn: true,
                systemImage: "lightswitch.on.fill",
                areaName: nil,
                deviceName: nil
            ),
            WidgetSwitchSnapshot(
                entityID: "switch.fan",
                displayName: "Fan",
                isOn: false,
                systemImage: "lightswitch.off.fill",
                areaName: nil,
                deviceName: nil
            )
        ])

        #expect(WidgetSharedStore.coverSnapshots(from: covers) == [
            WidgetCoverSnapshot(
                entityID: "cover.garage_door",
                displayName: "Garage Door",
                state: "closed",
                statusText: "Closed",
                systemImage: "door.garage.closed",
                isOpen: false,
                isClosed: true,
                isMoving: false,
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            ),
            WidgetCoverSnapshot(
                entityID: "cover.living_room_shades",
                displayName: "Living Room Shades",
                state: "open",
                statusText: "Open • 70%",
                systemImage: "window.shade.open",
                isOpen: true,
                isClosed: false,
                isMoving: false,
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            )
        ])

        #expect(WidgetSharedStore.fanSnapshots(from: fans) == [
            WidgetFanSnapshot(
                entityID: "fan.bedroom",
                displayName: "Bedroom Fan",
                isOn: true,
                statusText: "On • 50%",
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            ),
            WidgetFanSnapshot(
                entityID: "fan.office",
                displayName: "Office Fan",
                isOn: false,
                statusText: "Off",
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            )
        ])

        #expect(WidgetSharedStore.lockSnapshots(from: entities) == [
            WidgetLockSnapshot(
                entityID: "lock.front_door",
                displayName: "Front Door",
                state: "locked",
                statusText: "Locked",
                systemImage: "lock.fill",
                isLocked: true,
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            ),
            WidgetLockSnapshot(
                entityID: "lock.garage_entry",
                displayName: "Garage Entry",
                state: "unlocked",
                statusText: "Unlocked",
                systemImage: "lock.open.fill",
                isLocked: false,
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            )
        ])

        #expect(WidgetSharedStore.sensorSnapshots(from: sensors) == [
            WidgetSensorSnapshot(
                entityID: "sensor.battery",
                displayName: "Battery",
                valueText: "18%",
                subtitle: "Low Battery",
                systemImage: "battery.75percent",
                unit: "%",
                isNumeric: true,
                isAlerting: true,
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            ),
            WidgetSensorSnapshot(
                entityID: "sensor.temperature",
                displayName: "Temperature",
                valueText: "72.4°F",
                subtitle: "Temperature",
                systemImage: "thermometer.medium",
                unit: "°F",
                isNumeric: true,
                isAlerting: false,
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            )
        ])

        #expect(WidgetSharedStore.presenceSnapshots(from: entities) == [
            WidgetPresenceSnapshot(
                entityID: "person.guest",
                displayName: "Guest",
                statusText: "Away",
                isHome: false,
                systemImage: "person",
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            ),
            WidgetPresenceSnapshot(
                entityID: "person.tyler",
                displayName: "Tyler",
                statusText: "Home",
                isHome: true,
                systemImage: "person.fill",
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            )
        ])

        #expect(WidgetSharedStore.actionSnapshots(from: entities) == [
            WidgetActionSnapshot(
                entityID: "scene.movie_time",
                displayName: "Movie Time",
                domain: "scene",
                systemImage: "sparkles",
                areaName: nil,
                deviceName: nil
            ),
            WidgetActionSnapshot(
                entityID: "script.good_night",
                displayName: "Good Night",
                domain: "script",
                systemImage: "play.circle",
                areaName: nil,
                deviceName: nil
            )
        ])

        let contextualLightSnapshots = WidgetSharedStore.lightSnapshots(
            from: lights,
            contextForEntityID: { entityID in
                entityID == "light.a_lamp"
                    ? WidgetEntityContext(areaName: "Bedroom", deviceName: "Hue Bulb")
                    : .empty
            }
        )
        #expect(contextualLightSnapshots.first?.areaName == "Bedroom")
        #expect(contextualLightSnapshots.first?.deviceName == "Hue Bulb")
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

    @MainActor
    @Test func connectionSettingsPersistsServerRoutingMetadata() throws {
        let suiteName = "com.tyler.Homestead.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tokenStore = InMemoryHAOAuthTokenStore()
        let settings = HAConnectionSettings(
            baseURL: "https://home.example.com",
            defaults: defaults,
            tokenStore: tokenStore
        )
        settings.internalURL = "http://homeassistant.local:8123"
        settings.externalURL = "https://home.example.com"
        settings.homeNetworkName = "Home Wi-Fi"

        let restoredSettings = HAConnectionSettings(
            defaults: defaults,
            tokenStore: tokenStore
        )

        #expect(restoredSettings.baseURL == "https://home.example.com")
        #expect(restoredSettings.internalURL == "http://homeassistant.local:8123")
        #expect(restoredSettings.externalURL == "https://home.example.com")
        #expect(restoredSettings.homeNetworkName == "Home Wi-Fi")
    }

    @Test func connectionRouteResolverPrefersInternalRouteOnHomeNetwork() {
        let settings = HAConnectionRoutingSettingsSnapshot(
            baseURLString: "https://home.example.com",
            internalURLString: "http://homeassistant.local:8123",
            externalURLString: "https://remote.example.com",
            homeNetworkName: "Home Wi-Fi"
        )

        let selection = HAConnectionRouteResolver.resolve(
            settings: settings,
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: true)
        )

        #expect(selection.authenticationBaseURLString == "https://home.example.com")
        #expect(selection.candidates.map(\.route) == [.internalURL, .externalURL, .current])
        #expect(selection.candidates.map(\.baseURLString) == [
            "http://homeassistant.local:8123",
            "https://remote.example.com",
            "https://home.example.com"
        ])
    }

    @Test func connectionRouteResolverUsesExternalRouteAwayFromHomeAndFallsBackToCurrentURL() {
        let settings = HAConnectionRoutingSettingsSnapshot(
            baseURLString: "https://home.example.com",
            internalURLString: "http://homeassistant.local:8123",
            externalURLString: "https://remote.example.com",
            homeNetworkName: "Home Wi-Fi"
        )

        let selection = HAConnectionRouteResolver.resolve(
            settings: settings,
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: false)
        )

        #expect(selection.candidates.map(\.route) == [.externalURL, .current])
        #expect(selection.candidates.map(\.baseURLString) == [
            "https://remote.example.com",
            "https://home.example.com"
        ])
    }

    @Test func routedConnectionConfigurationKeepsOAuthServerAsDataSourceIdentity() {
        let oauthConfiguration = HAConnectionConfiguration(
            baseURLString: "https://home.example.com",
            accessToken: "access-token"
        )
        let routedConfiguration = oauthConfiguration.routed(to: "http://homeassistant.local:8123")

        #expect(routedConfiguration.baseURLString == "http://homeassistant.local:8123")
        #expect(routedConfiguration.tokenRefreshBaseURLString == "https://home.example.com")
        #expect(routedConfiguration.dataSourceID == oauthConfiguration.dataSourceID)
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
    @Test func nativeNotificationAuthorizationStatusSeparatesAllowedAndRequestableStates() {
        #expect(NativeNotificationAuthorizationStatus.notDetermined.canRequestInApp)
        #expect(!NativeNotificationAuthorizationStatus.denied.canRequestInApp)
        #expect(!NativeNotificationAuthorizationStatus.authorized.canRequestInApp)

        #expect(!NativeNotificationAuthorizationStatus.notDetermined.isAllowed)
        #expect(!NativeNotificationAuthorizationStatus.denied.isAllowed)
        #expect(NativeNotificationAuthorizationStatus.authorized.isAllowed)
        #expect(NativeNotificationAuthorizationStatus.provisional.isAllowed)
        #expect(NativeNotificationAuthorizationStatus.ephemeral.isAllowed)
    }

    @MainActor
    @Test func nativeNotificationServiceRefreshesPermissionStatus() async {
        let expectedStatus = NativeNotificationStatusSnapshot(
            authorizationStatus: .denied,
            alertSetting: .disabled,
            soundSetting: .disabled,
            badgeSetting: .enabled
        )
        let client = StubNativeNotificationPermissionClient(currentStatus: expectedStatus)
        let service = NativeNotificationService(client: client)

        await service.refreshAuthorizationStatus()

        #expect(service.status == expectedStatus)
        #expect(service.lastErrorMessage == nil)
        #expect(client.currentStatusCallCount == 1)
    }

    @MainActor
    @Test func nativeNotificationServiceRequestsPermissionThenRefreshesStatus() async {
        let expectedStatus = NativeNotificationStatusSnapshot(
            authorizationStatus: .authorized,
            alertSetting: .enabled,
            soundSetting: .enabled,
            badgeSetting: .enabled
        )
        let client = StubNativeNotificationPermissionClient(currentStatus: expectedStatus)
        let service = NativeNotificationService(client: client)

        await service.requestAuthorization()

        #expect(service.status == expectedStatus)
        #expect(service.lastErrorMessage == nil)
        #expect(client.didRequestAuthorization)
        #expect(client.currentStatusCallCount == 1)
    }

    @MainActor
    @Test func nativeNotificationServicePresentsNotificationRequests() async throws {
        let client = StubNativeNotificationPermissionClient(currentStatus: .unknown)
        let service = NativeNotificationService(client: client)
        let request = NativeNotificationRequest(
            identifier: "notification-1",
            title: "Laundry",
            body: "Washer finished",
            userInfo: ["source": "home_assistant"]
        )

        try await service.presentNotification(request)

        #expect(client.presentedNotifications == [request])
    }

    @MainActor
    @Test func nativePermissionStatusSeparatesAllowedAndRequestableStates() {
        #expect(NativeCapabilityAuthorizationStatus.notDetermined.canRequestInApp)
        #expect(!NativeCapabilityAuthorizationStatus.denied.canRequestInApp)
        #expect(!NativeCapabilityAuthorizationStatus.allowed.canRequestInApp)

        #expect(NativeCapabilityAuthorizationStatus.allowed.isAllowed)
        #expect(NativeCapabilityAuthorizationStatus.limited.isAllowed)
        #expect(!NativeCapabilityAuthorizationStatus.managedBySystem.isAllowed)
    }

    @MainActor
    @Test func nativePermissionServiceRefreshesPlatformStatus() async {
        let expectedStatus = NativePermissionStatusSnapshot(
            camera: .denied,
            location: .allowed,
            localNetwork: .managedBySystem
        )
        let client = StubNativePermissionClient(currentStatus: expectedStatus)
        let service = NativePermissionService(client: client)

        await service.refreshStatus()

        #expect(service.status == expectedStatus)
        #expect(service.lastErrorMessage == nil)
        #expect(client.currentStatusCallCount == 1)
    }

    @MainActor
    @Test func nativePermissionServiceRequestsCameraAndLocationThenRefreshesStatus() async {
        let client = StubNativePermissionClient(
            currentStatus: NativePermissionStatusSnapshot(
                camera: .notDetermined,
                location: .notDetermined,
                localNetwork: .managedBySystem
            ),
            requestedCameraStatus: .allowed,
            requestedLocationStatus: .denied
        )
        let service = NativePermissionService(client: client)

        await service.requestCameraAccess()
        await service.requestLocationAccess()

        #expect(service.status.camera == .allowed)
        #expect(service.status.location == .denied)
        #expect(service.status.localNetwork == .managedBySystem)
        #expect(service.lastErrorMessage == nil)
        #expect(client.didRequestCameraAccess)
        #expect(client.didRequestLocationAccess)
        #expect(client.currentStatusCallCount == 2)
    }

    @MainActor
    @Test func serviceConnectionRegistersWebSocketNotificationsAndSubscribes() async throws {
        let store = InMemoryHAMobileAppRegistrationStore()
        let mobileAppClient = StubHAMobileAppClient(
            registrationResponse: HAMobileAppRegistrationResponseDTO(
                cloudhookURL: nil,
                remoteUIURL: nil,
                secret: nil,
                webhookID: "webhook-created"
            )
        )
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: mobileAppClient,
            mobileAppRegistrationStore: store,
            nativeNotificationService: NativeNotificationService(
                client: StubNativeNotificationPermissionClient(currentStatus: .unknown)
            ),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(
                    credential: testCredential(accessToken: "token-a")
                )
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")

        let savedRegistration = try #require(try store.readRegistration())
        #expect(savedRegistration.supportsWebSocketNotifications == true)
        #expect(mobileAppClient.lastRegistrationRequest?.appData?["push_websocket_channel"]?.boolValue == true)
        #expect(webSocketClient.mobileAppPushNotificationSubscription?.webhookID == "webhook-created")
        #expect(webSocketClient.mobileAppPushNotificationSubscription?.supportConfirm == true)
        #expect(service.mobileAppPushNotificationState.isSubscribed)
    }

    @MainActor
    @Test func servicePresentsAndConfirmsMobileAppPushNotificationEvents() async throws {
        let configuration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let store = InMemoryHAMobileAppRegistrationStore(
            registration: HAMobileAppRegistrationInfo(
                serverIdentifier: configuration.dataSourceID,
                deviceID: "device-a",
                appVersion: "1.0",
                deviceName: "Test Phone",
                webhookID: "webhook-a",
                supportsWebSocketNotifications: true
            )
        )
        let nativeClient = StubNativeNotificationPermissionClient(currentStatus: .unknown)
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: store,
            nativeNotificationService: NativeNotificationService(client: nativeClient),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(
                    credential: testCredential(accessToken: "token-a")
                )
            )
        )

        await service.connect(baseURLString: configuration.baseURLString)
        await webSocketClient.emitMobileAppPushNotification(
            HAMobileAppPushNotificationEventDTO(
                message: "Washer finished",
                title: "Laundry",
                hassConfirmID: "confirm-123",
                data: nil
            )
        )

        let presentedNotification = try #require(nativeClient.presentedNotifications.first)
        #expect(presentedNotification.title == "Laundry")
        #expect(presentedNotification.body == "Washer finished")
        #expect(webSocketClient.mobileAppPushNotificationConfirmations.count == 1)
        #expect(webSocketClient.mobileAppPushNotificationConfirmations.first?.webhookID == "webhook-a")
        #expect(webSocketClient.mobileAppPushNotificationConfirmations.first?.confirmID == "confirm-123")
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
    @Test func serviceConnectionUsesResolvedInternalRouteAndPreservesServerIdentity() async throws {
        let baseURLString = "https://home.example.com"
        let internalURLString = "http://homeassistant.local:8123"
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: baseURLString, accessToken: "route-access")
        )
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore),
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: true)
        )
        let settings = HAConnectionSettings(
            baseURL: baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        settings.internalURL = internalURLString
        settings.externalURL = "https://remote.example.com"
        settings.homeNetworkName = "Home Wi-Fi"

        await service.refreshAuthState()
        await service.connect(settings: settings)

        let connectedConfiguration = try #require(webSocketClient.lastConnectConfiguration)
        #expect(connectedConfiguration.baseURLString == internalURLString)
        #expect(connectedConfiguration.tokenRefreshBaseURLString == baseURLString)
        #expect(connectedConfiguration.dataSourceID == HAConnectionConfiguration(
            baseURLString: baseURLString,
            accessToken: "route-access"
        ).dataSourceID)
        #expect(service.activeRouteSummary?.route == .internalURL)
        #expect(service.connectionStatus == .connected)
    }

    @MainActor
    @Test func serviceConnectionFallsBackFromInternalRouteToExternalRoute() async throws {
        let baseURLString = "https://home.example.com"
        let internalURLString = "http://homeassistant.local:8123"
        let externalURLString = "https://remote.example.com"
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: baseURLString, accessToken: "route-access")
        )
        let webSocketClient = StubHAWebSocketClient()
        webSocketClient.connectErrorsByBaseURL[internalURLString] = HAWebSocketError.transportFailure("Internal route unavailable.")
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore),
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: true)
        )
        let settings = HAConnectionSettings(
            baseURL: baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        settings.internalURL = internalURLString
        settings.externalURL = externalURLString
        settings.homeNetworkName = "Home Wi-Fi"

        await service.refreshAuthState()
        await service.connect(settings: settings)

        #expect(webSocketClient.connectConfigurations.map(\.baseURLString) == [
            internalURLString,
            externalURLString
        ])
        #expect(webSocketClient.lastConnectConfiguration?.baseURLString == externalURLString)
        #expect(service.activeRouteSummary == HAConnectionRouteSummary(
            route: .externalURL,
            baseURLString: externalURLString
        ))
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
    @Test func serviceRefreshLoadsHomeAssistantServerConfiguration() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "config-access"))
        let webSocketClient = StubHAWebSocketClient()
        webSocketClient.config = HAConfigDTO(
            version: "2026.6.0",
            locationName: "Home",
            timeZone: "America/Chicago",
            internalURL: "http://homeassistant.local:8123",
            externalURL: "https://home.example.com",
            state: "RUNNING",
            configSource: "storage",
            unitSystem: nil
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        await service.refreshServerConfiguration()

        #expect(service.serverConfiguration?.homeAssistantVersion == "2026.6.0")
        #expect(service.serverConfiguration?.internalURL == "http://homeassistant.local:8123")
        #expect(service.serverConfiguration?.externalURL == "https://home.example.com")
        if case .loaded = service.serverConfigurationStatus {
            // Expected loaded server config status.
        } else {
            Issue.record("Expected loaded server config status.")
        }
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
    @Test func automationToggleUsesHomeAssistantAutomationDomain() async throws {
        let automation = HAEntityDTO(
            entityID: "automation.good_night",
            state: "on",
            attributes: ["friendly_name": .string("Good Night")]
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([automation])
        let webSocketClient = StubHAWebSocketClient(states: [automation])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "automation-access"))
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        stateStore.applySnapshot([automation])

        await service.toggleAutomation(entityID: "automation.good_night")

        #expect(stateStore.pendingCommand(for: "automation.good_night")?.expectedState == "off")
        #expect(webSocketClient.callServiceInvocations.last?.domain == "automation")
        #expect(webSocketClient.callServiceInvocations.last?.service == "turn_off")
    }

    @MainActor
    @Test func updateActionsUseOfficialHomeAssistantUpdateServices() async throws {
        let update = HAEntityDTO(
            entityID: "update.home_assistant_core_update",
            state: "on",
            attributes: [
                "friendly_name": .string("Home Assistant Core"),
                "installed_version": .string("2026.6.0"),
                "latest_version": .string("2026.6.1")
            ]
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([update])
        let webSocketClient = StubHAWebSocketClient(states: [update])
        webSocketClient.serviceRegistry = HAServiceRegistry(domains: [
            "update": [
                "install": HAServiceDescription(name: "Install"),
                "skip": HAServiceDescription(name: "Skip"),
                "clear_skipped": HAServiceDescription(name: "Clear skipped")
            ]
        ])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "update-access"))
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil {
            service.serviceRegistry.hasLoaded
        }
        stateStore.applySnapshot([update])

        await service.installUpdate(
            entityID: "update.home_assistant_core_update",
            backup: true,
            version: "2026.6.1"
        )
        await service.skipUpdate(entityID: "update.home_assistant_core_update")
        await service.clearSkippedUpdate(entityID: "update.home_assistant_core_update")

        #expect(webSocketClient.callServiceInvocations.map(\.domain) == ["update", "update", "update"])
        #expect(webSocketClient.callServiceInvocations.map(\.service) == ["install", "skip", "clear_skipped"])
        #expect(webSocketClient.callServiceInvocations[0].entityID == "update.home_assistant_core_update")
        #expect(webSocketClient.callServiceInvocations[0].serviceData["backup"] == .bool(true))
        #expect(webSocketClient.callServiceInvocations[0].serviceData["version"] == .string("2026.6.1"))
        #expect(webSocketClient.callServiceInvocations[1].serviceData.isEmpty)
        #expect(webSocketClient.callServiceInvocations[2].serviceData.isEmpty)
    }

    @MainActor
    @Test func updateActionServiceCallsAreGatedByLoadedServiceRegistry() async throws {
        let update = HAEntityDTO(
            entityID: "update.home_assistant_core_update",
            state: "on",
            attributes: ["friendly_name": .string("Home Assistant Core")]
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([update])
        let webSocketClient = StubHAWebSocketClient(states: [update])
        webSocketClient.serviceRegistry = HAServiceRegistry(domains: [
            "update": [
                "skip": HAServiceDescription(name: "Skip")
            ]
        ])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "update-access"))
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil {
            service.serviceRegistry.hasLoaded
        }
        stateStore.applySnapshot([update])

        await service.installUpdate(entityID: "update.home_assistant_core_update", backup: true)

        #expect(webSocketClient.callServiceInvocations.isEmpty)
        #expect(service.serviceFeedback?.title == "Action unavailable")
        #expect(service.serviceFeedback?.message?.contains("update.install") == true)
    }

    @Test func updateSettingsActionAvailabilityMatchesStatusAndServiceCatalog() throws {
        let available = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.core",
            state: "on"
        )))
        let skipped = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.router",
            state: "off",
            attributes: ["skipped_version": .string("7.2")]
        )))
        let availableServices: Set<String> = [
            "update.install",
            "update.skip",
            "update.clear_skipped"
        ]

        let availableActions = HAUpdateSettingsActionAvailability.make(
            update: available,
            serviceActionAvailable: { availableServices.contains("\($0).\($1)") }
        )
        let skippedActions = HAUpdateSettingsActionAvailability.make(
            update: skipped,
            serviceActionAvailable: { availableServices.contains("\($0).\($1)") }
        )
        let missingInstallActions = HAUpdateSettingsActionAvailability.make(
            update: available,
            serviceActionAvailable: { $1 != "install" }
        )

        #expect(availableActions.canInstall)
        #expect(availableActions.canSkip)
        #expect(!availableActions.canClearSkipped)
        #expect(!skippedActions.canInstall)
        #expect(!skippedActions.canSkip)
        #expect(skippedActions.canClearSkipped)
        #expect(!missingInstallActions.canInstall)
        #expect(missingInstallActions.installUnavailableReason?.contains("not available") == true)
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
    @Test func serviceFetchesLogbookWithOAuthConfigurationAndMapsEntityTitles() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "logbook-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["friendly_name": .string("Kitchen Pendant")]
            )
        ])
        let httpClient = StubHAHTTPClient(logbookEntries: [
            HALogbookEntryDTO(
                when: try testDate("2026-06-05T15:30:00Z"),
                name: "Kitchen",
                message: "turned on",
                domain: "light",
                entityID: "light.kitchen"
            )
        ])
        let service = HomeAssistantService(
            stateStore: stateStore,
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let request = HALogbookRequest(
            startDate: try testDate("2026-06-05T00:00:00Z"),
            endDate: try testDate("2026-06-06T00:00:00Z"),
            entityID: "light.kitchen"
        )

        let rows = try await service.fetchLogbook(settings: settings, request: request)

        #expect(httpClient.lastLogbookConfiguration?.accessToken == "logbook-access")
        #expect(httpClient.lastLogbookRequest == request)
        #expect(rows.map(\.title) == ["Kitchen Pendant"])
        #expect(rows.map(\.entityDomain) == [.light])
    }

    @MainActor
    @Test func serviceFetchesLogbookThroughResolvedExternalRoute() async throws {
        let baseURLString = "https://home.example.com"
        let externalURLString = "https://remote.example.com"
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: baseURLString, accessToken: "logbook-access")
        )
        let httpClient = StubHAHTTPClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore),
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: false)
        )
        let settings = HAConnectionSettings(
            baseURL: baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        settings.internalURL = "http://homeassistant.local:8123"
        settings.externalURL = externalURLString
        settings.homeNetworkName = "Home Wi-Fi"
        let request = HALogbookRequest(
            startDate: try testDate("2026-06-05T00:00:00Z"),
            endDate: nil,
            entityID: nil
        )

        _ = try await service.fetchLogbook(settings: settings, request: request)

        let configuration = try #require(httpClient.lastLogbookConfiguration)
        #expect(configuration.baseURLString == externalURLString)
        #expect(configuration.tokenRefreshBaseURLString == baseURLString)
        #expect(configuration.dataSourceID == HAConnectionConfiguration(
            baseURLString: baseURLString,
            accessToken: "logbook-access"
        ).dataSourceID)
    }

    @MainActor
    @Test func serviceRegistersMobileAppThroughResolvedExternalRoute() async throws {
        let baseURLString = "https://home.example.com"
        let externalURLString = "https://remote.example.com"
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: baseURLString, accessToken: "mobile-app-access")
        )
        let registrationStore = InMemoryHAMobileAppRegistrationStore()
        let mobileAppClient = StubHAMobileAppClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppClient: mobileAppClient,
            mobileAppRegistrationStore: registrationStore,
            authManager: HAOAuthManager(tokenStore: tokenStore),
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: false)
        )
        let settings = HAConnectionSettings(
            baseURL: baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        settings.internalURL = "http://homeassistant.local:8123"
        settings.externalURL = externalURLString
        settings.homeNetworkName = "Home Wi-Fi"

        await service.registerMobileApp(settings: settings)

        let registrationConfiguration = try #require(mobileAppClient.lastRegistrationConfiguration)
        #expect(registrationConfiguration.baseURLString == externalURLString)
        #expect(registrationConfiguration.dataSourceID == HAConnectionConfiguration(
            baseURLString: baseURLString,
            accessToken: "mobile-app-access"
        ).dataSourceID)
        #expect(try registrationStore.readRegistration()?.serverIdentifier == registrationConfiguration.dataSourceID)
    }

    @MainActor
    @Test func serviceFetchesHistoryWithOAuthConfigurationAndMapsSensorPresentation() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "history-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "71.2",
                attributes: [
                    "friendly_name": .string("Kitchen Temperature"),
                    "unit_of_measurement": .string("F"),
                    "device_class": .string("temperature")
                ]
            )
        ])
        let firstSampleDate = try testDate("2026-06-05T15:30:00Z")
        let httpClient = StubHAHTTPClient(
            historyResponse: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(
                        entityID: "sensor.kitchen_temperature",
                        state: "70",
                        lastChanged: firstSampleDate
                    )
                ]
            ])
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let request = HAHistoryRequest(
            startDate: try testDate("2026-06-05T15:00:00Z"),
            endDate: try testDate("2026-06-05T16:00:00Z"),
            entityID: "sensor.kitchen_temperature"
        )

        let series = try await service.fetchHistory(settings: settings, request: request, range: .oneHour)

        #expect(httpClient.lastHistoryConfiguration?.accessToken == "history-access")
        #expect(httpClient.lastHistoryRequest == request)
        #expect(series.displayName == "Kitchen Temperature")
        #expect(series.unit == "°F")
        #expect(series.samples.map(\.value) == [70])
    }

    @MainActor
    @Test func serviceFetchesTimelineWithOAuthConfigurationAndMapsBinarySensorPresentation() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "timeline-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "binary_sensor.front_door",
                state: "off",
                attributes: [
                    "friendly_name": .string("Front Door"),
                    "device_class": .string("door")
                ]
            )
        ])
        let httpClient = StubHAHTTPClient(
            historyResponse: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(
                        entityID: "binary_sensor.front_door",
                        state: "on",
                        lastChanged: try testDate("2026-06-05T15:30:00Z")
                    )
                ]
            ])
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let request = HAHistoryRequest(
            startDate: try testDate("2026-06-05T15:00:00Z"),
            endDate: try testDate("2026-06-05T16:00:00Z"),
            entityID: "binary_sensor.front_door"
        )

        let timeline = try await service.fetchTimeline(settings: settings, request: request, range: .oneHour)

        #expect(httpClient.lastHistoryConfiguration?.accessToken == "timeline-access")
        #expect(httpClient.lastHistoryRequest == request)
        #expect(timeline.displayName == "Front Door")
        #expect(timeline.entries.map(\.title) == ["Opened"])
    }

    @MainActor
    @Test func serviceFetchesTimelineWithOAuthConfigurationAndMapsLockPresentation() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "lock-timeline-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "lock.front_door",
                state: "locked",
                attributes: [
                    "friendly_name": .string("Front Door")
                ]
            )
        ])
        let httpClient = StubHAHTTPClient(
            historyResponse: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(
                        entityID: "lock.front_door",
                        state: "unlocked",
                        lastChanged: try testDate("2026-06-05T15:30:00Z")
                    )
                ]
            ])
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let request = HAHistoryRequest(
            startDate: try testDate("2026-06-05T15:00:00Z"),
            endDate: try testDate("2026-06-05T16:00:00Z"),
            entityID: "lock.front_door"
        )

        let timeline = try await service.fetchTimeline(settings: settings, request: request, range: .oneHour)

        #expect(httpClient.lastHistoryConfiguration?.accessToken == "lock-timeline-access")
        #expect(httpClient.lastHistoryRequest == request)
        #expect(timeline.displayName == "Front Door")
        #expect(timeline.entries.map(\.title) == ["Unlocked"])
    }

    @MainActor
    @Test func serviceFetchesTimelineWithOAuthConfigurationAndMapsDiscreteDetailDomainPresentation() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "cover-timeline-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "cover.garage_door",
                state: "closed",
                attributes: [
                    "friendly_name": .string("Garage Door"),
                    "device_class": .string("garage")
                ]
            ),
            HAEntityDTO(
                entityID: "person.tyler",
                state: "home",
                attributes: [
                    "friendly_name": .string("Tyler")
                ]
            )
        ])
        let httpClient = StubHAHTTPClient(
            historyResponse: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(
                        entityID: "cover.garage_door",
                        state: "open",
                        lastChanged: try testDate("2026-06-05T15:30:00Z")
                    )
                ]
            ])
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let coverRequest = HAHistoryRequest(
            startDate: try testDate("2026-06-05T15:00:00Z"),
            endDate: try testDate("2026-06-05T16:00:00Z"),
            entityID: "cover.garage_door"
        )

        let coverTimeline = try await service.fetchTimeline(settings: settings, request: coverRequest, range: .oneHour)

        #expect(httpClient.lastHistoryConfiguration?.accessToken == "cover-timeline-access")
        #expect(httpClient.lastHistoryRequest == coverRequest)
        #expect(coverTimeline.displayName == "Garage Door")
        #expect(coverTimeline.entries.map(\.title) == ["Opened"])
        #expect(coverTimeline.entries.map(\.systemImage) == ["door.garage.open"])

        httpClient.historyResponse = HAHistoryResponseDTO(series: [
            [
                HAHistoryStateDTO(
                    entityID: "person.tyler",
                    state: "work",
                    lastChanged: try testDate("2026-06-05T15:45:00Z")
                )
            ]
        ])
        let personRequest = HAHistoryRequest(
            startDate: try testDate("2026-06-05T15:00:00Z"),
            endDate: try testDate("2026-06-05T16:00:00Z"),
            entityID: "person.tyler"
        )

        let personTimeline = try await service.fetchTimeline(settings: settings, request: personRequest, range: .oneHour)

        #expect(httpClient.lastHistoryRequest == personRequest)
        #expect(personTimeline.displayName == "Tyler")
        #expect(personTimeline.entries.map(\.title) == ["At Work"])
    }

    @MainActor
    @Test func serviceFetchesDashboardHistoryUsingSixHourHistoryRequest() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "dashboard-history-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "71.2",
                attributes: [
                    "friendly_name": .string("Kitchen Temperature"),
                    "unit_of_measurement": .string("F"),
                    "device_class": .string("temperature")
                ]
            )
        ])
        let httpClient = StubHAHTTPClient(
            historyResponse: HAHistoryResponseDTO(series: [
                [
                    HAHistoryStateDTO(
                        entityID: "sensor.kitchen_temperature",
                        state: "70",
                        lastChanged: try testDate("2026-06-05T15:30:00Z")
                    )
                ]
            ])
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let endDate = try testDate("2026-06-05T16:00:00Z")
        let expectedRequest = HAHistoryRequest(
            startDate: try testDate("2026-06-05T10:00:00Z"),
            endDate: endDate,
            entityID: "sensor.kitchen_temperature"
        )

        let series = try await service.fetchDashboardHistory(
            settings: settings,
            entityID: "sensor.kitchen_temperature",
            endingAt: endDate
        )

        #expect(httpClient.lastHistoryConfiguration?.accessToken == "dashboard-history-access")
        #expect(httpClient.lastHistoryRequest == expectedRequest)
        #expect(series.range == .sixHours)
        #expect(series.displayName == "Kitchen Temperature")
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
    @Test func dashboardConfigurationAddEntityItemPersistsInitialCardSize() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.add("camera.driveway", size: .square)
        configuration.add("sensor.hallway_temperature")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.entityID) == ["camera.driveway", "sensor.hallway_temperature"])
        #expect(restoredConfiguration.items.map(\.resolvedCardSize) == [.square, .compact])
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
    @Test func dashboardConfigurationFeatureVisibilityPersistsOnEntityItem() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let itemID = configuration.add("light.kitchen")

        #expect(configuration.featureVisibility(forItemID: itemID) == .automatic)
        configuration.setFeatureVisibility(.hidden, forItemID: itemID)

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.first?.resolvedFeatureVisibility == .hidden)
        #expect(restoredConfiguration.featureVisibility(forItemID: itemID) == .hidden)

        restoredConfiguration.setFeatureVisibility(.automatic, forItemID: itemID)
        #expect(restoredConfiguration.items.first?.featureVisibility == nil)
        #expect(restoredConfiguration.featureVisibility(forItemID: itemID) == .automatic)
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
        #expect(restoredConfiguration.items.first?.displayNameOverride == nil)
        #expect(restoredConfiguration.entityDisplayNameOverride(for: "sensor.hallway_temperature") == "Hallway")

        restoredConfiguration.renameEntityItem(id: itemID, displayNameOverride: " ")
        #expect(restoredConfiguration.entityDisplayNameOverride(for: "sensor.hallway_temperature") == nil)
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
    @Test func dashboardConfigurationPersistsLargeCardSize() throws {
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
    @Test func generatedCameraCardsPreferSquarePreviewSize() {
        let camera = HAEntityState(
            homeEntity: HomeEntity(
                entityID: "camera.driveway",
                domain: .camera,
                displayName: "Driveway",
                state: "idle",
                iconName: "camera.fill",
                isAvailable: true,
                lastUpdated: nil
            )
        )

        #expect(DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: camera) == .square)
    }

    @MainActor
    @Test func generatedNumericSensorCardsPreferSquareHistorySize() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.hallway_temperature",
                state: "70.5",
                attributes: [
                    "friendly_name": .string("Hallway Temperature"),
                    "unit_of_measurement": .string("F"),
                    "device_class": .string("temperature")
                ]
            ),
            HAEntityDTO(entityID: "sensor.mode", state: "auto")
        ])

        let numericSensor = try #require(store.entityBox(for: "sensor.hallway_temperature"))
        let textSensor = try #require(store.entityBox(for: "sensor.mode"))

        #expect(DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: numericSensor) == .square)
        #expect(DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: textSensor) == .compact)
    }

    @MainActor
    @Test func dashboardAddCardPresentationGroupsFiltersAndSuggestsCardSizes() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: [
                    "friendly_name": .string("Kitchen Light"),
                    "brightness": .number(128)
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "71.5",
                attributes: [
                    "friendly_name": .string("Kitchen Temperature"),
                    "unit_of_measurement": .string("°F"),
                    "device_class": .string("temperature")
                ]
            ),
            HAEntityDTO(
                entityID: "camera.driveway",
                state: "idle",
                attributes: ["friendly_name": .string("Driveway Camera")]
            ),
            HAEntityDTO(
                entityID: "scene.movie_night",
                state: "scening",
                attributes: ["friendly_name": .string("Movie Night")]
            ),
            HAEntityDTO(
                entityID: "media_player.tv",
                state: "unavailable",
                attributes: ["friendly_name": .string("TV")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(entityID: "light.kitchen", deviceID: "kitchen-device", originalName: "Kitchen Light"),
                HAEntityRegistryDisplayDTO(entityID: "sensor.kitchen_temperature", deviceID: "kitchen-device", originalName: "Kitchen Temperature"),
                HAEntityRegistryDisplayDTO(entityID: "camera.driveway", deviceID: "driveway-device", originalName: "Driveway Camera"),
                HAEntityRegistryDisplayDTO(entityID: "scene.movie_night", deviceID: nil, originalName: "Movie Night"),
                HAEntityRegistryDisplayDTO(entityID: "media_player.tv", deviceID: "tv-device", originalName: "TV")
            ],
            devices: [
                HADeviceRegistryDTO(id: "kitchen-device", name: "Kitchen Hub"),
                HADeviceRegistryDTO(id: "driveway-device", name: "Driveway"),
                HADeviceRegistryDTO(id: "tv-device", name: "Living Room TV")
            ]
        )

        let groups = DashboardAddCardPresentation.makeCandidateGroups(
            entityBoxes: store.allEntityBoxes(),
            configuredEntityIDs: ["light.kitchen"],
            deviceGroups: store.entityIDGroupsByDevice,
            domainGroups: store.entityIDGroupsByDomain,
            displayNameForDeviceGroupedEntity: store.displayNameForDeviceGroupedEntity(entityID:),
            category: .all,
            searchText: "",
            includesUnavailable: false
        )
        let candidates = groups.flatMap(\.candidates)

        #expect(groups.map(\.title) == ["Driveway", "Kitchen Hub", "Other Entities"])
        #expect(candidates.map(\.entityID) == ["camera.driveway", "sensor.kitchen_temperature", "scene.movie_night"])
        #expect(candidates.first { $0.entityID == "sensor.kitchen_temperature" }?.recommendedSize == .square)
        #expect(candidates.first { $0.entityID == "camera.driveway" }?.recommendedSize == .square)
        #expect(candidates.first { $0.entityID == "scene.movie_night" }?.cardStyle == .action)

        let categories = DashboardAddCardPresentation.makeCategories(from: candidates)
        #expect(categories.map(\.title) == ["All", "Values", "Cameras", "Actions"])

        let categorySummaries = DashboardAddCardPresentation.makeCategorySummaries(from: candidates)
        #expect(categorySummaries.map(\.category.title) == ["All", "Values", "Cameras", "Actions"])
        #expect(categorySummaries.map(\.count) == [3, 1, 1, 1])

        let sensorChoices = DashboardAddCardPresentation.makeSizeChoices(
            for: try #require(store.entityBox(for: "sensor.kitchen_temperature"))
        )
        #expect(sensorChoices.map(\.size) == DashboardCardSize.allCases)
        #expect(sensorChoices.first { $0.size == .square }?.isRecommended == true)
        #expect(sensorChoices.first { $0.size == .square }?.summary == "Shows a 6-hour trend chart.")
        #expect(sensorChoices.first { $0.size == .compact }?.summary == "Shows name and current state.")

        let cameraChoices = DashboardAddCardPresentation.makeSizeChoices(
            for: try #require(store.entityBox(for: "camera.driveway"))
        )
        #expect(cameraChoices.first { $0.size == .square }?.isRecommended == true)
        #expect(cameraChoices.first { $0.size == .wide }?.summary == "Shows a live camera-style preview.")

        let lightChoices = DashboardAddCardPresentation.makeSizeChoices(
            for: try #require(store.entityBox(for: "light.kitchen"))
        )
        #expect(lightChoices.first { $0.size == .square }?.summary == "Includes brightness controls.")
        #expect(lightChoices.first { $0.size == .square }?.featureTitles == ["Brightness"])
    }

    @MainActor
    @Test func dashboardAddCardPresentationFiltersByCardTypeSearchAndAvailability() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on", attributes: ["friendly_name": .string("Kitchen Light")]),
            HAEntityDTO(entityID: "sensor.temperature", state: "72", attributes: ["friendly_name": .string("Temperature")]),
            HAEntityDTO(entityID: "media_player.tv", state: "unavailable", attributes: ["friendly_name": .string("TV")])
        ])

        let valueGroups = DashboardAddCardPresentation.makeCandidateGroups(
            entityBoxes: store.allEntityBoxes(),
            configuredEntityIDs: [],
            deviceGroups: [],
            domainGroups: store.entityIDGroupsByDomain,
            displayNameForDeviceGroupedEntity: { _ in nil },
            category: .style(.value),
            searchText: "",
            includesUnavailable: true
        )
        #expect(valueGroups.flatMap(\.candidates).map(\.entityID) == ["sensor.temperature"])

        let searchGroups = DashboardAddCardPresentation.makeCandidateGroups(
            entityBoxes: store.allEntityBoxes(),
            configuredEntityIDs: [],
            deviceGroups: [],
            domainGroups: store.entityIDGroupsByDomain,
            displayNameForDeviceGroupedEntity: { _ in nil },
            category: .all,
            searchText: "Media",
            includesUnavailable: true
        )
        #expect(searchGroups.map(\.title) == ["Media Players"])
        #expect(searchGroups.flatMap(\.candidates).map(\.entityID) == ["media_player.tv"])

        let configuredUnavailableGroups = DashboardAddCardPresentation.makeCandidateGroups(
            entityBoxes: store.allEntityBoxes(),
            configuredEntityIDs: ["media_player.tv"],
            deviceGroups: [],
            domainGroups: store.entityIDGroupsByDomain,
            displayNameForDeviceGroupedEntity: { _ in nil },
            category: .all,
            searchText: "",
            includesUnavailable: true
        )
        #expect(configuredUnavailableGroups.flatMap(\.candidates).map(\.entityID) == ["light.kitchen", "sensor.temperature"])

        let availableOnlyGroups = DashboardAddCardPresentation.makeCandidateGroups(
            entityBoxes: store.allEntityBoxes(),
            configuredEntityIDs: [],
            deviceGroups: [],
            domainGroups: store.entityIDGroupsByDomain,
            displayNameForDeviceGroupedEntity: { _ in nil },
            category: .all,
            searchText: "",
            includesUnavailable: false
        )
        #expect(availableOnlyGroups.flatMap(\.candidates).map(\.entityID) == ["light.kitchen", "sensor.temperature"])
    }

    @Test func entityDisplayNameResolverShortensNamesOnlyInMatchingAreaContext() {
        #expect(EntityDisplayNameResolver.contextualDisplayName("Primary Bedroom Light", areaName: "Primary Bedroom") == "Light")
        #expect(EntityDisplayNameResolver.contextualDisplayName("Primary Bedroom - Lamp", areaName: "Primary Bedroom") == "Lamp")
        #expect(EntityDisplayNameResolver.contextualDisplayName("Kitchen Island", areaName: "Primary Bedroom") == "Kitchen Island")
        #expect(EntityDisplayNameResolver.contextualDisplayName("Primary Bedroom", areaName: "Primary Bedroom") == "Primary Bedroom")

        #expect(EntityDisplayNameResolver.displayName(
            canonicalName: "Primary Bedroom Light",
            overrideName: nil,
            contextualAreaName: "Primary Bedroom"
        ) == "Light")
        #expect(EntityDisplayNameResolver.displayName(
            canonicalName: "Kitchen Island",
            overrideName: nil,
            contextualAreaName: "Primary Bedroom"
        ) == nil)
        #expect(EntityDisplayNameResolver.displayName(
            canonicalName: "Primary Bedroom Light",
            overrideName: "Bedside Lamp",
            contextualAreaName: "Primary Bedroom"
        ) == "Bedside Lamp")
    }

    @Test func entityDisplayNameResolverShortensCameraSuffixWhenUseful() {
        #expect(EntityDisplayNameResolver.cameraDisplayName("Front Door Camera") == "Front Door")
        #expect(EntityDisplayNameResolver.cameraDisplayName("Living Room - Camera") == "Living Room")
        #expect(EntityDisplayNameResolver.cameraDisplayName("Camera") == "Camera")
        #expect(EntityDisplayNameResolver.cameraDisplayName("Driveway Cam") == "Driveway Cam")
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
    @Test func dashboardConfigurationMovesReorderGroupsIndependently() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.addSummaryChip(kind: .lights)
        configuration.addHeader(title: "Downstairs")
        configuration.add("light.kitchen")
        configuration.addSummaryChip(kind: .security)
        configuration.add("sensor.hallway_temperature")

        configuration.moveItems(in: .chips, from: IndexSet(integer: 1), to: 0)

        #expect(configuration.items.map(\.type) == [.chip, .header, .entity, .chip, .entity])
        #expect(configuration.items[0].summaryKind == .security)
        #expect(configuration.items[3].summaryKind == .lights)

        configuration.moveItems(in: .cards, from: IndexSet(integer: 0), to: 3)

        #expect(configuration.items.map(\.type) == [.chip, .entity, .entity, .chip, .header])
        #expect(configuration.items[0].summaryKind == .security)
        #expect(configuration.items[1].entityID == "light.kitchen")
        #expect(configuration.items[2].entityID == "sensor.hallway_temperature")
        #expect(configuration.items[3].summaryKind == .lights)
        #expect(configuration.items[4].resolvedTitle == "Downstairs")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.chip, .entity, .entity, .chip, .header])
        #expect(restoredConfiguration.items[0].summaryKind == .security)
        #expect(restoredConfiguration.items[3].summaryKind == .lights)
        #expect(restoredConfiguration.items[4].resolvedTitle == "Downstairs")
    }

    @MainActor
    @Test func dashboardConfigurationMovesVisibleGridItemsAndPreservesChipSlots() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        configuration.addSummaryChip(kind: .lights)
        let headerID = configuration.addHeader(title: "Downstairs")
        let lightID = configuration.add("light.kitchen")
        configuration.addSummaryChip(kind: .security)
        let sensorID = configuration.add("sensor.hallway_temperature")

        configuration.moveVisibleGridItem(
            id: sensorID,
            before: headerID,
            visibleGridItemIDs: [headerID, lightID, sensorID]
        )

        #expect(configuration.items.map(\.type) == [.chip, .entity, .header, .chip, .entity])
        #expect(configuration.items[0].summaryKind == .lights)
        #expect(configuration.items[1].entityID == "sensor.hallway_temperature")
        #expect(configuration.items[2].resolvedTitle == "Downstairs")
        #expect(configuration.items[3].summaryKind == .security)
        #expect(configuration.items[4].entityID == "light.kitchen")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.chip, .entity, .header, .chip, .entity])
        #expect(restoredConfiguration.items[1].entityID == "sensor.hallway_temperature")
        #expect(restoredConfiguration.items[3].summaryKind == .security)
    }

    @MainActor
    @Test func dashboardConfigurationMovesVisibleChipItemsAndPreservesGridSlots() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let lightsID = configuration.addSummaryChip(kind: .lights)
        configuration.addHeader(title: "Downstairs")
        configuration.add("light.kitchen")
        let securityID = configuration.addSummaryChip(kind: .security)
        configuration.add("sensor.hallway_temperature")

        configuration.moveVisibleChipItem(
            id: securityID,
            before: lightsID,
            visibleChipItemIDs: [lightsID, securityID]
        )

        #expect(configuration.items.map(\.type) == [.chip, .header, .entity, .chip, .entity])
        #expect(configuration.items[0].summaryKind == .security)
        #expect(configuration.items[1].resolvedTitle == "Downstairs")
        #expect(configuration.items[2].entityID == "light.kitchen")
        #expect(configuration.items[3].summaryKind == .lights)
        #expect(configuration.items[4].entityID == "sensor.hallway_temperature")

        let restoredConfiguration = DashboardConfiguration(defaults: defaults)
        #expect(restoredConfiguration.items.map(\.type) == [.chip, .header, .entity, .chip, .entity])
        #expect(restoredConfiguration.items[0].summaryKind == .security)
        #expect(restoredConfiguration.items[3].summaryKind == .lights)
    }

    @MainActor
    @Test func dashboardConfigurationMovesVisibleGridItemsWithoutMovingHiddenConfiguredItems() throws {
        let suiteName = "com.tyler.Homestead.dashboard.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DashboardConfiguration(defaults: defaults)
        let headerID = configuration.addHeader(title: "Downstairs")
        let lightID = configuration.add("light.kitchen")
        configuration.add("sensor.hidden_temperature")
        let sensorID = configuration.add("sensor.hallway_temperature")

        configuration.moveVisibleGridItem(
            id: sensorID,
            before: lightID,
            visibleGridItemIDs: [headerID, lightID, sensorID]
        )

        #expect(configuration.items.map(\.type) == [.header, .entity, .entity, .entity])
        #expect(configuration.items[0].resolvedTitle == "Downstairs")
        #expect(configuration.items[1].entityID == "sensor.hallway_temperature")
        #expect(configuration.items[2].entityID == "sensor.hidden_temperature")
        #expect(configuration.items[3].entityID == "light.kitchen")
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
                featureVisibility: .hidden,
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
                featureVisibility: nil,
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
        #expect(lightCard.featureVisibility == .hidden)
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

    @Test func dashboardEntityDetailRouteUsesStableSourceIdentity() {
        let cardID = UUID()
        let sourceID = "dashboard-card-\(cardID.uuidString)"
        let route = DashboardEntityDetailRoute(
            entityID: "light.kitchen",
            sourceID: sourceID
        )

        #expect(route.entityID == "light.kitchen")
        #expect(route.sourceID == sourceID)
        #expect(route.id == "\(sourceID)-light.kitchen")
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
                lastUpdated: try testDate("2026-05-20T10:00:00.000000+00:00")
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
                lastUpdated: try testDate("2026-05-20T10:00:00.000000+00:00")
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
    @Test func dashboardConfigurationOwnsDeviceDashboardMembership() throws {
        let suiteName = "com.tyler.Homestead.dashboard.membership.tests.\(UUID().uuidString)"
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
        #expect(kitchen?.activeDomainCounts[.light] == 1)
        #expect(kitchen?.topDomains == [.light, .sensor])
        #expect(kitchen?.domainChips == [
            DashboardAreaDomainChip(domain: .light, isActive: true),
            DashboardAreaDomainChip(domain: .sensor, isActive: false)
        ])
        #expect(office?.unavailableCount == 1)
    }

    @MainActor
    @Test func areaBuilderPrioritizesActiveDomainChipsBeforeInactiveDomains() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.living_room_lamp", state: "off"),
            HAEntityDTO(entityID: "sensor.living_room_temperature", state: "72"),
            HAEntityDTO(entityID: "media_player.living_room_tv", state: "playing"),
            HAEntityDTO(entityID: "camera.living_room", state: "idle")
        ])

        let areaNames = [
            "light.living_room_lamp": "Living Room",
            "sensor.living_room_temperature": "Living Room",
            "media_player.living_room_tv": "Living Room",
            "camera.living_room": "Living Room"
        ]

        let area = DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaNameForEntityID: { areaNames[$0] }
        ).first

        #expect(area?.domainChips.prefix(3).map(\.domain) == [.mediaPlayer, .light, .sensor])
        #expect(area?.domainChips.first?.isActive == true)
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
    @Test func areaBuilderGroupsAreasIntoFloorSectionsWhenMultipleFloorsExist() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "off", attributes: ["friendly_name": .string("Kitchen Light")]),
            HAEntityDTO(entityID: "light.bedroom", state: "on", attributes: ["friendly_name": .string("Bedroom Light")]),
            HAEntityDTO(entityID: "light.garage", state: "off", attributes: ["friendly_name": .string("Garage Light")]),
            HAEntityDTO(entityID: "light.loose", state: "off", attributes: ["friendly_name": .string("Loose Light")])
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(entityID: "light.kitchen", deviceID: nil, areaID: "kitchen", originalName: "Kitchen Light"),
                HAEntityRegistryDisplayDTO(entityID: "light.bedroom", deviceID: nil, areaID: "bedroom", originalName: "Bedroom Light"),
                HAEntityRegistryDisplayDTO(entityID: "light.garage", deviceID: nil, areaID: "garage", originalName: "Garage Light")
            ],
            devices: [],
            areas: [
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen", floorID: "main"),
                HAAreaRegistryDTO(id: "bedroom", name: "Bedroom", floorID: "upstairs"),
                HAAreaRegistryDTO(id: "garage", name: "Garage")
            ],
            floors: [
                HAFloorRegistryDTO(id: "main", name: "Main Floor", level: 0),
                HAFloorRegistryDTO(id: "upstairs", name: "Upstairs", level: 1)
            ]
        )

        let areas = DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaContextForEntityID: store.areaContext(for:)
        )
        let sections = DashboardAreaBuilder.buildSections(from: areas)

        #expect(sections.map(\.title) == ["Main Floor", "Upstairs", "Other Areas"])
        #expect(sections[0].areas.map(\.name) == ["Kitchen"])
        #expect(sections[1].areas.map(\.name) == ["Bedroom"])
        #expect(sections[2].areas.map(\.name) == ["Garage", "Unassigned"])
    }

    @MainActor
    @Test func areaBuilderSuppressesFloorSectionForSingleFloorHome() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "off", attributes: ["friendly_name": .string("Kitchen Light")]),
            HAEntityDTO(entityID: "light.living_room", state: "off", attributes: ["friendly_name": .string("Living Room Light")])
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(entityID: "light.kitchen", deviceID: nil, areaID: "kitchen", originalName: "Kitchen Light"),
                HAEntityRegistryDisplayDTO(entityID: "light.living_room", deviceID: nil, areaID: "living_room", originalName: "Living Room Light")
            ],
            devices: [],
            areas: [
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen", floorID: "main"),
                HAAreaRegistryDTO(id: "living_room", name: "Living Room", floorID: "main")
            ],
            floors: [
                HAFloorRegistryDTO(id: "main", name: "Main Floor", level: 0)
            ]
        )

        let areas = DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaContextForEntityID: store.areaContext(for:)
        )
        let sections = DashboardAreaBuilder.buildSections(from: areas)

        #expect(sections.count == 1)
        #expect(sections.first?.title == nil)
        #expect(sections.first?.areas.map(\.name) == ["Kitchen", "Living Room"])
    }

    @MainActor
    @Test func entityPresentationCentralizesDomainActionsAndDetails() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on"),
            HAEntityDTO(entityID: "cover.shades", state: "open"),
            HAEntityDTO(entityID: "scene.movie_night", state: "scening"),
            HAEntityDTO(entityID: "script.good_morning", state: "off"),
            HAEntityDTO(entityID: "automation.good_night", state: "on"),
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
        let automationPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "automation.good_night"))
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
        #expect(automationPresentation.primaryAction == .toggleAutomation)
        #expect(automationPresentation.primaryServiceIntent == .stateToggle(domain: "automation", onService: "turn_on", offService: "turn_off"))
        #expect(automationPresentation.primaryActionAccessibilityLabel == "Turn off Good Night")
        #expect(automationPresentation.cardStyle == .control)
        #expect(automationPresentation.detailKind == .toggle)
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
            .automation: (.control, .toggleAutomation, .toggle),
            .vacuum: (.status, nil, .vacuum),
            .remote: (.status, nil, .entity),
            .button: (.status, nil, .button),
            .select: (.value, nil, .select),
            .number: (.value, nil, .number),
            .text: (.value, nil, .entity),
            .date: (.value, nil, .entity),
            .time: (.value, nil, .entity),
            .datetime: (.value, nil, .entity),
            .deviceTracker: (.status, nil, .entity),
            .person: (.status, nil, .entity),
            .update: (.status, nil, .entity),
            .alarmControlPanel: (.status, nil, .alarmControlPanel),
            .humidifier: (.status, nil, .entity),
            .waterHeater: (.status, nil, .entity),
            .lawnMower: (.status, nil, .entity),
            .valve: (.status, nil, .entity),
            .siren: (.status, nil, .entity),
            .weather: (.value, nil, .weather),
            .calendar: (.status, nil, .entity),
            .todo: (.status, nil, .entity),
            .event: (.status, nil, .entity),
            .image: (.status, nil, .entity),
            .imageProcessing: (.status, nil, .entity),
            .airQuality: (.value, nil, .entity),
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
    @Test func newHomeAssistantDomainsRenderWithNativeOrSafeGenericPresentations() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "remote.ashtons_tv",
                state: "off",
                attributes: ["friendly_name": .string("Ashton's TV")]
            ),
            HAEntityDTO(
                entityID: "button.router_restart",
                state: "2026-06-02T08:00:00Z",
                attributes: [
                    "friendly_name": .string("Restart Router"),
                    "device_class": .string("restart")
                ]
            ),
            HAEntityDTO(
                entityID: "number.target_humidity",
                state: "45",
                attributes: [
                    "friendly_name": .string("Target Humidity"),
                    "device_class": .string("humidity"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: "alarm_control_panel.home",
                state: "armed_away",
                attributes: ["friendly_name": .string("Home Alarm")]
            ),
            HAEntityDTO(
                entityID: "weather.home",
                state: "partlycloudy",
                attributes: [
                    "friendly_name": .string("Home Weather"),
                    "temperature": .number(73),
                    "temperature_unit": .string("F"),
                    "humidity": .number(56),
                    "wind_speed": .number(8),
                    "wind_speed_unit": .string("mph"),
                    "wind_bearing": .number(90),
                    "forecast": .array([.object(["condition": .string("sunny")])])
                ]
            )
        ])

        let remote = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "remote.ashtons_tv")))
        let button = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "button.router_restart")))
        let number = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "number.target_humidity")))
        let alarm = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "alarm_control_panel.home")))
        let weather = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "weather.home")))

        #expect(remote.title == "Ashton's TV")
        #expect(remote.cardStyle == .status)
        #expect(remote.iconName == "appletvremote.gen4.fill")
        #expect(remote.subtitle == "Off")
        #expect(remote.primaryAction == nil)
        #expect(remote.detailKind == .entity)
        #expect(button.cardStyle == .status)
        #expect(button.iconName == "arrow.trianglehead.2.clockwise")
        #expect(button.primaryAction == nil)
        #expect(button.detailKind == .button)
        #expect(number.cardStyle == .value)
        #expect(number.iconName == "humidity")
        #expect(number.subtitle == "45")
        #expect(number.primaryAction == nil)
        #expect(number.detailKind == .number)
        #expect(alarm.cardStyle == .status)
        #expect(alarm.iconName == "shield.lefthalf.filled")
        #expect(alarm.subtitle == "Armed Away")
        #expect(alarm.primaryAction == nil)
        #expect(alarm.detailKind == .alarmControlPanel)
        #expect(weather.cardStyle == .value)
        #expect(weather.iconName == "cloud.sun.fill")
        #expect(weather.subtitle == "Partly Cloudy")
        #expect(weather.headline == "73°F")
        #expect(weather.supplementalMetrics.contains(DashboardEntityCardMetric(title: "Humidity", value: "56%", systemImage: "humidity.fill")))
        #expect(weather.supplementalMetrics.contains(DashboardEntityCardMetric(title: "Wind", value: "E 8 mph", systemImage: "wind")))
        #expect(weather.detailKind == .weather)
        #expect(weather.primaryAction == nil)
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
            ),
            HAEntityDTO(
                entityID: "lock.front_door",
                state: "unlocked",
                attributes: ["friendly_name": .string("Front Door")]
            ),
            HAEntityDTO(
                entityID: "lock.side_door",
                state: "unlocking",
                attributes: ["friendly_name": .string("Side Door")]
            ),
            HAEntityDTO(
                entityID: "weather.home",
                state: "sunny",
                attributes: [
                    "friendly_name": .string("Home Weather"),
                    "temperature": .number(81),
                    "temperature_unit": .string("F"),
                    "humidity": .number(48),
                    "wind_speed": .number(5),
                    "wind_speed_unit": .string("mph")
                ]
            )
        ])

        let fanPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "fan.bedroom")))
        let fanWide = DashboardEntityCardContentModel.make(presentation: fanPresentation, size: .wide)
        let fanLarge = DashboardEntityCardContentModel.make(presentation: fanPresentation, size: .large)
        #expect(fanWide.metrics.map(\.title) == ["Status"])
        #expect(fanWide.metrics.map(\.value) == ["On"])
        #expect(fanLarge.metrics.contains(DashboardEntityCardMetric(title: "Level", value: "45%", systemImage: "fan.fill")))
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

        let unlockedLockPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "lock.front_door")))
        let unlockedLockWide = DashboardEntityCardContentModel.make(presentation: unlockedLockPresentation, size: .wide)
        #expect(unlockedLockWide.metrics.first == DashboardEntityCardMetric(title: "Status", value: "Unlocked", systemImage: "circle.fill"))

        let unlockingLockPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "lock.side_door")))
        let unlockingLockLarge = DashboardEntityCardContentModel.make(presentation: unlockingLockPresentation, size: .large)
        #expect(unlockingLockLarge.metrics.first == DashboardEntityCardMetric(title: "Status", value: "Unlocking", systemImage: "circle.fill"))

        let weatherPresentation = DashboardEntityPresentation(entityBox: try #require(store.entityBox(for: "weather.home")))
        let weatherLarge = DashboardEntityCardContentModel.make(presentation: weatherPresentation, size: .large)
        #expect(weatherLarge.metrics.first == DashboardEntityCardMetric(title: "Condition", value: "Sunny", systemImage: "sun.max.fill"))
        #expect(weatherLarge.metrics.contains(DashboardEntityCardMetric(title: "Temperature", value: "81°F", systemImage: "thermometer.medium")))
        #expect(weatherLarge.metrics.contains(DashboardEntityCardMetric(title: "Humidity", value: "48%", systemImage: "humidity.fill")))
    }

    @MainActor
    @Test func dashboardCardFeatureProviderBuildsReusableInteractiveFeatures() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: [
                    "friendly_name": .string("Kitchen"),
                    "brightness": .number(128)
                ]
            ),
            HAEntityDTO(
                entityID: "climate.downstairs",
                state: "cool",
                attributes: [
                    "friendly_name": .string("Downstairs"),
                    "temperature": .number(72),
                    "current_temperature": .number(74),
                    "temperature_unit": .string("°F"),
                    "min_temp": .number(60),
                    "max_temp": .number(80),
                    "target_temp_step": .number(0.5)
                ]
            ),
            HAEntityDTO(
                entityID: "cover.garage_door",
                state: "closed",
                attributes: [
                    "friendly_name": .string("Garage Door"),
                    "current_position": .number(0)
                ]
            ),
            HAEntityDTO(entityID: "lock.front_door", state: "locked")
        ])

        let lightBox = try #require(store.entityBox(for: "light.kitchen"))
        let lightFeatures = DashboardCardFeatureProvider.features(
            for: lightBox,
            presentation: DashboardEntityPresentation(entityBox: lightBox)
        )
        #expect(lightFeatures.map(\.key) == [.lightBrightness])
        guard case .level(let brightness) = try #require(lightFeatures.first?.content) else {
            Issue.record("Expected light brightness level feature")
            return
        }
        #expect(brightness.value == 50)
        #expect(brightness.action == .setLightBrightness)

        let climateBox = try #require(store.entityBox(for: "climate.downstairs"))
        let climateFeatures = DashboardCardFeatureProvider.features(
            for: climateBox,
            presentation: DashboardEntityPresentation(entityBox: climateBox)
        )
        #expect(climateFeatures.map(\.key) == [.climateSetpoint])
        guard case .setpoint(let setpoint) = try #require(climateFeatures.first?.content) else {
            Issue.record("Expected climate setpoint feature")
            return
        }
        #expect(setpoint.action == .setClimateTemperature)
        #expect(setpoint.values.first?.value == 72)
        #expect(setpoint.values.first?.step == 0.5)

        let coverBox = try #require(store.entityBox(for: "cover.garage_door"))
        let coverFeatures = DashboardCardFeatureProvider.features(
            for: coverBox,
            presentation: DashboardEntityPresentation(entityBox: coverBox)
        )
        #expect(coverFeatures.map(\.key) == [.coverControls, .coverPosition])
        #expect(DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: coverBox) == .square)
        guard case .commandGroup(let commands) = try #require(coverFeatures.first?.content) else {
            Issue.record("Expected cover command feature")
            return
        }
        #expect(commands.commands.map(\.action) == [.openCover, .stopCover, .closeCover])
        #expect(commands.commands.first?.isDisabled == false)
        #expect(commands.commands.last?.isDisabled == true)

        let lockBox = try #require(store.entityBox(for: "lock.front_door"))
        let lockFeatures = DashboardCardFeatureProvider.features(
            for: lockBox,
            presentation: DashboardEntityPresentation(entityBox: lockBox)
        )
        #expect(lockFeatures.map(\.key) == [.lockControls])
        guard case .commandGroup(let lockCommands) = try #require(lockFeatures.first?.content) else {
            Issue.record("Expected lock command feature")
            return
        }
        #expect(lockCommands.commands.map(\.action) == [.lock, .unlock])
        #expect(lockCommands.commands.first?.isDisabled == true)
        #expect(lockCommands.commands.last?.isDisabled == false)
        #expect(lockCommands.commands.last?.confirmation == DashboardCardCommandConfirmation(
            title: "Unlock?",
            actionTitle: "Unlock",
            message: "This will send an unlock command to Home Assistant.",
            isDestructive: true
        ))
    }

    @MainActor
    @Test func lockCardFeatureProviderRequiresInlineUnlockConfirmation() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "lock.front_door", state: "locked"),
            HAEntityDTO(entityID: "lock.back_door", state: "unlocked"),
            HAEntityDTO(entityID: "lock.side_door", state: "unlocking")
        ])

        let lockedBox = try #require(store.entityBox(for: "lock.front_door"))
        let lockedCommands = try lockCommands(for: lockedBox)
        #expect(lockedCommands.commands[0].isDisabled)
        #expect(lockedCommands.commands[1].isDisabled == false)
        #expect(lockedCommands.commands[1].confirmation?.isDestructive == true)

        let unlockedBox = try #require(store.entityBox(for: "lock.back_door"))
        let unlockedCommands = try lockCommands(for: unlockedBox)
        #expect(unlockedCommands.commands[0].isDisabled == false)
        #expect(unlockedCommands.commands[1].isDisabled)

        let unlockingBox = try #require(store.entityBox(for: "lock.side_door"))
        let unlockingCommands = try lockCommands(for: unlockingBox)
        #expect(unlockingCommands.commands[0].isDisabled == false)
        #expect(unlockingCommands.commands[1].isDisabled)
    }

    @MainActor
    private func lockCommands(for entityBox: HAEntityState) throws -> DashboardCardCommandGroupFeature {
        let features = DashboardCardFeatureProvider.features(
            for: entityBox,
            presentation: DashboardEntityPresentation(entityBox: entityBox)
        )
        if case .commandGroup(let commands) = try #require(features.first?.content) {
            return commands
        } else {
            Issue.record("Expected lock command feature")
            return DashboardCardCommandGroupFeature(commands: [])
        }
    }

    @MainActor
    @Test func dashboardCardSizesGateInteractiveFeatureRendering() throws {
        let features = [
            DashboardCardFeature(
                key: .coverControls,
                title: "Cover",
                content: .commandGroup(DashboardCardCommandGroupFeature(commands: []))
            ),
            DashboardCardFeature(
                key: .coverPosition,
                title: "Position",
                content: .level(
                    DashboardCardLevelFeature(
                        value: 40,
                        range: 0...100,
                        step: 1,
                        valueLabel: "40%",
                        accessibilityLabel: "Cover position",
                        action: .setCoverPosition
                    )
                )
            )
        ]

        #expect(DashboardCardSize.mini.featureLayout == .hidden)
        #expect(DashboardCardSize.compact.featureLayout == .hidden)
        #expect(DashboardCardSize.row.featureLayout == .trailing)
        #expect(DashboardCardSize.square.featureLayout == .stacked)
        #expect(DashboardCardSize.wide.featureLayout == .stacked)
        #expect(DashboardCardSize.large.featureLayout == .stacked)
        #expect(DashboardCardSize.mini.visibleFeatures(from: features).isEmpty)
        #expect(DashboardCardSize.compact.visibleFeatures(from: features).isEmpty)
        #expect(DashboardCardSize.row.visibleFeatures(from: features).map(\.key) == [.coverControls])
        #expect(DashboardCardSize.square.visibleFeatures(from: features).map(\.key) == [.coverControls])
        #expect(DashboardCardSize.large.visibleFeatures(from: features).map(\.key) == [.coverControls, .coverPosition])
        #expect(DashboardCardSize.large.visibleFeatures(from: features, visibility: .hidden).isEmpty)
        #expect(DashboardCardSize.large.visibleFeatures(from: features, visibility: .automatic).map(\.key) == [.coverControls, .coverPosition])
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
            HAEntityDTO(
                entityID: "cover.garage_door",
                state: "open",
                attributes: ["device_class": .string("garage")]
            ),
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
        let maintenance = try #require(DashboardSummaryProvider.makeSummary(kind: .maintenance, entityBoxes: boxes))
        let media = try #require(DashboardSummaryProvider.makeSummary(kind: .media, entityBoxes: boxes))

        #expect(lights.value == "1 On")
        #expect(lights.isActive)
        #expect(lights.systemImage == "lightbulb.fill")
        #expect(lights.iconTint == .lights)
        #expect(security.title == "Security")
        #expect(security.value == "2 Open")
        #expect(security.systemImage == "lock.fill")
        #expect(security.iconTint == .security)
        #expect(climate.value == "74.5°F")
        #expect(climate.iconTint == .climate)
        #expect(maintenance.title == "Maintenance")
        #expect(maintenance.value == "1 Issue")
        #expect(maintenance.systemImage == "wrench.fill")
        #expect(maintenance.iconTint == .maintenance)
        #expect(media.value == "1 Playing")
        #expect(media.systemImage == "play.tv.fill")
        #expect(media.iconTint == .media)
        #expect(DashboardSummaryKind.allCases == [.lights, .security, .climate, .maintenance, .media])
        #expect(DashboardSummaryKind.areasOverviewOrder == [.climate, .lights, .security, .media, .maintenance])

        let lightChip = DashboardSummaryProvider.makeEntityChip(
            entityBox: try #require(store.entityBox(for: "light.kitchen")),
            titleOverride: "Counter",
            iconNameOverride: "lamp.table"
        )
        #expect(lightChip.title == "Counter")
        #expect(lightChip.systemImage == "lamp.table")
        #expect(lightChip.isActive)
        #expect(lightChip.iconTint == .status)
    }

    @MainActor
    @Test func climateSummaryUsesHomeAssistantAreaClimateReadings() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "fan.office", state: "off"),
            HAEntityDTO(
                entityID: "sensor.office_temperature",
                state: "72",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.office_device_temperature",
                state: "82",
                attributes: [
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            )
        ])

        let detail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .climate,
            entityBoxes: store.allEntityBoxes(),
            preferredClimateReadingEntityIDs: ["sensor.office_temperature"],
            areaNameForEntityID: { _ in "Office" }
        ))

        #expect(detail.sections.first?.items.map(\.entityID) == [
            "fan.office",
            "sensor.office_temperature"
        ])
        #expect(detail.sections.first?.items.contains { $0.entityID == "sensor.office_device_temperature" } == false)
    }

    @MainActor
    @Test func summariesFilterNonPrimaryEntitiesLikeHomeAssistantStrategies() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.room", state: "on"),
            HAEntityDTO(entityID: "light.room_diagnostic", state: "on"),
            HAEntityDTO(entityID: "media_player.tv", state: "playing"),
            HAEntityDTO(entityID: "media_player.tv_diagnostic", state: "playing"),
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "50",
                attributes: [
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.remote_diagnostic_battery",
                state: "5",
                attributes: [
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.remote_low_battery",
                state: "on",
                attributes: ["device_class": .string("battery")]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.case_tamper",
                state: "on",
                attributes: ["device_class": .string("tamper")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.room_diagnostic",
                    deviceID: nil,
                    originalName: "Room Diagnostic",
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "media_player.tv_diagnostic",
                    deviceID: nil,
                    originalName: "TV Diagnostic",
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.remote_diagnostic_battery",
                    deviceID: nil,
                    originalName: "Remote Diagnostic Battery",
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "binary_sensor.case_tamper",
                    deviceID: nil,
                    originalName: "Case Tamper",
                    entityCategory: "diagnostic"
                )
            ],
            devices: []
        )

        let boxes = store.allEntityBoxes()
        let nonPrimaryEntityIDs = store.nonPrimaryEntityIDs()
        let diagnosticEntityIDs = store.diagnosticEntityIDs()

        let lights = try #require(DashboardSummaryProvider.makeDetail(
            kind: .lights,
            entityBoxes: boxes,
            nonPrimaryEntityIDs: nonPrimaryEntityIDs,
            diagnosticEntityIDs: diagnosticEntityIDs
        ))
        #expect(lights.sections.flatMap(\.items).map(\.entityID) == ["light.room"])

        let maintenance = try #require(DashboardSummaryProvider.makeDetail(
            kind: .maintenance,
            entityBoxes: boxes,
            nonPrimaryEntityIDs: nonPrimaryEntityIDs,
            diagnosticEntityIDs: diagnosticEntityIDs
        ))
        #expect(maintenance.sections.flatMap(\.items).map(\.entityID) == [
            "binary_sensor.remote_low_battery",
            "sensor.remote_battery"
        ])

        let media = try #require(DashboardSummaryProvider.makeDetail(
            kind: .media,
            entityBoxes: boxes,
            nonPrimaryEntityIDs: nonPrimaryEntityIDs,
            diagnosticEntityIDs: diagnosticEntityIDs
        ))
        #expect(media.sections.flatMap(\.items).map(\.entityID) == ["media_player.tv"])

        let security = try #require(DashboardSummaryProvider.makeDetail(
            kind: .security,
            entityBoxes: boxes,
            nonPrimaryEntityIDs: nonPrimaryEntityIDs,
            diagnosticEntityIDs: diagnosticEntityIDs
        ))
        #expect(security.sections.flatMap(\.items).map(\.entityID) == ["binary_sensor.case_tamper"])
    }

    @MainActor
    @Test func stateStoreMapsUpdateEntitiesWithRegistryContext() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "update.router_firmware",
                state: "on",
                attributes: [
                    "friendly_name": .string("Router Firmware"),
                    "installed_version": .string("7.1"),
                    "latest_version": .string("7.2")
                ]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "update.router_firmware",
                    deviceID: "router-device",
                    originalName: "Router Firmware"
                )
            ],
            devices: [
                HADeviceRegistryDTO(
                    id: "router-device",
                    name: "Router",
                    areaID: "network-closet",
                    manufacturer: "Ubiquiti",
                    model: "Dream Machine"
                )
            ],
            areas: [
                HAAreaRegistryDTO(id: "network-closet", name: "Network Closet", floorID: "basement")
            ],
            floors: [
                HAFloorRegistryDTO(id: "basement", name: "Basement")
            ]
        )

        let update = try #require(store.updateEntity(for: "update.router_firmware"))

        #expect(store.updateEntities.map(\.entityID) == ["update.router_firmware"])
        #expect(update.status == .available)
        #expect(update.context.deviceName == "Router")
        #expect(update.context.areaName == "Network Closet")
        #expect(update.context.floorName == "Basement")
        #expect(update.contextSummary.contains("Network Closet"))
        #expect(update.contextSummary.contains("Router"))
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
            HAEntityDTO(
                entityID: "binary_sensor.leak_sensor",
                state: "off",
                attributes: ["device_class": .string("moisture")]
            ),
            HAEntityDTO(entityID: "lock.front_door", state: "unlocked"),
            HAEntityDTO(entityID: "lock.front_door_lock", state: "locked"),
            HAEntityDTO(
                entityID: "cover.garage_door",
                state: "closed",
                attributes: ["device_class": .string("garage")]
            ),
            HAEntityDTO(entityID: "camera.front_door", state: "idle"),
            HAEntityDTO(entityID: "camera.front_doorbell_snapshot", state: "idle"),
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
            "binary_sensor.leak_sensor": "Entryway",
            "lock.front_door": "Entryway",
            "lock.front_door_lock": "Entryway",
            "camera.front_door": "Entryway",
            "camera.front_doorbell_snapshot": "Entryway",
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
        #expect(securityDetail.summary.value == "1 Unlocked")
        #expect(securityDetail.sections.map(\.title) == ["Entryway", "Garage"])
        #expect(securityDetail.sections.first?.items.map(\.entityID) == [
            "lock.front_door",
            "binary_sensor.back_door",
            "binary_sensor.leak_sensor",
            "lock.front_door_lock",
            "camera.driveway",
            "camera.front_door",
            "camera.front_doorbell_snapshot"
        ])
        #expect(securityDetail.sections.first?.items.contains { $0.entityID == "binary_sensor.doorbell_ding" } == false)
        #expect(securityDetail.sections.first?.items.first { $0.entityID == "camera.driveway" }?.visualStyle == .camera)

        let maintenanceDetail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .maintenance,
            entityBoxes: boxes,
            areaNameForEntityID: { areaNames[$0] }
        ))
        #expect(maintenanceDetail.sections.map(\.title) == ["Entryway", "Garage"])
        #expect(maintenanceDetail.sections.first?.items.map(\.entityID) == ["sensor.remote_battery"])
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

    @MainActor
    @Test func stateStoreBuildsManagementSummariesFromRegistryMetadata() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "sensor.router_status", state: "unavailable"),
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.router_status",
                    deviceID: "router",
                    areaID: nil,
                    originalName: "Router Status",
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "light.kitchen",
                    deviceID: "kitchen-light",
                    areaID: "kitchen",
                    originalName: "Kitchen Light"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "router", name: "Router", areaID: "closet", manufacturer: "Ubiquiti", model: "Dream Machine"),
                HADeviceRegistryDTO(id: "kitchen-light", name: "Kitchen Light", areaID: "kitchen")
            ],
            areas: [
                HAAreaRegistryDTO(id: "closet", name: "Closet"),
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen")
            ]
        )

        let summaries = store.deviceManagementSummaries()

        #expect(summaries.map(\.title) == ["Kitchen Light", "Router"])
        #expect(summaries.last?.subtitle == "Ubiquiti • Dream Machine • Closet")
        #expect(summaries.last?.areaName == "Closet")
        #expect(summaries.last?.manufacturer == "Ubiquiti")
        #expect(summaries.last?.model == "Dream Machine")
        #expect(summaries.last?.entityCount == 1)
        #expect(summaries.last?.matches(query: "closet") == true)
        #expect(summaries.last?.matches(query: "dream") == true)
        #expect(summaries.last?.matches(query: "kitchen") == false)
        #expect(store.entityRegistryAdminDetail(for: "sensor.router_status") == "Closet • Router • Diagnostic • Unavailable")
        #expect(store.entityRegistryAdminDetail(for: "light.kitchen") == "Kitchen • Kitchen Light")
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
    private(set) var connectConfigurations: [HAConnectionConfiguration] = []
    private(set) var didDisconnect = false
    private(set) var disconnectCount = 0
    private(set) var callServiceInvocations: [(domain: String, service: String, entityID: String?, serviceData: [String: JSONValue])] = []
    private(set) var mobileAppPushNotificationSubscription: (webhookID: String, supportConfirm: Bool)?
    private(set) var mobileAppPushNotificationConfirmations: [(webhookID: String, confirmID: String)] = []
    private var mobileAppPushNotificationHandler: (@Sendable (HAMobileAppPushNotificationEventDTO) async -> Void)?
    var callServiceError: Error?
    var currentUser: HACurrentUserDTO?
    var states: [HAEntityDTO]
    var config = HAConfigDTO(
        version: nil,
        locationName: nil,
        timeZone: nil,
        internalURL: nil,
        externalURL: nil,
        state: nil,
        configSource: nil,
        unitSystem: nil
    )
    var serviceRegistry: HAServiceRegistry = .empty
    var fetchServicesDelay: Duration?
    var fetchServicesError: Error?
    var connectErrorsByBaseURL: [String: Error] = [:]

    init(currentUser: HACurrentUserDTO? = nil, states: [HAEntityDTO] = []) {
        self.currentUser = currentUser
        self.states = states
    }

    func setEventHandler(_ handler: (@Sendable (HAEventDTO) async -> Void)?) async {}

    func setMobileAppPushNotificationHandler(_ handler: (@Sendable (HAMobileAppPushNotificationEventDTO) async -> Void)?) async {
        mobileAppPushNotificationHandler = handler
    }

    func setDisconnectHandler(_ handler: (@MainActor @Sendable (Error) -> Void)?) async {}

    func connect(configuration: HAConnectionConfiguration) async throws {
        lastConnectConfiguration = configuration
        connectConfigurations.append(configuration)

        if let error = connectErrorsByBaseURL[configuration.baseURLString] {
            throw error
        }
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

    func fetchFloorRegistry() async throws -> [HAFloorRegistryDTO] {
        []
    }

    func fetchConfig() async throws -> HAConfigDTO {
        config
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

    func subscribeToMobileAppPushNotifications(webhookID: String, supportConfirm: Bool) async throws {
        mobileAppPushNotificationSubscription = (webhookID, supportConfirm)
    }

    func confirmMobileAppPushNotification(webhookID: String, confirmID: String) async throws {
        mobileAppPushNotificationConfirmations.append((webhookID, confirmID))
    }

    func emitMobileAppPushNotification(_ event: HAMobileAppPushNotificationEventDTO) async {
        await mobileAppPushNotificationHandler?(event)
    }

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

final class StubHAHTTPClient: HAHTTPClientProtocol, @unchecked Sendable {
    var logbookEntries: [HALogbookEntryDTO]
    var historyResponse: HAHistoryResponseDTO
    var logbookError: Error?
    var historyError: Error?
    private(set) var lastLogbookConfiguration: HAConnectionConfiguration?
    private(set) var lastLogbookRequest: HALogbookRequest?
    private(set) var lastHistoryConfiguration: HAConnectionConfiguration?
    private(set) var lastHistoryRequest: HAHistoryRequest?

    init(
        logbookEntries: [HALogbookEntryDTO] = [],
        historyResponse: HAHistoryResponseDTO = HAHistoryResponseDTO(series: [])
    ) {
        self.logbookEntries = logbookEntries
        self.historyResponse = historyResponse
    }

    func fetchCameraSnapshot(configuration: HAConnectionConfiguration, entityID: String) async throws -> Data {
        Data()
    }

    func fetchLogbook(configuration: HAConnectionConfiguration, request: HALogbookRequest) async throws -> [HALogbookEntryDTO] {
        lastLogbookConfiguration = configuration
        lastLogbookRequest = request

        if let logbookError {
            throw logbookError
        }

        return logbookEntries
    }

    func fetchHistory(configuration: HAConnectionConfiguration, request: HAHistoryRequest) async throws -> HAHistoryResponseDTO {
        lastHistoryConfiguration = configuration
        lastHistoryRequest = request

        if let historyError {
            throw historyError
        }

        return historyResponse
    }
}

final class StubHAMobileAppClient: HAMobileAppClientProtocol {
    var registrationResponse: HAMobileAppRegistrationResponseDTO
    var cameraStreamResponse: HACameraStreamResponseDTO
    private(set) var lastRegistrationConfiguration: HAConnectionConfiguration?
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
        lastRegistrationConfiguration = configuration
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

@MainActor
final class StubNativeNotificationPermissionClient: NativeNotificationPermissionClient {
    var currentStatus: NativeNotificationStatusSnapshot
    var requestAuthorizationError: Error?
    var currentStatusError: Error?
    var presentNotificationError: Error?
    private(set) var currentStatusCallCount = 0
    private(set) var didRequestAuthorization = false
    private(set) var presentedNotifications: [NativeNotificationRequest] = []

    init(currentStatus: NativeNotificationStatusSnapshot) {
        self.currentStatus = currentStatus
    }

    func currentStatus() async throws -> NativeNotificationStatusSnapshot {
        currentStatusCallCount += 1

        if let currentStatusError {
            throw currentStatusError
        }

        return currentStatus
    }

    func requestAuthorization() async throws -> Bool {
        didRequestAuthorization = true

        if let requestAuthorizationError {
            throw requestAuthorizationError
        }

        return currentStatus.authorizationStatus.isAllowed
    }

    func presentNotification(_ request: NativeNotificationRequest) async throws {
        if let presentNotificationError {
            throw presentNotificationError
        }

        presentedNotifications.append(request)
    }
}

@MainActor
final class StubNativePermissionClient: NativePermissionClient {
    var currentStatus: NativePermissionStatusSnapshot
    var requestedCameraStatus: NativeCapabilityAuthorizationStatus
    var requestedLocationStatus: NativeCapabilityAuthorizationStatus
    var currentStatusError: Error?
    var requestCameraError: Error?
    var requestLocationError: Error?
    private(set) var currentStatusCallCount = 0
    private(set) var didRequestCameraAccess = false
    private(set) var didRequestLocationAccess = false

    init(
        currentStatus: NativePermissionStatusSnapshot,
        requestedCameraStatus: NativeCapabilityAuthorizationStatus = .allowed,
        requestedLocationStatus: NativeCapabilityAuthorizationStatus = .allowed
    ) {
        self.currentStatus = currentStatus
        self.requestedCameraStatus = requestedCameraStatus
        self.requestedLocationStatus = requestedLocationStatus
    }

    func currentStatus() async throws -> NativePermissionStatusSnapshot {
        currentStatusCallCount += 1

        if let currentStatusError {
            throw currentStatusError
        }

        return currentStatus
    }

    func requestCameraAccess() async throws -> NativeCapabilityAuthorizationStatus {
        didRequestCameraAccess = true

        if let requestCameraError {
            throw requestCameraError
        }

        currentStatus = NativePermissionStatusSnapshot(
            camera: requestedCameraStatus,
            location: currentStatus.location,
            localNetwork: currentStatus.localNetwork
        )
        return requestedCameraStatus
    }

    func requestLocationAccess() async throws -> NativeCapabilityAuthorizationStatus {
        didRequestLocationAccess = true

        if let requestLocationError {
            throw requestLocationError
        }

        currentStatus = NativePermissionStatusSnapshot(
            camera: currentStatus.camera,
            location: requestedLocationStatus,
            localNetwork: currentStatus.localNetwork
        )
        return requestedLocationStatus
    }
}
