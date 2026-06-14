import SwiftUI
import UIKit

// MARK: - Home Assistant Diagnostics View
struct HomeAssistantDiagnosticsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var didCopyDiagnostics = false
    @State private var showsAdvancedDetails = false

    var body: some View {
        let diagnostics = HomeAssistantDiagnosticsSnapshot(
            connectionSettings: connectionSettings,
            homeAssistantService: homeAssistantService,
            serverDisplayText: serverDisplayText,
            signedInServerDisplayText: signedInServerDisplayText
        )

        Form {
            Section {
                Button {
                    UIPasteboard.general.string = diagnostics.clipboardText
                    didCopyDiagnostics = true
                    HapticFeedback.selection()
                } label: {
                    Label(didCopyDiagnostics ? "Diagnostics Copied" : "Copy Diagnostics", systemImage: didCopyDiagnostics ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .accessibilityHint("Copies a privacy-safe support summary without tokens or cache file paths.")
            } footer: {
                Text("Use this when sharing details for support. Tokens and exact cache paths are not included.")
            }

            Section("Connection") {
                LabeledContent("Connection") {
                    Text(connectionSummary)
                        .foregroundStyle(statusTint)
                }

                LabeledContent("Server", value: serverDisplayText)
            }

            Section("Recent State") {
                if let lastUpdated = homeAssistantService.dataFreshness.lastKnownUpdateDate {
                    LabeledContent("Last Update") {
                        Text(lastUpdated.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LabeledContent("Last Update", value: "Not available")
                }

                if let cacheSummary {
                    LabeledContent("Saved State", value: cacheSummary)
                }
            }

            Section {
                DisclosureGroup("Advanced Details", isExpanded: $showsAdvancedDetails) {
                    LabeledContent("Account", value: homeAssistantService.currentUserDisplayName ?? "Not available")
                    LabeledContent("Authentication", value: homeAssistantService.authState.diagnosticTitle)
                    LabeledContent("State", value: homeAssistantService.dataFreshness.settingsTitle)
                    LabeledContent("Network", value: homeAssistantService.isNetworkAvailable ? "Available" : "Unavailable")
                    LabeledContent("Background Setup", value: mobileAppStatusTitle)

                    if let signedInServerDisplayText {
                        LabeledContent("Signed-In Server", value: signedInServerDisplayText)
                    }

                    if let mobileAppStatusMessage {
                        Text(mobileAppStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await homeAssistantService.registerMobileApp(settings: connectionSettings)
                        }
                    } label: {
                        Text(mobileAppButtonTitle)
                    }
                    .disabled(!connectionSettings.hasServerURL ||
                              hasServerMismatch ||
                              !homeAssistantService.authState.isSignedIn ||
                              homeAssistantService.mobileAppRegistrationState.isRegistering)
                }
            } header: {
                Text("More")
            } footer: {
                Text("Most people will not need these details.")
            }
        }
        .navigationTitle("Diagnostics")
        .toolbarTitleDisplayMode(.inline)
        .onChange(of: diagnostics.clipboardText) { _, _ in
            didCopyDiagnostics = false
        }
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var signedInServerDisplayText: String? {
        guard let summary = homeAssistantService.authState.sessionSummary else {
            return nil
        }

        return SettingsHomeAssistantStatus.serverDisplayText(summary.baseURLString)
    }

    private var hasServerMismatch: Bool {
        guard connectionSettings.hasServerURL,
              let summary = homeAssistantService.authState.sessionSummary else {
            return false
        }

        let signedInServer = HAConnectionConfiguration(
            baseURLString: summary.baseURLString,
            accessToken: ""
        ).dataSourceID
        let enteredServer = HAConnectionConfiguration(
            baseURLString: connectionSettings.baseURL,
            accessToken: ""
        ).dataSourceID
        return signedInServer != enteredServer
    }

    private var statusTint: Color {
        SettingsHomeAssistantStatus.tint(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var connectionSummary: String {
        if !homeAssistantService.isNetworkAvailable {
            return "Offline"
        }

        switch homeAssistantService.authState {
        case .signedOut:
            return "Signed out"
        case .signingIn:
            return "Signing in"
        case .refreshing:
            return "Refreshing"
        case .refreshFailed, .accessTokenExpired:
            return "Needs attention"
        case .signedIn:
            switch homeAssistantService.connectionStatus {
            case .connected:
                return "Connected"
            case .preparing, .connecting, .reconnecting:
                return "Connecting"
            case .failed:
                return "Needs attention"
            case .disconnected:
                return "Not connected"
            }
        }
    }

    private var mobileAppStatusTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            "Not registered"
        case .registering:
            "Registering"
        case .registered:
            "Registered"
        case .failed:
            "Needs attention"
        }
    }

    private var mobileAppStatusMessage: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Homestead will try again automatically after sign-in."
        case .registering:
            return "Homestead is registering with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return message
        }
    }

    private var mobileAppButtonTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .registering:
            "Registering"
        case .registered:
            "Register Again"
        case .unregistered, .failed:
            "Register Mobile App"
        }
    }

    private var cacheSummary: String? {
        guard let metadata = homeAssistantService.stateCacheMetadata else {
            return nil
        }

        return "\(metadata.entityCount) items"
    }
}

private struct HomeAssistantDiagnosticsSnapshot: Equatable {
    let server: String
    let signedInServer: String?
    let account: String
    let auth: String
    let connection: String
    let state: String
    let lastUpdate: String
    let network: String
    let mobileApp: String
    let cache: String
    let app: String
    let device: String

    init(
        connectionSettings: HAConnectionSettings,
        homeAssistantService: HomeAssistantService,
        serverDisplayText: String,
        signedInServerDisplayText: String?
    ) {
        server = connectionSettings.hasServerURL ? serverDisplayText : "Not set"
        signedInServer = signedInServerDisplayText
        account = homeAssistantService.currentUserDisplayName ?? "Not available"
        auth = homeAssistantService.authState.diagnosticTitle
        connection = homeAssistantService.connectionStatus.title
        state = homeAssistantService.dataFreshness.settingsTitle
        lastUpdate = homeAssistantService.dataFreshness.lastKnownUpdateDate?
            .formatted(date: .abbreviated, time: .shortened) ?? "None"
        network = homeAssistantService.isNetworkAvailable ? "Available" : "Unavailable"
        mobileApp = homeAssistantService.mobileAppRegistrationState.diagnosticTitle
        cache = Self.cacheDescription(homeAssistantService.stateCacheMetadata)
        app = "\(Bundle.main.settingsDisplayName) \(Bundle.main.settingsShortVersionString) (\(Bundle.main.settingsBuildVersionString))"
        device = "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
    }

    var clipboardText: String {
        [
            "Homestead Diagnostics",
            "App: \(app)",
            "Device: \(device)",
            "Server: \(server)",
            "Signed-In Server: \(signedInServer ?? "None")",
            "Account: \(account)",
            "Auth: \(auth)",
            "Connection: \(connection)",
            "State: \(state)",
            "Last Update: \(lastUpdate)",
            "Network: \(network)",
            "Mobile App: \(mobileApp)",
            "Cache: \(cache)"
        ].joined(separator: "\n")
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

private extension Bundle {
    var settingsDisplayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String ??
            "Homestead"
    }

    var settingsShortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var settingsBuildVersionString: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
