import Foundation
import UIKit

// MARK: - Server Relationship

nonisolated enum SettingsServerRelationship: Equatable, Sendable {
    case unavailable
    case matches
    case mismatch(configured: String, signedIn: String)

    static func make(
        configuredBaseURL: String,
        signedInBaseURL: String?
    ) -> SettingsServerRelationship {
        let configured = configuredBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configured.isEmpty,
              let signedInBaseURL,
              !signedInBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unavailable
        }

        let configuredID = HAConnectionConfiguration(
            baseURLString: configured,
            accessToken: ""
        ).dataSourceID
        let signedInID = HAConnectionConfiguration(
            baseURLString: signedInBaseURL,
            accessToken: ""
        ).dataSourceID

        guard configuredID != signedInID else {
            return .matches
        }

        return .mismatch(
            configured: SettingsHomeAssistantStatus.serverDisplayText(configured),
            signedIn: SettingsHomeAssistantStatus.serverDisplayText(signedInBaseURL)
        )
    }

    var isMismatch: Bool {
        if case .mismatch = self {
            return true
        }
        return false
    }

    var warningMessage: String? {
        guard case .mismatch(let configured, let signedIn) = self else {
            return nil
        }

        return "Homestead is configured for \(configured), but the saved sign-in belongs to \(signedIn). Sign in again before using background services."
    }
}

// MARK: - Support Presentation

@MainActor
struct HomeAssistantSupportPresentation: Equatable {
    struct Row: Equatable, Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }

    let connectionRows: [Row]
    let backgroundRows: [Row]
    let backgroundDetail: String?
    let recentDataRows: [Row]
    let mismatchWarning: String?
    let registrationActionTitle: String?
    let isRegistrationActionEnabled: Bool
    let clipboardText: String

    init(
        connectionSettings: HAConnectionSettings,
        homeAssistantService: HomeAssistantService
    ) {
        let signedInBaseURL = homeAssistantService.authState.sessionSummary?.baseURLString
        let relationship = SettingsServerRelationship.make(
            configuredBaseURL: connectionSettings.baseURL,
            signedInBaseURL: signedInBaseURL
        )
        let signedInServer = signedInBaseURL.map(SettingsHomeAssistantStatus.serverDisplayText)

        var connectionRows = [
            Row(
                label: "Connection",
                value: Self.connectionSummary(
                    authState: homeAssistantService.authState,
                    connectionStatus: homeAssistantService.connectionStatus,
                    isNetworkAvailable: homeAssistantService.isNetworkAvailable
                )
            ),
            Row(label: "Authentication", value: homeAssistantService.authState.diagnosticTitle),
            Row(
                label: "Network",
                value: homeAssistantService.isNetworkAvailable ? "Available" : "Unavailable"
            )
        ]
        if let signedInServer {
            connectionRows.append(Row(label: "Signed-In Server", value: signedInServer))
        }
        self.connectionRows = connectionRows

        backgroundRows = [
            Row(
                label: "Mobile App",
                value: Self.mobileAppStatusTitle(homeAssistantService.mobileAppRegistrationState)
            )
        ]
        backgroundDetail = Self.mobileAppStatusMessage(homeAssistantService.mobileAppRegistrationState)

        let lastUpdate = homeAssistantService.dataFreshness.lastKnownUpdateDate?
            .formatted(date: .abbreviated, time: .shortened) ?? "Not available"
        recentDataRows = [
            Row(label: "State", value: homeAssistantService.dataFreshness.settingsTitle),
            Row(label: "Last Successful Update", value: lastUpdate),
            Row(
                label: "Saved State",
                value: homeAssistantService.stateCacheMetadata.map { "\($0.entityCount) items" } ?? "Not available"
            )
        ]

        mismatchWarning = relationship.warningMessage

        let registrationAction = Self.registrationAction(
            state: homeAssistantService.mobileAppRegistrationState,
            hasServerURL: connectionSettings.hasServerURL,
            isSignedIn: homeAssistantService.authState.isSignedIn,
            hasServerMismatch: relationship.isMismatch
        )
        registrationActionTitle = registrationAction.title
        isRegistrationActionEnabled = registrationAction.isEnabled

        clipboardText = HomeAssistantDiagnosticsReport(
            configuredServer: connectionSettings.hasServerURL
                ? SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
                : "Not set",
            signedInServer: signedInServer,
            authentication: homeAssistantService.authState.diagnosticTitle,
            connection: homeAssistantService.connectionStatus.title,
            state: homeAssistantService.dataFreshness.settingsTitle,
            lastUpdate: lastUpdate,
            network: homeAssistantService.isNetworkAvailable ? "Available" : "Unavailable",
            mobileApp: homeAssistantService.mobileAppRegistrationState.diagnosticTitle,
            cache: Self.cacheDescription(homeAssistantService.stateCacheMetadata),
            installation: homeAssistantService.serverEnvironment?.installationMethod.title ?? "Not available",
            coreVersion: homeAssistantService.serverEnvironment?.coreVersion ?? "Not available",
            supervisorVersion: homeAssistantService.serverEnvironment?.supervisorVersion ?? "Not available",
            operatingSystemVersion: homeAssistantService.serverEnvironment?.operatingSystemVersion ?? "Not available",
            authenticationFailure: homeAssistantService.lastAuthenticationErrorMessage.map {
                HAConnectionIssuePresentation.fallbackMessage(forRawMessage: $0)
            } ?? "None"
        ).text
    }

    var visibleRowLabels: [String] {
        connectionRows.map(\.label) + backgroundRows.map(\.label) + recentDataRows.map(\.label)
    }

    private static func connectionSummary(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        isNetworkAvailable: Bool
    ) -> String {
        guard isNetworkAvailable else {
            return "Offline"
        }

        switch authState {
        case .signedOut:
            return "Signed Out"
        case .signingIn:
            return "Signing In"
        case .refreshing:
            return "Refreshing"
        case .refreshFailed, .accessTokenExpired:
            return "Needs Attention"
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Connected"
            case .preparing, .connecting, .reconnecting:
                return "Connecting"
            case .failed:
                return "Needs Attention"
            case .disconnected:
                return "Not Connected"
            }
        }
    }

    private static func mobileAppStatusTitle(_ state: HAMobileAppRegistrationState) -> String {
        switch state {
        case .unregistered:
            return "Not Registered"
        case .registering:
            return "Registering"
        case .registered:
            return "Registered"
        case .failed:
            return "Needs Attention"
        }
    }

    private static func mobileAppStatusMessage(_ state: HAMobileAppRegistrationState) -> String? {
        switch state {
        case .unregistered:
            return "Homestead will try to register automatically after sign-in."
        case .registering:
            return "Homestead is registering with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return UserFacingErrorPresentation.message(forRawMessage: message)
        }
    }

    private static func registrationAction(
        state: HAMobileAppRegistrationState,
        hasServerURL: Bool,
        isSignedIn: Bool,
        hasServerMismatch: Bool
    ) -> (title: String?, isEnabled: Bool) {
        guard isSignedIn else {
            return (nil, false)
        }

        let title = switch state {
        case .registered:
            "Register Again"
        case .registering:
            "Registering"
        case .unregistered, .failed:
            "Register Mobile App"
        }

        return (
            title,
            hasServerURL && !hasServerMismatch && !state.isRegistering
        )
    }

    private static func cacheDescription(_ metadata: HAStateCacheMetadata?) -> String {
        guard let metadata else {
            return "No saved cache metadata"
        }

        let registryParts = [
            metadata.entityRegistryCount.map { "\($0) entity registry" },
            metadata.deviceRegistryCount.map { "\($0) devices" },
            metadata.areaRegistryCount.map { "\($0) areas" },
            metadata.floorRegistryCount.map { "\($0) floors" }
        ].compactMap { $0 }

        var parts = [
            "\(metadata.entityCount) entities",
            "saved \(metadata.savedAt.formatted(date: .abbreviated, time: .shortened))",
            "scope \(metadata.shortScopeIdentifier)"
        ]
        parts.append(contentsOf: registryParts)
        return parts.joined(separator: ", ")
    }
}

