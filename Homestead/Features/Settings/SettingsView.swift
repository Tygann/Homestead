import SwiftUI
import UIKit

// MARK: - Settings View
struct SettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: HomeAssistantSettingsView()) {
                    HomeAssistantSettingsRow(
                        title: accountTitle,
                        server: serverDisplayText,
                        status: accountStatusText,
                        tint: accountStatusTint
                    )
                }
            }

            Section {
                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .task(id: authRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
        }
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var accountTitle: String {
        homeAssistantService.currentUserDisplayName ?? "Home Assistant"
    }

    private var accountStatusText: String {
        SettingsHomeAssistantStatus.summaryStatusText(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var accountStatusTint: Color {
        SettingsHomeAssistantStatus.tint(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var authRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }
}

// MARK: - Home Assistant Settings View
struct HomeAssistantSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @FocusState private var focusedField: Field?
    @State private var isConfirmingSignOut = false

    var body: some View {
        @Bindable var connectionSettings = connectionSettings

        Form {
            accountSection

            // MARK: - Server Section
            Section {
                if connectionSettings.hasServerURL {
                    DisclosureGroup("Change Server") {
                        TextField("Base URL", text: $connectionSettings.baseURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .baseURL)
                    }
                } else {
                    TextField("Base URL", text: $connectionSettings.baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .baseURL)
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Use the address you normally use to open Home Assistant.")
            }

            // MARK: - Server Section
            if shouldShowSignIn || canRetryConnection {
                Section {
                    if shouldShowSignIn {
                        Button {
                            focusedField = nil
                            Task {
                                await homeAssistantService.signInWithHomeAssistant(settings: connectionSettings)
                            }
                        } label: {
                            Text(signInButtonTitle)
                        }
                        .disabled(!connectionSettings.hasServerURL || homeAssistantService.authState == .signingIn)
                        .frame(maxWidth: .infinity)
                    }

                    if canRetryConnection {
                        Button {
                            focusedField = nil
                            Task {
                                await homeAssistantService.connect(
                                    baseURLString: connectionSettings.baseURL
                                )
                            }
                        } label: {
                            Text("Retry Connection")
                        }
                        .disabled(homeAssistantService.connectionStatus == .connecting ||
                                  homeAssistantService.connectionStatus == .reconnecting)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            if shouldShowRegistrationProblem {
                Section {
                    Label("Background setup needs attention", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    if let mobileAppStatusMessage {
                        Text(mobileAppStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        focusedField = nil
                        Task {
                            await homeAssistantService.registerMobileApp(settings: connectionSettings)
                        }
                    } label: {
                        Text(mobileAppButtonTitle)
                    }
                    .disabled(!connectionSettings.hasServerURL ||
                              hasServerMismatch ||
                              homeAssistantService.mobileAppRegistrationState.isRegistering)
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text("Homestead normally handles this automatically after sign-in.")
                }
            }

            if shouldShowSupport {
                Section {
                    NavigationLink {
                        HomeAssistantDiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "stethoscope")
                    }
                } footer: {
                    Text("Support details are available if something is not working as expected.")
                }
            }

            if canSignOut {
                Section {
                    Button(role: .destructive) {
                        focusedField = nil
                        isConfirmingSignOut = true
                    } label: {
                        Text("Sign Out")
                    }
                    .disabled(!canSignOut)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Home Assistant")
        .toolbarTitleDisplayMode(.inline)
        .padding(.top, -30)
        .task(id: authRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
        }
        .confirmationDialog(
            "Sign out of Home Assistant?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await homeAssistantService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved Home Assistant credentials and mobile app registration from this device.")
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section {
            VStack(alignment: .center, spacing: 10) {
                HomeAssistantAvatarView()
                    .frame(width: 100, height: 100)
                
                Text(accountTitle)
//                    .foregroundStyle(.primary)
                    .font(.title)
                    .fontWeight(.bold)
//                    .fontDesign(.rounded)
                
                Text(serverDisplayText)
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
                    .foregroundColor(.gray)
                    .fontDesign(.rounded)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
            

            if let primaryStatusMessage {
                Text(primaryStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if hasServerMismatch, let signedInServerDisplayText {
                LabeledContent("Signed-In Server") {
                    Text(signedInServerDisplayText)
                        .foregroundStyle(.orange)
                }
            }
        }
        .listRowBackground(Color.clear)
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var accountTitle: String {
        homeAssistantService.currentUserDisplayName ?? "Home Assistant"
    }

    private var statusMessage: String {
        if hasServerMismatch {
            return "This server is different from the saved Home Assistant sign-in. Sign in again for this server."
        }

        return SettingsHomeAssistantStatus.detailMessage(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            serviceError: homeAssistantService.lastErrorMessage,
            storageError: connectionSettings.authStorageErrorMessage
        )
    }

    private var primaryStatusMessage: String? {
        if hasServerMismatch || connectionSettings.authStorageErrorMessage != nil {
            return statusMessage
        }

        switch homeAssistantService.authState {
        case .signedOut, .signingIn, .refreshing, .refreshFailed, .accessTokenExpired:
            return statusMessage
        case .signedIn:
            switch homeAssistantService.connectionStatus {
            case .failed, .disconnected:
                return statusMessage
            case .connected, .connecting, .reconnecting:
                return nil
            }
        }
    }

    private var statusTint: Color {
        SettingsHomeAssistantStatus.tint(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
    }

    private var signInButtonTitle: String {
        switch homeAssistantService.authState {
        case .signedOut, .refreshFailed, .accessTokenExpired:
            "Sign in with Home Assistant"
        case .signingIn:
            "Signing In"
        case .refreshing:
            "Refreshing"
        case .signedIn:
            "Sign in again"
        }
    }

    private var shouldShowSignIn: Bool {
        if hasServerMismatch {
            return true
        }

        return switch homeAssistantService.authState {
        case .signedOut, .signingIn, .refreshFailed, .accessTokenExpired:
            true
        case .refreshing, .signedIn:
            false
        }
    }

    private var canRetryConnection: Bool {
        guard !hasServerMismatch else {
            return false
        }

        guard homeAssistantService.authState.isSignedIn else {
            return false
        }

        switch homeAssistantService.connectionStatus {
        case .failed, .disconnected:
            return true
        case .connected, .connecting, .reconnecting:
            return false
        }
    }

    private var canSignOut: Bool {
        if homeAssistantService.authState.isSignedIn {
            return true
        }

        if case .refreshFailed = homeAssistantService.authState {
            return true
        }

        return false
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

    private var mobileAppStatusMessage: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return nil
        case .registering:
            return nil
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return message
        }
    }

    private var shouldShowRegistrationProblem: Bool {
        guard homeAssistantService.authState.isSignedIn else {
            return false
        }

        if case .failed = homeAssistantService.mobileAppRegistrationState {
            return true
        }

        return false
    }

    private var shouldShowSupport: Bool {
        connectionSettings.hasServerURL || homeAssistantService.authState.isSignedIn || homeAssistantService.hasCompletedInitialCacheLoad
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

    private var authRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }

    private enum Field {
        case baseURL
    }
}

private extension HAAuthState {
    var sessionSummary: HAAuthSessionSummary? {
        switch self {
        case .signedIn(let summary), .accessTokenExpired(let summary), .refreshing(let summary?):
            summary
        case .refreshing(nil), .signedOut, .signingIn, .refreshFailed:
            nil
        }
    }
}

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
            case .connecting, .reconnecting:
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
        app = "\(Bundle.main.displayName) \(Bundle.main.shortVersionString) (\(Bundle.main.buildVersionString))"
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
            metadata.areaRegistryCount.map { "\($0) areas" }
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

private extension HAAuthState {
    var diagnosticTitle: String {
        switch self {
        case .signedOut:
            "Signed Out"
        case .signingIn:
            "Signing In"
        case .refreshing:
            "Refreshing"
        case .signedIn:
            "Signed In"
        case .accessTokenExpired:
            "Access Token Expired"
        case .refreshFailed:
            "Refresh Failed"
        }
    }
}

private extension HADataFreshness {
    var settingsTitle: String {
        switch self {
        case .empty:
            "No state loaded"
        case .cached:
            "Showing cached state"
        case .refreshing:
            "Refreshing"
        case .live:
            "Live"
        case .stale:
            "Stale"
        }
    }

    var settingsTint: Color {
        switch self {
        case .live:
            .green
        case .cached, .refreshing:
            .orange
        case .stale:
            .red
        case .empty:
            .secondary
        }
    }
}

private extension HAMobileAppRegistrationState {
    var diagnosticTitle: String {
        switch self {
        case .unregistered:
            return "Not Registered"
        case .registering:
            return "Registering"
        case .registered(let summary):
            let cloudhook = summary.usesCloudhook ? "cloudhook" : "local webhook"
            let encryptedSecret = summary.hasEncryptedWebhookSecret ? "secret present" : "no secret"
            return "Registered as \(summary.deviceName), app \(summary.appVersion), \(cloudhook), \(encryptedSecret)"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}

private extension Bundle {
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String ??
            "Homestead"
    }

    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildVersionString: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

// MARK: - Home Assistant Settings Row
private struct HomeAssistantSettingsRow: View {
    let title: String
    let server: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(spacing: 15) {
            HomeAssistantAvatarView()
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(server)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fontDesign(.rounded)
            .lineLimit(1)

            Spacer()

            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())
        }
    }
}

// MARK: - Home Assistant Avatar View
private struct HomeAssistantAvatarView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
//        .frame(width: 60, height: 60)
        .clipShape(Circle())
        .task(id: taskID) {
            await loadImage()
        }
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title
        ].joined(separator: "|")
    }

    private func loadImage() async {
        guard let request = await homeAssistantService.homeAssistantProfileImageRequest(settings: connectionSettings) else {
            image = nil
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                image = nil
                return
            }
            image = Image(uiImage: uiImage)
        } catch {
            image = nil
        }
    }
}

// MARK: - Settings Home Assistant Status
private enum SettingsHomeAssistantStatus {
    static func serverDisplayText(_ baseURL: String) -> String {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            return "No server set"
        }

        let normalizedURL: String
        if trimmedURL.contains("://") {
            normalizedURL = trimmedURL
        } else {
            normalizedURL = "http://\(trimmedURL)"
        }

        guard let host = URL(string: normalizedURL)?.host(percentEncoded: false) else {
            return trimmedURL
        }

        return host
    }

    static func summaryStatusText(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus
    ) -> String {
        switch authState {
        case .signedOut:
            "Signed Out"
        case .signingIn:
            "Signing In"
        case .refreshing:
            "Refreshing"
        case .refreshFailed:
            "Error"
        case .accessTokenExpired:
            "Needs Sign-In"
        case .signedIn:
            switch connectionStatus {
            case .connected:
                "Connected"
            case .connecting:
                "Connecting"
            case .reconnecting:
                "Reconnecting"
            case .failed:
                "Error"
            case .disconnected:
                "Signed In"
            }
        }
    }

    static func tint(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus
    ) -> Color {
        if case .signedIn = authState,
           connectionStatus == .connected {
            return .green
        }

        switch authState {
        case .signedIn:
            return connectionTint(connectionStatus)
        case .signingIn, .refreshing, .accessTokenExpired:
            return .orange
        case .refreshFailed:
            return .red
        case .signedOut:
            return .secondary
        }
    }

    static func detailTitle(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus
    ) -> String {
        switch authState {
        case .signedOut:
            return "Signed Out"
        case .signingIn:
            return "Signing In"
        case .refreshing:
            return "Refreshing"
        case .accessTokenExpired, .refreshFailed:
            return "Needs Attention"
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Connected"
            case .connecting:
                return "Connecting"
            case .reconnecting:
                return "Reconnecting"
            case .failed:
                return "Connection Issue"
            case .disconnected:
                return "Not Connected"
            }
        }
    }

    static func detailMessage(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        serviceError: String?,
        storageError: String?
    ) -> String {
        if let storageError {
            return storageError
        }

        switch authState {
        case .signedOut:
            return "Sign in to connect Homestead to Home Assistant."
        case .signingIn:
            return "Waiting for Home Assistant authorization."
        case .refreshing:
            return "Refreshing your Home Assistant session."
        case .accessTokenExpired:
            return "Sign in again to continue using Home Assistant."
        case .refreshFailed(let message):
            return message
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Homestead is connected to Home Assistant."
            case .connecting:
                return "Homestead is connecting to Home Assistant."
            case .reconnecting:
                return "Homestead is restoring the connection."
            case .failed(let message):
                return serviceError ?? message
            case .disconnected:
                return serviceError ?? "Homestead is signed in but not currently connected."
            }
        }
    }

    private static func connectionTint(_ connectionStatus: HAConnectionStatus) -> Color {
        switch connectionStatus {
        case .connected:
            .green
        case .failed:
            .red
        case .connecting, .reconnecting:
            .orange
        case .disconnected:
            .secondary
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
    }
    .withPreviewEnvironment()
}

#Preview("Home Assistant Settings") {
    NavigationStack {
        HomeAssistantSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
