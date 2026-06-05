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
            defaults.string(forKey: Keys.baseURL) ??
            storedCredentialBaseURL ??
            UserDefaults(suiteName: WidgetSharedStore.appGroupID)?.string(forKey: Keys.baseURL) ??
            ""
        internalURL = defaults.string(forKey: Keys.internalURL) ?? ""
        externalURL = defaults.string(forKey: Keys.externalURL) ?? ""
        homeNetworkName = defaults.string(forKey: Keys.homeNetworkName) ?? ""

        WidgetSharedStore.saveBaseURL(self.baseURL)
    }

    private enum Keys {
        static let baseURL = "homeAssistantBaseURL"
        static let internalURL = "homeAssistantInternalURL"
        static let externalURL = "homeAssistantExternalURL"
        static let homeNetworkName = "homeAssistantHomeNetworkName"
    }
}
