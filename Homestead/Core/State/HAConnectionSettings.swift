import Foundation
import Observation

@MainActor
@Observable
final class HAConnectionSettings {
    var baseURL: String {
        didSet {
            defaults.set(baseURL, forKey: Keys.baseURL)
            WidgetSharedStore.saveBaseURL(baseURL)
        }
    }

    var internalURL: String {
        didSet {
            defaults.set(internalURL, forKey: Keys.internalURL)
        }
    }

    var externalURL: String {
        didSet {
            defaults.set(externalURL, forKey: Keys.externalURL)
        }
    }

    var homeNetworkName: String {
        didSet {
            defaults.set(homeNetworkName, forKey: Keys.homeNetworkName)
        }
    }

    var internalNetworkSSIDs: [String] {
        didSet {
            defaults.set(Self.normalizedSSIDs(internalNetworkSSIDs), forKey: Keys.internalNetworkSSIDs)
        }
    }

    private(set) var authStorageErrorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let tokenStore: any HAOAuthTokenStore

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
        tokenStore: (any HAOAuthTokenStore)? = nil
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

        self.baseURL = baseURL ??
            storedCredentialBaseURL ??
            defaults.string(forKey: Keys.baseURL) ??
            UserDefaults(suiteName: WidgetSharedStore.appGroupID)?.string(forKey: Keys.baseURL) ??
            ""
        internalURL = defaults.string(forKey: Keys.internalURL) ?? ""
        externalURL = defaults.string(forKey: Keys.externalURL) ?? ""
        let storedHomeNetworkName = defaults.string(forKey: Keys.homeNetworkName) ?? ""
        let storedSSIDs = defaults.stringArray(forKey: Keys.internalNetworkSSIDs) ?? []
        homeNetworkName = storedHomeNetworkName
        internalNetworkSSIDs = Self.normalizedSSIDs(
            storedSSIDs.isEmpty && !storedHomeNetworkName.isEmpty ? [storedHomeNetworkName] : storedSSIDs
        )

        WidgetSharedStore.saveBaseURL(self.baseURL)
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
