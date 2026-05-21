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

    var accessToken: String {
        didSet { persistAccessToken() }
    }

    private(set) var credentialStorageErrorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let credentialStore: HACredentialStore

    var hasCredentials: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        baseURL: String? = nil,
        accessToken: String? = nil,
        defaults: UserDefaults = .standard,
        credentialStore: HACredentialStore? = nil
    ) {
        self.defaults = defaults
        self.credentialStore = credentialStore ?? MigratingHACredentialStore()
        self.baseURL = baseURL ??
            defaults.string(forKey: Keys.baseURL) ??
            UserDefaults(suiteName: WidgetSharedStore.appGroupID)?.string(forKey: Keys.baseURL) ??
            ""

        do {
            let storedToken = try self.credentialStore.readAccessToken()
            self.accessToken = accessToken ?? storedToken ?? ""
            credentialStorageErrorMessage = nil
        } catch {
            self.accessToken = accessToken ?? ""
            credentialStorageErrorMessage = error.localizedDescription
        }

        WidgetSharedStore.saveBaseURL(self.baseURL)
    }

    private func persistAccessToken() {
        do {
            if accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try credentialStore.deleteAccessToken()
            } else {
                try credentialStore.saveAccessToken(accessToken)
            }

            credentialStorageErrorMessage = nil
        } catch {
            credentialStorageErrorMessage = error.localizedDescription
        }
    }

    private enum Keys {
        static let baseURL = "homeAssistantBaseURL"
    }
}
