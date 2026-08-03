import AppIntents
import Foundation
import Security

// MARK: - Widget App-Group Store

struct WidgetScopedSnapshot<Value> {
    let reference: EntityPresentationReference
    let serverName: String
    let isServerAvailable: Bool
    let hasMultipleServers: Bool
    let value: Value
}

enum HomesteadWidgetSharedStore {
    static let appGroupID = WidgetStorageContract.appGroupID
    static let keychainAccessGroup = WidgetStorageContract.keychainAccessGroup

    private static let optimisticLightStatesKey = "widgetOptimisticLightStates"
    private static let optimisticSwitchStatesKey = "widgetOptimisticSwitchStates"
    private static let optimisticFanStatesKey = "widgetOptimisticFanStates"
    private static let tokenService = "com.tyler.Homestead.homeAssistant"
    private static let oauthCredentialAccount = "oauthCredential"
    private static let oauthClientID = "https://connect.homesteadcontrol.com"
    private static let tokenRefreshLeeway: TimeInterval = 60

    static var serverProfiles: [WidgetServerProfile] {
        guard let data = sharedDefaults?.data(forKey: WidgetStorageContract.Key.serverProfiles) else { return [] }
        return (try? JSONDecoder().decode([WidgetServerProfile].self, from: data)) ?? []
    }

    static var serverSnapshots: [WidgetServerSnapshot] {
        WidgetServerSnapshotStore.snapshots
    }

    static var scopedLightSnapshots: [WidgetScopedSnapshot<WidgetLightSnapshot>] {
        scoped(\.lights, entityID: \.entityID)
    }

    static var scopedSwitchSnapshots: [WidgetScopedSnapshot<WidgetSwitchSnapshot>] {
        scoped(\.switches, entityID: \.entityID)
    }

    static var scopedCoverSnapshots: [WidgetScopedSnapshot<WidgetCoverSnapshot>] {
        scoped(\.covers, entityID: \.entityID)
    }

    static var scopedFanSnapshots: [WidgetScopedSnapshot<WidgetFanSnapshot>] {
        scoped(\.fans, entityID: \.entityID)
    }

    static var scopedLockSnapshots: [WidgetScopedSnapshot<WidgetLockSnapshot>] {
        scoped(\.locks, entityID: \.entityID)
    }

    static var scopedSensorSnapshots: [WidgetScopedSnapshot<WidgetSensorSnapshot>] {
        scoped(\.sensors, entityID: \.entityID)
    }

    static var scopedPresenceSnapshots: [WidgetScopedSnapshot<WidgetPresenceSnapshot>] {
        scoped(\.presence, entityID: \.entityID)
    }

    static var scopedActionSnapshots: [WidgetScopedSnapshot<WidgetActionSnapshot>] {
        scoped(\.actions, entityID: \.entityID)
    }

    static func reference(for identifier: String) -> EntityPresentationReference? {
        EntityPresentationReference(encodedID: identifier)
    }

    static func baseURL(profileID: UUID) -> String? {
        return serverProfiles.first(where: { $0.id == profileID })?.baseURLString
    }

    static func serverName(profileID: UUID) -> String {
        serverProfiles.first(where: { $0.id == profileID })?.displayName
            ?? serverSnapshots.first(where: { $0.profileID == profileID })?.serverName
            ?? "Server Removed"
    }

    static func isServerAvailable(profileID: UUID) -> Bool {
        serverProfiles.contains { $0.id == profileID }
    }

