import Foundation
import Observation

@MainActor
@Observable
final class HAConnectionSettings {
    var baseURL: String {
        didSet {
            defaults.set(baseURL, forKey: Keys.baseURL)
            profileStore.updateActiveProfile { $0.baseURL = baseURL }
        }
    }

    var internalURL: String {
        didSet {
            defaults.set(internalURL, forKey: Keys.internalURL)
            profileStore.updateActiveProfile { $0.internalURL = internalURL }
        }
    }

    var externalURL: String {
        didSet {
            defaults.set(externalURL, forKey: Keys.externalURL)
            profileStore.updateActiveProfile { $0.externalURL = externalURL }
        }
    }

    var homeNetworkName: String {
        didSet {
            defaults.set(homeNetworkName, forKey: Keys.homeNetworkName)
        }
    }

    var internalNetworkSSIDs: [String] {
        didSet {
            let normalized = Self.normalizedSSIDs(internalNetworkSSIDs)
            defaults.set(normalized, forKey: Keys.internalNetworkSSIDs)
            profileStore.updateActiveProfile { $0.internalNetworkSSIDs = normalized }
        }
    }

    private(set) var authStorageErrorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let tokenStore: any HAOAuthTokenStore
    let profileStore: HAConnectionProfileStore

    var activeProfileID: UUID { profileStore.activeProfileID }
    var activeProfile: HAConnectionProfile { profileStore.activeProfile }
    var profiles: [HAConnectionProfile] { profileStore.configuredProfiles }

    var hasServerURL: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var routingSnapshot: HAConnectionRoutingSettingsSnapshot {
        HAConnectionRoutingSettingsSnapshot(
            baseURLString: baseURL,
            internalURLString: internalURL,
            externalURLString: externalURL,
            homeNetworkName: homeNetworkName,
            internalNetworkSSIDs: internalNetworkSSIDs
        )
    }

    var syncSnapshot: HAConnectionSettingsSyncSnapshot {
        HAConnectionSettingsSyncSnapshot(
            baseURL: baseURL,
            internalURL: internalURL,
            externalURL: externalURL,
            internalNetworkSSIDs: internalNetworkSSIDs
        )
    }

    var hasAutomaticRouteCandidates: Bool {
        routingSnapshot.hasAutomaticRouteCandidates
    }

    init(
        baseURL: String? = nil,
        defaults: UserDefaults = .standard,
        tokenStore: (any HAOAuthTokenStore)? = nil,
        profileStore: HAConnectionProfileStore? = nil
    ) {
        self.defaults = defaults
        self.tokenStore = tokenStore ?? KeychainHAOAuthTokenStore()

        let storedCredentialBaseURL: String?
        do {
            storedCredentialBaseURL = try self.tokenStore.readCredential()?.baseURLString
            authStorageErrorMessage = nil
        } catch {
            storedCredentialBaseURL = nil
            authStorageErrorMessage = error.localizedDescription
        }

        let legacyBaseURL = baseURL ??
            storedCredentialBaseURL ??
            defaults.string(forKey: Keys.baseURL) ??
            UserDefaults(suiteName: WidgetSharedStore.appGroupID)?.string(forKey: Keys.baseURL) ??
            ""
        let resolvedProfileStore = profileStore ?? HAConnectionProfileStore(
            defaults: defaults,
            legacyBaseURL: legacyBaseURL
        )
        self.profileStore = resolvedProfileStore
        let activeProfile = resolvedProfileStore.activeProfile

        self.baseURL = baseURL ?? activeProfile.baseURL
        internalURL = activeProfile.internalURL
        externalURL = activeProfile.externalURL
        homeNetworkName = activeProfile.internalNetworkSSIDs.first ?? defaults.string(forKey: Keys.homeNetworkName) ?? ""
        internalNetworkSSIDs = Self.normalizedSSIDs(activeProfile.internalNetworkSSIDs)

        if let baseURL {
            resolvedProfileStore.updateActiveProfile { $0.baseURL = baseURL }
        }

    }

    @discardableResult
    func activateProfile(id: UUID) -> Bool {
        guard profileStore.setActiveProfile(id: id), let profile = profileStore.profile(id: id) else {
            return false
        }

        baseURL = profile.baseURL
        internalURL = profile.internalURL
        externalURL = profile.externalURL
        internalNetworkSSIDs = Self.normalizedSSIDs(profile.internalNetworkSSIDs)
        homeNetworkName = internalNetworkSSIDs.first ?? ""
        return true
    }

