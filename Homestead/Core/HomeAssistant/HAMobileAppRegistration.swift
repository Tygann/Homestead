import Foundation
#if canImport(UIKit)
import UIKit
#endif

nonisolated struct HAMobileAppRegistrationRequestDTO: Encodable, Equatable, Sendable {
    let deviceID: String
    let appID: String
    let appName: String
    let appVersion: String
    let deviceName: String
    let manufacturer: String
    let model: String
    let osName: String
    let osVersion: String
    let supportsEncryption: Bool
    let appData: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case appID = "app_id"
        case appName = "app_name"
        case appVersion = "app_version"
        case deviceName = "device_name"
        case manufacturer
        case model
        case osName = "os_name"
        case osVersion = "os_version"
        case supportsEncryption = "supports_encryption"
        case appData = "app_data"
    }
}

nonisolated struct HAMobileAppRegistrationUpdateDTO: Encodable, Equatable, Sendable {
    let appVersion: String
    let deviceName: String
    let manufacturer: String
    let model: String
    let osVersion: String
    let appData: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case deviceName = "device_name"
        case manufacturer
        case model
        case osVersion = "os_version"
        case appData = "app_data"
    }
}

nonisolated struct HAMobileAppRegistrationResponseDTO: Decodable, Equatable, Sendable {
    let cloudhookURL: String?
    let remoteUIURL: String?
    let secret: String?
    let webhookID: String

    enum CodingKeys: String, CodingKey {
        case cloudhookURL = "cloudhook_url"
        case remoteUIURL = "remote_ui_url"
        case secret
        case webhookID = "webhook_id"
    }
}

nonisolated struct HAMobileAppRegistrationInfo: Codable, Equatable, Sendable {
    let serverIdentifier: String
    let deviceID: String
    let appID: String
    let appName: String
    let appVersion: String
    let deviceName: String
    let webhookID: String
    let cloudhookURL: String?
    let remoteUIURL: String?
    let secret: String?
    let supportsWebSocketNotifications: Bool?
    let supportsCloudPushNotifications: Bool?
    let registeredAt: Date

    nonisolated var hasEncryptedWebhookSecret: Bool {
        guard let secret else { return false }
        return !secret.isEmpty
    }

    nonisolated func hasCurrentRemotePushRegistration(for configuration: HAConnectionConfiguration) -> Bool {
        serverIdentifier == configuration.dataSourceID &&
            supportsCloudPushNotifications == true &&
            supportsWebSocketNotifications != true
    }

    enum CodingKeys: String, CodingKey {
        case serverIdentifier
        case deviceID
        case appID
        case appName
        case appVersion
        case deviceName
        case webhookID
        case cloudhookURL
        case remoteUIURL
        case secret
        case supportsWebSocketNotifications
        case supportsCloudPushNotifications
        case registeredAt
    }

    init(
        serverIdentifier: String,
        request: HAMobileAppRegistrationRequestDTO,
        response: HAMobileAppRegistrationResponseDTO,
        registeredAt: Date = Date()
    ) {
        self.serverIdentifier = serverIdentifier
        deviceID = request.deviceID
        appID = request.appID
        appName = request.appName
        appVersion = request.appVersion
        deviceName = request.deviceName
        webhookID = response.webhookID
        cloudhookURL = response.cloudhookURL
        remoteUIURL = response.remoteUIURL
        secret = response.secret
        supportsWebSocketNotifications = request.appData?["push_websocket_channel"]?.boolValue == true
        supportsCloudPushNotifications = request.includesRemotePushAppData
        self.registeredAt = registeredAt
    }

    init(
        serverIdentifier: String,
        deviceID: String,
        appID: String = "com.tyler.Homestead",
        appName: String = "Homestead",
        appVersion: String,
        deviceName: String,
        webhookID: String,
        cloudhookURL: String? = nil,
        remoteUIURL: String? = nil,
        secret: String? = nil,
        supportsWebSocketNotifications: Bool? = nil,
        supportsCloudPushNotifications: Bool? = nil,
        registeredAt: Date = Date()
    ) {
        self.serverIdentifier = serverIdentifier
        self.deviceID = deviceID
        self.appID = appID
        self.appName = appName
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.webhookID = webhookID
        self.cloudhookURL = cloudhookURL
        self.remoteUIURL = remoteUIURL
        self.secret = secret
        self.supportsWebSocketNotifications = supportsWebSocketNotifications
        self.supportsCloudPushNotifications = supportsCloudPushNotifications
        self.registeredAt = registeredAt
    }
}

nonisolated enum HAMobileAppRegistrationState: Equatable, Sendable {
    case unregistered
    case registering
    case registered(HAMobileAppRegistrationSummary)
    case failed(String)

    var isRegistered: Bool {
        if case .registered = self {
            return true
        }
        return false
    }

    var isRegistering: Bool {
        if case .registering = self {
            return true
        }
        return false
    }
}

nonisolated struct HAMobileAppRegistrationSummary: Equatable, Sendable {
    let deviceName: String
    let appVersion: String
    let registeredAt: Date
    let usesCloudhook: Bool
    let hasEncryptedWebhookSecret: Bool
    let supportsWebSocketNotifications: Bool
    let supportsCloudPushNotifications: Bool

    init(info: HAMobileAppRegistrationInfo) {
        deviceName = info.deviceName
        appVersion = info.appVersion
        registeredAt = info.registeredAt
        usesCloudhook = info.cloudhookURL != nil
        hasEncryptedWebhookSecret = info.hasEncryptedWebhookSecret
        supportsWebSocketNotifications = info.supportsWebSocketNotifications == true
        supportsCloudPushNotifications = info.supportsCloudPushNotifications == true
    }
}

