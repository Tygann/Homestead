import Foundation
import Testing
import UIKit
@testable import Homestead

struct HomesteadTests {
    @Test func onboardingPresentationShowsServerEntryForFreshInstall() {
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: false,
            authState: .signedOut,
            connectionStatus: .disconnected,
            serviceError: nil,
            storageError: nil
        )

        #expect(presentation.shouldShow)
        #expect(presentation.statusTitle == "Server Needed")
        #expect(presentation.buttonTitle == "Continue")
        #expect(!presentation.isButtonEnabled)
        #expect(!presentation.isBusy)
        #expect(!presentation.showsStatusRow)
    }

    @Test func onboardingPresentationEnablesSignInWhenServerIsEntered() {
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: true,
            authState: .signedOut,
            connectionStatus: .disconnected,
            serviceError: nil,
            storageError: nil
        )

        #expect(presentation.shouldShow)
        #expect(presentation.statusTitle == "Ready to Sign In")
        #expect(presentation.isButtonEnabled)
        #expect(!presentation.isBusy)
        #expect(!presentation.showsStatusRow)
    }

    @Test func onboardingPresentationKeepsInitialRefreshVisuallyStable() {
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: true,
            hasKnownSession: false,
            authState: .refreshing(nil),
            connectionStatus: .preparing,
            serviceError: nil,
            storageError: nil
        )

        #expect(presentation.shouldShow)
        #expect(presentation.statusTitle == "Ready to Sign In")
        #expect(presentation.buttonTitle == "Continue")
        #expect(presentation.isButtonEnabled)
        #expect(!presentation.isBusy)
        #expect(!presentation.showsStatusRow)
    }

    @Test func onboardingPresentationDisablesSignInWhileSigningIn() {
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: true,
            authState: .signingIn,
            connectionStatus: .disconnected,
            serviceError: nil,
            storageError: nil
        )

        #expect(presentation.shouldShow)
        #expect(presentation.statusTitle == "Signing In")
        #expect(presentation.buttonTitle == "Signing In")
        #expect(!presentation.isButtonEnabled)
        #expect(presentation.isBusy)
    }

    @Test func onboardingPresentationShowsRetryStateAfterAuthFailure() {
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: true,
            hasKnownSession: false,
            authState: .refreshFailed("Home Assistant rejected the sign-in."),
            connectionStatus: .failed("Unauthorized"),
            serviceError: nil,
            storageError: nil
        )

        #expect(presentation.shouldShow)
        #expect(presentation.statusTitle == "Sign-In Failed")
        #expect(presentation.statusMessage == "Home Assistant rejected the sign-in.")
        #expect(presentation.buttonTitle == "Continue")
        #expect(presentation.isButtonEnabled)
        #expect(presentation.showsStatusRow)
    }

    @Test func onboardingPresentationDoesNotInterruptKnownSessionAfterRefreshFailure() {
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: true,
            hasKnownSession: true,
            authState: .refreshFailed("The request timed out."),
            connectionStatus: .failed("The request timed out."),
            serviceError: nil,
            storageError: nil
        )

        #expect(!presentation.shouldShow)
        #expect(presentation.statusTitle == "Sign-In Failed")
    }

    @Test func onboardingPresentationSuppressesSetupAfterSignIn() {
        let credential = HAOAuthCredential(
            baseURLString: "http://homeassistant.local:8123",
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: "access-token",
            accessTokenExpiresAt: .distantFuture,
            tokenType: "Bearer",
            updatedAt: .now
        )

        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .connecting,
            serviceError: nil,
            storageError: nil
        )

        #expect(!presentation.shouldShow)
        #expect(presentation.statusTitle == "Connecting")
    }

    @Test func onboardingPresentationSuppressesSetupFromStoredLaunchSession() {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: HAOAuthCredential(
                baseURLString: "http://homeassistant.local:8123",
                clientID: HAOAuthClientMetadata.clientID,
                refreshToken: "refresh-token",
                accessToken: "access-token",
                accessTokenExpiresAt: .distantFuture,
                tokenType: "Bearer",
                updatedAt: .now
            )
        )
        let authState = HAOAuthManager.status(tokenStore: tokenStore)
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: true,
            hasKnownSession: authState.isSignedIn,
            authState: authState,
            connectionStatus: .disconnected,
            serviceError: nil,
            storageError: nil
        )

        #expect(authState.isSignedIn)
        #expect(!presentation.shouldShow)
    }

    @Test func serviceFeedbackDurationMatchesOutcomeSeverity() {
        let successFeedback = HAServiceFeedback(title: "Done", message: nil, style: .success)
        let failureFeedback = HAServiceFeedback(title: "Failed", message: nil, style: .failure)

        #expect(successFeedback.displayDuration == .seconds(2))
        #expect(failureFeedback.displayDuration == .seconds(5))
    }

    @MainActor
    @Test func actionConfirmationSettingsDefaultToSmartSafetyAndPersist() throws {
        let defaults = try isolatedDefaults()
        let settings = ActionConfirmationSettings(defaults: defaults)

        #expect(settings.mode == .smart)
        #expect(settings.confirmsLockUnlocks)
        #expect(settings.confirmsSecurityCoverOpens)
        #expect(settings.confirmsScenes)
        #expect(settings.confirmsScripts)
        #expect(settings.confirmsOtherImpactfulActions)

        settings.mode = .off
        settings.confirmsScenes = false
        settings.confirmsOtherImpactfulActions = false

        let restoredSettings = ActionConfirmationSettings(defaults: defaults)
        #expect(restoredSettings.mode == .off)
        #expect(restoredSettings.confirmsScenes == false)
        #expect(restoredSettings.confirmsOtherImpactfulActions == false)
        #expect(restoredSettings.confirmsLockUnlocks)
    }

    @MainActor
    @Test func actionConfirmationPolicyConfirmsSensitiveSmartActions() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "lock.front_door", state: "locked"),
            HAEntityDTO(entityID: "lock.back_door", state: "unlocked"),
            HAEntityDTO(
                entityID: "cover.garage_door",
                state: "closed",
                attributes: ["device_class": .string("garage")]
            ),
            HAEntityDTO(
                entityID: "cover.office_shade",
                state: "closed",
                attributes: ["device_class": .string("shade")]
            ),
            HAEntityDTO(entityID: "cover.unknown_cover", state: "closed"),
            HAEntityDTO(entityID: "scene.movie_night", state: "scening"),
            HAEntityDTO(entityID: "script.good_morning", state: "off"),
            HAEntityDTO(entityID: "button.restart_router", state: "unknown"),
            HAEntityDTO(entityID: "light.kitchen", state: "off"),
            HAEntityDTO(entityID: "switch.coffee", state: "off"),
            HAEntityDTO(entityID: "fan.bedroom", state: "off"),
            HAEntityDTO(entityID: "climate.downstairs", state: "heat"),
            HAEntityDTO(
                entityID: "select.house_mode",
                state: "Home",
                attributes: ["options": .array([.string("Home"), .string("Away")])]
            )
        ])
        let settings = ActionConfirmationSettingsSnapshot(
            mode: .smart,
            confirmsLockUnlocks: true,
            confirmsSecurityCoverOpens: true,
            confirmsScenes: true,
            confirmsScripts: true,
            confirmsOtherImpactfulActions: true
        )

        #expect(confirmation(store, "lock.front_door", "lock", "unlock", settings) != nil)
        #expect(confirmation(store, "lock.back_door", "lock", "lock", settings) == nil)
        #expect(confirmation(store, "cover.garage_door", "cover", "open_cover", settings) != nil)
        #expect(confirmation(store, "cover.unknown_cover", "cover", "open_cover", settings) != nil)
        #expect(confirmation(store, "cover.office_shade", "cover", "open_cover", settings) == nil)
        #expect(confirmation(store, "cover.garage_door", "cover", "close_cover", settings) == nil)
        #expect(confirmation(store, "cover.garage_door", "cover", "stop_cover", settings) == nil)
        #expect(confirmation(store, "cover.garage_door", "cover", "set_cover_position", settings) == nil)
        #expect(confirmation(store, "scene.movie_night", "scene", "turn_on", settings) != nil)
        #expect(confirmation(store, "script.good_morning", "script", "turn_on", settings) != nil)
        #expect(confirmation(store, "button.restart_router", "button", "press", settings) != nil)
        #expect(confirmation(store, "light.kitchen", "light", "turn_on", settings) == nil)
        #expect(confirmation(store, "switch.coffee", "switch", "turn_on", settings) == nil)
        #expect(confirmation(store, "fan.bedroom", "fan", "turn_on", settings) == nil)
        #expect(confirmation(store, "climate.downstairs", "climate", "set_temperature", settings) == nil)
        #expect(confirmation(store, "select.house_mode", "select", "select_option", settings) == nil)
    }

    @MainActor
    @Test func actionConfirmationPolicyHonorsOffAllAndCategoryToggles() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "lock.front_door", state: "locked"),
            HAEntityDTO(
                entityID: "cover.garage_door",
                state: "closed",
                attributes: ["device_class": .string("garage")]
            ),
            HAEntityDTO(entityID: "scene.movie_night", state: "scening"),
            HAEntityDTO(entityID: "light.kitchen", state: "off")
        ])

        let offSettings = ActionConfirmationSettingsSnapshot(
            mode: .off,
            confirmsLockUnlocks: true,
            confirmsSecurityCoverOpens: true,
            confirmsScenes: true,
            confirmsScripts: true,
            confirmsOtherImpactfulActions: true
        )
        #expect(confirmation(store, "lock.front_door", "lock", "unlock", offSettings) == nil)

        let allSettings = ActionConfirmationSettingsSnapshot(
            mode: .all,
            confirmsLockUnlocks: false,
            confirmsSecurityCoverOpens: false,
            confirmsScenes: false,
            confirmsScripts: false,
            confirmsOtherImpactfulActions: false
        )
        #expect(confirmation(store, "light.kitchen", "light", "turn_on", allSettings) != nil)
        #expect(confirmation(store, "cover.garage_door", "cover", "close_cover", allSettings) != nil)

        let smartDisabledSettings = ActionConfirmationSettingsSnapshot(
            mode: .smart,
            confirmsLockUnlocks: false,
            confirmsSecurityCoverOpens: false,
            confirmsScenes: false,
            confirmsScripts: true,
            confirmsOtherImpactfulActions: true
        )
        #expect(confirmation(store, "lock.front_door", "lock", "unlock", smartDisabledSettings) == nil)
        #expect(confirmation(store, "cover.garage_door", "cover", "open_cover", smartDisabledSettings) == nil)
        #expect(confirmation(store, "scene.movie_night", "scene", "turn_on", smartDisabledSettings) == nil)
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

        let hostOnlyExternalURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "ha.keegan.me")
        #expect(hostOnlyExternalURL.absoluteString == "wss://ha.keegan.me/api/websocket")

        let hostOnlyExternalPathURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "example.com/ha")
        #expect(hostOnlyExternalPathURL.absoluteString == "wss://example.com/ha/api/websocket")

        let cleartextExternalURL = try HomeAssistantEndpointBuilder.webSocketURL(from: "http://ha.keegan.me")
        #expect(cleartextExternalURL.absoluteString == "wss://ha.keegan.me/api/websocket")
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
        let hostOnlyExternalURL = try HomeAssistantEndpointBuilder.cameraSnapshotURL(
            from: "ha.keegan.me",
            entityID: "camera.porch"
        )
        let cleartextExternalURL = try HomeAssistantEndpointBuilder.cameraSnapshotURL(
            from: "http://ha.keegan.me",
            entityID: "camera.garage"
        )
        #expect(nestedURL.absoluteString == "https://example.com/ha/api/camera_proxy/camera.front_door")
        #expect(hostOnlyExternalURL.absoluteString == "https://ha.keegan.me/api/camera_proxy/camera.porch")
        #expect(cleartextExternalURL.absoluteString == "https://ha.keegan.me/api/camera_proxy/camera.garage")
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
            clientID: "https://connect.homesteadcontrol.com",
            redirectURI: "homestead://auth",
            state: "state-123"
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        #expect(components.scheme == "https")
        #expect(components.host == "example.com")
        #expect(components.path == "/ha/auth/authorize")
        #expect(queryItems["response_type"] == "code")
        #expect(queryItems["client_id"] == "https://connect.homesteadcontrol.com")
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
            clientID: "https://connect.homesteadcontrol.com"
        )
        let body = String(decoding: request.formEncodedBody(), as: UTF8.self)

        #expect(body.contains("grant_type=authorization_code"))
        #expect(body.contains("code=code%20with%20space"))
        #expect(body.contains("client_id=https%3A%2F%2Fconnect.homesteadcontrol.com"))
    }

    @Test func refreshTokenRequestEncodesFormBody() throws {
        let request = HAOAuthTokenRequest(
            grant: .refreshToken("refresh-token"),
            clientID: "https://connect.homesteadcontrol.com"
        )
        let body = String(decoding: request.formEncodedBody(), as: UTF8.self)

        #expect(body.contains("grant_type=refresh_token"))
        #expect(body.contains("refresh_token=refresh-token"))
        #expect(body.contains("client_id=https%3A%2F%2Fconnect.homesteadcontrol.com"))
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

    @Test func getServicesForTargetRequestEncodesEntityTarget() throws {
        let request = HAWebSocketRequest.getServicesForTarget(id: 9, entityID: "valve.garden")
        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 9)
        #expect(object["type"] as? String == "get_services_for_target")
        let target = try #require(object["target"] as? [String: Any])
        let entityIDs = try #require(target["entity_id"] as? [String])
        #expect(entityIDs == ["valve.garden"])
    }

    @Test func getConfigRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.getConfig(id: 10)

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 10)
        #expect(object["type"] as? String == "get_config")
    }

    @Test func updateCoreConfigRequestEncodesHomeAssistantLocationName() throws {
        let request = HAWebSocketRequest.updateCoreConfig(id: 11, locationName: "Keegdom")

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 11)
        #expect(object["type"] as? String == "config/core/update")
        #expect(object["location_name"] as? String == "Keegdom")
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

    @Test func supervisorAppsRequestUsesHomeAssistantSupervisorAPIBridge() throws {
        let request = HAWebSocketRequest.supervisorAPI(
            id: 11,
            endpoint: "/addons",
            method: "get"
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["id"] as? Int == 11)
        #expect(object["type"] as? String == "supervisor/api")
        #expect(object["endpoint"] as? String == "/addons")
        #expect(object["method"] as? String == "get")
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

    @Test func serverEnvironmentMapsSupervisorAndOSInfo() throws {
        let config = HAConfigDTO(
            version: "2026.6.0",
            locationName: "Home",
            timeZone: "America/Chicago",
            internalURL: nil,
            externalURL: nil,
            state: nil,
            configSource: nil,
            unitSystem: nil
        )

        let environment = HAServerEnvironmentSnapshot(
            config: config,
            supervisorInfo: HASupervisorInfoDTO(version: "2026.06.1"),
            operatingSystemInfo: HAOperatingSystemInfoDTO(version: "16.2")
        )

        #expect(environment.installationMethod == .homeAssistantOS)
        #expect(environment.installationMethod.title == "Home Assistant OS")
        #expect(environment.coreVersion == "2026.6.0")
        #expect(environment.supervisorVersion == "2026.06.1")
        #expect(environment.operatingSystemVersion == "16.2")
    }

    @Test func serverEnvironmentFallsBackToCoreWhenSupervisorInfoIsUnavailable() throws {
        let config = HAConfigDTO(
            version: "2026.6.0",
            locationName: "Home",
            timeZone: "America/Chicago",
            internalURL: nil,
            externalURL: nil,
            state: nil,
            configSource: nil,
            unitSystem: nil
        )

        let environment = HAServerEnvironmentSnapshot(
            config: config,
            supervisorInfo: nil,
            operatingSystemInfo: nil
        )

        #expect(environment.installationMethod == .core)
        #expect(environment.installationMethod.title == "Core")
        #expect(environment.coreVersion == "2026.6.0")
        #expect(environment.supervisorVersion == nil)
        #expect(environment.operatingSystemVersion == nil)
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
        #expect(object["device_name"] as? String == "Homestead • Test Phone")
        #expect(object["manufacturer"] as? String == "Apple, Inc.")
        #expect(object["model"] as? String == "iPhone")
        #expect(object["os_name"] as? String == "iOS")
        #expect(object["os_version"] as? String == "26.5")
        #expect(object["supports_encryption"] as? Bool == false)
        #expect(object["push_url"] == nil)
        #expect(object["push_token"] == nil)
        #expect(object["app_data"] == nil)
    }

    @Test func mobileAppRegistrationRequestEncodesRemotePushMetadataInAppData() throws {
        let request = HAMobileAppRegistrationRequestFactory.makeRequest(
            deviceID: "device-123",
            appVersion: "1.2.3",
            deviceName: "Test Phone",
            manufacturer: "Apple, Inc.",
            model: "iPhone",
            osName: "iOS",
            osVersion: "26.5",
            pushRelayToken: "relay-token-123"
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let appData = try #require(object["app_data"] as? [String: Any])

        #expect(object["push_url"] == nil)
        #expect(object["push_token"] == nil)
        #expect(appData["push_url"] as? String == "https://api.homesteadcontrol.com/mobile-app/push")
        #expect(appData["push_token"] as? String == "relay-token-123")
    }

    @Test func mobileAppRegistrationRequestDoesNotAdvertiseLocalPushByDefault() throws {
        let request = HAMobileAppRegistrationRequestFactory.makeRequest(pushRelayToken: "relay-token-123")
        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let appData = try #require(object["app_data"] as? [String: Any])

        #expect(appData["push_websocket_channel"] == nil)
    }

    @Test func mobileAppRegistrationNameUsesHomeAssistantUserForGenericAppleDeviceNames() {
        #expect(HAMobileAppRegistrationRequestFactory.visibleDeviceName(
            for: "iPhone",
            userDisplayName: "Tyler"
        ) == "Homestead • Tyler • iPhone")

        #expect(HAMobileAppRegistrationRequestFactory.visibleDeviceName(
            for: "Tyler-iPhone",
            userDisplayName: "Tyler"
        ) == "Homestead • Tyler-iPhone")

        #expect(HAMobileAppRegistrationRequestFactory.visibleDeviceName(
            for: "iPad",
            userDisplayName: "  "
        ) == "Homestead • iPad")
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
                "state": "on",
                "domain": "light",
                "entity_id": "light.kitchen",
                "context_user_id": "user-123",
                "context_name": "Tyler",
                "context_message": "action Light: Turn on"
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
        #expect(entries[0].state == "on")
        #expect(rows[0].entityID == "light.kitchen")
        #expect(rows[0].entityDomain == .light)
        #expect(rows[0].sourceDomain == "light")
        #expect(rows[0].contextUserID == "user-123")
        #expect(rows[0].contextName == "Tyler")
        #expect(rows[0].attributionName == "Tyler")
        #expect(rows[0].triggerText == "triggered by action Light: Turn on")
        #expect(rows[0].iconSystemName == EntityDomain.light.systemImage)
        #expect(rows[0].matches(query: "pendant"))
        #expect(rows[1].title == "Automation")
        #expect(rows[1].iconSystemName == "list.bullet.clipboard")
    }

    @Test func logbookStateChangesMapToHomeAssistantStyleActivityMessages() throws {
        let date = try testDate("2026-06-13T15:30:00Z")
        let entries = [
            HALogbookEntryDTO(
                when: date,
                name: "Malissa",
                state: "not_home",
                domain: "person",
                entityID: "person.malissa"
            ),
            HALogbookEntryDTO(
                when: date,
                name: "Front Door Lock",
                state: "locked",
                domain: "lock",
                entityID: "lock.front_door"
            ),
            HALogbookEntryDTO(
                when: date,
                name: "Garage Door",
                state: "open",
                domain: "cover",
                entityID: "cover.garage_door"
            ),
            HALogbookEntryDTO(
                when: date,
                name: "Garage Entry Door",
                state: "off",
                domain: "binary_sensor",
                entityID: "binary_sensor.garage_entry_door"
            )
        ]

        let rows = HAActivityRow.makeRows(
            from: entries,
            entityDisplayName: { _ in nil },
            entityDeviceClass: { entityID in
                entityID == "binary_sensor.garage_entry_door" ? "door" : nil
            }
        )

        #expect(rows.map(\.message) == [
            "was detected away",
            "was locked",
            "was opened",
            "was closed"
        ])
    }

    @Test func securityActivityUsesStateSpecificIconsAndAttribution() throws {
        let date = try testDate("2026-06-13T15:30:00Z")
        let rows = HAActivityRow.makeRows(
            from: [
                HALogbookEntryDTO(
                    when: date,
                    name: "Front Door Lock",
                    state: "unlocked",
                    domain: "lock",
                    entityID: "lock.front_door"
                ),
                HALogbookEntryDTO(
                    when: date,
                    name: "Front Door Lock",
                    state: "locked",
                    domain: "lock",
                    entityID: "lock.front_door",
                    contextUserID: "user-123",
                    contextName: "Tyler",
                    contextMessage: "action Lock: Lock lock"
                )
            ],
            entityDisplayName: { _ in nil }
        )

        #expect(rows[0].message == "was unlocked")
        #expect(rows[0].iconSystemName == "lock.open.fill")
        #expect(rows[0].triggerText == nil)
        #expect(rows[0].attributionName == nil)
        #expect(rows[1].message == "was locked")
        #expect(rows[1].iconSystemName == "lock.fill")
        #expect(rows[1].triggerText == "triggered by action Lock: Lock lock")
        #expect(rows[1].attributionName == "Tyler")
    }

    @Test func activityRowsResolveCurrentUserAttributionAndHistoricalDoorIcons() throws {
        let date = try testDate("2026-06-13T15:30:00Z")
        let rows = HAActivityRow.makeRows(
            from: [
                HALogbookEntryDTO(
                    when: date,
                    name: "Front Door Lock",
                    state: "locked",
                    domain: "lock",
                    entityID: "lock.front_door",
                    contextUserID: "current-user-id",
                    contextMessage: "action Lock: Lock lock"
                ),
                HALogbookEntryDTO(
                    when: date,
                    name: "Garage Entry Door Door",
                    state: "on",
                    domain: "binary_sensor",
                    entityID: "binary_sensor.garage_entry_door"
                ),
                HALogbookEntryDTO(
                    when: date,
                    name: "Garage Entry Door Door",
                    state: "off",
                    domain: "binary_sensor",
                    entityID: "binary_sensor.garage_entry_door"
                )
            ],
            entityDisplayName: { _ in nil },
            entityDeviceClass: { entityID in
                entityID == "binary_sensor.garage_entry_door" ? "door" : nil
            },
            contextUserDisplayName: { userID in
                userID == "current-user-id" ? "Tyler" : nil
            }
        )

        #expect(rows[0].attributionName == "Tyler")
        #expect(rows[1].iconSystemName == "door.left.hand.open")
        #expect(rows[2].iconSystemName == "door.left.hand.closed")
    }

    @MainActor
    @Test func stateStoreResolvesPersonDisplayNameForUserID() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "person.tyler",
                state: "home",
                attributes: [
                    "friendly_name": .string("Tyler"),
                    "user_id": .string("user-123")
                ]
            )
        ])

        #expect(store.personDisplayName(forUserID: "user-123") == "Tyler")
        #expect(store.personDisplayName(forUserID: "missing-user") == nil)
    }

    @Test func securityActivityPresentationKeepsAllRowsByDefault() throws {
        let baseDate = try testDate("2026-06-13T15:30:00Z")
        let rows = (0..<55).map { index in
            HALogbookEntryDTO(
                when: baseDate.addingTimeInterval(TimeInterval(index)),
                name: "Front Door Lock",
                state: index.isMultiple(of: 2) ? "locked" : "unlocked",
                domain: "lock",
                entityID: "lock.front_door"
            )
        }

        let presentation = HALogbookPresentation.makeSecurityActivity(
            rows: HAActivityRow.makeRows(from: rows, entityDisplayName: { _ in nil }),
            entityIDs: ["lock.front_door"],
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(presentation.visibleRowCount == 55)
    }

    @Test func securityActivityCacheRetainsRowsAcrossViewLifetimes() async throws {
        let date = try testDate("2026-06-13T15:30:00Z")
        let rows = HAActivityRow.makeRows(
            from: [
                HALogbookEntryDTO(
                    when: date,
                    name: "Front Door Lock",
                    state: "locked",
                    domain: "lock",
                    entityID: "lock.front_door"
                )
            ],
            entityDisplayName: { _ in nil }
        )
        let cache = HASecurityActivityCache()
        let snapshot = HASecurityActivityCacheSnapshot(rows: rows, loadedAt: date)

        await cache.store(snapshot, for: "test-server|test-user|lock.front_door")
        let restored = await cache.snapshot(for: "test-server|test-user|lock.front_door")

        #expect(restored == snapshot)
    }

    @Test func supervisorAppsDecodeFilterInstalledAndMapStatus() throws {
        let payload = """
        {
            "addons": [
                {
                    "name": "Studio Code Server",
                    "slug": "core_vscode",
                    "description": "Edit Home Assistant configuration",
                    "version": "5.19.1",
                    "version_latest": "5.20.0",
                    "update_available": true,
                    "installed": true,
                    "available": true,
                    "icon": true,
                    "logo": true,
                    "state": "started"
                },
                {
                    "name": "Terminal",
                    "slug": "core_terminal",
                    "description": "Command line access",
                    "version": "9.15.0",
                    "version_latest": "9.15.0",
                    "update_available": false,
                    "installed": true,
                    "available": true,
                    "icon": false,
                    "logo": false,
                    "state": "stopped"
                },
                {
                    "name": "Store App",
                    "slug": "store_app",
                    "description": "Not installed",
                    "version": null,
                    "version_latest": "1.0.0",
                    "update_available": false,
                    "installed": false,
                    "available": true,
                    "icon": false,
                    "logo": false,
                    "state": null
                }
            ]
        }
        """

        let response = try JSONDecoder().decode(HASupervisorAppsResponseDTO.self, from: Data(payload.utf8))
        let apps = HASupervisorApp.installedApps(from: response)

        #expect(apps.map(\.slug) == ["core_vscode", "core_terminal"])
        #expect(apps[0].name == "Studio Code Server")
        #expect(apps[0].description == "Edit Home Assistant configuration")
        #expect(apps[0].installedVersion == "5.19.1")
        #expect(apps[0].latestVersion == "5.20.0")
        #expect(apps[0].updateAvailable)
        #expect(apps[0].hasIcon)
        #expect(apps[0].hasLogo)
        #expect(apps[0].iconPath == "/api/hassio/addons/core_vscode/icon")
        #expect(apps[0].logoPath == "/api/hassio/addons/core_vscode/logo")
        #expect(apps[0].status == .running)
        #expect(apps[1].status == .stopped)
        #expect(HASupervisorAppStatus(supervisorState: nil) == .unknown)
        #expect(HASupervisorAppStatus(supervisorState: "restarting") == .unknown)
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

    @Test func securityActivityPresentationKeepsOnlySummaryEntitiesAndNewestRows() throws {
        let baseDate = try testDate("2026-06-05T15:30:00Z")
        let entries = (0..<5).map { index in
            HALogbookEntryDTO(
                when: baseDate.addingTimeInterval(TimeInterval(index * 60)),
                name: "Front Door",
                message: index.isMultiple(of: 2) ? "was locked" : "was unlocked",
                domain: "lock",
                entityID: "lock.front_door"
            )
        } + [
            HALogbookEntryDTO(
                when: baseDate.addingTimeInterval(600),
                name: "Kitchen Light",
                message: "turned on",
                domain: "light",
                entityID: "light.kitchen"
            ),
            HALogbookEntryDTO(
                when: baseDate.addingTimeInterval(660),
                name: "Automation",
                message: "triggered",
                domain: "automation"
            )
        ]
        let rows = HAActivityRow.makeRows(from: entries, entityDisplayName: { $0 })
        let presentation = HALogbookPresentation.makeSecurityActivity(
            rows: rows,
            entityIDs: ["lock.front_door"],
            limit: 3,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(presentation.visibleRowCount == 3)
        #expect(presentation.sections.flatMap(\.rows).map(\.entityID) == Array(repeating: "lock.front_door", count: 3))
        #expect(presentation.sections.flatMap(\.rows).map(\.occurredAt) == [
            baseDate.addingTimeInterval(240),
            baseDate.addingTimeInterval(180),
            baseDate.addingTimeInterval(120)
        ])
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

    @Test func automationOverviewAndTraceTimelineUseAutomationConfigurationAndRuns() throws {
        let config: [String: JSONValue] = [
            "triggers": .array([.object([
                "trigger": .string("state"),
                "entity_id": .string("binary_sensor.entryway_occupancy"),
                "to": .string("on")
            ])]),
            "conditions": .array([.object([
                "condition": .string("state"),
                "entity_id": .string("person.tyler"),
                "state": .string("home")
            ])]),
            "actions": .array([.object([
                "action": .string("light.turn_on"),
                "target": .object(["entity_id": .array([.string("light.entryway_lamp")])])
            ])])
        ]

        let overview = HAAutomationOverviewBuilder.make(config: config) { id in
            [
                "binary_sensor.entryway_occupancy": "Entryway Occupancy",
                "person.tyler": "Tyler",
                "light.entryway_lamp": "Entryway Lamp"
            ][id] ?? id
        }
        #expect(overview.triggers.map(\.title) == ["When Entryway Occupancy is on"])
        #expect(overview.conditions.map(\.title) == ["Only if Tyler is home"])
        #expect(overview.actions.map(\.title) == ["Turn On light"])
        #expect(overview.actions.map(\.subtitle) == ["Entryway Lamp"])

        let modernOverview = HAAutomationOverviewBuilder.make(config: [
            "triggers": .array([.object(["trigger": .string("zone.left")])]),
            "conditions": .array([
                .object(["condition": .string("zone.not_in_zone")]),
                .object(["condition": .string("switch.is_off")])
            ]),
            "actions": .array([.object(["action": .string("input_select.select_option")])])
        ]) { $0 }
        #expect(modernOverview.triggers.map(\.title) == ["Zone left"])
        #expect(modernOverview.conditions.map(\.title) == ["Is not in zone", "Switch is off"])
        #expect(modernOverview.actions.map(\.title) == ["Input select: Select input select option"])

        let chooseOverview = HAAutomationOverviewBuilder.make(config: [
            "actions": .array([.object([
                "choose": .array([
                    .object([
                        "conditions": .array([.object([
                            "condition": .string("trigger"),
                            "id": .string("detected")
                        ])]),
                        "sequence": .array([.object([
                            "action": .string("light.turn_on"),
                            "target": .object(["entity_id": .array([.string("light.entryway_lamp"), .string("light.hallway_chandelier")])])
                        ])])
                    ]),
                    .object([
                        "conditions": .array([.object([
                            "condition": .string("trigger"),
                            "id": .string("cleared")
                        ])]),
                        "sequence": .array([.object(["action": .string("light.turn_off")])])
                    ])
                ])
            ])])
        ]) { id in
            ["light.entryway_lamp": "Entryway Lamp", "light.hallway_chandelier": "Hallway Chandelier"][id] ?? id
        }
        let choose = try #require(chooseOverview.actions.first)
        #expect(choose.title == "Choose between 2 options")
        #expect(choose.children.map(\.title) == ["Option 1: If triggered by detected", "Option 2: If triggered by cleared"])
        #expect(choose.children[0].groups.map(\.title) == ["Conditions", "Actions"])
        #expect(choose.children[0].groups[1].steps.map(\.title) == ["Turn on light"])
        #expect(choose.children[0].groups[1].steps.map(\.subtitle) == ["Entryway Lamp • Hallway Chandelier"])

        let scriptOverview = HAAutomationOverviewBuilder.makeScript(config: [
            "sequence": .array([.object([
                "if": .array([.object([
                    "condition": .string("state"),
                    "entity_id": .string("person.tyler"),
                    "state": .string("not_home")
                ])]),
                "then": .array([.object([
                    "action": .string("light.turn_off"),
                    "target": .object(["entity_id": .string("light.entryway_lamp")])
                ])])
            ])])
        ]) { id in
            ["person.tyler": "Tyler", "light.entryway_lamp": "Entryway Lamp"][id] ?? id
        }
        let conditional = try #require(scriptOverview.actions.first)
        #expect(conditional.title == "If a condition matches")
        #expect(conditional.groups.map(\.title) == ["Conditions", "Then Do"])
        #expect(conditional.groups[0].steps.map(\.title) == ["Only if Tyler is not home"])
        #expect(conditional.groups[1].steps.map(\.title) == ["Turn off light"])

        let legacyScriptOverview = HAAutomationOverviewBuilder.makeScript(
            config: [
                "sequence": .array([
                    .object([
                        "condition": .string("and"),
                        "conditions": .array([.object([
                            "condition": .string("not"),
                            "conditions": .array([.object([
                                "condition": .string("zone"),
                                "entity_id": .array([.string("person.tyler"), .string("person.melissa")]),
                                "zone": .string("zone.home")
                            ])])
                        ])])
                    ]),
                    .object([
                        "action": .string("light.turn_off"),
                        "data": .object(["label_id": .array([.string("upstairs"), .string("downstairs")])])
                    ]),
                    .object([
                        "action": .string("media_player.turn_off"),
                        "service_data": .object(["floor_id": .string("ground_floor")])
                    ]),
                    .object([
                        "action": .string("climate.set_preset_mode"),
                        "target": .object(["device_id": .string("thermostat")]),
                        "data": .object(["preset_mode": .string("away")])
                    ])
                ])
            ],
            entityName: { id in ["person.tyler": "Tyler", "person.melissa": "Melissa"][id] ?? id },
            areaName: { id in ["upstairs": "Upstairs", "downstairs": "Downstairs", "ground_floor": "Ground Floor"][id] },
            deviceName: { id in ["thermostat": "Hall Thermostat"][id] }
        )
        let conditionAction = try #require(legacyScriptOverview.actions.first)
        #expect(conditionAction.title == "Test if 1 condition matches")
        #expect(conditionAction.groups[0].steps.map(\.title) == ["Is not in zone"])
        #expect(conditionAction.groups[0].steps.map(\.subtitle) == ["Tyler • Melissa"])
        #expect(legacyScriptOverview.actions[1].subtitle == "Upstairs • Downstairs")
        #expect(legacyScriptOverview.actions[2].subtitle == "Ground Floor")
        #expect(legacyScriptOverview.actions[3].subtitle == "Hall Thermostat • Preset: Away")

        let traces = try JSONDecoder().decode([HAAutomationTraceDTO].self, from: Data(#"""
        [
          {"run_id":"finished","state":"stopped","script_execution":"finished","timestamp":{"start":"2026-06-05T15:10:00Z"}},
          {"run_id":"failed","state":"stopped","script_execution":"failed_conditions","timestamp":{"start":"2026-06-05T15:20:00Z"}},
          {"run_id":"ignored","state":"stopped","not_triggered":true,"timestamp":{"start":"2026-06-05T15:30:00Z"}}
        ]
        """#.utf8))
        let start = try testDate("2026-06-05T15:00:00Z")
        let end = try testDate("2026-06-05T16:00:00Z")
        let timeline = HAAutomationTraceTimeline.make(
            traces: traces,
            entityID: "automation.entryway_light",
            displayName: "Entryway Light",
            range: .oneHour,
            interval: DateInterval(start: start, end: end)
        )
        #expect(timeline.entries.map(\.title) == ["Triggered", "Failed"])
        #expect(timeline.summaryText == "2 executions • Now Failed")
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

    @Test func entityOrganizationAndScopedCategoryPayloadsDecode() throws {
        let organizationPayload = """
        [{
            "entity_id": "automation.arrival_lights",
            "labels": ["important"],
            "categories": {"automation": "presence"}
        }]
        """
        let organization = try JSONDecoder().decode(
            [HAEntityOrganizationDTO].self,
            from: Data(organizationPayload.utf8)
        )

        let categoryPayload = """
        [{"category_id": "presence", "name": "Presence", "icon": "mdi:home-account"}]
        """
        let categories = try JSONDecoder().decode(
            [HACategoryRegistryDTO].self,
            from: Data(categoryPayload.utf8)
        ).map { $0.withScope(.automation) }

        #expect(organization.first?.labels == ["important"])
        #expect(organization.first?.categories["automation"] == "presence")
        #expect(categories.first?.name == "Presence")
        #expect(categories.first?.scope == .automation)
    }

    @Test func areaRegistryResponseDecodesHomeAssistantAreaID() throws {
        let payload = """
        [
            {
                "area_id": "living_room",
                "name": "Living Room",
                "icon": "mdi:sofa",
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
        #expect(areas.first?.icon == "mdi:sofa")
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
        #expect(light?.testIconName == "lightbulb.fill")
        #expect(sensor?.displayName == "Hallway")
        #expect(sensor?.formattedValue == "72°F")
        #expect(sensor?.unit == "F")
        #expect(sensor?.testIconName == "thermometer.medium")
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
            ("input_select.house_mode", .select, "filemenu.and.selection"),
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

    @MainActor
    @Test func entityMapperMapsSelectOptionsFromSelectAndInputSelectDomains() throws {
        let selectDTO = HAEntityDTO(
            entityID: "select.hvac_mode",
            state: "home",
            attributes: ["options": .array([.string("home"), .string("away")])]
        )
        let inputSelectDTO = HAEntityDTO(
            entityID: "input_select.house_mode",
            state: "Home",
            attributes: ["options": .array([.string("Morning"), .string("Home"), .string("Away")])]
        )

        let select = try #require(EntityMapper.selectEntity(from: selectDTO))
        let inputSelect = try #require(EntityMapper.selectEntity(from: inputSelectDTO))
        let inputSelectHomeEntity = EntityMapper.homeEntity(from: inputSelectDTO)
        let inputSelectBox = HAEntityState(homeEntity: inputSelectHomeEntity, selectEntity: inputSelect)
        let inputSelectPresentation = DashboardEntityPresentation(entityBox: inputSelectBox)

        #expect(select.options == ["home", "away"])
        #expect(inputSelect.options == ["Morning", "Home", "Away"])
        #expect(inputSelectHomeEntity.domain == .select)
        #expect(inputSelectPresentation.detailKind == .select)
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
                "entity_picture": .string("/api/image/core-update"),
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
        #expect(update.entityPicturePath == "/api/image/core-update")
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

    @Test func updateActionablePresentationShowsOnlyAvailableAndInProgressUpdates() throws {
        let core = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.home_assistant_core_update",
            state: "on",
            attributes: ["friendly_name": .string("Home Assistant Core")]
        )))
        let bridge = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.bridge",
            state: "on",
            attributes: [
                "friendly_name": .string("Bridge"),
                "in_progress": .number(24)
            ]
        )))
        let current = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.current",
            state: "off",
            attributes: ["friendly_name": .string("Current")]
        )))
        let skipped = try #require(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.skipped",
            state: "off",
            attributes: [
                "friendly_name": .string("Skipped"),
                "skipped_version": .string("1.1")
            ]
        )))

        let presentation = HAUpdatePresentation.makeActionable(
            updates: [current, skipped, bridge, core]
        )

        #expect(presentation.visibleCount == 2)
        #expect(presentation.sections.map(\.title) == ["Available Updates"])
        #expect(presentation.sections.first?.updates.map(\.entityID) == [
            "update.home_assistant_core_update",
            "update.bridge"
        ])
        #expect(presentation.summary.availableCount == 1)
        #expect(presentation.summary.inProgressCount == 1)
        #expect(presentation.summary.totalCount == 4)
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
        #expect(cover.testIconName == "blinds.horizontal.open")
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
        #expect(garageCover.testIconName == "door.garage.closed")
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

        #expect(curtainCover.testIconName == "curtains.open")
        #expect(gateCover.testIconName == "pedestrian.gate.closed")
        #expect(shadeCover.testIconName == "window.shade.closed")
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
        #expect(media.testIconName == "speaker.wave.2.fill")
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
        #expect(carbonMonoxide.testIconName == "carbon.monoxide.cloud.fill")
        #expect(carbonMonoxide.isSecurityRelevant)
        #expect(batteryCharging.displayKind == .batteryCharging)
        #expect(batteryCharging.displaySubtitle == "Not Charging")
        #expect(batteryCharging.testIconName == "battery.100percent")
        #expect(vibration.displayKind == .vibration)
        #expect(vibration.displaySubtitle == "Vibration Detected")
        #expect(vibration.testIconName == "waveform.path")
        #expect(vibration.isSecurityRelevant)
        #expect(update.displayKind == .update)
        #expect(update.displaySubtitle == "Update Available")
        #expect(update.testIconName == "arrow.trianglehead.2.clockwise")
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

    @Test func climateSetpointAdjustmentClampsAndRoundsSingleTemperature() {
        let adjustment = ClimateSetpointAdjustment(
            minimumTemperature: 50,
            maximumTemperature: 90,
            step: 0.5
        )

        #expect(adjustment.clampedSingleTemperature(72.24) == 72)
        #expect(adjustment.clampedSingleTemperature(72.26) == 72.5)
        #expect(adjustment.clampedSingleTemperature(42) == 50)
        #expect(adjustment.clampedSingleTemperature(96) == 90)
    }

    @Test func climateSetpointAdjustmentPreservesValidHeatCoolRange() {
        let adjustment = ClimateSetpointAdjustment(
            minimumTemperature: 50,
            maximumTemperature: 90,
            step: 1
        )

        let raisedLow = adjustment.adjustedLowTemperature(
            currentLowTemperature: 72,
            currentHighTemperature: 74,
            delta: 5
        )
        #expect(raisedLow.lowTemperature == 74)
        #expect(raisedLow.highTemperature == 74)

        let loweredHigh = adjustment.adjustedHighTemperature(
            currentLowTemperature: 68,
            currentHighTemperature: 70,
            delta: -5
        )
        #expect(loweredHigh.lowTemperature == 68)
        #expect(loweredHigh.highTemperature == 68)

        let clampedRange = adjustment.clampedRange(lowTemperature: 95, highTemperature: 80)
        #expect(clampedRange.lowTemperature == 90)
        #expect(clampedRange.highTemperature == 90)
    }

    @Test func sensorFormattingHandlesUnitsAndUnavailableStates() {
        let humidity = SensorEntity(
            entityID: "sensor.humidity",
            displayName: "Humidity",
            value: "44.2",
            unit: "%",
            deviceClass: "humidity",
            lastUpdated: nil
        )
        let energy = SensorEntity(
            entityID: "sensor.energy",
            displayName: "Energy",
            value: "12.3456",
            unit: "kWh",
            deviceClass: "energy",
            lastUpdated: nil
        )
        let unavailable = SensorEntity(
            entityID: "sensor.unavailable",
            displayName: "Unavailable",
            value: "unavailable",
            unit: nil,
            deviceClass: nil,
            lastUpdated: nil
        )
        let textState = SensorEntity(
            entityID: "sensor.location_permission",
            displayName: "Location Permission",
            value: "authorized_always",
            unit: nil,
            deviceClass: nil,
            lastUpdated: nil
        )
        let lowBattery = SensorEntity(
            entityID: "sensor.front_door_battery",
            displayName: "Front Door Battery",
            value: "18",
            unit: "%",
            deviceClass: "battery",
            lastUpdated: nil
        )
        let waterClear = SensorEntity(
            entityID: "sensor.laundry_leak",
            displayName: "Laundry Leak",
            value: "off",
            unit: nil,
            deviceClass: "water",
            lastUpdated: nil
        )
        let waterDetected = SensorEntity(
            entityID: "sensor.laundry_leak",
            displayName: "Laundry Leak",
            value: "on",
            unit: nil,
            deviceClass: "water",
            lastUpdated: nil
        )

        #expect(humidity.formattedValue == "44%")
        #expect(humidity.valueText == "44")
        #expect(humidity.unitText == "%")
        #expect(humidity.displayKind == .humidity)
        #expect(humidity.gaugePresentation?.statusDisplayText == "Comfortable")
        #expect(humidity.gaugePresentation?.sections.map(\.status) == [.critical, .warning, .nominal, .warning, .critical])
        #expect(humidity.gaugePresentation?.sections.map(\.range.upperBound) == [20, 30, 60, 70, 100])
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

    @Test func sensorGaugePresentationInfersSafeRangesAndStatus() {
        let lowBattery = SensorEntity(
            entityID: "sensor.front_door_battery",
            displayName: "Front Door Battery",
            value: "8",
            unit: "%",
            deviceClass: "battery",
            lastUpdated: nil
        )
        let batteryGauge = lowBattery.gaugePresentation
        #expect(batteryGauge?.range == 0...100)
        #expect(batteryGauge?.rangeSource == .deviceClass)
        #expect(batteryGauge?.status == .critical)
        #expect(batteryGauge?.statusDisplayText == "Critical")
        #expect(batteryGauge?.isDashboardFeatureEligible == true)
        #expect(batteryGauge?.sections.map(\.status) == [.critical, .warning, .nominal])

        let warmTemperature = SensorEntity(
            entityID: "sensor.living_room_temperature",
            displayName: "Living Room Temperature",
            value: "82",
            unit: "F",
            deviceClass: "temperature",
            lastUpdated: nil
        )
        let temperatureGauge = warmTemperature.gaugePresentation
        #expect(temperatureGauge?.range == 0...120)
        #expect(temperatureGauge?.status == .high)
        #expect(temperatureGauge?.statusDisplayText == "High")
        #expect(temperatureGauge?.isDashboardFeatureEligible == true)

        let tankLevel = SensorEntity(
            entityID: "sensor.water_tank",
            displayName: "Water Tank Level",
            value: "72",
            unit: "%",
            deviceClass: nil,
            lastUpdated: nil,
            suggestedMinimumValue: 10,
            suggestedMaximumValue: 90
        )
        let levelGauge = tankLevel.gaugePresentation
        #expect(levelGauge?.range == 10...90)
        #expect(levelGauge?.rangeSource == .homeAssistant)
        #expect(levelGauge?.isDashboardFeatureEligible == true)

        let textSensor = SensorEntity(
            entityID: "sensor.mode",
            displayName: "Mode",
            value: "auto",
            unit: nil,
            deviceClass: nil,
            lastUpdated: nil
        )
        #expect(textSensor.gaugePresentation == nil)

        let alkalinity = SensorEntity(
            entityID: "sensor.apex_alk",
            displayName: "Alk",
            value: "9.68",
            unit: "dKH",
            deviceClass: nil,
            stateClass: .measurement,
            displayPrecision: 2,
            lastUpdated: nil
        )
        let alkalinityGauge = alkalinity.gaugePresentation
        #expect(alkalinity.valueText == "9.68")
        #expect(alkalinityGauge?.range == 0...12)
        #expect(alkalinityGauge?.rangeSource == .valueSuggested)
        #expect(alkalinityGauge?.isDashboardFeatureEligible == true)
        #expect(alkalinityGauge?.sections.map(\.status) == [.nominal])

        let lifetimeTotal = SensorEntity(
            entityID: "sensor.lifetime_energy",
            displayName: "Lifetime Energy",
            value: "12345",
            unit: "kWh",
            deviceClass: "energy",
            stateClass: .totalIncreasing,
            lastUpdated: nil
        )
        #expect(lifetimeTotal.gaugePresentation == nil)
    }

    @Test func serviceRegistryBuildsGenericEntityActions() {
        let registry = HAServiceRegistry(domains: [
            "valve": [
                "open_valve": HAServiceDescription(name: "Open", fields: [:]),
                "set_position": HAServiceDescription(
                    name: "Set position",
                    fields: ["position": .object(["required": .bool(true)])]
                )
            ]
        ])

        let actions = registry.actions(for: "valve.garden")
        #expect(actions.map(\.service) == ["open_valve", "set_position"])
        #expect(actions[0].requiresFields == false)
        #expect(actions[1].requiresFields == true)
        #expect(registry.actions(for: "light.kitchen").isEmpty)
    }

    @Test func gaugeZoneConfigurationValidatesAndOverridesPresentation() throws {
        let humidity = SensorEntity(
            entityID: "sensor.living_room_humidity",
            displayName: "Living Room Humidity",
            value: "72",
            unit: "%",
            deviceClass: "humidity",
            lastUpdated: nil
        )
        let presentation = try #require(humidity.gaugePresentation)
        let custom = GaugeZoneConfiguration(
            lowerBound: 10,
            upperBound: 90,
            boundaries: [25, 35, 55, 65],
            colors: [
                .standard(for: .critical), .standard(for: .warning), .standard(for: .nominal),
                .standard(for: .warning), .standard(for: .critical)
            ]
        )
        let resolved = presentation.applying(zoneConfiguration: custom)

        #expect(custom.isValid)
        #expect(resolved.range == 10...90)
        #expect(resolved.rangeSource == .userConfigured)
        #expect(resolved.sections.map(\.range.upperBound) == [25, 35, 55, 65, 90])
        #expect(resolved.status == presentation.status)
        #expect(resolved.sections.map(\.color) == custom.colors)

        let invalid = GaugeZoneConfiguration(
            lowerBound: 0,
            upperBound: 100,
            boundaries: [30, 20],
            colors: [.standard(for: .warning), .standard(for: .nominal), .standard(for: .warning)]
        )
        #expect(!invalid.isValid)
        let invalidResolved = presentation.applying(zoneConfiguration: invalid)
        #expect(invalidResolved.range == presentation.range)
        #expect(invalidResolved.sections.map(\.status) == presentation.sections.map(\.status))
    }

    @Test func widgetGaugeAppliesDecimalFiveZoneOverrides() {
        let gauge = WidgetGaugePresentation(
            value: 56.25,
            lowerBound: 0,
            upperBound: 100,
            valueText: "56.25",
            unitText: "%",
            status: .nominal,
            statusDisplayText: "Normal",
            sections: [WidgetGaugeSection(lowerBound: 0, upperBound: 100, color: .green)],
            accessibilityLabel: "Humidity gauge",
            accessibilityValue: "56.25%"
        )
        let resolved = gauge.applyingFiveZoneConfiguration(
            lowerBound: 5.5,
            boundaries: [20.25, 30.5, 60.75, 70.125],
            upperBound: 95.5
        )

        #expect(resolved.lowerBound == 5.5)
        #expect(resolved.upperBound == 95.5)
        #expect(resolved.sections.map(\.upperBound) == [20.25, 30.5, 60.75, 70.125, 95.5])
        #expect(resolved.sections.map(\.color) == [.red, .orange, .green, .orange, .red])
        #expect(resolved.status == .nominal)

        let invalid = gauge.applyingFiveZoneConfiguration(
            lowerBound: 0,
            boundaries: [30, 20, 60, 70],
            upperBound: 100
        )
        #expect(invalid.sections.count == 1)
        #expect(invalid.lowerBound == 0)
        #expect(invalid.upperBound == 100)
    }

    @Test func entityMapperCarriesSensorGaugeRangeMetadata() throws {
        let dto = HAEntityDTO(
            entityID: "sensor.water_tank",
            state: "62",
            attributes: [
                "unit_of_measurement": .string("%"),
                "min": .number(10),
                "max": .number(90)
            ]
        )

        let sensor = try #require(EntityMapper.sensorEntity(from: dto))
        #expect(sensor.suggestedMinimumValue == 10)
        #expect(sensor.suggestedMaximumValue == 90)
        #expect(sensor.gaugePresentation?.range == 10...90)
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
        #expect(carbonDioxide.testIconName == "carbon.dioxide.cloud.fill")
        #expect(carbonDioxide.formattedValue == "842.4 ppm")
        #expect(particulateMatter.displayKind == .particulateMatter)
        #expect(particulateMatter.testIconName == "aqi.medium")
        #expect(particulateMatter.formattedValue == "3.46 µg/m³")
        #expect(timestamp.displayKind == .date)
        #expect(timestamp.testIconName == "calendar")
        #expect(timestamp.formattedValue == "2026-06-01T12:00:00Z")
        #expect(carbonMonoxide.displayKind == .carbonMonoxide)
        #expect(carbonMonoxide.testIconName == "carbon.monoxide.cloud.fill")
        #expect(carbonMonoxide.isAlerting)
        #expect(carbonMonoxide.displaySubtitle == "CO Detected")
        #expect(atmosphericPressure.displayKind == .pressure)
        #expect(atmosphericPressure.testIconName == "barometer")
        #expect(atmosphericPressure.formattedValue == "29.9 inHg")
        #expect(reactivePower.displayKind == .reactivePower)
        #expect(reactivePower.testIconName == "bolt.fill")
        #expect(reactivePower.formattedValue == "1.23 var")
        #expect(windSpeed.displayKind == .speed)
        #expect(windSpeed.testIconName == "speedometer")
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
                lastUpdated: nil
            ),
            LightEntity(
                entityID: "light.a_lamp",
                displayName: "A Lamp",
                isOn: true,
                brightness: 128,
                supportsBrightness: true,
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
                lastUpdated: nil
            ),
            SensorEntity(
                entityID: "sensor.battery",
                displayName: "Battery",
                value: "18",
                unit: "%",
                deviceClass: "battery",
                lastUpdated: nil
            )
        ]
        let covers = [
            CoverEntity(
                entityID: "cover.living_room_shades",
                displayName: "Living Room Shades",
                state: "open",
                position: 70,
                deviceClass: "shade"
            ),
            CoverEntity(
                entityID: "cover.garage_door",
                displayName: "Garage Door",
                state: "closed",
                position: 0,
                deviceClass: "garage"
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
                deviceName: nil,
                icon: .sfSymbol("lightbulb.fill", provenance: .haSemanticMapping)
            ),
            WidgetLightSnapshot(
                entityID: "light.z_lamp",
                displayName: "Z Lamp",
                isOn: false,
                brightnessPercentage: nil,
                areaName: nil,
                deviceName: nil,
                icon: .sfSymbol("lightbulb.fill", provenance: .haSemanticMapping)
            )
        ])

        #expect(WidgetSharedStore.switchSnapshots(from: entities) == [
            WidgetSwitchSnapshot(
                entityID: "switch.coffee",
                displayName: "Coffee",
                isOn: true,
                systemImage: "lightswitch.on.fill",
                areaName: nil,
                deviceName: nil,
                icon: .sfSymbol("lightswitch.on.fill", provenance: .homesteadSemanticMapping)
            ),
            WidgetSwitchSnapshot(
                entityID: "switch.fan",
                displayName: "Fan",
                isOn: false,
                systemImage: "lightswitch.off.fill",
                areaName: nil,
                deviceName: nil,
                icon: .sfSymbol("lightswitch.off.fill", provenance: .homesteadSemanticMapping)
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
                deviceName: nil,
                icon: .sfSymbol("door.garage.closed", provenance: .haSemanticMapping)
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
                deviceName: nil,
                icon: .sfSymbol("window.shade.open", provenance: .haSemanticMapping)
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
                deviceName: nil,
                icon: .sfSymbol("fan.fill", provenance: .haSemanticMapping)
            ),
            WidgetFanSnapshot(
                entityID: "fan.office",
                displayName: "Office Fan",
                isOn: false,
                statusText: "Off",
                isAvailable: true,
                areaName: nil,
                deviceName: nil,
                icon: .sfSymbol("fan.fill", provenance: .haSemanticMapping)
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
                deviceName: nil,
                icon: .sfSymbol("lock.fill", provenance: .homesteadSemanticMapping)
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
                deviceName: nil,
                icon: .sfSymbol("lock.open.fill", provenance: .homesteadSemanticMapping)
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
                deviceName: nil,
                icon: .sfSymbol("battery.75percent", provenance: .haSemanticMapping),
                gauge: WidgetGaugePresentation(
                    value: 18,
                    lowerBound: 0,
                    upperBound: 100,
                    valueText: "18",
                    unitText: "%",
                    status: .warning,
                    statusDisplayText: "Warning",
                    sections: [
                        WidgetGaugeSection(lowerBound: 0, upperBound: 10, color: .red),
                        WidgetGaugeSection(lowerBound: 10, upperBound: 20, color: .orange),
                        WidgetGaugeSection(lowerBound: 20, upperBound: 100, color: .green)
                    ],
                    accessibilityLabel: "Battery gauge",
                    accessibilityValue: "18%, warning"
                )
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
                deviceName: nil,
                icon: .sfSymbol("thermometer.medium", provenance: .haSemanticMapping)
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
                deviceName: nil,
                icon: .sfSymbol("person", provenance: .homesteadSemanticMapping)
            ),
            WidgetPresenceSnapshot(
                entityID: "person.tyler",
                displayName: "Tyler",
                statusText: "Home",
                isHome: true,
                systemImage: "person.fill",
                isAvailable: true,
                areaName: nil,
                deviceName: nil,
                icon: .sfSymbol("person.fill", provenance: .homesteadSemanticMapping)
            )
        ])

        #expect(WidgetSharedStore.actionSnapshots(from: entities) == [
            WidgetActionSnapshot(
                entityID: "scene.movie_time",
                displayName: "Movie Time",
                domain: "scene",
                systemImage: "sparkles",
                areaName: nil,
                deviceName: nil,
                icon: .sfSymbol("sparkles", provenance: .homesteadSemanticMapping)
            ),
            WidgetActionSnapshot(
                entityID: "script.good_night",
                displayName: "Good Night",
                domain: "script",
                systemImage: "play.circle",
                areaName: nil,
                deviceName: nil,
                icon: .sfSymbol("play.circle", provenance: .homesteadSemanticMapping)
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
    @Test func connectionSettingsPrefersExistingCredentialOverStaleSavedBaseURL() throws {
        let suiteName = "com.tyler.Homestead.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("http://homeassistant.local:8123", forKey: "homeAssistantBaseURL")

        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: "https://home.example.com")
        )
        let settings = HAConnectionSettings(defaults: defaults, tokenStore: tokenStore)

        #expect(settings.baseURL == "https://home.example.com")
    }

    @MainActor
    @Test func connectionSettingsUsesRemoteURLAsSyncedIdentityWhenAvailable() throws {
        let settings = HAConnectionSettings(baseURL: "https://old.example.com", defaults: try isolatedDefaults(), tokenStore: InMemoryHAOAuthTokenStore())

        settings.applySyncSnapshot(HomesteadConnectionSyncSnapshot(
            baseURL: "http://homeassistant.local:8123",
            internalURL: "http://homeassistant.local:8123",
            externalURL: "https://home.example.com"
        ))

        #expect(settings.baseURL == "https://home.example.com")
        #expect(settings.internalURL == "http://homeassistant.local:8123")
        #expect(settings.externalURL == "https://home.example.com")
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
        #expect(restoredSettings.internalNetworkSSIDs == ["Home Wi-Fi"])
    }

    @Test func connectionSettingsNormalizesMultipleInternalNetworkSSIDs() {
        let normalized = HAConnectionSettings.normalizedSSIDs([
            " Home Wi-Fi ",
            "",
            "home wi-fi",
            "Cabin",
            "  CABIN  ",
            "Guest"
        ])

        #expect(normalized == ["Home Wi-Fi", "Cabin", "Guest"])
    }

    @MainActor
    @Test func connectionSettingsInternalURLSaveUpdatesIdentityOnlyWithoutExternalURL() throws {
        let settings = HAConnectionSettings(
            baseURL: "http://old.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )
        settings.internalURL = "http://old.local:8123"
        settings.externalURL = ""

        settings.saveInternalURLSettings(
            internalURL: " http://new.local:8123 ",
            internalNetworkSSIDs: [" Home Wi-Fi ", "home wi-fi", "Cabin"]
        )

        #expect(settings.baseURL == "http://new.local:8123")
        #expect(settings.internalURL == "http://new.local:8123")
        #expect(settings.externalURL == "")
        #expect(settings.internalNetworkSSIDs == ["Home Wi-Fi", "Cabin"])
    }

    @MainActor
    @Test func connectionSettingsInternalURLSavePreservesIdentityWhenExternalURLExists() throws {
        let settings = HAConnectionSettings(
            baseURL: "https://remote.example.com",
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )
        settings.internalURL = "http://old.local:8123"
        settings.externalURL = "https://remote.example.com"

        settings.saveInternalURLSettings(
            internalURL: "http://new.local:8123",
            internalNetworkSSIDs: ["Home Wi-Fi"]
        )

        #expect(settings.baseURL == "https://remote.example.com")
        #expect(settings.internalURL == "http://new.local:8123")
        #expect(settings.externalURL == "https://remote.example.com")
        #expect(settings.internalNetworkSSIDs == ["Home Wi-Fi"])
    }

    @MainActor
    @Test func connectionSettingsExternalURLSaveKeepsBaseURLAlignedWithExternalRoute() throws {
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )
        settings.internalURL = "http://homeassistant.local:8123"
        settings.externalURL = ""

        settings.saveExternalURL(" https://remote.example.com ")

        #expect(settings.baseURL == "https://remote.example.com")
        #expect(settings.internalURL == "http://homeassistant.local:8123")
        #expect(settings.externalURL == "https://remote.example.com")

        settings.saveExternalURL(" ")

        #expect(settings.baseURL == "http://homeassistant.local:8123")
        #expect(settings.externalURL == "")
    }

    @Test func connectionRouteResolverPrefersInternalRouteOnHomeNetwork() {
        let settings = HAConnectionRoutingSettingsSnapshot(
            baseURLString: "https://home.example.com",
            internalURLString: "http://homeassistant.local:8123",
            externalURLString: "https://remote.example.com",
            homeNetworkName: "",
            internalNetworkSSIDs: ["Home Wi-Fi"]
        )

        let selection = HAConnectionRouteResolver.resolve(
            settings: settings,
            networkContext: HAConnectionNetworkContext(
                isNetworkAvailable: true,
                isLikelyHomeNetwork: true,
                currentWiFiSSID: "Home Wi-Fi"
            )
        )

        #expect(selection.authenticationBaseURLString == "https://home.example.com")
        #expect(selection.candidates.map(\.route) == [.internalURL, .externalURL, .current])
        #expect(selection.candidates.map(\.baseURLString) == [
            "http://homeassistant.local:8123",
            "https://remote.example.com",
            "https://home.example.com"
        ])
    }

    @Test func connectionRouteResolverUsesExternalRouteOnUnlistedWifi() {
        let settings = HAConnectionRoutingSettingsSnapshot(
            baseURLString: "https://home.example.com",
            internalURLString: "http://homeassistant.local:8123",
            externalURLString: "https://remote.example.com",
            homeNetworkName: "",
            internalNetworkSSIDs: ["Home Wi-Fi"]
        )

        let selection = HAConnectionRouteResolver.resolve(
            settings: settings,
            networkContext: HAConnectionNetworkContext(
                isNetworkAvailable: true,
                isLikelyHomeNetwork: true,
                currentWiFiSSID: "Work Wi-Fi"
            )
        )

        #expect(selection.candidates.map(\.route) == [.externalURL, .current])
        #expect(selection.candidates.map(\.baseURLString) == [
            "https://remote.example.com",
            "https://home.example.com"
        ])
    }

    @Test func connectionRouteResolverUsesExternalRouteWhenNoLocalNetworkIsSaved() {
        let settings = HAConnectionRoutingSettingsSnapshot(
            baseURLString: "https://home.example.com",
            internalURLString: "http://homeassistant.local:8123",
            externalURLString: "https://remote.example.com",
            homeNetworkName: ""
        )

        let selection = HAConnectionRouteResolver.resolve(
            settings: settings,
            networkContext: HAConnectionNetworkContext(
                isNetworkAvailable: true,
                isLikelyHomeNetwork: true,
                currentWiFiSSID: "Home Wi-Fi"
            )
        )

        #expect(selection.candidates.map(\.route) == [.externalURL, .current])
        #expect(selection.candidates.map(\.baseURLString) == [
            "https://remote.example.com",
            "https://home.example.com"
        ])
    }

    @Test func connectionRouteResolverUsesInternalRouteWhenNoExternalRouteExists() {
        let settings = HAConnectionRoutingSettingsSnapshot(
            baseURLString: "http://homeassistant.local:8123",
            internalURLString: "http://homeassistant.local:8123",
            externalURLString: "",
            homeNetworkName: ""
        )

        let selection = HAConnectionRouteResolver.resolve(
            settings: settings,
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: true)
        )

        #expect(selection.candidates.map(\.route) == [.internalURL])
        #expect(selection.candidates.map(\.baseURLString) == ["http://homeassistant.local:8123"])
    }

    @Test func connectionRouteResolverUsesExternalRouteAwayFromHomeAndFallsBackToCurrentURL() {
        let settings = HAConnectionRoutingSettingsSnapshot(
            baseURLString: "https://home.example.com",
            internalURLString: "http://homeassistant.local:8123",
            externalURLString: "https://remote.example.com",
            homeNetworkName: "",
            internalNetworkSSIDs: ["Home Wi-Fi"]
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
        #expect(service.connectionStatus == .preparing)

        try store.saveCredential(testCredential(expiresAt: now.addingTimeInterval(-1)))
        await service.refreshAuthState()
        if case .accessTokenExpired = service.authState {
            // Expected expired access-token state.
        } else {
            Issue.record("Expected expired auth state.")
        }
        #expect(service.connectionStatus == .preparing)

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
        let deviceIDStore = InMemoryHAMobileAppDeviceIDStore(deviceID: "stable-device-id")
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
            mobileAppDeviceIDStore: deviceIDStore,
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token"),
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
        #expect(savedRegistration.deviceID == "stable-device-id")
        #expect(client.lastRegistrationRequest?.deviceID == "stable-device-id")
        #expect(client.lastRegistrationRequest?.appData?["push_url"]?.stringValue == "https://api.homesteadcontrol.com/mobile-app/push")
        #expect(client.lastRegistrationRequest?.appData?["push_token"]?.stringValue == "stable-relay-token")
        #expect(client.lastRegistrationRequest?.appData?["push_websocket_channel"] == nil)
        #expect(savedRegistration.webhookID == "webhook-created")
        #expect(savedRegistration.supportsCloudPushNotifications == true)
        #expect(savedRegistration.supportsWebSocketNotifications == false)
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
    @Test func serviceUpdatesExistingMobileAppRegistrationWithRemotePushMetadata() async throws {
        let configuration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let existingRegistration = HAMobileAppRegistrationInfo(
            serverIdentifier: configuration.dataSourceID,
            deviceID: "existing-device-id",
            appVersion: "1.0",
            deviceName: "Homestead • iPhone",
            webhookID: "existing-webhook",
            supportsWebSocketNotifications: true,
            supportsCloudPushNotifications: true
        )
        let store = InMemoryHAMobileAppRegistrationStore(registration: existingRegistration)
        let client = StubHAMobileAppClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppClient: client,
            mobileAppRegistrationStore: store,
            mobileAppDeviceIDStore: InMemoryHAMobileAppDeviceIDStore(deviceID: "stable-device-id"),
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token"),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(
                    credential: testCredential(accessToken: "token-a")
                )
            )
        )
        let settings = HAConnectionSettings(
            baseURL: configuration.baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )

        await service.refreshMobileAppPushRegistrationIfNeeded(settings: settings)

        #expect(client.lastRegistrationRequest == nil)
        #expect(client.lastRegistrationUpdate?.appData?["push_url"]?.stringValue == "https://api.homesteadcontrol.com/mobile-app/push")
        #expect(client.lastRegistrationUpdate?.appData?["push_token"]?.stringValue == "stable-relay-token")
        #expect(client.lastRegistrationUpdate?.appData?["push_websocket_channel"] == nil)
        #expect(client.lastRegistrationToUpdate?.webhookID == "existing-webhook")

        let savedRegistration = try #require(try store.readRegistration())
        #expect(savedRegistration.deviceID == "existing-device-id")
        #expect(savedRegistration.webhookID == "existing-webhook")
        #expect(savedRegistration.supportsCloudPushNotifications == true)
        #expect(savedRegistration.supportsWebSocketNotifications == false)
    }

    @MainActor
    @Test func serviceConnectionCanSkipAutomaticMobileAppRegistration() async throws {
        let store = InMemoryHAMobileAppRegistrationStore()
        let mobileAppClient = StubHAMobileAppClient()
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: mobileAppClient,
            mobileAppRegistrationStore: store,
            mobileAppDeviceIDStore: InMemoryHAMobileAppDeviceIDStore(deviceID: "preview-device-id"),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(
                    credential: testCredential(accessToken: "token-a")
                )
            ),
            automaticallyRegistersMobileApp: false
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")

        #expect(try store.readRegistration() == nil)
        #expect(mobileAppClient.lastRegistrationRequest == nil)
        #expect(webSocketClient.mobileAppPushNotificationSubscription == nil)
        #expect(service.connectionStatus == .connected)
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

    @Test func apnsDeviceTokenHexStringIsLowercase() {
        let token = Data([0x00, 0x0f, 0x10, 0xab, 0xff])

        #expect(token.lowercaseHexString == "000f10abff")
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
        let remoteClient = StubNativeRemoteNotificationRegistrationClient()
        let service = NativeNotificationService(
            client: client,
            remoteRegistrationClient: remoteClient,
            pushRegistrationClient: StubHomesteadPushTokenRegistrationClient(),
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token")
        )

        await service.requestAuthorization()

        #expect(service.status == expectedStatus)
        #expect(service.lastErrorMessage == nil)
        #expect(client.didRequestAuthorization)
        #expect(client.currentStatusCallCount == 1)
        #expect(remoteClient.registerCallCount == 1)
        #expect(service.remoteRegistrationState == .registeringWithAPNS)
    }

    @MainActor
    @Test func nativeNotificationServiceRegistersBackendAfterAPNSToken() async throws {
        let client = StubNativeNotificationPermissionClient(currentStatus: .unknown)
        let pushClient = StubHomesteadPushTokenRegistrationClient()
        let service = NativeNotificationService(
            client: client,
            remoteRegistrationClient: StubNativeRemoteNotificationRegistrationClient(),
            pushRegistrationClient: pushClient,
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token")
        )

        await service.handleRemoteNotificationDeviceToken(Data([0xab, 0xcd, 0xef]))

        let request = try #require(pushClient.lastRequest)
        #expect(request.pushRelayToken == "stable-relay-token")
        #expect(request.apnsToken == "abcdef")
        #expect(request.environment == HomesteadPushEnvironment.current)
        #expect(!request.deviceName.isEmpty)
        #expect(!request.appVersion.isEmpty)
        #expect(service.remoteRegistrationState.isRegistered)
        #expect(service.lastErrorMessage == nil)
    }

    @MainActor
    @Test func nativeNotificationServiceReportsBackendRegistrationFailure() async {
        let client = StubNativeNotificationPermissionClient(currentStatus: .unknown)
        let pushClient = StubHomesteadPushTokenRegistrationClient(error: HomesteadPushRegistrationError.backendRejected(statusCode: 500))
        let service = NativeNotificationService(
            client: client,
            remoteRegistrationClient: StubNativeRemoteNotificationRegistrationClient(),
            pushRegistrationClient: pushClient,
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token")
        )

        await service.handleRemoteNotificationDeviceToken(Data([0xab]))

        guard case .failed = service.remoteRegistrationState else {
            Issue.record("Expected failed remote notification registration state.")
            return
        }
        #expect(service.lastErrorMessage != nil)
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
    @Test func serviceConnectionRegistersRemotePushWithoutLocalPushAdvertising() async throws {
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
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token"),
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
        #expect(savedRegistration.supportsCloudPushNotifications == true)
        #expect(savedRegistration.supportsWebSocketNotifications == false)
        #expect(mobileAppClient.lastRegistrationRequest?.appData?["push_url"]?.stringValue == "https://api.homesteadcontrol.com/mobile-app/push")
        #expect(mobileAppClient.lastRegistrationRequest?.appData?["push_token"]?.stringValue == "stable-relay-token")
        #expect(mobileAppClient.lastRegistrationRequest?.appData?["push_websocket_channel"] == nil)
        #expect(webSocketClient.mobileAppPushNotificationSubscription == nil)
        try await waitUntil {
            webSocketClient.registryChangeSubscriptionCount == 1
        }
        #expect(webSocketClient.registryChangeSubscriptionCount == 1)
        #expect(service.mobileAppPushNotificationState == .unavailable)
    }

    @MainActor
    @Test func registryUpdateEventsRefreshSummaryMembershipMetadata() async throws {
        let stateStore = HAStateStore()
        let webSocketClient = StubHAWebSocketClient(states: [
            HAEntityDTO(entityID: "light.utility", state: "off")
        ])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "stable-relay-token"),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(
                    credential: testCredential(accessToken: "registry-refresh-access")
                )
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil {
            webSocketClient.entityRegistryFetchCount >= 1
        }

        webSocketClient.entityRegistryEntities = [
            HAEntityRegistryDisplayDTO(
                entityID: "light.utility",
                deviceID: nil,
                originalName: "Utility",
                entityCategory: "diagnostic"
            )
        ]
        await webSocketClient.emitEvent(HAEventDTO(
            eventType: "entity_registry_updated",
            data: .object([:])
        ))

        try await waitUntil(timeout: .seconds(2)) {
            webSocketClient.entityRegistryFetchCount >= 2 &&
                stateStore.dashboardSummaryMembershipContext()
                    .metadata(for: "light.utility")?.entityCategory == "diagnostic"
        }
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
            currentWiFiNetworkProvider: StubCurrentWiFiNetworkProvider(ssid: "Home Wi-Fi"),
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: true)
        )
        let settings = HAConnectionSettings(
            baseURL: baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        settings.internalURL = internalURLString
        settings.externalURL = "https://remote.example.com"
        settings.internalNetworkSSIDs = ["Home Wi-Fi"]

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
            currentWiFiNetworkProvider: StubCurrentWiFiNetworkProvider(ssid: "Home Wi-Fi"),
            networkContext: HAConnectionNetworkContext(isNetworkAvailable: true, isLikelyHomeNetwork: true)
        )
        let settings = HAConnectionSettings(
            baseURL: baseURLString,
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        settings.internalURL = internalURLString
        settings.externalURL = externalURLString
        settings.internalNetworkSSIDs = ["Home Wi-Fi"]

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

    @Test func connectionRecoveryPolicyClassifiesFallbackAndReconnectErrors() {
        #expect(HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: HAWebSocketError.invalidURL))
        #expect(HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: HAWebSocketError.notConnected))
        #expect(HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: HAWebSocketError.requestTimedOut))
        #expect(HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: HAWebSocketError.transportFailure("Offline")))
        #expect(!HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: HAWebSocketError.authenticationFailed(nil)))
        #expect(!HAConnectionRecoveryPolicy.shouldTryFallbackRoute(after: URLError(.notConnectedToInternet)))

        #expect(HAConnectionRecoveryPolicy.shouldReconnectSocket(after: HAWebSocketError.notConnected))
        #expect(HAConnectionRecoveryPolicy.shouldReconnectSocket(after: HAWebSocketError.requestTimedOut))
        #expect(HAConnectionRecoveryPolicy.shouldReconnectSocket(after: HAWebSocketError.transportFailure("Dropped")))
        #expect(!HAConnectionRecoveryPolicy.shouldReconnectSocket(after: HAWebSocketError.invalidURL))
        #expect(!HAConnectionRecoveryPolicy.shouldReconnectSocket(after: HAWebSocketError.authenticationFailed(nil)))
    }

    @Test func connectionRecoveryPolicyClampsReconnectDelayAndResumeRefresh() {
        #expect(HAConnectionRecoveryPolicy.reconnectDelaySeconds(forAttempt: -1, delays: [1, 2, 5]) == 1)
        #expect(HAConnectionRecoveryPolicy.reconnectDelaySeconds(forAttempt: 1, delays: [1, 2, 5]) == 2)
        #expect(HAConnectionRecoveryPolicy.reconnectDelaySeconds(forAttempt: 7, delays: [1, 2, 5]) == 5)
        #expect(HAConnectionRecoveryPolicy.reconnectDelaySeconds(forAttempt: 0, delays: []) == 0)

        let now = Date(timeIntervalSince1970: 100)
        #expect(!HAConnectionRecoveryPolicy.shouldRefreshAfterResume(
            lastSuspendedAt: nil,
            now: now,
            interval: 5
        ))
        #expect(!HAConnectionRecoveryPolicy.shouldRefreshAfterResume(
            lastSuspendedAt: Date(timeIntervalSince1970: 96),
            now: now,
            interval: 5
        ))
        #expect(HAConnectionRecoveryPolicy.shouldRefreshAfterResume(
            lastSuspendedAt: Date(timeIntervalSince1970: 95),
            now: now,
            interval: 5
        ))
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
        webSocketClient.supervisorInfo = HASupervisorInfoDTO(version: "2026.06.1")
        webSocketClient.operatingSystemInfo = HAOperatingSystemInfoDTO(version: "16.2")
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
        #expect(service.serverEnvironment?.installationMethod == .homeAssistantOS)
        #expect(service.serverEnvironment?.coreVersion == "2026.6.0")
        #expect(service.serverEnvironment?.supervisorVersion == "2026.06.1")
        #expect(service.serverEnvironment?.operatingSystemVersion == "16.2")
        if case .loaded = service.serverConfigurationStatus {
            // Expected loaded server config status.
        } else {
            Issue.record("Expected loaded server config status.")
        }

        let updated = await service.updateServerName("Keegdom")

        #expect(updated)
        #expect(webSocketClient.updatedLocationNames == ["Keegdom"])
        #expect(service.serverConfiguration?.locationName == "Keegdom")
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
    @Test func selectOptionRoutesByHomeAssistantEntityDomain() async throws {
        let stateStore = HAStateStore()
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "select-access"))
            )
        )

        await service.selectOption(entityID: "select.house_mode", option: "Away")
        await service.selectOption(entityID: "input_select.house_mode", option: "Home")

        #expect(webSocketClient.callServiceInvocations.map(\.domain) == ["select", "input_select"])
        #expect(webSocketClient.callServiceInvocations.map(\.service) == ["select_option", "select_option"])
        #expect(webSocketClient.callServiceInvocations.map(\.entityID) == ["select.house_mode", "input_select.house_mode"])
        #expect(webSocketClient.callServiceInvocations[0].serviceData["option"] == .string("Away"))
        #expect(webSocketClient.callServiceInvocations[1].serviceData["option"] == .string("Home"))
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
    @Test func serviceInstallsAllAvailableUpdatesWithBackup() async throws {
        let availableCore = HAEntityDTO(
            entityID: "update.home_assistant_core_update",
            state: "on",
            attributes: ["friendly_name": .string("Home Assistant Core")]
        )
        let availableRouter = HAEntityDTO(
            entityID: "update.router_firmware",
            state: "on",
            attributes: ["friendly_name": .string("Router Firmware")]
        )
        let currentBridge = HAEntityDTO(
            entityID: "update.bridge",
            state: "off",
            attributes: ["friendly_name": .string("Bridge")]
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([availableCore, availableRouter, currentBridge])
        let webSocketClient = StubHAWebSocketClient(states: [availableCore, availableRouter, currentBridge])
        webSocketClient.serviceRegistry = HAServiceRegistry(domains: [
            "update": [
                "install": HAServiceDescription(name: "Install")
            ]
        ])
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                tokenStore: InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "update-all-access"))
            )
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")
        try await waitUntil {
            service.serviceRegistry.hasLoaded
        }
        stateStore.applySnapshot([availableCore, availableRouter, currentBridge])

        await service.installAvailableUpdates(stateStore.updateEntities, backup: true)

        #expect(webSocketClient.callServiceInvocations.map(\.domain) == ["update", "update"])
        #expect(webSocketClient.callServiceInvocations.map(\.service) == ["install", "install"])
        #expect(webSocketClient.callServiceInvocations.map(\.entityID) == [
            "update.home_assistant_core_update",
            "update.router_firmware"
        ])
        #expect(webSocketClient.callServiceInvocations.allSatisfy { $0.serviceData["backup"] == .bool(true) })
    }

    @MainActor
    @Test func presenceRecordsMapPeopleTrackersAndRegistryContext() throws {
        let changedAt = try testDate("2026-06-10T14:15:00Z")
        let updatedAt = try testDate("2026-06-10T14:16:00Z")
        let person = HAEntityDTO(
            entityID: "person.tyler",
            state: "PCS",
            attributes: [
                "friendly_name": .string("Tyler"),
                "source": .string("device_tracker.tylers_iphone"),
                "entity_picture": .string("/api/image/tyler")
            ],
            lastChanged: changedAt,
            lastUpdated: updatedAt
        )
        let tracker = HAEntityDTO(
            entityID: "device_tracker.tylers_iphone",
            state: "home",
            attributes: [
                "friendly_name": .string("Tyler's iPhone"),
                "source_type": .string("gps"),
                "battery_level": .number(88),
                "gps_accuracy": .number(12)
            ],
            lastChanged: changedAt,
            lastUpdated: updatedAt
        )
        let watch = HAEntityDTO(
            entityID: "device_tracker.tylers_watch",
            state: "not_home",
            attributes: [
                "friendly_name": .string("Tyler's Watch"),
                "source_type": .string("bluetooth_le")
            ]
        )
        let store = HAStateStore()
        store.applySnapshot([person, tracker, watch])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "device_tracker.tylers_iphone",
                    deviceID: "phone-device",
                    originalName: "Tyler's iPhone"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "device_tracker.tylers_watch",
                    deviceID: "watch-device",
                    originalName: "Tyler's Watch"
                )
            ],
            devices: [
                HADeviceRegistryDTO(
                    id: "phone-device",
                    name: "Tyler's iPhone",
                    areaID: "living_room",
                    manufacturer: "Apple",
                    model: "iPhone"
                ),
                HADeviceRegistryDTO(
                    id: "watch-device",
                    name: "Tyler's Watch",
                    manufacturer: "Apple",
                    model: "Watch"
                )
            ],
            areas: [
                HAAreaRegistryDTO(id: "living_room", name: "Living Room", floorID: "downstairs")
            ],
            floors: [
                HAFloorRegistryDTO(id: "downstairs", name: "Downstairs")
            ]
        )

        let records = store.presenceRecords()
        let personRecord = try #require(records.first { $0.entityID == "person.tyler" })
        let trackerRecord = try #require(records.first { $0.entityID == "device_tracker.tylers_iphone" })
        let watchRecord = try #require(records.first { $0.entityID == "device_tracker.tylers_watch" })

        #expect(records.map(\.entityID) == [
            "person.tyler",
            "device_tracker.tylers_iphone",
            "device_tracker.tylers_watch"
        ])
        #expect(personRecord.status == .zone("PCS"))
        #expect(personRecord.status.title == "PCS")
        #expect(personRecord.status.shortTitle == "PCS")
        #expect(personRecord.entityPicturePath == "/api/image/tyler")
        #expect(personRecord.lastChanged == changedAt)
        #expect(personRecord.lastUpdated == updatedAt)
        #expect(personRecord.linkedTrackers.map(\.entityID) == ["device_tracker.tylers_iphone"])
        #expect(personRecord.linkedTrackers.first?.sourceTypeTitle == "GPS")
        #expect(personRecord.linkedTrackers.first?.context.areaName == "Living Room")
        #expect(trackerRecord.linkedPersonEntityID == "person.tyler")
        #expect(trackerRecord.linkedPersonName == "Tyler")
        #expect(trackerRecord.sourceTypeTitle == "GPS")
        #expect(trackerRecord.batteryText == "88%")
        #expect(trackerRecord.gpsAccuracyText == "12m")
        #expect(trackerRecord.context.deviceName == "Tyler's iPhone")
        #expect(trackerRecord.context.areaName == "Living Room")
        #expect(trackerRecord.context.floorName == "Downstairs")
        #expect(watchRecord.sourceTypeTitle == "Bluetooth LE")
        #expect(watchRecord.status == .away)
    }

    @Test func personPresencePresentationShowsPeopleOnlyAndSearchesLinkedTrackers() throws {
        let people = [
            HAPresenceRecord(
                entityID: "person.tyler",
                domain: .person,
                displayName: "Tyler",
                status: .home,
                rawState: "home",
                resolvedIcon: .sfSymbol("person.fill", provenance: .homesteadSemanticMapping),
                isAvailable: true,
                lastChanged: nil,
                lastUpdated: nil,
                entityPicturePath: "/api/image/tyler",
                sourceEntityID: "device_tracker.iphone",
                sourceType: nil,
                batteryLevel: nil,
                gpsAccuracy: nil,
                linkedPersonEntityID: nil,
                linkedPersonName: nil,
                linkedTrackers: [
                    HAPresenceTrackerSummary(
                        entityID: "device_tracker.iphone",
                        displayName: "Tyler iPhone",
                        status: .home,
                        sourceType: "gps",
                        batteryLevel: 91,
                        context: HAPresenceContext(
                            deviceID: "phone",
                            deviceName: "Tyler iPhone",
                            areaID: "office",
                            areaName: "Office",
                            floorID: nil,
                            floorName: nil
                        )
                    )
                ],
                context: HAPresenceContext(
                    deviceID: nil,
                    deviceName: nil,
                    areaID: nil,
                    areaName: nil,
                    floorID: nil,
                    floorName: nil
                )
            ),
            HAPresenceRecord(
                entityID: "person.guest",
                domain: .person,
                displayName: "Guest",
                status: .away,
                rawState: "not_home",
                resolvedIcon: .sfSymbol("person", provenance: .homesteadSemanticMapping),
                isAvailable: true,
                lastChanged: nil,
                lastUpdated: nil,
                entityPicturePath: nil,
                sourceEntityID: nil,
                sourceType: nil,
                batteryLevel: nil,
                gpsAccuracy: nil,
                linkedPersonEntityID: nil,
                linkedPersonName: nil,
                linkedTrackers: [],
                context: HAPresenceContext(
                    deviceID: nil,
                    deviceName: nil,
                    areaID: "guest_room",
                    areaName: "Guest Room",
                    floorID: nil,
                    floorName: nil
                )
            ),
            HAPresenceRecord(
                entityID: "device_tracker.car",
                domain: .deviceTracker,
                displayName: "Car",
                status: .zone("Work"),
                rawState: "work",
                resolvedIcon: .sfSymbol("location", provenance: .homesteadSemanticMapping),
                isAvailable: true,
                lastChanged: nil,
                lastUpdated: nil,
                entityPicturePath: nil,
                sourceEntityID: nil,
                sourceType: "gps",
                batteryLevel: nil,
                gpsAccuracy: nil,
                linkedPersonEntityID: nil,
                linkedPersonName: nil,
                linkedTrackers: [],
                context: HAPresenceContext(
                    deviceID: "car",
                    deviceName: "Car",
                    areaID: nil,
                    areaName: nil,
                    floorID: nil,
                    floorName: nil
                )
            )
        ]

        let searchPresentation = HAPersonPresencePresentation.make(
            records: people,
            searchText: "iphone"
        )
        let allPeoplePresentation = HAPersonPresencePresentation.make(
            records: people,
            searchText: ""
        )
        let filteredPresentation = HAPersonPresencePresentation.make(
            records: people,
            searchText: "",
            currentUserEntityPicturePath: "/api/image/tyler"
        )

        #expect(searchPresentation.people.map(\.entityID) == ["person.tyler"])
        #expect(allPeoplePresentation.people.map(\.entityID) == ["person.guest", "person.tyler"])
        #expect(filteredPresentation.people.map(\.entityID) == ["person.guest"])
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
    @Test func connectionFailureUsesFriendlyStatusAndKeepsRawDiagnosticMessage() async throws {
        let rawError = HAWebSocketError.requestFailed("Unexpected response from Home Assistant")
        let tokenStore = InMemoryHAOAuthTokenStore(credential: testCredential(accessToken: "friendly-failure-access"))
        let credential = try tokenStore.readCredential()!
        let webSocketClient = StubHAWebSocketClient()
        webSocketClient.connectErrorsByBaseURL["http://homeassistant.local:8123"] = rawError
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        await service.connect(baseURLString: "http://homeassistant.local:8123")

        #expect(service.connectionStatus == .failed("Home Assistant returned an unexpected response. Try again in a moment."))
        #expect(service.lastErrorMessage == rawError.localizedDescription)
        if case .signedIn = service.authState {
            // Expected: WebSocket failures should not turn a valid session into an account error.
        } else {
            Issue.record("Expected WebSocket failure to preserve signed-in auth state.")
        }
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
    @Test func oauthSignInUsesExternalRouteWhenCurrentWiFiIsNotTrusted() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore()
        let oauthClient = StubHAOAuthClient(
            exchangeResponse: HAOAuthTokenResponseDTO(
                accessToken: "oauth-access",
                expiresIn: 1200,
                refreshToken: "oauth-refresh",
                tokenType: "Bearer"
            )
        )
        let authorizer = StubHAOAuthAuthorizer(authorizationCode: "auth-code")
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(
                client: oauthClient,
                tokenStore: tokenStore
            ),
            oauthAuthorizer: authorizer,
            currentWiFiNetworkProvider: StubCurrentWiFiNetworkProvider(ssid: "Coffee Shop"),
            networkContext: HAConnectionNetworkContext(
                isNetworkAvailable: true,
                isLikelyHomeNetwork: true,
                currentWiFiSSID: nil
            ),
            automaticallyRegistersMobileApp: false
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        settings.internalURL = "http://homeassistant.local:8123"
        settings.externalURL = "https://remote.example.com"
        settings.internalNetworkSSIDs = ["Home Wi-Fi"]

        await service.signInWithHomeAssistant(settings: settings)

        #expect(authorizer.lastAuthorizationURL?.host == "remote.example.com")
        #expect(oauthClient.lastExchangeBaseURLString == "https://remote.example.com")
        #expect(settings.baseURL == "https://remote.example.com")
        #expect(try tokenStore.readCredential()?.baseURLString == "https://remote.example.com")
        #expect(webSocketClient.lastConnectConfiguration?.baseURLString == "https://remote.example.com")
    }

    @MainActor
    @Test func oauthSignInCancellationReturnsToReadyStateAndStoresRawFailure() async throws {
        let rawError = NSError(
            domain: "com.apple.AuthenticationServices.WebAuthenticationSession",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (com.apple.AuthenticationServices.WebAuthenticationSession error 1.)"]
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: InMemoryHAOAuthTokenStore()),
            oauthAuthorizer: StubHAOAuthAuthorizer(error: rawError),
            automaticallyRegistersMobileApp: false
        )
        let settings = HAConnectionSettings(
            baseURL: "https://remote.example.com",
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )

        await service.signInWithHomeAssistant(settings: settings)

        #expect(service.authState == .signedOut)
        #expect(service.lastErrorMessage == nil)
        #expect(service.lastAuthenticationErrorMessage == "The operation couldn’t be completed. (com.apple.AuthenticationServices.WebAuthenticationSession error 1.)")
    }

    @MainActor
    @Test func oauthSignInShowsFriendlyMessageAndStoresRawFailure() async throws {
        let rawError = NSError(
            domain: "com.apple.AuthenticationServices.WebAuthenticationSession",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (com.apple.AuthenticationServices.WebAuthenticationSession error 2.)"]
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: InMemoryHAOAuthTokenStore()),
            oauthAuthorizer: StubHAOAuthAuthorizer(error: rawError),
            automaticallyRegistersMobileApp: false
        )
        let settings = HAConnectionSettings(
            baseURL: "https://remote.example.com",
            defaults: try isolatedDefaults(),
            tokenStore: InMemoryHAOAuthTokenStore()
        )

        await service.signInWithHomeAssistant(settings: settings)

        #expect(service.authState == .refreshFailed("Couldn’t complete sign-in with Home Assistant. Check that Home Assistant is reachable and try again."))
        #expect(service.lastErrorMessage == "Couldn’t complete sign-in with Home Assistant. Check that Home Assistant is reachable and try again.")
        #expect(service.lastAuthenticationErrorMessage == "The operation couldn’t be completed. (com.apple.AuthenticationServices.WebAuthenticationSession error 2.)")
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
    @Test func imageRequestUsesStoredOAuthConfigurationAndRelativeOrAbsolutePaths() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "image-access")
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: StubHAWebSocketClient(),
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )

        let relativeRequest = try #require(await service.homeAssistantImageRequest(
            settings: settings,
            pathOrURL: "/api/image/person"
        ))
        let absoluteRequest = try #require(await service.homeAssistantImageRequest(
            settings: settings,
            pathOrURL: "https://cdn.example.com/person.jpg"
        ))
        let integrationBrandRequest = try #require(await service.homeAssistantImageRequest(
            settings: settings,
            pathOrURL: "/api/brands/integration/hue/icon@2x.png"
        ))
        let blankRequest = await service.homeAssistantImageRequest(settings: settings, pathOrURL: " ")

        #expect(relativeRequest.url?.absoluteString == "http://homeassistant.local:8123/api/image/person")
        #expect(relativeRequest.value(forHTTPHeaderField: "Authorization") == "Bearer image-access")
        #expect(absoluteRequest.url?.absoluteString == "https://cdn.example.com/person.jpg")
        #expect(absoluteRequest.value(forHTTPHeaderField: "Authorization") == "Bearer image-access")
        #expect(integrationBrandRequest.url?.absoluteString == "http://homeassistant.local:8123/api/brands/integration/hue/icon@2x.png")
        #expect(integrationBrandRequest.value(forHTTPHeaderField: "Authorization") == "Bearer image-access")
        #expect(blankRequest == nil)
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
    @Test func serviceFetchesSupervisorAppsThroughConnectedWebSocketBridge() async throws {
        let baseURLString = "https://home.example.com"
        let externalURLString = "https://remote.example.com"
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: baseURLString, accessToken: "apps-access")
        )
        let webSocketClient = StubHAWebSocketClient()
        webSocketClient.supervisorAppsResponse = HASupervisorAppsResponseDTO(addons: [
            HASupervisorAppDTO(
                name: "Terminal",
                slug: "core_terminal",
                description: "Command line access",
                version: "9.15.0",
                versionLatest: "9.15.0",
                updateAvailable: false,
                installed: true,
                available: true,
                icon: false,
                logo: false,
                state: "started"
            )
        ])
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            connectionStatus: .connected,
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

        let result = await service.fetchSupervisorApps(settings: settings)

        #expect(webSocketClient.fetchSupervisorAppsCount == 1)
        #expect(result == .available([
            HASupervisorApp(
                id: "core_terminal",
                slug: "core_terminal",
                name: "Terminal",
                description: "Command line access",
                installedVersion: "9.15.0",
                latestVersion: "9.15.0",
                updateAvailable: false,
                status: .running
            )
        ]))
    }

    @MainActor
    @Test func serviceMapsSupervisorAppsUnavailableAndConnectionFailures() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "apps-access")
        )
        let webSocketClient = StubHAWebSocketClient()
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

        webSocketClient.supervisorAppsError = HAWebSocketError.requestFailed("Unknown command.")
        #expect(await service.fetchSupervisorApps(settings: settings) == .unavailable(.unsupported))

        webSocketClient.supervisorAppsError = HAWebSocketError.notConnected
        #expect(await service.fetchSupervisorApps(settings: settings) == .unavailable(.connectionUnavailable))
    }

    @MainActor
    @Test func serviceDoesNotFetchSupervisorAppsWhenDisconnected() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "apps-access")
        )
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            connectionStatus: .disconnected,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )

        #expect(await service.fetchSupervisorApps(settings: settings) == .unavailable(.connectionUnavailable))
        #expect(webSocketClient.fetchSupervisorAppsCount == 0)
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

        let configuration = try #require(mobileAppClient.lastRegistrationConfiguration)
        #expect(configuration.baseURLString == externalURLString)
        #expect(configuration.tokenRefreshBaseURLString == baseURLString)
        #expect(configuration.dataSourceID == HAConnectionConfiguration(
            baseURLString: baseURLString,
            accessToken: "mobile-app-access"
        ).dataSourceID)
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
    @Test func serviceReusesFreshDashboardHistoryRequest() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "dashboard-history-cache-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "71.2",
                attributes: [
                    "friendly_name": .string("Kitchen Temperature"),
                    "unit_of_measurement": .string("F")
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
            authManager: HAOAuthManager(tokenStore: tokenStore),
            dashboardHistoryCache: DashboardHistoryCache(freshnessInterval: 60)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let endDate = try testDate("2026-06-05T16:00:00Z")

        let firstSeries = try await service.fetchDashboardHistory(
            settings: settings,
            entityID: "sensor.kitchen_temperature",
            endingAt: endDate
        )
        let secondSeries = try await service.fetchDashboardHistory(
            settings: settings,
            entityID: "sensor.kitchen_temperature",
            endingAt: endDate
        )

        #expect(httpClient.historyFetchCount == 1)
        #expect(secondSeries == firstSeries)
    }

    @MainActor
    @Test func serviceCoalescesConcurrentDashboardHistoryRequests() async throws {
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(accessToken: "dashboard-history-coalesced-access")
        )
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(
                entityID: "sensor.kitchen_temperature",
                state: "71.2",
                attributes: [
                    "friendly_name": .string("Kitchen Temperature"),
                    "unit_of_measurement": .string("F")
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
        httpClient.historyDelay = .milliseconds(100)
        let service = HomeAssistantService(
            stateStore: stateStore,
            httpClient: httpClient,
            authManager: HAOAuthManager(tokenStore: tokenStore),
            dashboardHistoryCache: DashboardHistoryCache(freshnessInterval: 60)
        )
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: try isolatedDefaults(),
            tokenStore: tokenStore
        )
        let endDate = try testDate("2026-06-05T16:00:00Z")

        async let firstSeries = service.fetchDashboardHistory(
            settings: settings,
            entityID: "sensor.kitchen_temperature",
            endingAt: endDate
        )
        async let secondSeries = service.fetchDashboardHistory(
            settings: settings,
            entityID: "sensor.kitchen_temperature",
            endingAt: endDate
        )
        let (first, second) = try await (firstSeries, secondSeries)

        #expect(httpClient.historyFetchCount == 1)
        #expect(second == first)
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

        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: camera) == .square)
    }

    @MainActor
    @Test func generatedSensorCardsPreferHistoryExceptBatterySize() throws {
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
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "85",
                attributes: [
                    "unit_of_measurement": .string("%"),
                    "device_class": .string("battery")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.living_room_humidity",
                state: "44",
                attributes: [
                    "unit_of_measurement": .string("%"),
                    "device_class": .string("humidity")
                ]
            ),
            HAEntityDTO(entityID: "sensor.mode", state: "auto")
        ])

        let numericSensor = try #require(store.entityBox(for: "sensor.hallway_temperature"))
        let batterySensor = try #require(store.entityBox(for: "sensor.remote_battery"))
        let humiditySensor = try #require(store.entityBox(for: "sensor.living_room_humidity"))
        let textSensor = try #require(store.entityBox(for: "sensor.mode"))

        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: numericSensor) == .square)
        #expect(
            DashboardCardSize.defaultGeneratedFeatureVisibility(
                entityBox: numericSensor,
                size: .square
            ) == .automatic
        )
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: batterySensor) == .compact)
        #expect(
            DashboardCardSize.defaultGeneratedFeatureVisibility(
                entityBox: batterySensor,
                size: .compact
            ) == .automatic
        )
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: humiditySensor) == .square)
        #expect(
            DashboardCardSize.defaultGeneratedFeatureVisibility(
                entityBox: humiditySensor,
                size: .square
            ) == .hidden
        )
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: textSensor) == .compact)
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

    @Test func dashboardIconCatalogSupportsSearchAndRecommendations() {
        let choices = DashboardIconChoice.choices
        let choiceNames = Set(choices.map(\.systemName))
        let floorLampResults = DashboardIconChoice.matching("floor lamp")
        let irrigationResults = DashboardIconChoice.matching("irrigation")
        let lightRecommendations = DashboardIconChoice.recommended(for: .domain(.light))
        let securityRecommendations = DashboardIconChoice.recommended(for: .summary(.security))

        #expect(choices.count >= 150)
        #expect(choiceNames.count == choices.count)
        #expect(DashboardIconCategory.allCases.allSatisfy { category in
            choices.contains { $0.category == category }
        })
        #expect(floorLampResults.first?.systemName == "lamp.floor.fill")
        #expect(irrigationResults.contains { $0.systemName == "sprinkler.and.droplets.fill" })
        #expect(lightRecommendations.map(\.systemName) == [
            "lightbulb.fill", "light.recessed.3.fill", "lamp.table.fill", "lamp.floor.fill", "chandelier.fill"
        ])
        #expect(securityRecommendations.map(\.systemName) == [
            "lock.fill", "shield.fill", "camera.fill", "video.doorbell.fill", "key.fill"
        ])
    }

    @MainActor
    @Test func dashboardIconCatalogOnlyContainsAvailableSFSymbols() {
        let unavailableNames = DashboardIconChoice.choices.compactMap { choice in
            UIImage(systemName: choice.systemName) == nil ? choice.systemName : nil
        }

        #expect(unavailableNames.isEmpty)
    }

    @Test func cameraSnapshotStoreKeepsRecentFallbackAndExpiresOldSnapshots() async throws {
        let store = CameraSnapshotStore()
        let entityID = "camera.driveway"
        let capturedAt = Date(timeIntervalSince1970: 1_000)
        let data = Data([0x01, 0x02, 0x03])

        await store.store(data, for: entityID, now: capturedAt)

        let freshSnapshot = try #require(
            await store.snapshot(for: entityID, now: capturedAt.addingTimeInterval(10))
        )
        #expect(freshSnapshot.data == data)
        #expect(
            freshSnapshot.isFresh(
                now: capturedAt.addingTimeInterval(10),
                freshnessInterval: CameraSnapshotStore.freshnessInterval
            )
        )

        let staleSnapshot = try #require(
            await store.snapshot(
                for: entityID,
                now: capturedAt.addingTimeInterval(CameraSnapshotStore.freshnessInterval + 1)
            )
        )
        #expect(
            !staleSnapshot.isFresh(
                now: capturedAt.addingTimeInterval(CameraSnapshotStore.freshnessInterval + 1),
                freshnessInterval: CameraSnapshotStore.freshnessInterval
            )
        )

        let expiredSnapshot = await store.snapshot(
            for: entityID,
            now: capturedAt.addingTimeInterval(CameraSnapshotStore.maximumFallbackAge + 1)
        )
        #expect(expiredSnapshot == nil)
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

        let currentUser = HAStateCacheCurrentUser(id: "current-user", name: "Tyler")

        await cache.save(
            entities,
            registryMetadata: registryMetadata,
            currentUser: currentUser,
            for: primaryConfiguration
        )

        let restoredSnapshot = try #require(await cache.load(for: primaryConfiguration))
        let metadata = try #require(await cache.metadata(for: primaryConfiguration))
        #expect(restoredSnapshot.entities == entities)
        #expect(restoredSnapshot.registryMetadata == registryMetadata)
        #expect(restoredSnapshot.currentUser == currentUser)
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
    @Test func homeAssistantServiceCanRestoreCachedStatesSynchronouslyForLaunch() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadSynchronousLaunchCacheTests-\(UUID().uuidString)", isDirectory: true)
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
                attributes: ["friendly_name": .string("Kitchen")]
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

        service.restoreCachedStatesSynchronouslyIfPossible(
            settings: settings,
            tokenStore: tokenStore,
            cacheDirectoryURL: cacheDirectory
        )

        #expect(store.hasLoadedInitialSnapshot == true)
        #expect(store.entity(for: "light.kitchen")?.state == "on")
        #expect(store.areaName(for: "light.kitchen") == "Kitchen")
        #expect(service.stateCacheMetadata?.entityCount == 1)
        #expect(service.hasCompletedInitialCacheLoad == true)
        if case .cached = service.dataFreshness {
            // Expected cached-first launch state before SwiftUI renders.
        } else {
            Issue.record("Expected synchronous cached data freshness before launch rendering.")
        }
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
                entityID: "person.tyler",
                state: "home",
                attributes: [
                    "friendly_name": .string("Tyler"),
                    "user_id": .string("current-user"),
                    "entity_picture": .string("/api/image/current")
                ]
            ),
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

        await cache.save(
            entities,
            registryMetadata: registryMetadata,
            currentUser: HAStateCacheCurrentUser(id: "current-user", name: "Tyler"),
            for: configuration
        )

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
        #expect(service.currentUserDisplayName == "Tyler")
        #expect(service.currentUserEntityPicturePath == "/api/image/current")
        #expect(service.stateCacheMetadata?.entityCount == 2)
        #expect(service.stateCacheMetadata?.areaRegistryCount == 1)
        if case .cached = service.dataFreshness {
            // Expected cached-first launch state.
        } else {
            Issue.record("Expected cached data freshness after applying the saved snapshot.")
        }
    }

    @MainActor
    @Test func homeAssistantServiceAutomaticallyRetriesRecoverableColdLaunchConnectionFailure() async throws {
        let store = HAStateStore()
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: "homeassistant.local:8123", accessToken: "token-a")
        )
        let client = StubHAWebSocketClient(states: [
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])
        client.connectResults = [
            .failure(HAWebSocketError.transportFailure("Network route is still warming up.")),
            .success(())
        ]
        let service = HomeAssistantService(
            stateStore: store,
            client: client,
            authState: HAOAuthManager.status(tokenStore: tokenStore),
            authManager: HAOAuthManager(tokenStore: tokenStore),
            automaticallyRegistersMobileApp: false
        )
        let settings = HAConnectionSettings(
            baseURL: "homeassistant.local:8123",
            tokenStore: tokenStore
        )

        await service.connectIfPossible(settings: settings)

        #expect(service.connectionStatus == .reconnecting)
        #expect(client.connectConfigurations.count == 1)

        try await waitUntil(timeout: .seconds(2)) {
            service.connectionStatus == .connected
        }

        #expect(client.connectConfigurations.count == 2)
        if case .signedIn = service.authState {
            // Expected: a recoverable transport retry should preserve the known session.
        } else {
            Issue.record("Expected automatic reconnect to preserve the signed-in session.")
        }
    }

    @MainActor
    @Test func cachedColdLaunchReconnectSuppressesTransientConnectionHealth() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomesteadCachedReconnectGraceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = HAStateCache(directoryURL: cacheDirectory)
        let configuration = HAConnectionConfiguration(
            baseURLString: "http://homeassistant.local:8123",
            accessToken: "token-a"
        )
        let cachedLight = HAEntityDTO(
            entityID: "light.kitchen",
            state: "on",
            attributes: ["friendly_name": .string("Kitchen")]
        )
        await cache.save([cachedLight], for: configuration)

        let store = HAStateStore()
        let tokenStore = InMemoryHAOAuthTokenStore(
            credential: testCredential(baseURL: "homeassistant.local:8123", accessToken: "token-a")
        )
        let client = StubHAWebSocketClient(states: [cachedLight])
        client.connectResults = [
            .failure(HAWebSocketError.transportFailure("Network route is still warming up.")),
            .success(())
        ]
        let service = HomeAssistantService(
            stateStore: store,
            client: client,
            stateCache: cache,
            authState: HAOAuthManager.status(tokenStore: tokenStore),
            authManager: HAOAuthManager(tokenStore: tokenStore),
            automaticallyRegistersMobileApp: false
        )
        let settings = HAConnectionSettings(
            baseURL: "homeassistant.local:8123",
            tokenStore: tokenStore
        )

        await service.connectIfPossible(settings: settings)

        #expect(store.entity(for: "light.kitchen")?.state == "on")
        #expect(service.connectionStatus == .reconnecting)
        #expect(service.suppressesTransientConnectionHealth == true)

        try await waitUntil(timeout: .seconds(2)) {
            service.connectionStatus == .connected
        }

        #expect(service.suppressesTransientConnectionHealth == false)
        #expect(client.connectConfigurations.count == 2)
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
        #expect(kitchen?.topDomains == [.light])
        #expect(kitchen?.domainChips == [
            DashboardAreaDomainChip(domain: .light, isActive: true, family: .lights)
        ])
        #expect(office?.unavailableCount == 1)
    }

    @MainActor
    @Test func areaBuilderBuildsActiveFamilyDomainChipsAndSuppressesGenericDomains() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.living_room_lamp", state: "off"),
            HAEntityDTO(entityID: "sensor.living_room_temperature", state: "72"),
            HAEntityDTO(entityID: "media_player.living_room_tv", state: "playing"),
            HAEntityDTO(entityID: "remote.living_room_tv", state: "on"),
            HAEntityDTO(entityID: "switch.living_room_outlet", state: "on"),
            HAEntityDTO(entityID: "camera.living_room", state: "idle")
        ])

        let areaNames = [
            "light.living_room_lamp": "Living Room",
            "sensor.living_room_temperature": "Living Room",
            "media_player.living_room_tv": "Living Room",
            "remote.living_room_tv": "Living Room",
            "switch.living_room_outlet": "Living Room",
            "camera.living_room": "Living Room"
        ]

        let area = DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaNameForEntityID: { areaNames[$0] }
        ).first

        #expect(area?.domainChips == [
            DashboardAreaDomainChip(domain: .mediaPlayer, isActive: true, family: .media)
        ])
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
    @Test func areaResolutionPrefersEntityAreaThenDeviceAreaThenUnassigned() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.entity_override", state: "off"),
            HAEntityDTO(entityID: "light.device_area", state: "off"),
            HAEntityDTO(entityID: "light.no_device", state: "off"),
            HAEntityDTO(entityID: "light.missing_area", state: "off")
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.entity_override",
                    deviceID: "living-device",
                    areaID: "kitchen",
                    originalName: "Entity Override"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "light.device_area",
                    deviceID: "bedroom-device",
                    originalName: "Device Area"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "light.no_device",
                    deviceID: nil,
                    originalName: "No Device"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "light.missing_area",
                    deviceID: nil,
                    areaID: "missing",
                    originalName: "Missing Area"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "living-device", name: "Living Device", areaID: "living"),
                HADeviceRegistryDTO(id: "bedroom-device", name: "Bedroom Device", areaID: "bedroom")
            ],
            areas: [
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen"),
                HAAreaRegistryDTO(id: "living", name: "Living Room"),
                HAAreaRegistryDTO(id: "bedroom", name: "Bedroom")
            ]
        )

        #expect(store.areaName(for: "light.entity_override") == "Kitchen")
        #expect(store.areaName(for: "light.device_area") == "Bedroom")
        #expect(store.areaName(for: "light.no_device") == nil)
        #expect(store.areaName(for: "light.missing_area") == nil)

        let areas = DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaContextForEntityID: store.areaContext(for:)
        )

        #expect(areas.map(\.name) == ["Bedroom", "Kitchen", "Unassigned"])
        #expect(try #require(areas.first { $0.name == "Unassigned" }).entityIDs == [
            "light.missing_area",
            "light.no_device"
        ])
    }

    @MainActor
    @Test func areaDetailSectioningMatchesHomeAssistantAreaStrategy() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.table", state: "on", attributes: ["friendly_name": .string("Table")]),
            HAEntityDTO(
                entityID: "cover.window_shade",
                state: "open",
                attributes: ["friendly_name": .string("Window Shade"), "device_class": .string("shade")]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.window",
                state: "on",
                attributes: ["friendly_name": .string("Window"), "device_class": .string("window")]
            ),
            HAEntityDTO(entityID: "fan.ceiling", state: "off", attributes: ["friendly_name": .string("Ceiling Fan")]),
            HAEntityDTO(entityID: "water_heater.tank", state: "heat_pump", attributes: ["friendly_name": .string("Tank")]),
            HAEntityDTO(entityID: "media_player.speaker", state: "playing", attributes: ["friendly_name": .string("Speaker")]),
            HAEntityDTO(entityID: "camera.patio", state: "idle", attributes: ["friendly_name": .string("Patio Camera")]),
            HAEntityDTO(entityID: "lock.front", state: "locked", attributes: ["friendly_name": .string("Front Lock")]),
            HAEntityDTO(entityID: "scene.movie", state: "scening", attributes: ["friendly_name": .string("Movie")]),
            HAEntityDTO(entityID: "automation.night", state: "on", attributes: ["friendly_name": .string("Night")]),
            HAEntityDTO(entityID: "switch.outlet", state: "off", attributes: ["friendly_name": .string("Outlet")]),
            HAEntityDTO(entityID: "input_boolean.guest_mode", state: "off", attributes: ["friendly_name": .string("Guest Mode")])
        ])
        store.applyRegistryMetadata(
            entities: store.allEntityBoxes().map { entityBox in
                HAEntityRegistryDisplayDTO(
                    entityID: entityBox.entityID,
                    deviceID: nil,
                    areaID: "living",
                    originalName: entityBox.homeEntity.displayName
                )
            },
            devices: [],
            areas: [
                HAAreaRegistryDTO(id: "living", name: "Living Room")
            ]
        )

        let sections = DashboardAreaDetailSectionProvider.makeSections(
            from: store.allEntityBoxes(),
            membershipContext: store.dashboardSummaryMembershipContext()
        )

        #expect(sections.compactMap(\.kind) == [
            .lights,
            .covers,
            .climate,
            .mediaPlayers,
            .security,
            .actions,
            .others
        ])
        #expect(sections.first { $0.kind == .covers }?.entityIDs == [
            "binary_sensor.window",
            "cover.window_shade"
        ])
        #expect(sections.first { $0.kind == .climate }?.entityIDs == [
            "fan.ceiling",
            "water_heater.tank"
        ])
        #expect(sections.first { $0.kind == .security }?.entityIDs == [
            "lock.front",
            "camera.patio"
        ])
        #expect(sections.first { $0.kind == .actions }?.entityIDs == [
            "scene.movie",
            "automation.night"
        ])
        #expect(sections.first { $0.kind == .others }?.entityIDs == [
            "input_boolean.guest_mode",
            "switch.outlet"
        ])
    }

    @MainActor
    @Test func areaDetailSectioningExcludesHiddenConfigAndDiagnosticEntities() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.visible", state: "on", attributes: ["friendly_name": .string("Visible")]),
            HAEntityDTO(entityID: "light.hidden", state: "on", attributes: ["friendly_name": .string("Hidden")]),
            HAEntityDTO(entityID: "switch.config", state: "off", attributes: ["friendly_name": .string("Config")]),
            HAEntityDTO(entityID: "sensor.diagnostic", state: "1", attributes: ["friendly_name": .string("Diagnostic")])
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.visible",
                    deviceID: nil,
                    areaID: "office",
                    originalName: "Visible"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "light.hidden",
                    deviceID: nil,
                    areaID: "office",
                    originalName: "Hidden",
                    hiddenBy: true
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "switch.config",
                    deviceID: nil,
                    areaID: "office",
                    originalName: "Config",
                    entityCategory: "config"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.diagnostic",
                    deviceID: nil,
                    areaID: "office",
                    originalName: "Diagnostic",
                    entityCategory: "diagnostic"
                )
            ],
            devices: [],
            areas: [
                HAAreaRegistryDTO(id: "office", name: "Office")
            ]
        )

        let sections = DashboardAreaDetailSectionProvider.makeSections(
            from: store.allEntityBoxes(),
            membershipContext: store.dashboardSummaryMembershipContext()
        )

        #expect(sections.compactMap(\.kind) == [.lights])
        #expect(sections.first?.entityIDs == ["light.visible"])
    }

    @MainActor
    @Test func areaDetailSectioningGroupsVisibleDeviceLeftoversByDevice() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "media_player.bedroom_tv", state: "on", attributes: ["friendly_name": .string("TV")]),
            HAEntityDTO(entityID: "select.bedroom_tv_channel", state: "unavailable", attributes: ["friendly_name": .string("TV Channel")]),
            HAEntityDTO(entityID: "button.bedroom_tv_remote", state: "2026-04-11T08:00:00", attributes: ["friendly_name": .string("TV Remote")]),
            HAEntityDTO(entityID: "sensor.bedroom_tv_last_seen", state: "2026-04-11T08:00:00", attributes: ["friendly_name": .string("TV Last Seen")]),
            HAEntityDTO(
                entityID: "binary_sensor.primary_bath_leak",
                state: "off",
                attributes: [
                    "friendly_name": .string("Primary Bath Leak"),
                    "device_class": .string("moisture")
                ]
            ),
            HAEntityDTO(entityID: "switch.standalone", state: "off", attributes: ["friendly_name": .string("Standalone Switch")])
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "media_player.bedroom_tv",
                    deviceID: "bedroom-tv",
                    areaID: "primary-bedroom",
                    originalName: "TV"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "select.bedroom_tv_channel",
                    deviceID: "bedroom-tv",
                    areaID: "primary-bedroom",
                    originalName: "TV Channel"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "button.bedroom_tv_remote",
                    deviceID: "bedroom-tv",
                    areaID: "primary-bedroom",
                    originalName: "TV Remote"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.bedroom_tv_last_seen",
                    deviceID: "bedroom-tv",
                    areaID: "primary-bedroom",
                    originalName: "TV Last Seen"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "binary_sensor.primary_bath_leak",
                    deviceID: "bath-leak-sensor",
                    areaID: "primary-bedroom",
                    originalName: "Primary Bath Leak"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "switch.standalone",
                    deviceID: nil,
                    areaID: "primary-bedroom",
                    originalName: "Standalone Switch"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "bedroom-tv", name: "Primary Bedroom TV", areaID: "primary-bedroom"),
                HADeviceRegistryDTO(id: "bath-leak-sensor", name: "Primary Bath Leak Sensor", areaID: "primary-bedroom")
            ],
            areas: [
                HAAreaRegistryDTO(id: "primary-bedroom", name: "Primary Bedroom")
            ]
        )

        let sections = DashboardAreaDetailSectionProvider.makeSections(
            from: store.allEntityBoxes(),
            membershipContext: store.dashboardSummaryMembershipContext()
        )

        #expect(sections.map(\.title) == [
            "Media Players",
            "Security",
            "Primary Bedroom TV",
            "Others"
        ])
        #expect(sections.first { $0.kind == .security }?.entityIDs == [
            "binary_sensor.primary_bath_leak"
        ])
        #expect(sections.first { $0.kind == .mediaPlayers }?.entityIDs == [
            "media_player.bedroom_tv"
        ])
        #expect(sections.first { $0.title == "Primary Bedroom TV" }?.entityIDs == [
            "sensor.bedroom_tv_last_seen",
            "select.bedroom_tv_channel",
            "button.bedroom_tv_remote"
        ])
        #expect(sections.first { $0.kind == .others }?.entityIDs == [
            "switch.standalone"
        ])
    }

    @MainActor
    @Test func areaBuilderPrefersHomeAssistantAreaIconMetadata() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "off", attributes: ["friendly_name": .string("Kitchen Light")])
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(entityID: "light.kitchen", deviceID: nil, areaID: "kitchen", originalName: "Kitchen Light")
            ],
            devices: [],
            areas: [
                HAAreaRegistryDTO(id: "kitchen", name: "Kitchen", icon: "mdi:sofa")
            ]
        )

        let area = try #require(DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaContextForEntityID: store.areaContext(for:)
        ).first)

        #expect(area.icon == "mdi:sofa")
        #expect(area.systemImage == "sofa")
    }

    @MainActor
    @Test func areaBuilderFallsBackToNameInferenceWhenHomeAssistantIconIsUnsupported() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.entry", state: "off", attributes: ["friendly_name": .string("Entry Light")])
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(entityID: "light.entry", deviceID: nil, areaID: "entry", originalName: "Entry Light")
            ],
            devices: [],
            areas: [
                HAAreaRegistryDTO(id: "entry", name: "Entryway", icon: "mdi:custom-room")
            ]
        )

        let area = try #require(DashboardAreaBuilder.buildAreas(
            from: store.allEntityBoxes(),
            areaContextForEntityID: store.areaContext(for:)
        ).first)

        #expect(area.systemImage == "door.left.hand.closed")
    }

    @Test func areaIconResolverInfersCommonAreaNames() {
        let expectedIconsByAreaName = [
            "Primary Bedroom": "bed.double",
            "Guest Bedroom": "bed.double",
            "Office": "desktopcomputer",
            "Garage": "door.garage.closed",
            "Foyer": "door.left.hand.closed",
            "Den": "sofa",
            "Family Room": "sofa",
            "Dining Room": "fork.knife",
            "Pantry": "fork.knife",
            "Laundry": "washer",
            "Bathroom": "shower",
            "Hallway": "door.left.hand.open",
            "Backyard": "tree",
            "Game Room": "gamecontroller",
            "Media Room": "play.tv",
            "Closet": "hanger",
            "Nursery": "teddybear.fill"
        ]

        for (areaName, expectedIcon) in expectedIconsByAreaName {
            #expect(
                IconResolver.resolveArea(AreaIconResolutionInput(name: areaName)).sfSymbolName == expectedIcon,
                "Expected \(areaName) to resolve to \(expectedIcon)"
            )
        }
    }

    @Test func areaIconResolverUsesGenericHouseFallbackForUnknownAreas() {
        #expect(IconResolver.resolveArea(AreaIconResolutionInput(name: "Workshop")).sfSymbolName == "house")
        #expect(
            IconResolver.resolveArea(
                AreaIconResolutionInput(name: "Workshop", registryIcon: "mdi:custom-room")
            ).sfSymbolName == "house"
        )
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

        #expect(sections.map(\.title) == ["Main Floor", "Upstairs", "Unassigned"])
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
            HAEntityDTO(entityID: "sensor.temperature", state: "72"),
            HAEntityDTO(
                entityID: "sensor.front_door_battery",
                state: "68",
                attributes: [
                    "friendly_name": .string("Front Door Battery"),
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.back_door_battery",
                state: "8",
                attributes: [
                    "friendly_name": .string("Back Door Battery"),
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            )
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
        let batteryPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "sensor.front_door_battery"))
        )
        let lowBatteryPresentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "sensor.back_door_battery"))
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
        #expect(batteryPresentation.subtitle == "68%")
        #expect(lowBatteryPresentation.subtitle == "8% • Critical")
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
    @Test func unavailableLightPresentationDisablesPrimaryControlStyling() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.hallway",
                state: "unavailable",
                attributes: ["friendly_name": .string("Hallway Light")]
            )
        ])

        let presentation = DashboardEntityPresentation(
            entityBox: try #require(store.entityBox(for: "light.hallway"))
        )

        #expect(presentation.isAvailable == false)
        #expect(presentation.isActive == false)
        #expect(presentation.primaryAction == nil)
        #expect(presentation.primaryServiceIntent == nil)
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
            HAEntityDTO(
                entityID: "fan.bedroom",
                state: "on",
                attributes: [
                    "friendly_name": .string("Bedroom Fan"),
                    "percentage": .number(45),
                    "percentage_step": .number(5)
                ]
            ),
            HAEntityDTO(
                entityID: "fan.office",
                state: "off",
                attributes: [
                    "friendly_name": .string("Office Fan"),
                    "percentage": .number(30),
                    "percentage_step": .number(10)
                ]
            ),
            HAEntityDTO(
                entityID: "fan.basic",
                state: "on",
                attributes: [
                    "friendly_name": .string("Basic Fan")
                ]
            ),
            HAEntityDTO(entityID: "lock.front_door", state: "locked"),
            HAEntityDTO(
                entityID: "select.house_mode",
                state: "Home",
                attributes: [
                    "friendly_name": .string("House Mode"),
                    "options": .array([.string("Morning"), .string("Home"), .string("Away")])
                ]
            ),
            HAEntityDTO(
                entityID: "input_select.guest_mode",
                state: "Away",
                attributes: [
                    "friendly_name": .string("Guest Mode"),
                    "options": .array([.string("Home"), .string("Away")])
                ]
            ),
            HAEntityDTO(entityID: "select.empty_mode", state: "Home"),
            HAEntityDTO(
                entityID: "sensor.front_door_battery",
                state: "18",
                attributes: [
                    "friendly_name": .string("Front Door Battery"),
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.living_room_temperature",
                state: "72",
                attributes: [
                    "friendly_name": .string("Living Room Temperature"),
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("F")
                ]
            )
        ])

        let lightBox = try #require(store.entityBox(for: "light.kitchen"))
        let lightFeatures = DashboardCardFeatureProvider.features(
            for: lightBox,
            presentation: DashboardEntityPresentation(entityBox: lightBox)
        )
        #expect(lightFeatures.map(\.key) == [.lightBrightness])
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: lightBox) == .square)
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
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: climateBox) == .square)
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
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: coverBox) == .square)
        guard case .commandGroup(let commands) = try #require(coverFeatures.first?.content) else {
            Issue.record("Expected cover command feature")
            return
        }
        #expect(commands.commands.map(\.action) == [.openCover, .stopCover, .closeCover])
        #expect(commands.commands.first?.isDisabled == false)
        #expect(commands.commands.last?.isDisabled == true)

        let fanBox = try #require(store.entityBox(for: "fan.bedroom"))
        let fanFeatures = DashboardCardFeatureProvider.features(
            for: fanBox,
            presentation: DashboardEntityPresentation(entityBox: fanBox)
        )
        #expect(fanFeatures.map(\.key) == [.fanSpeed])
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: fanBox) == .square)
        guard case .level(let fanSpeed) = try #require(fanFeatures.first?.content) else {
            Issue.record("Expected fan speed level feature")
            return
        }
        #expect(fanSpeed.value == 45)
        #expect(fanSpeed.step == 5)
        #expect(fanSpeed.action == .setFanPercentage)

        let offFanBox = try #require(store.entityBox(for: "fan.office"))
        let offFanFeatures = DashboardCardFeatureProvider.features(
            for: offFanBox,
            presentation: DashboardEntityPresentation(entityBox: offFanBox)
        )
        guard case .level(let offFanSpeed) = try #require(offFanFeatures.first?.content) else {
            Issue.record("Expected off fan speed level feature")
            return
        }
        #expect(offFanSpeed.value == 0)
        #expect(offFanSpeed.step == 10)

        let basicFanBox = try #require(store.entityBox(for: "fan.basic"))
        #expect(DashboardCardFeatureProvider.features(
            for: basicFanBox,
            presentation: DashboardEntityPresentation(entityBox: basicFanBox)
        ).isEmpty)

        let lockBox = try #require(store.entityBox(for: "lock.front_door"))
        let lockFeatures = DashboardCardFeatureProvider.features(
            for: lockBox,
            presentation: DashboardEntityPresentation(entityBox: lockBox)
        )
        #expect(lockFeatures.map(\.key) == [.lockControls])
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: lockBox) == .square)
        guard case .commandGroup(let lockCommands) = try #require(lockFeatures.first?.content) else {
            Issue.record("Expected lock command feature")
            return
        }
        #expect(lockCommands.commands.map(\.action) == [.lock, .unlock])
        #expect(lockCommands.commands.first?.isDisabled == true)
        #expect(lockCommands.commands.last?.isDisabled == false)
        let selectBox = try #require(store.entityBox(for: "select.house_mode"))
        let selectFeatures = DashboardCardFeatureProvider.features(
            for: selectBox,
            presentation: DashboardEntityPresentation(entityBox: selectBox)
        )
        #expect(selectFeatures.map(\.key) == [.selectOptions])
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: selectBox) == .compact)
        guard case .options(let selectOptions) = try #require(selectFeatures.first?.content) else {
            Issue.record("Expected select options feature")
            return
        }
        #expect(selectOptions.selectedValue == "Home")
        #expect(selectOptions.selectedDisplayValue == "Home")
        #expect(selectOptions.options.map(\.value) == ["Morning", "Home", "Away"])
        #expect(selectOptions.options.map(\.isSelected) == [false, true, false])

        let inputSelectBox = try #require(store.entityBox(for: "input_select.guest_mode"))
        let inputSelectFeatures = DashboardCardFeatureProvider.features(
            for: inputSelectBox,
            presentation: DashboardEntityPresentation(entityBox: inputSelectBox)
        )
        #expect(inputSelectBox.domain == .select)
        #expect(inputSelectFeatures.map(\.key) == [.selectOptions])
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: inputSelectBox) == .compact)

        let emptySelectBox = try #require(store.entityBox(for: "select.empty_mode"))
        #expect(DashboardCardFeatureProvider.features(
            for: emptySelectBox,
            presentation: DashboardEntityPresentation(entityBox: emptySelectBox)
        ).isEmpty)
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: emptySelectBox) == .compact)

        let batteryBox = try #require(store.entityBox(for: "sensor.front_door_battery"))
        let batteryFeatures = DashboardCardFeatureProvider.features(
            for: batteryBox,
            presentation: DashboardEntityPresentation(entityBox: batteryBox)
        )
        #expect(batteryFeatures.map(\.key) == [.sensorGauge])
        #expect(DashboardCardSize.defaultGeneratedSize(entityBox: batteryBox) == .compact)
        guard case .gauge(let gauge) = try #require(batteryFeatures.first?.content) else {
            Issue.record("Expected sensor gauge feature")
            return
        }
        #expect(gauge.presentation.range == 0...100)
        #expect(gauge.presentation.status == .warning)

        let temperatureBox = try #require(store.entityBox(for: "sensor.living_room_temperature"))
        #expect(DashboardCardFeatureProvider.features(
            for: temperatureBox,
            presentation: DashboardEntityPresentation(entityBox: temperatureBox)
        ).isEmpty)
    }

    @MainActor
    @Test func lockCardFeatureProviderDisablesUnavailableLockCommands() throws {
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
            ),
            DashboardCardFeature(
                key: .selectOptions,
                title: "Options",
                content: .options(
                    DashboardCardOptionsFeature(
                        selectedValue: "Home",
                        selectedDisplayValue: "Home",
                        options: [
                            DashboardCardOption(value: "Home", displayValue: "Home", isSelected: true),
                            DashboardCardOption(value: "Away", displayValue: "Away", isSelected: false)
                        ]
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
        #expect(DashboardCardSize.large.visibleFeatures(from: features).map(\.key) == [.coverControls, .coverPosition, .selectOptions])
        #expect(DashboardCardSize.large.visibleFeatures(from: features, visibility: .hidden).isEmpty)
        #expect(DashboardCardSize.large.visibleFeatures(from: features, visibility: .automatic).map(\.key) == [.coverControls, .coverPosition, .selectOptions])

        let optionFeatures = [features[2]]
        #expect(DashboardCardSize.mini.visibleFeatures(from: optionFeatures).isEmpty)
        #expect(DashboardCardSize.compact.visibleFeatures(from: optionFeatures).isEmpty)
        #expect(DashboardCardSize.row.visibleFeatures(from: optionFeatures).map(\.key) == [.selectOptions])
        #expect(DashboardCardSize.square.visibleFeatures(from: optionFeatures).map(\.key) == [.selectOptions])
        #expect(DashboardCardSize.wide.visibleFeatures(from: optionFeatures).map(\.key) == [.selectOptions])
        #expect(DashboardCardSize.large.visibleFeatures(from: optionFeatures).map(\.key) == [.selectOptions])
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
        #expect(security.value == "All Secure")
        #expect(security.systemImage == "lock.fill")
        #expect(security.iconTint == .security)
        #expect(climate.value == "74.5°")
        #expect(climate.iconTint == .climate)
        #expect(maintenance.title == "Maintenance")
        #expect(maintenance.value == "1 Low Battery")
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
            membershipContext: DashboardSummaryMembershipContext(
                entityMetadataByID: [:],
                preferredClimateReadingEntityIDs: ["sensor.office_temperature"],
                chargingDeviceIDs: []
            ),
            areaNameForEntityID: { _ in "Office" }
        ))

        #expect(detail.sections.first?.items.map(\.entityID) == [
            "fan.office",
            "sensor.office_temperature"
        ])
        #expect(detail.sections.first?.items.contains { $0.entityID == "sensor.office_device_temperature" } == false)
    }

    @MainActor
    @Test func summaryVisibleOrderKeepsItemsStableAcrossStatusChanges() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.same_name_zeta",
                state: "off",
                attributes: ["friendly_name": .string("Shared Name")]
            ),
            HAEntityDTO(
                entityID: "light.alpha",
                state: "on",
                attributes: ["friendly_name": .string("Alpha")]
            ),
            HAEntityDTO(
                entityID: "light.gamma",
                state: "on",
                attributes: ["friendly_name": .string("Gamma")]
            ),
            HAEntityDTO(
                entityID: "light.same_name_beta",
                state: "off",
                attributes: ["friendly_name": .string("Shared Name")]
            )
        ])
        let initialDetail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .lights,
            entityBoxes: store.allEntityBoxes(),
            areaNameForEntityID: { _ in "Kitchen" }
        ))
        var visibleOrder = DashboardSummaryVisibleOrder()
        visibleOrder.reconcile(with: initialDetail)
        let initialSection = try #require(initialDetail.sections.first)
        let initialEntityIDs = visibleOrder.items(in: initialSection).map(\.entityID)

        #expect(initialEntityIDs == [
            "light.alpha",
            "light.gamma",
            "light.same_name_beta",
            "light.same_name_zeta"
        ])

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "light.same_name_zeta",
                state: "on",
                attributes: ["friendly_name": .string("Shared Name")]
            ),
            HAEntityDTO(
                entityID: "light.alpha",
                state: "off",
                attributes: ["friendly_name": .string("Alpha")]
            ),
            HAEntityDTO(
                entityID: "light.gamma",
                state: "unavailable",
                attributes: ["friendly_name": .string("Gamma")]
            ),
            HAEntityDTO(
                entityID: "light.same_name_beta",
                state: "off",
                attributes: ["friendly_name": .string("Shared Name")]
            )
        ])
        let updatedDetail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .lights,
            entityBoxes: store.allEntityBoxes(),
            areaNameForEntityID: { _ in "Kitchen" }
        ))
        let reopenedDetail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .lights,
            entityBoxes: store.allEntityBoxes(),
            areaNameForEntityID: { _ in "Kitchen" }
        ))

        visibleOrder.reconcile(with: updatedDetail)
        let updatedSection = try #require(updatedDetail.sections.first)
        let visibleItems = visibleOrder.items(in: updatedSection)

        #expect(visibleItems.map(\.entityID) == initialEntityIDs)
        #expect(reopenedDetail.sections.first?.items.map(\.entityID) == initialEntityIDs)
        #expect(visibleItems.first { $0.entityID == "light.same_name_zeta" }?.isActive == true)
        #expect(visibleItems.first { $0.entityID == "light.alpha" }?.isActive == false)
        #expect(visibleItems.first { $0.entityID == "light.gamma" }?.isAvailable == false)
        #expect(updatedDetail.summary.value == "1 On")
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
        let membershipContext = store.dashboardSummaryMembershipContext()

        let lights = try #require(DashboardSummaryProvider.makeDetail(
            kind: .lights,
            entityBoxes: boxes,
            membershipContext: membershipContext
        ))
        #expect(lights.sections.flatMap(\.items).map(\.entityID) == ["light.room"])

        let maintenance = try #require(DashboardSummaryProvider.makeDetail(
            kind: .maintenance,
            entityBoxes: boxes,
            membershipContext: membershipContext
        ))
        #expect(maintenance.sections.flatMap(\.items).map(\.entityID) == [
            "binary_sensor.remote_low_battery",
            "sensor.remote_diagnostic_battery",
            "sensor.remote_battery"
        ])

        let media = try #require(DashboardSummaryProvider.makeDetail(
            kind: .media,
            entityBoxes: boxes,
            membershipContext: membershipContext
        ))
        #expect(media.sections.flatMap(\.items).map(\.entityID) == ["media_player.tv"])

        let security = try #require(DashboardSummaryProvider.makeDetail(
            kind: .security,
            entityBoxes: boxes,
            membershipContext: membershipContext
        ))
        #expect(security.sections.flatMap(\.items).map(\.entityID) == ["binary_sensor.case_tamper"])
    }

    @MainActor
    @Test func summariesMatchCurrentHomeAssistantFrontendMembershipRules() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "humidifier.bedroom", state: "off"),
            HAEntityDTO(entityID: "water_heater.house", state: "eco"),
            HAEntityDTO(entityID: "camera.entry_snapshot", state: "idle"),
            HAEntityDTO(entityID: "camera.hidden_driveway", state: "idle"),
            HAEntityDTO(entityID: "camera.diagnostic_thumbnail", state: "idle"),
            HAEntityDTO(
                entityID: "binary_sensor.attic_heat",
                state: "on",
                attributes: ["device_class": .string("heat")]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.window_vibration",
                state: "on",
                attributes: ["device_class": .string("vibration")]
            ),
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "10",
                attributes: ["device_class": .string("battery")]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.remote_low_battery",
                state: "on",
                attributes: ["device_class": .string("battery")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "camera.hidden_driveway",
                    deviceID: nil,
                    originalName: "Hidden Driveway",
                    hiddenBy: true
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "camera.diagnostic_thumbnail",
                    deviceID: nil,
                    originalName: "Diagnostic Thumbnail",
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.remote_battery",
                    deviceID: nil,
                    originalName: "Remote Battery",
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "binary_sensor.remote_low_battery",
                    deviceID: nil,
                    originalName: "Remote Low Battery",
                    entityCategory: "diagnostic"
                )
            ],
            devices: []
        )

        let boxes = store.allEntityBoxes()
        let membershipContext = store.dashboardSummaryMembershipContext()
        let climate = try #require(DashboardSummaryProvider.makeDetail(
            kind: .climate,
            entityBoxes: boxes,
            membershipContext: membershipContext
        ))
        let security = try #require(DashboardSummaryProvider.makeDetail(
            kind: .security,
            entityBoxes: boxes,
            membershipContext: membershipContext
        ))
        let maintenance = try #require(DashboardSummaryProvider.makeDetail(
            kind: .maintenance,
            entityBoxes: boxes,
            membershipContext: membershipContext
        ))

        #expect(Set(climate.sections.flatMap(\.items).map(\.entityID)) == [
            "humidifier.bedroom",
            "water_heater.house"
        ])
        #expect(security.sections.flatMap(\.items).map(\.entityID) == ["camera.entry_snapshot"])
        #expect(maintenance.sections.flatMap(\.items).map(\.entityID) == ["sensor.remote_battery"])
    }

    @MainActor
    @Test func climateAndMaintenanceSummaryValuesMatchHomeAssistantBehavior() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.downstairs_temperature",
                state: "68",
                attributes: ["device_class": .string("temperature")]
            ),
            HAEntityDTO(
                entityID: "sensor.upstairs_temperature",
                state: "72",
                attributes: ["device_class": .string("temperature")]
            ),
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "10",
                attributes: ["device_class": .string("battery")]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.remote_charging",
                state: "on",
                attributes: ["device_class": .string("battery_charging")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.remote_battery",
                    deviceID: "remote",
                    originalName: "Battery"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "binary_sensor.remote_charging",
                    deviceID: "remote",
                    originalName: "Charging"
                )
            ],
            devices: [HADeviceRegistryDTO(id: "remote", name: "Remote")],
            areas: [
                HAAreaRegistryDTO(
                    id: "downstairs",
                    name: "Downstairs",
                    temperatureEntityID: "sensor.downstairs_temperature"
                ),
                HAAreaRegistryDTO(
                    id: "upstairs",
                    name: "Upstairs",
                    temperatureEntityID: "sensor.upstairs_temperature"
                )
            ]
        )

        let membershipContext = store.dashboardSummaryMembershipContext()
        let climate = try #require(DashboardSummaryProvider.makeSummary(
            kind: .climate,
            entityBoxes: store.allEntityBoxes(),
            membershipContext: membershipContext
        ))
        let maintenance = try #require(DashboardSummaryProvider.makeSummary(
            kind: .maintenance,
            entityBoxes: store.allEntityBoxes(),
            membershipContext: membershipContext
        ))

        #expect(climate.value == "68–72°")
        #expect(maintenance.value == "All Good")
        #expect(!maintenance.isActive)
    }

    @MainActor
    @Test func climateSummaryFallsBackToAreaThermostatTemperatures() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "climate.upstairs_primary",
                state: "cool",
                attributes: ["current_temperature": .number(66.3)]
            ),
            HAEntityDTO(
                entityID: "climate.upstairs_secondary",
                state: "cool",
                attributes: ["current_temperature": .number(67.7)]
            ),
            HAEntityDTO(
                entityID: "climate.downstairs",
                state: "cool",
                attributes: ["current_temperature": .number(70)]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "climate.upstairs_primary",
                    deviceID: nil,
                    areaID: "upstairs",
                    originalName: "Upstairs Primary"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "climate.upstairs_secondary",
                    deviceID: nil,
                    areaID: "upstairs",
                    originalName: "Upstairs Secondary"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "climate.downstairs",
                    deviceID: nil,
                    areaID: "downstairs",
                    originalName: "Downstairs"
                )
            ],
            devices: [],
            areas: [
                HAAreaRegistryDTO(id: "upstairs", name: "Upstairs"),
                HAAreaRegistryDTO(id: "downstairs", name: "Downstairs")
            ]
        )

        let climate = try #require(DashboardSummaryProvider.makeSummary(
            kind: .climate,
            entityBoxes: store.allEntityBoxes(),
            membershipContext: store.dashboardSummaryMembershipContext()
        ))

        #expect(climate.value == "67–70°")
    }

    @MainActor
    @Test func climateSummaryShowsExplicitEmptyStateWithoutTemperatureReadings() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "climate.upstairs", state: "cool")
        ])

        let climate = try #require(DashboardSummaryProvider.makeSummary(
            kind: .climate,
            entityBoxes: store.allEntityBoxes()
        ))

        #expect(climate.value == "No Readings")
    }

    @MainActor
    @Test func climateSummaryPrefersConfiguredAreaReadingOverThermostatFallback() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.upstairs_temperature",
                state: "68.5",
                attributes: ["device_class": .string("temperature")]
            ),
            HAEntityDTO(
                entityID: "climate.upstairs",
                state: "cool",
                attributes: ["current_temperature": .number(74)]
            ),
            HAEntityDTO(
                entityID: "climate.downstairs",
                state: "cool",
                attributes: ["current_temperature": .number(66.3)]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "climate.upstairs",
                    deviceID: nil,
                    areaID: "upstairs",
                    originalName: "Upstairs"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "climate.downstairs",
                    deviceID: nil,
                    areaID: "downstairs",
                    originalName: "Downstairs"
                )
            ],
            devices: [],
            areas: [
                HAAreaRegistryDTO(
                    id: "upstairs",
                    name: "Upstairs",
                    temperatureEntityID: "sensor.upstairs_temperature"
                ),
                HAAreaRegistryDTO(id: "downstairs", name: "Downstairs")
            ]
        )

        let climate = try #require(DashboardSummaryProvider.makeSummary(
            kind: .climate,
            entityBoxes: store.allEntityBoxes(),
            membershipContext: store.dashboardSummaryMembershipContext()
        ))

        #expect(climate.value == "66.3–68.5°")
    }

    @MainActor
    @Test func dashboardSummaryMembershipContextInvalidatesWhenStateChanges() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.remote_battery",
                state: "10",
                attributes: ["device_class": .string("battery")]
            ),
            HAEntityDTO(
                entityID: "binary_sensor.remote_charging",
                state: "off",
                attributes: ["device_class": .string("battery_charging")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.remote_battery",
                    deviceID: "remote",
                    originalName: "Battery"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "binary_sensor.remote_charging",
                    deviceID: "remote",
                    originalName: "Charging"
                )
            ],
            devices: [HADeviceRegistryDTO(id: "remote", name: "Remote")]
        )

        let initialContext = store.dashboardSummaryMembershipContext()
        #expect(initialContext.chargingDeviceIDs.isEmpty)

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "binary_sensor.remote_charging",
                state: "on",
                attributes: ["device_class": .string("battery_charging")]
            )
        ])

        let updatedContext = store.dashboardSummaryMembershipContext()
        #expect(updatedContext.chargingDeviceIDs == ["remote"])

        let maintenance = try #require(DashboardSummaryProvider.makeSummary(
            kind: .maintenance,
            workspace: store.dashboardSummaryWorkspace()
        ))
        #expect(maintenance.value == "All Good")
        #expect(!maintenance.isActive)
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

    @MainActor
    @Test func securityActivityIncludesAllPeopleAlongsideSecurityEntities() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "lock.front_door", state: "locked"),
            HAEntityDTO(entityID: "person.malissa", state: "not_home"),
            HAEntityDTO(entityID: "person.tyler", state: "home"),
            HAEntityDTO(entityID: "light.entryway", state: "on"),
            HAEntityDTO(entityID: "camera.hidden_driveway", state: "idle")
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "person.malissa",
                    deviceID: nil,
                    originalName: "Malissa",
                    hiddenBy: true
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "camera.hidden_driveway",
                    deviceID: nil,
                    originalName: "Hidden Driveway",
                    hiddenBy: true
                )
            ],
            devices: []
        )

        let entityIDs = HomeAssistantSummaryClassifier.securityActivityEntityIDs(
            from: store.allEntityBoxes(),
            context: store.dashboardSummaryMembershipContext()
        )

        #expect(entityIDs == [
            "lock.front_door",
            "person.malissa",
            "person.tyler"
        ])
    }

    @MainActor
    @Test func summaryDetailsGroupAreasByFloorAndKeepUnassignedDevicesSeparate() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on"),
            HAEntityDTO(entityID: "light.bedroom", state: "off"),
            HAEntityDTO(entityID: "light.garage", state: "off"),
            HAEntityDTO(entityID: "light.portable", state: "off")
        ])
        let contexts: [String: DashboardAreaContext] = [
            "light.kitchen": DashboardAreaContext(
                areaID: "kitchen",
                name: "Kitchen",
                icon: nil,
                floorID: "main",
                floorName: "Main Floor",
                floorLevel: 0,
                floorSortOrder: 0
            ),
            "light.bedroom": DashboardAreaContext(
                areaID: "bedroom",
                name: "Bedroom",
                icon: nil,
                floorID: "upstairs",
                floorName: "Upstairs",
                floorLevel: 1,
                floorSortOrder: 1
            ),
            "light.garage": DashboardAreaContext(
                areaID: "garage",
                name: "Garage",
                icon: nil,
                floorID: nil,
                floorName: nil,
                floorLevel: nil,
                floorSortOrder: nil
            )
        ]

        let detail = try #require(DashboardSummaryProvider.makeDetail(
            kind: .lights,
            entityBoxes: store.allEntityBoxes(),
            areaContextForEntityID: { contexts[$0] }
        ))

        #expect(detail.groups.map(\.title) == [
            "Main Floor",
            "Upstairs",
            "Other Areas",
            "Unassigned"
        ])
        #expect(detail.groups.prefix(3).allSatisfy { $0.systemImage == nil })
        #expect(detail.groups.last?.systemImage == "square.grid.2x2")
        #expect(detail.groups.flatMap(\.sections).map(\.areaID) == [
            "kitchen",
            "bedroom",
            "garage",
            nil
        ])
        #expect(detail.groups.last?.sections.first?.title == nil)
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
                    platform: "unifi",
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "light.kitchen",
                    deviceID: "kitchen-light",
                    areaID: "kitchen",
                    originalName: "Kitchen Light",
                    platform: "hue"
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
        #expect(summaries.last?.platform == "unifi")
        #expect(summaries.last?.entityCount == 1)
        #expect(summaries.last?.rowSubtitle == "1 entity")
        #expect(summaries.last?.detailSubtitle == "Ubiquiti • Dream Machine • Closet • 1 entity • 1 unavailable")
        #expect(summaries.last?.matches(query: "closet") == true)
        #expect(summaries.last?.matches(query: "dream") == true)
        #expect(summaries.last?.matches(query: "kitchen") == false)
        #expect(store.entityRegistryAdminDetail(for: "sensor.router_status") == "Closet • Router • Diagnostic • Unavailable")
        #expect(store.entityRegistryAdminDetail(for: "light.kitchen") == "Kitchen • Kitchen Light")
    }

    @Test @MainActor func integrationManagementSummariesGroupRegistryPlatforms() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "light.kitchen", state: "on"),
            HAEntityDTO(entityID: "sensor.bridge_status", state: "unavailable"),
            HAEntityDTO(entityID: "switch.outlet", state: "off")
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "light.kitchen",
                    deviceID: "hue-bridge",
                    originalName: "Kitchen",
                    platform: "hue"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "sensor.bridge_status",
                    deviceID: "hue-bridge",
                    originalName: "Bridge Status",
                    platform: "hue",
                    hiddenBy: true,
                    entityCategory: "diagnostic"
                ),
                HAEntityRegistryDisplayDTO(
                    entityID: "switch.outlet",
                    deviceID: "plug",
                    originalName: "Outlet",
                    platform: "tplink",
                    entityCategory: "config"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "hue-bridge", name: "Hue Bridge"),
                HADeviceRegistryDTO(id: "plug", name: "Plug")
            ]
        )

        let summaries = store.integrationManagementSummaries()

        #expect(summaries.map(\.platform) == ["hue", "tplink"])
        #expect(summaries.first?.title == "Hue")
        #expect(summaries.first?.entityCount == 2)
        #expect(summaries.first?.deviceCount == 1)
        #expect(summaries.first?.unavailableEntityCount == 1)
        #expect(summaries.first?.hiddenEntityCount == 1)
        #expect(summaries.first?.diagnosticEntityCount == 1)
        #expect(summaries.first?.entityIDs == ["sensor.bridge_status", "light.kitchen"])
        #expect(summaries.first?.devices.map(\.title) == ["Hue Bridge"])
        #expect(summaries.first?.unassignedEntityIDs.isEmpty == true)
        #expect(summaries.first?.subtitle == "1 device")
        #expect(summaries.first?.detailSubtitle == "2 entities • 1 device • 1 unavailable")
        #expect(summaries.last?.configEntityCount == 1)
        #expect(summaries.first?.matches(query: "hue") == true)
    }

    @Test @MainActor func managementOrganizationUsesAreasScopedCategoriesLabelsAndActivity() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "automation.arrival_lights",
                state: "on",
                attributes: ["last_triggered": .string("2026-07-10T15:00:00Z")]
            )
        ])
        store.applyRegistryMetadata(
            entities: [
                HAEntityRegistryDisplayDTO(
                    entityID: "automation.arrival_lights",
                    deviceID: nil,
                    areaID: "entry",
                    originalName: "Arrival Lights"
                )
            ],
            devices: [
                HADeviceRegistryDTO(id: "bridge", name: "Bridge", labels: ["important"])
            ],
            areas: [HAAreaRegistryDTO(id: "entry", name: "Entry", icon: "mdi:door")],
            organization: [
                HAEntityOrganizationDTO(
                    entityID: "automation.arrival_lights",
                    labels: ["important"],
                    categories: ["automation": "presence"]
                )
            ],
            labels: [HALabelRegistryDTO(id: "important", name: "Important", icon: nil, color: nil)],
            categories: [HACategoryRegistryDTO(id: "presence", name: "Presence", scope: .automation)]
        )

        #expect(store.managementAreaName(for: "automation.arrival_lights") == "Entry")
        #expect(store.managementArea(for: "automation.arrival_lights")?.icon == "mdi:door")
        #expect(store.managementCategory(for: "automation.arrival_lights", scope: .automation)?.name == "Presence")
        #expect(store.managementLabels(for: "automation.arrival_lights").map(\.name) == ["Important"])
        #expect(store.managementOrganizationDetail(for: "automation.arrival_lights", scope: .automation) == "Entry • Presence")
        #expect(store.managementSearchMetadata(for: "automation.arrival_lights", scope: .automation) == "Entry Presence Important")
        let expectedActivityDate = HADateParser.date(from: "2026-07-10T15:00:00Z")
        #expect(store.managementActivityDate(for: "automation.arrival_lights") == expectedActivityDate)
        #expect(store.deviceManagementSummaries().first?.labels == ["Important"])
    }

    @Test @MainActor func helperManagementSummariesClassifyHelperEntityDomains() {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(entityID: "input_boolean.guest_mode", state: "off"),
            HAEntityDTO(entityID: "input_select.house_mode", state: "Home"),
            HAEntityDTO(entityID: "counter.coffee_count", state: "3"),
            HAEntityDTO(entityID: "light.kitchen", state: "on")
        ])

        let summaries = store.helperManagementSummaries()

        #expect(store.helperEntityIDs() == [
            "input_boolean.guest_mode",
            "input_select.house_mode",
            "counter.coffee_count"
        ])
        #expect(summaries.map(\.domain) == [.counter, .inputSelect, .inputBoolean])
        #expect(HAHelperDomain(entityID: "input_text.note") == .inputText)
        #expect(HAHelperDomain(entityID: "light.kitchen") == nil)
    }

    @Test @MainActor func iCloudSyncPayloadIncludesOnlyHomesteadPreferences() throws {
        let defaults = testUserDefaults()
        let connectionSettings = HAConnectionSettings(baseURL: "https://home.example", defaults: defaults, tokenStore: InMemoryHAOAuthTokenStore())
        connectionSettings.internalURL = "http://homeassistant.local:8123"
        connectionSettings.externalURL = "https://home.example"
        connectionSettings.homeNetworkName = "Home Wi-Fi"
        let dashboardConfiguration = DashboardConfiguration(defaults: defaults)
        let dashboardItemID = try #require(dashboardConfiguration.add(
            source: .entity("light.kitchen"),
            presentation: .card(.control(
                layout: .square,
                featureVisibility: .automatic
            ))
        ))
        dashboardConfiguration.renameDisplayItem(id: dashboardItemID, displayNameOverride: "Kitchen")
        let actionSettings = ActionConfirmationSettings(defaults: defaults)
        actionSettings.mode = .all
        let appearanceSettings = HomesteadAppearanceSettings(
            profileID: connectionSettings.activeProfileID,
            defaults: defaults,
            storageDirectory: try temporaryTestDirectory()
        )
        let syncService = HomesteadICloudSyncService(defaults: defaults, store: FakeICloudKeyValueStore())

        let payload = syncService.makePayload(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionSettings,
            appearanceSettings: appearanceSettings,
            now: try testDate("2026-06-14T12:00:00Z")
        )
        let encodedPayload = try syncService.encodedPayload(payload)
        let encodedText = String(decoding: encodedPayload, as: UTF8.self)

        #expect(payload.connection.value.baseURL == "https://home.example")
        #expect(payload.connection.value.internalURL == "http://homeassistant.local:8123")
        #expect(payload.dashboard.value.dashboards.first?.items.first?.entityID == "light.kitchen")
        #expect(payload.dashboard.value.dashboards.first?.items.first?.displayNameOverride == "Kitchen")
        #expect(payload.actionConfirmations.value.mode == .all)
        #expect(!encodedText.contains("Home Wi-Fi"))
        #expect(!encodedText.localizedCaseInsensitiveContains("token"))
        #expect(!encodedText.localizedCaseInsensitiveContains("refresh"))
        #expect(!encodedText.localizedCaseInsensitiveContains("wallpaper.jpg"))
    }

    @Test @MainActor func iCloudBootstrapOffersAndAppliesRemotePreferencesWithoutUploadingDefaults() throws {
        let defaults = testUserDefaults()
        let store = FakeICloudKeyValueStore()
        let syncService = HomesteadICloudSyncService(defaults: defaults, store: store)
        let connectionSettings = HAConnectionSettings(baseURL: "", defaults: defaults, tokenStore: InMemoryHAOAuthTokenStore())
        let dashboardConfiguration = DashboardConfiguration(defaults: defaults)
        let actionSettings = ActionConfirmationSettings(defaults: defaults)
        let appearanceSettings = HomesteadAppearanceSettings(
            profileID: connectionSettings.activeProfileID,
            defaults: defaults,
            storageDirectory: try temporaryTestDirectory()
        )
        let updatedAt = try testDate("2026-06-14T12:00:00Z")
        let payload = HomesteadICloudSyncPayload(
            version: HomesteadICloudSyncPayload.currentVersion,
            sourceDeviceID: "iphone",
            connection: HomesteadSyncRecord(updatedAt: updatedAt, value: HomesteadConnectionSyncSnapshot(
                baseURL: "https://new.example", internalURL: "http://new.local:8123", externalURL: "https://new.example"
            )),
            dashboard: HomesteadSyncRecord(updatedAt: updatedAt, value: DashboardConfigurationSyncSnapshot(
                dashboards: [SavedDashboardConfiguration(
                    id: UUID(),
                    name: "Dashboard",
                    items: [.entityCard(entityID: "switch.outlet", configuration: .status(layout: .wide))]
                )]
            )),
            actionConfirmations: HomesteadSyncRecord(updatedAt: updatedAt, value: ActionConfirmationSettingsSyncSnapshot(
                mode: .off,
                confirmsLockUnlocks: false,
                confirmsSecurityCoverOpens: false,
                confirmsScenes: false,
                confirmsScripts: false,
                confirmsOtherImpactfulActions: false
            )),
            appearance: HomesteadSyncRecord(
                updatedAt: updatedAt,
                value: HomesteadAppearanceSettingsSyncSnapshot(
                    wallpaperEnabledProfileIDs: [connectionSettings.activeProfileID]
                )
            )
        )
        let originalData = try JSONEncoder().encode(payload)
        store.set(originalData, forKey: "homestead.preferences.v2")

        syncService.bootstrap(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionSettings,
            appearanceSettings: appearanceSettings
        )
        #expect(syncService.bootstrapState == .restoreAvailable(HomesteadICloudRestoreSummary(
            serverDisplayName: "https://new.example", dashboardItemCount: 1, updatedAt: updatedAt
        )))
        #expect(store.data(forKey: "homestead.preferences.v2") == originalData)

        syncService.acceptBootstrapRestore(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionSettings,
            appearanceSettings: appearanceSettings
        )

        #expect(connectionSettings.baseURL == "https://new.example")
        #expect(dashboardConfiguration.items.first?.entityID == "switch.outlet")
        #expect(dashboardConfiguration.items.first?.displayNameOverride == nil)
        #expect(actionSettings.mode == .off)
        #expect(!appearanceSettings.isWallpaperEnabled)
        #expect(syncService.lastRemoteChangeDate == updatedAt)
        #expect(syncService.isEnabled)
    }

    @Test func discoveryParsesAdvertisedHomeAndPrefersExternalSignInAddress() {
        let instance = HomeAssistantDiscoveryService.instance(serviceName: "Home Assistant", txt: [
            "uuid": "ABC-123",
            "location_name": "Our Home",
            "internal_url": "http://homeassistant.local:8123",
            "external_url": "https://home.example",
            "version": "2026.6"
        ])

        #expect(instance?.id == "abc-123")
        #expect(instance?.name == "Our Home")
        #expect(instance?.signInURL == "https://home.example")
        #expect(instance?.internalURL == "http://homeassistant.local:8123")
    }

    @Test func iconResolverHonorsPrecedenceAndProvenance() {
        let presentation = IconResolver.resolveEntity(EntityIconResolutionInput(
            domain: "light",
            state: "on",
            registryIcon: "mdi:router-wireless",
            explicitIcon: "mdi:piano",
            presentationOverride: "star.fill",
            appOverride: "heart.fill"
        ))
        #expect(presentation.asset == .sfSymbol("star.fill"))
        #expect(presentation.provenance == .dashboardOverride)
        #expect(presentation.sourceIdentifier == "star.fill")

        let app = IconResolver.resolveEntity(EntityIconResolutionInput(
            domain: "light",
            state: "on",
            registryIcon: "mdi:router-wireless",
            explicitIcon: "mdi:piano",
            appOverride: "heart.fill"
        ))
        #expect(app.asset == .sfSymbol("heart.fill"))
        #expect(app.provenance == .appOverride)

        let registry = IconResolver.resolveEntity(EntityIconResolutionInput(
            domain: "light",
            state: "on",
            registryIcon: "mdi:router-wireless",
            explicitIcon: "mdi:piano"
        ))
        #expect(registry.asset == .sfSymbol("wifi.router.fill"))
        #expect(registry.provenance == .haRegistryIcon)
        #expect(registry.sourceIdentifier == "mdi:router-wireless")
    }

    @Test func iconResolverUsesValidActiveSymbolsForPresenceBinarySensors() {
        for deviceClass in ["motion", "occupancy", "presence"] {
            let active = IconResolver.resolveEntity(EntityIconResolutionInput(
                domain: "binary_sensor",
                deviceClass: deviceClass,
                state: "on"
            ))
            let inactive = IconResolver.resolveEntity(EntityIconResolutionInput(
                domain: "binary_sensor",
                deviceClass: deviceClass,
                state: "off"
            ))

            #expect(active.sfSymbolName == "figure.walk")
            #expect(inactive.sfSymbolName == "figure.stand")
        }
    }

    @Test func iconResolverUsesNativeFirstHybridRendering() throws {
        let mapped = IconResolver.resolveEntity(EntityIconResolutionInput(
            domain: "light",
            state: "on",
            explicitIcon: "mdi:lightbulb"
        ))
        #expect(mapped.asset == .sfSymbol("lightbulb.fill"))
        #expect(mapped.provenance == .haExplicitIcon)
        #expect(mapped.sourceIdentifier == "mdi:lightbulb")

        let materialDesign = IconResolver.resolveEntity(EntityIconResolutionInput(
            domain: "media_player",
            state: "idle",
            explicitIcon: "mdi:piano"
        ))
        #expect(materialDesign.asset == .materialDesign("piano"))
        #expect(try #require(MaterialDesignIconCatalog.glyph(for: "piano")).isEmpty == false)

        let unsupported = IconResolver.resolveEntity(EntityIconResolutionInput(
            domain: "light",
            state: "on",
            explicitIcon: "custom:party-light"
        ))
        #expect(unsupported.asset == .unsupportedHomeAssistant("custom:party-light"))
        #expect(unsupported.sfSymbolName == "lightbulb.fill")
    }

    @Test func iconResolverMapsCuratedMDIIconsToNativeSymbols() {
        let expectations: [(String, String, String)] = [
            ("light", "mdi:chandelier", "chandelier.fill"),
            ("light", "mdi:lamp", "lamp.table.fill"),
            ("light", "mdi:desk-lamp", "lamp.desk.fill"),
            ("light", "mdi:floor-lamp", "lamp.floor.fill"),
            ("light", "mdi:ceiling-light", "light.recessed.3.fill"),
            ("switch", "mdi:power-plug", "powerplug.fill"),
            ("switch", "mdi:power-socket-united-states", "poweroutlet.type.b.fill"),
            ("sensor", "mdi:dishwasher", "dishwasher.fill"),
            ("sensor", "mdi:tumble-dryer", "dryer.fill"),
            ("sensor", "mdi:oven", "oven.fill"),
            ("sensor", "mdi:microwave", "microwave.fill"),
            ("sensor", "mdi:router-wireless", "wifi.router.fill"),
            ("sensor", "mdi:server", "server.rack"),
            ("sensor", "mdi:printer", "printer.fill"),
            ("media_player", "mdi:projector", "videoprojector.fill"),
            ("media_player", "mdi:speaker", "speaker.wave.2.fill"),
            ("cover", "mdi:blinds-open", "blinds.horizontal.open"),
            ("cover", "mdi:curtains-closed", "curtains.closed"),
            ("cover", "mdi:garage-open", "door.garage.open"),
            ("binary_sensor", "mdi:motion-sensor", "figure.motion"),
            ("binary_sensor", "mdi:smoke-detector", "smoke.fill"),
            ("sensor", "mdi:humidity", "humidity.fill")
        ]

        for (domain, mdiIcon, sfSymbol) in expectations {
            let resolved = IconResolver.resolveEntity(EntityIconResolutionInput(
                domain: domain,
                state: "on",
                explicitIcon: mdiIcon
            ))
            #expect(resolved.asset == .sfSymbol(sfSymbol), "Expected \(mdiIcon) to map to \(sfSymbol)")
            #expect(resolved.provenance == .haExplicitIcon)
            #expect(resolved.sourceIdentifier == mdiIcon)
        }
    }

    @Test func iconResolverKeepsAmbiguousMDIIconsAsMaterialDesign() {
        let resolved = IconResolver.resolveEntity(EntityIconResolutionInput(
            domain: "light",
            state: "on",
            explicitIcon: "mdi:lava-lamp"
        ))

        #expect(resolved.asset == .materialDesign("lava-lamp"))
        #expect(resolved.sfSymbolName == "lightbulb.fill")
    }

    @MainActor
    @Test func dashboardIconOverrideRemainsPresentationScoped() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "media_player.piano",
                state: "idle",
                attributes: ["icon": .string("mdi:piano")]
            )
        ])

        let entityBox = try #require(store.entityBox(for: "media_player.piano"))
        let baseIcon = entityBox.homeEntity.resolvedIcon
        let presentation = DashboardEntityPresentation(
            entityBox: entityBox,
            iconNameOverride: "star.fill"
        )

        #expect(baseIcon.asset == .materialDesign("piano"))
        #expect(baseIcon.provenance == .haExplicitIcon)
        #expect(presentation.icon.asset == .sfSymbol("star.fill"))
        #expect(presentation.icon.provenance == .dashboardOverride)
        #expect(entityBox.homeEntity.resolvedIcon == baseIcon)
    }

    @MainActor
    @Test func stateStoreRecomputesIconsOnlyForIconRelevantChanges() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.temperature",
                state: "70",
                attributes: ["device_class": .string("temperature")]
            ),
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["brightness": .number(64)]
            ),
            HAEntityDTO(entityID: "lock.front_door", state: "locked")
        ])
        #expect(store.iconResolutionCount == 3)

        store.applyLiveStateUpdates([
            HAEntityDTO(
                entityID: "sensor.temperature",
                state: "71",
                attributes: ["device_class": .string("temperature")]
            ),
            HAEntityDTO(
                entityID: "light.kitchen",
                state: "on",
                attributes: ["brightness": .number(192)]
            )
        ])
        #expect(store.iconResolutionCount == 3)

        store.applyLiveStateUpdates([
            HAEntityDTO(entityID: "lock.front_door", state: "unlocked")
        ])
        #expect(store.iconResolutionCount == 4)
        #expect(try #require(store.entity(for: "lock.front_door")).resolvedIcon.sfSymbolName == "lock.open.fill")
    }

    @MainActor
    @Test func registryIconUpdateTakesPrecedenceWithoutRedundantRecomputation() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "media_player.piano",
                state: "idle",
                attributes: ["icon": .string("mdi:piano")]
            )
        ])
        #expect(store.iconResolutionCount == 1)

        let registry = HAEntityRegistryDisplayDTO(
            entityID: "media_player.piano",
            deviceID: nil,
            originalName: "Piano",
            icon: "mdi:router-wireless"
        )
        store.applyRegistryMetadata(entities: [registry], devices: [])

        let resolved = try #require(store.entity(for: "media_player.piano")).resolvedIcon
        #expect(resolved.asset == .sfSymbol("wifi.router.fill"))
        #expect(resolved.provenance == .haRegistryIcon)
        #expect(store.iconResolutionCount == 2)

        store.applyRegistryMetadata(entities: [registry], devices: [])
        #expect(store.iconResolutionCount == 2)
    }

    @Test func areaRegistryIconPrecedesNameInference() {
        let resolved = IconResolver.resolveArea(AreaIconResolutionInput(
            name: "Bedroom",
            registryIcon: "mdi:piano"
        ))

        #expect(resolved.asset == .materialDesign("piano"))
        #expect(resolved.provenance == .haRegistryIcon)
        #expect(resolved.fallbackSFSymbol == "bed.double")
    }

    @Test func genericRegistryIconUsesHybridResolverAndFallback() {
        let mapped = IconResolver.resolveRegistryIcon("mdi:router-wireless", fallback: "folder")
        let materialDesign = IconResolver.resolveRegistryIcon("mdi:piano", fallback: "folder")
        let fallback = IconResolver.resolveRegistryIcon(nil, fallback: "folder")

        #expect(mapped.asset == .sfSymbol("wifi.router.fill"))
        #expect(mapped.provenance == .haRegistryIcon)
        #expect(materialDesign.asset == .materialDesign("piano"))
        #expect(fallback.asset == .sfSymbol("folder"))
        #expect(fallback.provenance == .fallback)
    }

    @Test func entityRegistryCompactIconMetadataDecodes() throws {
        let data = Data(#"{"ei":"light.desk","di":null,"en":"Desk","ic":"mdi:piano","pl":"hue","tk":"desk"}"#.utf8)
        let metadata = try JSONDecoder().decode(HAEntityRegistryDisplayDTO.self, from: data)

        #expect(metadata.entityID == "light.desk")
        #expect(metadata.icon == "mdi:piano")
        #expect(metadata.platform == "hue")
        #expect(metadata.translationKey == "desk")
    }

    @Test func legacyWidgetSnapshotDecodesSFSymbolFallback() throws {
        let data = Data(#"{"entityID":"switch.coffee","displayName":"Coffee","isOn":true,"systemImage":"powerplug.fill","areaName":null,"deviceName":null}"#.utf8)
        let snapshot = try JSONDecoder().decode(WidgetSwitchSnapshot.self, from: data)

        #expect(snapshot.icon == nil)
        #expect(snapshot.resolvedIcon.asset == .sfSymbol("powerplug.fill"))
        #expect(snapshot.resolvedIcon.provenance == .homesteadSemanticMapping)
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

    @MainActor
    private func confirmation(
        _ store: HAStateStore,
        _ entityID: String,
        _ domain: String,
        _ service: String,
        _ settings: ActionConfirmationSettingsSnapshot
    ) -> ActionConfirmationPresentation? {
        guard let entityBox = store.entityBox(for: entityID) else {
            Issue.record("Missing test entity \(entityID)")
            return nil
        }

        return ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: domain,
            service: service,
            settings: settings
        )
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

private struct StubCurrentWiFiNetworkProvider: CurrentWiFiNetworkProviding {
    var ssid: String?

    func currentSSID() async -> String? {
        ssid
    }
}

final class StubHAOAuthClient: HAOAuthClientProtocol {
    var exchangeResponse: HAOAuthTokenResponseDTO
    var refreshResponse: HAOAuthTokenResponseDTO
    private(set) var lastExchangeBaseURLString: String?
    private(set) var lastExchangeCode: String?
    private(set) var lastRefreshBaseURLString: String?
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
        lastExchangeBaseURLString = baseURLString
        lastExchangeCode = code
        return exchangeResponse
    }

    func refreshAccessToken(
        baseURLString: String,
        refreshToken: String,
        clientID: String
    ) async throws -> HAOAuthTokenResponseDTO {
        lastRefreshBaseURLString = baseURLString
        lastRefreshToken = refreshToken
        return refreshResponse
    }
}

@MainActor
final class StubHAOAuthAuthorizer: HAOAuthAuthorizing {
    let authorizationCode: String
    let error: Error?
    private(set) var lastAuthorizationURL: URL?

    init(authorizationCode: String = "auth-code", error: Error? = nil) {
        self.authorizationCode = authorizationCode
        self.error = error
    }

    func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        lastAuthorizationURL = authorizationURL
        if let error {
            throw error
        }

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
    private(set) var registryChangeSubscriptionCount = 0
    private(set) var entityRegistryFetchCount = 0
    private var mobileAppPushNotificationHandler: (@Sendable (HAMobileAppPushNotificationEventDTO) async -> Void)?
    private var eventHandler: (@Sendable (HAEventDTO) async -> Void)?
    var callServiceError: Error?
    var currentUser: HACurrentUserDTO?
    var states: [HAEntityDTO]
    var entityRegistryEntities: [HAEntityRegistryDisplayDTO] = []
    var entityOrganization: [HAEntityOrganizationDTO] = []
    var labelRegistry: [HALabelRegistryDTO] = []
    var categoryRegistry: [HACategoryRegistryDTO] = []
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
    private(set) var updatedLocationNames: [String] = []
    var updateLocationNameError: Error?
    var serviceRegistry: HAServiceRegistry = .empty
    var servicesForTarget: [String] = []
    var supervisorAppsResponse = HASupervisorAppsResponseDTO(addons: [])
    var supervisorInfo = HASupervisorInfoDTO(version: nil)
    var operatingSystemInfo = HAOperatingSystemInfoDTO(version: nil)
    var automationConfiguration = HAAutomationConfigurationResponseDTO(config: [:])
    var automationTraces: [HAAutomationTraceDTO] = []
    var fetchServicesDelay: Duration?
    var fetchServicesError: Error?
    var supervisorAppsError: Error?
    var supervisorInfoError: Error?
    var operatingSystemInfoError: Error?
    var connectResults: [Result<Void, Error>] = []
    var connectErrorsByBaseURL: [String: Error] = [:]
    private(set) var fetchSupervisorAppsCount = 0
    private(set) var fetchSupervisorInfoCount = 0
    private(set) var fetchOperatingSystemInfoCount = 0

    init(currentUser: HACurrentUserDTO? = nil, states: [HAEntityDTO] = []) {
        self.currentUser = currentUser
        self.states = states
    }

    func setEventHandler(_ handler: (@Sendable (HAEventDTO) async -> Void)?) async {
        eventHandler = handler
    }

    func setMobileAppPushNotificationHandler(_ handler: (@Sendable (HAMobileAppPushNotificationEventDTO) async -> Void)?) async {
        mobileAppPushNotificationHandler = handler
    }

    func setDisconnectHandler(_ handler: (@MainActor @Sendable (Error) -> Void)?) async {}

    func fetchServicesForTarget(entityID: String) async throws -> [String] {
        servicesForTarget
    }

    func connect(configuration: HAConnectionConfiguration) async throws {
        lastConnectConfiguration = configuration
        connectConfigurations.append(configuration)

        if !connectResults.isEmpty {
            let result = connectResults.removeFirst()
            switch result {
            case .success:
                return
            case .failure(let error):
                throw error
            }
        }

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
        entityRegistryFetchCount += 1
        return HAEntityRegistryDisplayResponseDTO(entities: entityRegistryEntities)
    }

    func fetchEntityOrganization() async throws -> [HAEntityOrganizationDTO] {
        entityOrganization
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

    func fetchLabelRegistry() async throws -> [HALabelRegistryDTO] {
        labelRegistry
    }

    func fetchCategoryRegistry(scope: HAOrganizationScope) async throws -> [HACategoryRegistryDTO] {
        categoryRegistry.filter { $0.scope == scope }
    }

    func fetchConfig() async throws -> HAConfigDTO {
        config
    }

    func updateLocationName(_ locationName: String) async throws {
        if let updateLocationNameError {
            throw updateLocationNameError
        }
        updatedLocationNames.append(locationName)
        config = HAConfigDTO(
            version: config.version,
            locationName: locationName,
            timeZone: config.timeZone,
            internalURL: config.internalURL,
            externalURL: config.externalURL,
            state: config.state,
            configSource: config.configSource,
            unitSystem: config.unitSystem
        )
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

    func fetchSupervisorApps() async throws -> HASupervisorAppsResponseDTO {
        fetchSupervisorAppsCount += 1

        if let supervisorAppsError {
            throw supervisorAppsError
        }

        return supervisorAppsResponse
    }

    func fetchSupervisorInfo() async throws -> HASupervisorInfoDTO {
        fetchSupervisorInfoCount += 1

        if let supervisorInfoError {
            throw supervisorInfoError
        }

        return supervisorInfo
    }

    func fetchOperatingSystemInfo() async throws -> HAOperatingSystemInfoDTO {
        fetchOperatingSystemInfoCount += 1

        if let operatingSystemInfoError {
            throw operatingSystemInfoError
        }

        return operatingSystemInfo
    }

    func fetchAutomationConfiguration(entityID: String) async throws -> HAAutomationConfigurationResponseDTO {
        automationConfiguration
    }

    func fetchScriptConfiguration(entityID: String) async throws -> HAAutomationConfigurationResponseDTO {
        automationConfiguration
    }

    func fetchAutomationTraces(itemID: String) async throws -> [HAAutomationTraceDTO] {
        automationTraces
    }

    func subscribeToStateChanges() async throws {}

    func subscribeToRegistryChanges() async throws {
        registryChangeSubscriptionCount += 1
    }

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

    func emitEvent(_ event: HAEventDTO) async {
        await eventHandler?(event)
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
    var historyDelay: Duration?
    private(set) var lastLogbookConfiguration: HAConnectionConfiguration?
    private(set) var lastLogbookRequest: HALogbookRequest?
    private(set) var lastHistoryConfiguration: HAConnectionConfiguration?
    private(set) var lastHistoryRequest: HAHistoryRequest?
    private(set) var historyFetchCount = 0

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
        historyFetchCount += 1
        lastHistoryConfiguration = configuration
        lastHistoryRequest = request

        if let historyDelay {
            try await Task.sleep(for: historyDelay)
        }

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
    private(set) var lastRegistrationUpdateConfiguration: HAConnectionConfiguration?
    private(set) var lastRegistrationToUpdate: HAMobileAppRegistrationInfo?
    private(set) var lastRegistrationUpdate: HAMobileAppRegistrationUpdateDTO?
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

    func updateRegistration(
        configuration: HAConnectionConfiguration,
        registration: HAMobileAppRegistrationInfo,
        update: HAMobileAppRegistrationUpdateDTO
    ) async throws {
        lastRegistrationUpdateConfiguration = configuration
        lastRegistrationToUpdate = registration
        lastRegistrationUpdate = update
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
final class StubNativeRemoteNotificationRegistrationClient: NativeRemoteNotificationRegistrationClient {
    private(set) var registerCallCount = 0

    func registerForRemoteNotifications() async {
        registerCallCount += 1
    }
}

final class StubHomesteadPushTokenRegistrationClient: HomesteadPushTokenRegistrationClient {
    var error: Error?
    private(set) var lastRequest: HomesteadPushTokenRegistrationRequest?

    init(error: Error? = nil) {
        self.error = error
    }

    func register(_ request: HomesteadPushTokenRegistrationRequest) async throws {
        lastRequest = request

        if let error {
            throw error
        }
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

private extension LightEntity {
    var testIconName: String {
        IconResolver.resolveEntity(
            EntityIconResolutionInput(domain: "light", state: isOn ? "on" : "off")
        ).sfSymbolName
    }
}

private extension SensorEntity {
    var testIconName: String {
        IconResolver.resolveEntity(
            EntityIconResolutionInput(domain: "sensor", deviceClass: deviceClass, state: value)
        ).sfSymbolName
    }
}

private extension BinarySensorEntity {
    var testIconName: String {
        IconResolver.resolveEntity(
            EntityIconResolutionInput(domain: "binary_sensor", deviceClass: deviceClass, state: state)
        ).sfSymbolName
    }
}

private extension CoverEntity {
    var testIconName: String {
        IconResolver.resolveEntity(
            EntityIconResolutionInput(domain: "cover", deviceClass: deviceClass, state: state)
        ).sfSymbolName
    }
}

private extension MediaPlayerEntity {
    var testIconName: String {
        IconResolver.resolveEntity(
            EntityIconResolutionInput(domain: "media_player", deviceClass: deviceClass, state: state)
        ).sfSymbolName
    }
}
