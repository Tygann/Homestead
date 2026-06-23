import Foundation
import Testing
@testable import Homestead

struct ConnectionPresentationTests {
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

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .preparing,
            dataFreshness: .empty
        ) == nil)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .preparing,
            dataFreshness: .cached(Date(timeIntervalSinceNow: -60))
        ) == nil)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connecting,
            dataFreshness: .cached(Date(timeIntervalSinceNow: -60))
        ) == nil)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connected,
            dataFreshness: .cached(Date(timeIntervalSinceNow: -60))
        ) == nil)

        let cachedState = AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connected,
            dataFreshness: .cached(Date(timeIntervalSinceNow: -180))
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
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline"),
            suppressTransientConnectionHealth: true
        ) == nil)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .connected,
            dataFreshness: .stale("offline", lastUpdated: Date(timeIntervalSinceNow: -8)),
            suppressTransientConnectionHealth: true
        ) == nil)

        let failedState = AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .failed("No route to host"),
            dataFreshness: .empty
        )
        #expect(failedState?.title == "Connection failed")
        #expect(failedState?.message.contains("Tap to retry") == true)
        #expect(failedState?.message.contains("Check your network") == true)
        #expect(failedState?.message.contains("No route to host") == false)

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .failed("No route to host"),
            dataFreshness: .empty,
            suppressTransientConnectionHealth: true
        )?.title == "Connection failed")

        #expect(AppStatusAccessoryState.make(
            hasHomeAssistantSession: true,
            connectionStatus: .disconnected,
            dataFreshness: .empty
        ) == .disconnected)
    }

    @Test func settingsConnectionStatusUsesRecoveryCopyForRawFailures() {
        let message = SettingsHomeAssistantStatus.detailMessage(
            authState: .signedIn(HAAuthSessionSummary(credential: testCredential())),
            connectionStatus: .failed("NSURLErrorDomain -1001"),
            serviceError: "No route to host",
            storageError: nil
        )

        #expect(message.contains("Check your network") == true)
        #expect(message.contains("No route to host") == false)
        #expect(message.contains("NSURLErrorDomain") == false)
    }

    @Test func settingsAccountStatusSoftensConnectionFailureWhenCacheIsUsable() {
        let credential = testCredential()
        let authState = HAAuthState.signedIn(HAAuthSessionSummary(credential: credential))

        #expect(SettingsHomeAssistantStatus.summaryStatusText(
            authState: authState,
            connectionStatus: .failed("No route to host"),
            dataFreshness: .cached(Date(timeIntervalSinceNow: -30))
        ) == "Using Cache")

        #expect(SettingsHomeAssistantStatus.summaryStatusText(
            authState: authState,
            connectionStatus: .reconnecting,
            dataFreshness: .cached(Date(timeIntervalSinceNow: -30))
        ) == "Updating")

        #expect(SettingsHomeAssistantStatus.summaryStatusText(
            authState: .refreshFailed("Token expired"),
            connectionStatus: .failed("No route to host"),
            dataFreshness: .cached(Date(timeIntervalSinceNow: -30))
        ) == "Error")
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

        let credential = testCredential()
        let signedInChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline"),
            serviceFeedback: HAServiceFeedback(title: "Done", message: nil, style: .success)
        )

        #expect(signedInChrome.statusAccessoryState == .reconnecting)

        let preparingChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .preparing,
            dataFreshness: .cached(Date(timeIntervalSinceNow: -8)),
            serviceFeedback: nil
        )
        #expect(preparingChrome.statusAccessoryState == nil)

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

        let suppressedReconnectChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .reconnecting,
            dataFreshness: .stale("offline", lastUpdated: Date(timeIntervalSinceNow: -8)),
            serviceFeedback: nil,
            suppressTransientConnectionHealth: true
        )
        #expect(suppressedReconnectChrome.statusAccessoryState == nil)

        let failedDuringSuppressionChrome = AppChromePresentation.make(
            hasServerURL: true,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            connectionStatus: .failed("No route to host"),
            dataFreshness: .stale("offline"),
            serviceFeedback: nil,
            suppressTransientConnectionHealth: true
        )
        #expect(failedDuringSuppressionChrome.statusAccessoryState?.title == "Connection failed")
    }

    private func testCredential() -> HAOAuthCredential {
        HAOAuthCredential(
            baseURLString: "http://homeassistant.local:8123",
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: "access-token",
            accessTokenExpiresAt: .distantFuture,
            tokenType: "Bearer",
            updatedAt: .now
        )
    }
}