    private static func scoped<Value>(
        _ values: KeyPath<WidgetServerSnapshot, [Value]>,
        entityID: KeyPath<Value, String>
    ) -> [WidgetScopedSnapshot<Value>] {
        let snapshots = serverSnapshots
        let profilesByID = Dictionary(
            serverProfiles.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let hasMultipleServers = snapshots.count > 1

        return snapshots.flatMap { server in
            let profile = profilesByID[server.profileID]
            return server[keyPath: values].map { value in
                WidgetScopedSnapshot(
                    reference: EntityPresentationReference(
                        profileID: server.profileID,
                        entityID: value[keyPath: entityID]
                    ),
                    serverName: profile?.displayName ?? server.serverName,
                    isServerAvailable: profile != nil,
                    hasMultipleServers: hasMultipleServers,
                    value: value
                )
            }
        }
    }

    static func validAccessToken(profileID: UUID) async throws -> String {
        guard let credential = try readOAuthCredential(profileID: profileID) else {
            throw HAWidgetActionError.missingCredentials
        }

        guard credential.accessTokenExpiresSoon(leeway: tokenRefreshLeeway) else {
            return credential.accessToken
        }

        let response = try await refreshAccessToken(for: credential)
        let refreshedCredential = credential.replacingAccessToken(
            response.accessToken,
            expiresIn: response.expiresIn,
            tokenType: response.tokenType
        )
        try saveOAuthCredential(refreshedCredential, profileID: profileID)
        return refreshedCredential.accessToken
    }

    private static func readOAuthCredential(profileID: UUID) throws -> WidgetOAuthCredential? {
        var query = baseOAuthCredentialQuery(profileID: profileID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw HAWidgetActionError.missingCredentials
        }

        return try WidgetOAuthCredential.decoder.decode(WidgetOAuthCredential.self, from: data)
    }

    private static func saveOAuthCredential(
        _ credential: WidgetOAuthCredential,
        profileID: UUID
    ) throws {
        let data = try WidgetOAuthCredential.encoder.encode(credential)
        var query = baseOAuthCredentialQuery(profileID: profileID)
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw HAWidgetActionError.authenticationFailed
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw HAWidgetActionError.authenticationFailed
        }
    }

