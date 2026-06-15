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
            homeNetworkName: homeNetworkName
        )
    }

    var syncSnapshot: HAConnectionSettingsSyncSnapshot {
        HAConnectionSettingsSyncSnapshot(
            baseURL: baseURL,
            internalURL: internalURL,
            externalURL: externalURL
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
        homeNetworkName = defaults.string(forKey: Keys.homeNetworkName) ?? ""

        WidgetSharedStore.saveBaseURL(self.baseURL)
    }

    func applySyncSnapshot(_ snapshot: HAConnectionSettingsSyncSnapshot) {
        baseURL = snapshot.baseURL
        internalURL = snapshot.internalURL
        externalURL = snapshot.externalURL
    }

    func applySyncSnapshot(_ snapshot: HomesteadConnectionSyncSnapshot) {
        baseURL = Self.preferredIdentityBaseURL(
            baseURL: snapshot.baseURL,
            internalURL: snapshot.internalURL,
            externalURL: snapshot.externalURL
        )
        internalURL = snapshot.internalURL
        externalURL = snapshot.externalURL
    }

    func applyRoutingSyncSnapshot(_ snapshot: HomesteadConnectionSyncSnapshot) {
        if internalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            internalURL = snapshot.internalURL
        }
        if externalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            externalURL = snapshot.externalURL
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
}

struct HAConnectionSettingsSyncSnapshot: Codable, Equatable, Sendable {
    var baseURL: String
    var internalURL: String
    var externalURL: String
}
