import AppIntents
import Foundation
import Security

enum HomesteadWidgetSharedStore {
    static let appGroupID = "group.com.tyler.Homestead"
    static let keychainAccessGroup = "XKQ424HQ33.com.tyler.Homestead.shared"

    private static let baseURLKey = "homeAssistantBaseURL"
    private static let serverProfilesKey = "homeAssistantServerProfiles"
    private static let legacyWidgetProfileIDKey = "homeAssistantLegacyWidgetProfileID"
    private static let lightSnapshotsKey = "widgetLightSnapshots"
    private static let switchSnapshotsKey = "widgetSwitchSnapshots"
    private static let coverSnapshotsKey = "widgetCoverSnapshots"
    private static let fanSnapshotsKey = "widgetFanSnapshots"
    private static let lockSnapshotsKey = "widgetLockSnapshots"
    private static let sensorSnapshotsKey = "widgetSensorSnapshots"
    private static let presenceSnapshotsKey = "widgetPresenceSnapshots"
    private static let actionSnapshotsKey = "widgetActionSnapshots"
    private static let optimisticLightStatesKey = "widgetOptimisticLightStates"
    private static let optimisticSwitchStatesKey = "widgetOptimisticSwitchStates"
    private static let optimisticFanStatesKey = "widgetOptimisticFanStates"
    private static let tokenService = "com.tyler.Homestead.homeAssistant"
    private static let oauthCredentialAccount = "oauthCredential"
    private static let oauthClientID = "https://connect.homesteadcontrol.com"
    private static let tokenRefreshLeeway: TimeInterval = 60

    static var legacyWidgetProfileID: UUID? {
        sharedDefaults?.string(forKey: legacyWidgetProfileIDKey).flatMap(UUID.init(uuidString:))
    }

    static var serverProfiles: [WidgetServerProfile] {
        guard let data = sharedDefaults?.data(forKey: serverProfilesKey) else { return [] }
        return (try? JSONDecoder().decode([WidgetServerProfile].self, from: data)) ?? []
    }

    static var baseURL: String? {
        guard let profileID = legacyWidgetProfileID else {
            return sharedDefaults?.string(forKey: baseURLKey)
        }
        return serverProfiles.first(where: { $0.id == profileID })?.baseURLString
    }