    private static func refreshAccessToken(
        for credential: WidgetOAuthCredential
    ) async throws -> WidgetOAuthTokenResponse {
        let url = try authTokenURL(from: credential.baseURLString)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedBody([
            ("grant_type", "refresh_token"),
            ("refresh_token", credential.refreshToken),
            ("client_id", credential.clientID.isEmpty ? oauthClientID : credential.clientID)
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              !data.isEmpty else {
            throw HAWidgetActionError.authenticationFailed
        }

        return try JSONDecoder().decode(WidgetOAuthTokenResponse.self, from: data)
    }

    static func sensorSnapshot(entityID: String) -> WidgetSensorSnapshot? {
        guard let reference = reference(for: entityID) else { return nil }
        return serverSnapshots
            .first(where: { $0.profileID == reference.profileID })?
            .sensors.first { $0.entityID == reference.entityID }
    }

    static func optimisticLightState(entityID: String) -> Bool? {
        guard let optimisticState = optimisticLightStates[entityID],
              Date().timeIntervalSince(optimisticState.updatedAt) < 10 else {
            return nil
        }

        return optimisticState.isOn
    }

    static func optimisticSwitchState(entityID: String) -> Bool? {
        guard let optimisticState = optimisticSwitchStates[entityID],
              Date().timeIntervalSince(optimisticState.updatedAt) < 10 else {
            return nil
        }

        return optimisticState.isOn
    }

    static func optimisticFanState(entityID: String) -> Bool? {
        guard let optimisticState = optimisticFanStates[entityID],
              Date().timeIntervalSince(optimisticState.updatedAt) < 10 else {
            return nil
        }

        return optimisticState.isOn
    }

    static func updateLightSnapshot(entityID: String, isOn: Bool) {
        var optimisticStates = optimisticLightStates
        optimisticStates[entityID] = OptimisticLightState(isOn: isOn, updatedAt: Date())
        saveOptimisticLightStates(optimisticStates)
    }

    static func updateSwitchSnapshot(entityID: String, isOn: Bool) {
        var optimisticStates = optimisticSwitchStates
        optimisticStates[entityID] = OptimisticSwitchState(isOn: isOn, updatedAt: Date())
        saveOptimisticSwitchStates(optimisticStates)
    }

    static func updateFanSnapshot(entityID: String, isOn: Bool) {
        var optimisticStates = optimisticFanStates
        optimisticStates[entityID] = OptimisticFanState(isOn: isOn, updatedAt: Date())
        saveOptimisticFanStates(optimisticStates)
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static var optimisticLightStates: [String: OptimisticLightState] {
        guard let data = sharedDefaults?.data(forKey: optimisticLightStatesKey),
              let states = try? JSONDecoder().decode([String: OptimisticLightState].self, from: data) else {
            return [:]
        }

        return states
    }

    private static var optimisticSwitchStates: [String: OptimisticSwitchState] {
        guard let data = sharedDefaults?.data(forKey: optimisticSwitchStatesKey),
              let states = try? JSONDecoder().decode([String: OptimisticSwitchState].self, from: data) else {
            return [:]
        }

        return states
    }

    private static var optimisticFanStates: [String: OptimisticFanState] {
        guard let data = sharedDefaults?.data(forKey: optimisticFanStatesKey),
              let states = try? JSONDecoder().decode([String: OptimisticFanState].self, from: data) else {
            return [:]
        }

        return states
    }

    private static func saveOptimisticLightStates(_ states: [String: OptimisticLightState]) {
        guard let data = try? JSONEncoder().encode(states) else {
            return
        }

        sharedDefaults?.set(data, forKey: optimisticLightStatesKey)
    }

    private static func saveOptimisticSwitchStates(_ states: [String: OptimisticSwitchState]) {
        guard let data = try? JSONEncoder().encode(states) else {
            return
        }

        sharedDefaults?.set(data, forKey: optimisticSwitchStatesKey)
    }

    private static func saveOptimisticFanStates(_ states: [String: OptimisticFanState]) {
        guard let data = try? JSONEncoder().encode(states) else {
            return
        }

        sharedDefaults?.set(data, forKey: optimisticFanStatesKey)
    }

    private static func baseOAuthCredentialQuery(profileID: UUID) -> [String: Any] {
        let account = "\(oauthCredentialAccount).\(profileID.uuidString.lowercased())"
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: keychainAccessGroup
        ]
    }

    private static func authTokenURL(from baseURLString: String) throws -> URL {
        let normalizedString = baseURLString.contains("://") ? baseURLString : "http://\(baseURLString)"

        guard var components = URLComponents(string: normalizedString),
              let scheme = components.scheme,
              components.host != nil else {
            throw HAWidgetActionError.invalidURL
        }

        switch scheme.lowercased() {
        case "http", "ws":
            components.scheme = "http"
        case "https", "wss":
            components.scheme = "https"
        default:
            throw HAWidgetActionError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "auth", "token"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw HAWidgetActionError.invalidURL
        }

        return url
    }

    private static func formEncodedBody(_ items: [(String, String)]) -> Data {
        let body = items
            .map { key, value in
                "\(formEncode(key))=\(formEncode(value))"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private static func formEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._*")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

enum HomesteadWidgetEntityPickerText {
    static func collection<Entity: AppEntity>(
        from entities: [Entity],
        groupedBy groupTitle: (Entity) -> String,
        sortedBy sortTitle: (Entity) -> String
    ) -> IntentItemCollection<Entity> {
        let groupedEntities = Dictionary(grouping: entities, by: groupTitle)
        let sections = groupedEntities.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { title in
                let items = groupedEntities[title, default: []]
                    .sorted {
                        sortTitle($0).localizedCaseInsensitiveCompare(sortTitle($1)) == .orderedAscending
                    }
                return IntentItemSection("\(title)", items: items)
            }

        return IntentItemCollection(sections: sections)
    }

    static func contextualDisplayName(
        _ displayName: String,
        areaName: String?,
        deviceName: String?
    ) -> String {
        guard let contextName = contextName(areaName: areaName, deviceName: deviceName) else {
            return displayName
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count > contextName.count else {
            return displayName
        }

        let lowercasedName = trimmedName.lowercased()
        let lowercasedContextName = contextName.lowercased()
        guard lowercasedName.hasPrefix(lowercasedContextName) else {
            return displayName
        }

        let suffixStart = trimmedName.index(trimmedName.startIndex, offsetBy: contextName.count)
        let suffix = String(trimmedName[suffixStart...])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

        return suffix.isEmpty ? displayName : suffix
    }

    static func matches(query: String, values: [String?]) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        return values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(trimmedQuery)
    }

    static func displayName(forDomain domain: String) -> String {
        switch domain {
        case "light":
            "Light"
        case "switch":
            "Switch"
        case "fan":
            "Fan"
        case "cover":
            "Cover"
        case "lock":
            "Lock"
        case "sensor":
            "Sensor"
        case "person":
            "Person"
        case "scene":
            "Scene"
        case "script":
            "Script"
        default:
            domain.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func pluralDisplayName(forDomain domain: String) -> String {
        switch domain {
        case "switch":
            "Switches"
        case "person":
            "People"
        default:
            "\(displayName(forDomain: domain))s"
        }
    }

    private static func contextName(areaName: String?, deviceName: String?) -> String? {
        nonEmptyValue(areaName) ?? nonEmptyValue(deviceName)
    }

    static func groupName(
        areaName: String?,
        deviceName: String?,
        fallback: String
    ) -> String {
        contextName(areaName: areaName, deviceName: deviceName) ?? fallback
    }

    static func serverScopedGroupName(
        serverName: String,
        hasMultipleServers: Bool,
        areaName: String?,
        deviceName: String?,
        fallback: String
    ) -> String {
        let localGroup = groupName(
            areaName: areaName,
            deviceName: deviceName,
            fallback: fallback
        )
        guard hasMultipleServers else {
            return localGroup
        }
        return "\(serverName) · \(localGroup)"
    }

    static func contextDescription(
        serverName: String,
        hasMultipleServers: Bool,
        areaName: String?,
        deviceName: String?
    ) -> String {
        let context = contextName(areaName: areaName, deviceName: deviceName)
        guard hasMultipleServers else {
            return context ?? serverName
        }
        return [serverName, context].compactMap { $0 }.joined(separator: " · ")
    }

    private static func nonEmptyValue(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue : nil
    }
}

struct WidgetOAuthCredential: Codable, Equatable, Sendable {
    let baseURLString: String
    let clientID: String
    let refreshToken: String
    let accessToken: String
    let accessTokenExpiresAt: Date
    let tokenType: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case baseURLString
        case clientID
        case refreshToken
        case accessToken
        case accessTokenExpiresAt
        case tokenType
        case updatedAt
    }

    func accessTokenExpiresSoon(
        now: Date = Date(),
        leeway: TimeInterval
    ) -> Bool {
        accessTokenExpiresAt.timeIntervalSince(now) <= leeway
    }

    func replacingAccessToken(
        _ accessToken: String,
        expiresIn: TimeInterval,
        tokenType: String,
        now: Date = Date()
    ) -> WidgetOAuthCredential {
        WidgetOAuthCredential(
            baseURLString: baseURLString,
            clientID: clientID,
            refreshToken: refreshToken,
            accessToken: accessToken,
            accessTokenExpiresAt: now.addingTimeInterval(expiresIn),
            tokenType: tokenType,
            updatedAt: now
        )
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct WidgetOAuthTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: TimeInterval
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct OptimisticLightState: Codable, Equatable {
    let isOn: Bool
    let updatedAt: Date
}

private struct OptimisticSwitchState: Codable, Equatable {
    let isOn: Bool
    let updatedAt: Date
}

private struct OptimisticFanState: Codable, Equatable {
    let isOn: Bool
    let updatedAt: Date
}
