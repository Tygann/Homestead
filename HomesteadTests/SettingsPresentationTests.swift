import Foundation
import SwiftUI
import Testing
@testable import Homestead

struct SettingsPresentationTests {
    @Test func serverRelationshipNormalizesEquivalentServers() {
        #expect(SettingsServerRelationship.make(
            configuredBaseURL: "HTTPS://ha.example.com/",
            signedInBaseURL: "https://ha.example.com"
        ) == .matches)
    }

    @Test func serverRelationshipReportsConfiguredAndAuthenticatedMismatch() {
        let relationship = SettingsServerRelationship.make(
            configuredBaseURL: "https://configured.example.com",
            signedInBaseURL: "https://signed-in.example.com"
        )

        #expect(relationship == .mismatch(
            configured: "configured.example.com",
            signedIn: "signed-in.example.com"
        ))
        #expect(relationship.isMismatch)
        #expect(relationship.warningMessage?.contains("configured.example.com") == true)
        #expect(relationship.warningMessage?.contains("signed-in.example.com") == true)
    }

    @Test @MainActor func supportPresentationKeepsAccountAndEnvironmentDetailsOutOfVisibleRows() {
        let defaults = testUserDefaults()
        let credential = HAOAuthCredential(
            baseURLString: "https://ha.example.com",
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh-token",
            accessToken: "access-token",
            accessTokenExpiresAt: Date(timeIntervalSince1970: 1_900_000_000),
            tokenType: "Bearer",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let tokenStore = InMemoryHAOAuthTokenStore(credential: credential)
        let settings = HAConnectionSettings(
            baseURL: credential.baseURLString,
            defaults: defaults,
            tokenStore: tokenStore
        )
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            connectionStatus: .connected,
            dataFreshness: .live(.now),
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore),
            automaticallyRegistersMobileApp: false
        )

        let presentation = HomeAssistantSupportPresentation(
            connectionSettings: settings,
            homeAssistantService: service
        )

        #expect(presentation.visibleRowLabels == [
            "Connection",
            "Authentication",
            "Network",
            "Signed-In Server",
            "Mobile App",
            "State",
            "Last Successful Update",
            "Saved State"
        ])
        #expect(!presentation.visibleRowLabels.contains("Account"))
        #expect(!presentation.visibleRowLabels.contains("Installation"))
        #expect(!presentation.visibleRowLabels.contains("Core"))
        #expect(!presentation.visibleRowLabels.contains("Supervisor"))
        #expect(!presentation.visibleRowLabels.contains("OS"))
    }

    @Test @MainActor func diagnosticReportIncludesEnvironmentWithoutSensitiveAccountOrPathData() {
        let report = HomeAssistantDiagnosticsReport(
            configuredServer: "ha.example.com",
            signedInServer: "ha.example.com",
            authentication: "Signed In",
            connection: "Connected",
            state: "Live",
            lastUpdate: "Today",
            network: "Available",
            mobileApp: "Registered",
            cache: "42 entities",
            installation: "Home Assistant OS",
            coreVersion: "2026.7.3",
            supervisorVersion: "2026.07.3",
            operatingSystemVersion: "18.1",
            authenticationFailure: "None"
        ).text

        #expect(report.contains("Installation: Home Assistant OS"))
        #expect(report.contains("Core: 2026.7.3"))
        #expect(report.contains("Supervisor: 2026.07.3"))
        #expect(report.contains("OS: 18.1"))
        #expect(!report.contains("Account:"))
        #expect(!report.localizedCaseInsensitiveContains("token"))
        #expect(!report.contains("/Library/"))
    }

    @Test func permissionPresentationMapsEveryMeaningfulState() {
        #expect(NativePermissionRowPresentation.make(status: .notDetermined).accessory ==
            .action(title: "Allow", action: .allow))
        #expect(NativePermissionRowPresentation.make(status: .notDetermined, isRequesting: true).accessory ==
            .progress(title: "Requesting"))
        #expect(NativePermissionRowPresentation.make(status: .allowed).accessory ==
            .status(title: "Allowed", tone: .positive))
        #expect(NativePermissionRowPresentation.make(status: .limited).accessory ==
            .status(title: "Limited", tone: .caution))
        #expect(NativePermissionRowPresentation.make(status: .denied).accessory ==
            .action(title: "Settings", action: .openSettings))
        #expect(NativePermissionRowPresentation.make(status: .restricted).accessory ==
            .status(title: "Restricted", tone: .negative))
        #expect(NativePermissionRowPresentation.make(status: .unavailable).accessory ==
            .status(title: "Unavailable", tone: .neutral))
        #expect(NativePermissionRowPresentation.make(status: .unknown).accessory ==
            .progress(title: "Checking"))
        #expect(NativePermissionRowPresentation.make(status: .managedBySystem).accessory ==
            .status(title: "System Managed", tone: .neutral))
    }

    @Test func localNetworkDoesNotPretendToOfferAnInAppRequest() {
        #expect(NativePermissionRowPresentation.make(
            status: .notDetermined,
            supportsInAppRequest: false
        ).accessory == .status(title: "Not Determined", tone: .neutral))
    }

    @Test func permissionRefreshPolicyRefreshesOnlyWhenActive() {
        #expect(NativePermissionRefreshPolicy.shouldRefresh(when: .active))
        #expect(!NativePermissionRefreshPolicy.shouldRefresh(when: .inactive))
        #expect(!NativePermissionRefreshPolicy.shouldRefresh(when: .background))
    }

    @Test func homesteadDistributionDestinationsRemainCentralized() {
        #expect(HomesteadDistributionPresentation.publicInstallURL.absoluteString ==
            "https://testflight.apple.com/join/WU5kETTE")
        #expect(HomesteadDistributionPresentation.ratePlaceholder == HomesteadRatePresentation(
            title: "Coming Soon",
            message: "Rating will be available when Homestead launches on the App Store."
        ))
    }
}