    static func validAccessToken() async throws -> String {
        guard let credential = try readOAuthCredential() else {
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
        try saveOAuthCredential(refreshedCredential)
        return refreshedCredential.accessToken
    }

    static func savedOAuthCredentialForDiagnostics() throws -> WidgetOAuthCredential? {
        try readOAuthCredential()
    }

    private static func readOAuthCredential() throws -> WidgetOAuthCredential? {
        var query = baseOAuthCredentialQuery
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

    private static func saveOAuthCredential(_ credential: WidgetOAuthCredential) throws {
        let data = try WidgetOAuthCredential.encoder.encode(credential)
        var query = baseOAuthCredentialQuery
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

    static var lightSnapshots: [WidgetLightSnapshot] {
        guard let data = sharedDefaults?.data(forKey: lightSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetLightSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func lightSnapshot(entityID: String) -> WidgetLightSnapshot? {
        lightSnapshots.first { $0.entityID == entityID }
    }

    static var switchSnapshots: [WidgetSwitchSnapshot] {
        guard let data = sharedDefaults?.data(forKey: switchSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetSwitchSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func switchSnapshot(entityID: String) -> WidgetSwitchSnapshot? {
        switchSnapshots.first { $0.entityID == entityID }
    }

    static var coverSnapshots: [WidgetCoverSnapshot] {
        guard let data = sharedDefaults?.data(forKey: coverSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetCoverSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func coverSnapshot(entityID: String) -> WidgetCoverSnapshot? {
        coverSnapshots.first { $0.entityID == entityID }
    }

    static var fanSnapshots: [WidgetFanSnapshot] {
        guard let data = sharedDefaults?.data(forKey: fanSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetFanSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func fanSnapshot(entityID: String) -> WidgetFanSnapshot? {
        fanSnapshots.first { $0.entityID == entityID }
    }

    static var lockSnapshots: [WidgetLockSnapshot] {
        guard let data = sharedDefaults?.data(forKey: lockSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetLockSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func lockSnapshot(entityID: String) -> WidgetLockSnapshot? {
        lockSnapshots.first { $0.entityID == entityID }
    }

    static var sensorSnapshots: [WidgetSensorSnapshot] {
        guard let data = sharedDefaults?.data(forKey: sensorSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetSensorSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func sensorSnapshot(entityID: String) -> WidgetSensorSnapshot? {
        sensorSnapshots.first { $0.entityID == entityID }
    }

    static var presenceSnapshots: [WidgetPresenceSnapshot] {
        guard let data = sharedDefaults?.data(forKey: presenceSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetPresenceSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func presenceSnapshot(entityID: String) -> WidgetPresenceSnapshot? {
        presenceSnapshots.first { $0.entityID == entityID }
    }

    static var actionSnapshots: [WidgetActionSnapshot] {
        guard let data = sharedDefaults?.data(forKey: actionSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([WidgetActionSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }

    static func actionSnapshot(entityID: String) -> WidgetActionSnapshot? {
        actionSnapshots.first { $0.entityID == entityID }
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
        let updatedSnapshots = lightSnapshots.map { snapshot in
            guard snapshot.entityID == entityID else {
                return snapshot
            }

            return WidgetLightSnapshot(
                entityID: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: isOn,
                brightnessPercentage: snapshot.brightnessPercentage,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
                icon: snapshot.icon
            )
        }

        saveLightSnapshots(updatedSnapshots)

        var optimisticStates = optimisticLightStates
        optimisticStates[entityID] = OptimisticLightState(isOn: isOn, updatedAt: Date())
        saveOptimisticLightStates(optimisticStates)
    }

    static func updateSwitchSnapshot(entityID: String, isOn: Bool) {
        let updatedSnapshots = switchSnapshots.map { snapshot in
            guard snapshot.entityID == entityID else {
                return snapshot
            }

            return WidgetSwitchSnapshot(
                entityID: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: isOn,
                systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                icon: snapshot.icon
            )
        }

        saveSwitchSnapshots(updatedSnapshots)

        var optimisticStates = optimisticSwitchStates
        optimisticStates[entityID] = OptimisticSwitchState(isOn: isOn, updatedAt: Date())
        saveOptimisticSwitchStates(optimisticStates)
    }

    static func updateFanSnapshot(entityID: String, isOn: Bool) {
        let updatedSnapshots = fanSnapshots.map { snapshot in
            guard snapshot.entityID == entityID else {
                return snapshot
            }

            return WidgetFanSnapshot(
                entityID: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: isOn,
                statusText: isOn ? "On" : "Off",
                isAvailable: snapshot.isAvailable,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
                icon: snapshot.icon
            )
        }

        saveFanSnapshots(updatedSnapshots)

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

    private static func saveLightSnapshots(_ snapshots: [WidgetLightSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: lightSnapshotsKey)
    }

    private static func saveSwitchSnapshots(_ snapshots: [WidgetSwitchSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: switchSnapshotsKey)
    }

    private static func saveFanSnapshots(_ snapshots: [WidgetFanSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        sharedDefaults?.set(data, forKey: fanSnapshotsKey)
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

    private static func switchSystemImage(isOn: Bool, fallback: String) -> String {
        guard fallback == "lightswitch.on.fill" || fallback == "lightswitch.off.fill" else {
            return fallback
        }

        return isOn ? "lightswitch.on.fill" : "lightswitch.off.fill"
    }

    private static var baseOAuthCredentialQuery: [String: Any] {
        let account = legacyWidgetProfileID.map {
            "\(oauthCredentialAccount).\($0.uuidString.lowercased())"
        } ?? oauthCredentialAccount
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