    @discardableResult
    func addProfile(baseURL: String) -> UUID {
        profileStore.addProfile(baseURL: baseURL)
    }

    func updateServerName(_ name: String?) {
        profileStore.updateServerName(id: activeProfileID, name: name)
    }

    func applySyncSnapshot(_ snapshot: HAConnectionSettingsSyncSnapshot) {
        baseURL = snapshot.baseURL
        internalURL = snapshot.internalURL
        externalURL = snapshot.externalURL
        internalNetworkSSIDs = Self.normalizedSSIDs(snapshot.internalNetworkSSIDs)
    }

    func applySyncSnapshot(_ snapshot: HomesteadConnectionSyncSnapshot) {
        baseURL = Self.preferredIdentityBaseURL(
            baseURL: snapshot.baseURL,
            internalURL: snapshot.internalURL,
            externalURL: snapshot.externalURL
        )
        internalURL = snapshot.internalURL
        externalURL = snapshot.externalURL
        internalNetworkSSIDs = Self.normalizedSSIDs(snapshot.internalNetworkSSIDs ?? [])
    }

    func applyRoutingSyncSnapshot(_ snapshot: HomesteadConnectionSyncSnapshot) {
        if internalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            internalURL = snapshot.internalURL
        }
        if externalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            externalURL = snapshot.externalURL
        }
        if internalNetworkSSIDs.isEmpty {
            internalNetworkSSIDs = Self.normalizedSSIDs(snapshot.internalNetworkSSIDs ?? [])
        }
    }

    func adoptServerRoutes(from configuration: HAServerConfigurationSnapshot) {
        if internalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let internalURL = configuration.internalURL {
            self.internalURL = internalURL
        }
        if externalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let externalURL = configuration.externalURL {
            self.externalURL = externalURL
        }
    }

    func saveInternalURLSettings(internalURL newInternalURL: String, internalNetworkSSIDs newInternalNetworkSSIDs: [String]) {
        let oldInternalURL = internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInternalURL = newInternalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExternalURL = externalURL.trimmingCharacters(in: .whitespacesAndNewlines)

        internalURL = trimmedInternalURL
        internalNetworkSSIDs = Self.normalizedSSIDs(newInternalNetworkSSIDs)

        if trimmedInternalURL != oldInternalURL, trimmedExternalURL.isEmpty {
            baseURL = trimmedInternalURL
        }
    }

    func saveExternalURL(_ newExternalURL: String) {
        let oldDisplayedExternalURL = displayedExternalURL
        let trimmedExternalURL = newExternalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInternalURL = internalURL.trimmingCharacters(in: .whitespacesAndNewlines)

        externalURL = trimmedExternalURL

        if trimmedExternalURL != oldDisplayedExternalURL {
            baseURL = trimmedExternalURL.isEmpty ? trimmedInternalURL : trimmedExternalURL
        }
    }

    var displayedExternalURL: String {
        let trimmedExternalURL = externalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExternalURL.isEmpty { return trimmedExternalURL }

        let trimmedInternalURL = internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedInternalURL.isEmpty ? baseURL : ""
    }

    private enum Keys {
        static let baseURL = "homeAssistantBaseURL"
        static let internalURL = "homeAssistantInternalURL"
        static let externalURL = "homeAssistantExternalURL"
        static let homeNetworkName = "homeAssistantHomeNetworkName"
        static let internalNetworkSSIDs = "homeAssistantInternalNetworkSSIDs"
    }

    nonisolated private static func preferredIdentityBaseURL(
        baseURL: String,
        internalURL: String,
        externalURL: String
    ) -> String {
        let externalURL = externalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !externalURL.isEmpty { return externalURL }

        let baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !baseURL.isEmpty { return baseURL }

        return internalURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func normalizedSSIDs(_ ssids: [String]) -> [String] {
        var seen = Set<String>()
        return ssids.compactMap { ssid in
            let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }
}

struct HAConnectionSettingsSyncSnapshot: Codable, Equatable, Sendable {
    var baseURL: String
    var internalURL: String
    var externalURL: String
    var internalNetworkSSIDs: [String]
}
