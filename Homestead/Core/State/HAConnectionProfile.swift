import Foundation
import Observation

nonisolated struct HAConnectionProfile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var displayName: String
    var discoveredName: String?
    var baseURL: String
    var internalURL: String
    var externalURL: String
    var internalNetworkSSIDs: [String]
    let createdAt: Date
    var lastUsedAt: Date

    var hasServerURL: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var resolvedDisplayName: String {
        let preferredNames = [displayName, discoveredName ?? ""]
        if let name = preferredNames.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let host = URL(string: baseURL)?.host(percentEncoded: false), !host.isEmpty else {
            return "Home Assistant"
        }
        return host
    }

    init(
        id: UUID = UUID(),
        displayName: String = "",
        discoveredName: String? = nil,
        baseURL: String = "",
        internalURL: String = "",
        externalURL: String = "",
        internalNetworkSSIDs: [String] = [],
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.discoveredName = discoveredName
        self.baseURL = baseURL
        self.internalURL = internalURL
        self.externalURL = externalURL
        self.internalNetworkSSIDs = HAConnectionSettings.normalizedSSIDs(internalNetworkSSIDs)
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

nonisolated struct HAConnectionProfilesSyncSnapshot: Codable, Equatable, Sendable {
    var profiles: [HAConnectionProfile]
}

@MainActor
@Observable
final class HAConnectionProfileStore {
    private(set) var profiles: [HAConnectionProfile] {
        didSet { save() }
    }

    private(set) var activeProfileID: UUID {
        didSet {
            defaults.set(activeProfileID.uuidString, forKey: Keys.activeProfileID)
            WidgetSharedStore.saveActiveProfileID(activeProfileID)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    var activeProfile: HAConnectionProfile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    var configuredProfiles: [HAConnectionProfile] {
        profiles.filter(\.hasServerURL)
    }

    var syncSnapshot: HAConnectionProfilesSyncSnapshot {
        HAConnectionProfilesSyncSnapshot(profiles: configuredProfiles)
    }

    init(
        defaults: UserDefaults = .standard,
        legacyBaseURL: String? = nil,
        now: Date = Date()
    ) {
        self.defaults = defaults

        let decodedProfiles: [HAConnectionProfile]? = defaults.data(forKey: Keys.profiles).flatMap {
            try? JSONDecoder().decode([HAConnectionProfile].self, from: $0)
        }

        let resolvedProfiles: [HAConnectionProfile]
        if let decodedProfiles, !decodedProfiles.isEmpty {
            resolvedProfiles = decodedProfiles
        } else {
            let baseURL = legacyBaseURL ?? defaults.string(forKey: LegacyKeys.baseURL) ?? ""
            let storedName = defaults.string(forKey: LegacyKeys.homeNetworkName) ?? ""
            let storedSSIDs = defaults.stringArray(forKey: LegacyKeys.internalNetworkSSIDs) ?? []
            resolvedProfiles = [
                HAConnectionProfile(
                    baseURL: baseURL,
                    internalURL: defaults.string(forKey: LegacyKeys.internalURL) ?? "",
                    externalURL: defaults.string(forKey: LegacyKeys.externalURL) ?? "",
                    internalNetworkSSIDs: storedSSIDs.isEmpty && !storedName.isEmpty ? [storedName] : storedSSIDs,
                    createdAt: now,
                    lastUsedAt: now
                )
            ]
        }
        profiles = resolvedProfiles

        let storedActiveID = defaults.string(forKey: Keys.activeProfileID).flatMap(UUID.init(uuidString:))
        activeProfileID = storedActiveID.flatMap { id in resolvedProfiles.contains(where: { $0.id == id }) ? id : nil }
            ?? resolvedProfiles[0].id

        save()
        defaults.set(activeProfileID.uuidString, forKey: Keys.activeProfileID)
        publishWidgetProfiles()
    }

    @discardableResult
    func addProfile(
        id: UUID = UUID(),
        displayName: String = "",
        baseURL: String,
        internalURL: String = "",
        externalURL: String = "",
        internalNetworkSSIDs: [String] = []
    ) -> UUID {
        let profile = HAConnectionProfile(
            id: id,
            displayName: displayName,
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            internalURL: internalURL.trimmingCharacters(in: .whitespacesAndNewlines),
            externalURL: externalURL.trimmingCharacters(in: .whitespacesAndNewlines),
            internalNetworkSSIDs: internalNetworkSSIDs
        )
        profiles.append(profile)
        publishWidgetProfiles()
        return profile.id
    }

    @discardableResult
    func setActiveProfile(id: UUID, now: Date = Date()) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return false }
        activeProfileID = id
        profiles[index].lastUsedAt = now
        publishWidgetProfiles()
        return true
    }

    func updateActiveProfile(_ update: (inout HAConnectionProfile) -> Void) {
        updateProfile(id: activeProfileID, update)
    }

    func updateProfile(id: UUID, _ update: (inout HAConnectionProfile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        var updated = profiles
        update(&updated[index])
        updated[index].internalNetworkSSIDs = HAConnectionSettings.normalizedSSIDs(updated[index].internalNetworkSSIDs)
        profiles = updated
        publishWidgetProfiles()
    }

    func renameProfile(id: UUID, name: String) {
        updateProfile(id: id) {
            $0.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    @discardableResult
    func removeProfile(id: UUID) -> UUID? {
        guard profiles.contains(where: { $0.id == id }) else { return activeProfileID }
        profiles.removeAll { $0.id == id }

        if profiles.isEmpty {
            let emptyProfile = HAConnectionProfile()
            profiles = [emptyProfile]
            activeProfileID = emptyProfile.id
        } else if activeProfileID == id {
            let fallback = profiles.max { $0.lastUsedAt < $1.lastUsedAt } ?? profiles[0]
            activeProfileID = fallback.id
        }

        publishWidgetProfiles()
        return activeProfileID
    }

    func profile(id: UUID) -> HAConnectionProfile? {
        profiles.first { $0.id == id }
    }

    func profile(matchingBaseURL baseURL: String) -> HAConnectionProfile? {
        let candidate = HAConnectionConfiguration(baseURLString: baseURL, accessToken: "").dataSourceID
        return profiles.first {
            HAConnectionConfiguration(baseURLString: $0.baseURL, accessToken: "").dataSourceID == candidate
        }
    }

    func mergeSyncSnapshot(_ snapshot: HAConnectionProfilesSyncSnapshot) {
        var merged = profiles
        for remoteProfile in snapshot.profiles where remoteProfile.hasServerURL {
            if let index = merged.firstIndex(where: { $0.id == remoteProfile.id }) {
                merged[index].displayName = remoteProfile.displayName
                merged[index].discoveredName = remoteProfile.discoveredName
                merged[index].baseURL = remoteProfile.baseURL
                merged[index].internalURL = remoteProfile.internalURL
                merged[index].externalURL = remoteProfile.externalURL
                merged[index].internalNetworkSSIDs = remoteProfile.internalNetworkSSIDs
            } else {
                merged.append(remoteProfile)
            }
        }
        profiles = merged
        publishWidgetProfiles()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Keys.profiles)
    }

    private func publishWidgetProfiles() {
        WidgetSharedStore.saveServerProfiles(profiles, activeProfileID: activeProfileID)
    }

    private enum Keys {
        static let profiles = "homestead.connectionProfiles.v1"
        static let activeProfileID = "homestead.connectionProfiles.activeProfileID.v1"
    }

    private enum LegacyKeys {
        static let baseURL = "homeAssistantBaseURL"
        static let internalURL = "homeAssistantInternalURL"
        static let externalURL = "homeAssistantExternalURL"
        static let homeNetworkName = "homeAssistantHomeNetworkName"
        static let internalNetworkSSIDs = "homeAssistantInternalNetworkSSIDs"
    }
}