// MARK: - Diagnostic Report

@MainActor
struct HomeAssistantDiagnosticsReport: Equatable {
    let configuredServer: String
    let signedInServer: String?
    let authentication: String
    let connection: String
    let state: String
    let lastUpdate: String
    let network: String
    let mobileApp: String
    let cache: String
    let installation: String
    let coreVersion: String
    let supervisorVersion: String
    let operatingSystemVersion: String
    let authenticationFailure: String

    var text: String {
        [
            "Homestead Diagnostics",
            "App: \(Self.appDescription)",
            "Device: \(Self.deviceDescription)",
            "Configured Server: \(configuredServer)",
            "Signed-In Server: \(signedInServer ?? "None")",
            "Authentication: \(authentication)",
            "Connection: \(connection)",
            "State: \(state)",
            "Last Update: \(lastUpdate)",
            "Network: \(network)",
            "Mobile App: \(mobileApp)",
            "Cache: \(cache)",
            "Installation: \(installation)",
            "Core: \(coreVersion)",
            "Supervisor: \(supervisorVersion)",
            "OS: \(operatingSystemVersion)",
            "Last Authentication Failure: \(authenticationFailure)"
        ].joined(separator: "\n")
    }

    private static var appDescription: String {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Homestead"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(displayName) \(version) (\(build))"
    }

    private static var deviceDescription: String {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionComponents = [version.majorVersion, version.minorVersion, version.patchVersion]
            let versionString = versionComponents
                .dropLast(version.patchVersion == 0 ? 1 : 0)
                .map(String.init)
                .joined(separator: ".")
            return "Mac (Designed for iPad), macOS \(versionString)"
        }

        let deviceName = switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            "iPhone"
        case .pad:
            "iPad"
        default:
            UIDevice.current.model
        }
        return "\(deviceName), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }
}