enum HAMobileAppRegistrationRequestFactory {
    nonisolated static let appID = "com.tyler.Homestead"
    nonisolated static let appName = "Homestead"
    nonisolated static let deviceNamePrefix = "Homestead • "

    static func makeRequest(
        deviceID: String = UUID().uuidString,
        appVersion: String = Bundle.main.shortVersionString,
        deviceName: String = CurrentDeviceInfo.name,
        userDisplayName: String? = nil,
        manufacturer: String = CurrentDeviceInfo.manufacturer,
        model: String = CurrentDeviceInfo.model,
        osName: String = CurrentDeviceInfo.osName,
        osVersion: String = CurrentDeviceInfo.osVersion,
        pushRelayToken: String? = nil,
        pushURL: String = HomesteadPushRelayEndpoint.pushURLString,
        supportsWebSocketPush: Bool = false
    ) -> HAMobileAppRegistrationRequestDTO {
        return HAMobileAppRegistrationRequestDTO(
            deviceID: deviceID,
            appID: appID,
            appName: appName,
            appVersion: appVersion,
            deviceName: visibleDeviceName(for: deviceName, userDisplayName: userDisplayName),
            manufacturer: manufacturer,
            model: model,
            osName: osName,
            osVersion: osVersion,
            supportsEncryption: false,
            appData: appData(
                pushRelayToken: pushRelayToken,
                pushURL: pushURL,
                supportsWebSocketPush: supportsWebSocketPush
            )
        )
    }

    static func makeUpdate(
        appVersion: String = Bundle.main.shortVersionString,
        deviceName: String = CurrentDeviceInfo.name,
        userDisplayName: String? = nil,
        manufacturer: String = CurrentDeviceInfo.manufacturer,
        model: String = CurrentDeviceInfo.model,
        osVersion: String = CurrentDeviceInfo.osVersion,
        pushRelayToken: String? = nil,
        pushURL: String = HomesteadPushRelayEndpoint.pushURLString,
        supportsWebSocketPush: Bool = false
    ) -> HAMobileAppRegistrationUpdateDTO {
        HAMobileAppRegistrationUpdateDTO(
            appVersion: appVersion,
            deviceName: visibleDeviceName(for: deviceName, userDisplayName: userDisplayName),
            manufacturer: manufacturer,
            model: model,
            osVersion: osVersion,
            appData: appData(
                pushRelayToken: pushRelayToken,
                pushURL: pushURL,
                supportsWebSocketPush: supportsWebSocketPush
            )
        )
    }

    nonisolated static func visibleDeviceName(
        for deviceName: String,
        userDisplayName: String? = nil
    ) -> String {
        let trimmedName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return "\(deviceNamePrefix)Device"
        }

        guard !trimmedName.hasPrefix(deviceNamePrefix) else {
            return trimmedName
        }

        let trimmedUserName = userDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if isGenericAppleDeviceName(trimmedName),
           let trimmedUserName,
           !trimmedUserName.isEmpty {
            return "\(deviceNamePrefix)\(trimmedUserName) • \(trimmedName)"
        }

        return "\(deviceNamePrefix)\(trimmedName)"
    }

    private nonisolated static func isGenericAppleDeviceName(_ deviceName: String) -> Bool {
        switch deviceName.lowercased() {
        case "iphone", "ipad", "ipod touch", "apple watch", "mac":
            return true
        default:
            return false
        }
    }

    private nonisolated static func appData(
        pushRelayToken: String?,
        pushURL: String,
        supportsWebSocketPush: Bool
    ) -> [String: JSONValue]? {
        let trimmedPushRelayToken = pushRelayToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        var appData: [String: JSONValue] = [:]

        if let trimmedPushRelayToken, !trimmedPushRelayToken.isEmpty {
            appData["push_url"] = .string(pushURL)
            appData["push_token"] = .string(trimmedPushRelayToken)
        }

        if supportsWebSocketPush {
            appData["push_websocket_channel"] = .bool(true)
        }

        return appData.isEmpty ? nil : appData
    }
}

extension HAMobileAppRegistrationRequestDTO {
    nonisolated var includesRemotePushAppData: Bool {
        appData?.includesRemotePushMetadata == true
    }
}

extension HAMobileAppRegistrationUpdateDTO {
    nonisolated var includesRemotePushAppData: Bool {
        appData?.includesRemotePushMetadata == true
    }
}

private extension [String: JSONValue] {
    nonisolated var includesRemotePushMetadata: Bool {
        self["push_url"]?.stringValue?.isEmpty == false &&
            self["push_token"]?.stringValue?.isEmpty == false
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ??
            object(forInfoDictionaryKey: "CFBundleVersion") as? String ??
            "1.0"
    }
}

private enum CurrentDeviceInfo {
    static var name: String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "Homestead Device"
        #endif
    }

    static var manufacturer: String {
        "Apple, Inc."
    }

    static var model: String {
        #if canImport(UIKit)
        UIDevice.current.model
        #else
        "Mac"
        #endif
    }

    static var osName: String {
        #if os(iOS)
        "iOS"
        #elseif os(macOS)
        "macOS"
        #else
        "Apple OS"
        #endif
    }

    static var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
}
