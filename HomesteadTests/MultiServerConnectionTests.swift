import Foundation
import Testing
@testable import Homestead

@MainActor
struct MultiServerConnectionTests {
    @Test func legacyConnectionMigratesIntoActiveProfile() throws {
        let defaults = try makeDefaults()
        defaults.set("https://primary.example.com", forKey: "homeAssistantBaseURL")
        defaults.set("http://homeassistant.local:8123", forKey: "homeAssistantInternalURL")
        defaults.set(["Home WiFi"], forKey: "homeAssistantInternalNetworkSSIDs")

        let settings = HAConnectionSettings(defaults: defaults, tokenStore: EmptyTokenStore())

        #expect(settings.profiles.count == 1)
        #expect(settings.activeProfile.baseURL == "https://primary.example.com")
        #expect(settings.activeProfile.internalURL == "http://homeassistant.local:8123")
        #expect(settings.activeProfile.internalNetworkSSIDs == ["Home WiFi"])
    }

    @Test func activatingProfileUpdatesTheSingleActiveFacade() throws {
        let defaults = try makeDefaults()
        let settings = HAConnectionSettings(
            baseURL: "https://primary.example.com",
            defaults: defaults,
            tokenStore: EmptyTokenStore()
        )
        let secondID = settings.profileStore.addProfile(
            displayName: "Test Home",
            baseURL: "https://test.example.com",
            internalURL: "http://test.local:8123",
            externalURL: "https://test.example.com",
            internalNetworkSSIDs: ["Test WiFi"]
        )

        #expect(settings.activateProfile(id: secondID))
        #expect(settings.activeProfileID == secondID)
        #expect(settings.baseURL == "https://test.example.com")
        #expect(settings.internalURL == "http://test.local:8123")
        #expect(settings.internalNetworkSSIDs == ["Test WiFi"])
    }

    @Test func dashboardDocumentsRemainIsolatedByProfile() throws {
        let defaults = try makeDefaults()
        let primaryID = UUID()
        let secondaryID = UUID()
        let dashboards = DashboardConfiguration(defaults: defaults, profileID: primaryID)
        let primaryDashboardID = dashboards.createDashboard(named: "Primary")

        dashboards.activateProfile(secondaryID)
        #expect(!dashboards.dashboards.contains { $0.id == primaryDashboardID })
        let secondaryDashboardID = dashboards.createDashboard(named: "Secondary")

        dashboards.activateProfile(primaryID)
        #expect(dashboards.dashboards.contains { $0.id == primaryDashboardID })
        #expect(!dashboards.dashboards.contains { $0.id == secondaryDashboardID })
    }

    @Test func entityReferencesDisambiguateCollidingEntityIDs() {
        let first = HomesteadEntityReference(profileID: UUID(), entityID: "light.kitchen")
        let second = HomesteadEntityReference(profileID: UUID(), entityID: "light.kitchen")

        #expect(first.encodedID != second.encodedID)
        #expect(HomesteadEntityReference(encodedID: first.encodedID) == first)
        #expect(HomesteadEntityReference(encodedID: second.encodedID) == second)
    }

    @Test func profileSyncSnapshotContainsMetadataWithoutCredentials() throws {
        let profile = HAConnectionProfile(
            displayName: "Home",
            baseURL: "https://home.example.com"
        )
        let data = try JSONEncoder().encode(HAConnectionProfilesSyncSnapshot(profiles: [profile]))
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("home.example.com"))
        #expect(!json.localizedCaseInsensitiveContains("token"))
        #expect(!json.localizedCaseInsensitiveContains("credential"))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "MultiServerConnectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct EmptyTokenStore: HAOAuthTokenStore {
    func readCredential() throws -> HAOAuthCredential? { nil }
    func saveCredential(_ credential: HAOAuthCredential) throws {}
    func deleteCredential() throws {}
}
