import SwiftUI
import UIKit

// MARK: - Settings View
struct SettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    var body: some View {
        let peopleRecords = stateStore.presenceRecords().filter(\.isPerson)
        let visiblePeopleRecords = peopleRecords.filter {
            !$0.isCurrentUser(
                currentUserDisplayName: homeAssistantService.currentUserDisplayName,
                currentUserEntityPicturePath: homeAssistantService.currentUserEntityPicturePath
            )
        }

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
                NavigationLink {
                    PeopleSettingsView()
                } label: {
                    PeopleSettingsRow(records: visiblePeopleRecords)
                }
            }

            Section("Home Assistant") {
                NavigationLink {
                    DevicesAndServicesManagementView()
                } label: {
                    Label("Devices & Services", systemImage: "laptopcomputer.and.iphone")
                }

                NavigationLink {
                    AutomationsAndScenesManagementView()
                } label: {
                    Label("Automations & Scenes", systemImage: "sparkles")
                }

                NavigationLink {
                    UpdatesSettingsView()
                } label: {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                }

                NavigationLink {
                    LogbookSettingsView()
                } label: {
                    Label("Logbook", systemImage: "list.bullet.clipboard")
                }
            }

            Section("Homestead") {
                NavigationLink {
                    NativeNotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }

                NavigationLink {
                    ActionConfirmationSettingsView()
                } label: {
                    Label("Action Confirmations", systemImage: "hand.raised.circle")
                }

                NavigationLink {
                    SettingsFeaturePlaceholderView(
                        title: "Widgets",
                        systemImage: "rectangle.grid.2x2",
                        message: "Widget configuration will be added as Homestead expands its WidgetKit and App Intents support."
                    )
                } label: {
                    Label("Widgets", systemImage: "rectangle.grid.2x2")
                }

                NavigationLink {
                    SettingsFeaturePlaceholderView(
                        title: "Live Activities",
                        systemImage: "timer",
                        message: "Live Activity controls will be added after Homestead defines supported glanceable activity types."
                    )
                } label: {
                    Label("Live Activities", systemImage: "timer")
                }

                NavigationLink {
                    NativePermissionsSettingsView()
                } label: {
                    Label("Permissions", systemImage: "hand.raised")
                }

                NavigationLink {
                    SettingsFeaturePlaceholderView(
                        title: "iCloud Sync",
                        systemImage: "icloud",
                        message: "iCloud sync for Homestead-owned preferences and configuration metadata is not implemented yet."
                    )
                } label: {
                    Label("iCloud Sync", systemImage: "icloud")
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

private struct PeopleSettingsRow: View {
    let records: [HAPresenceRecord]

    var body: some View {
        HStack(spacing: 15) {
            PeoplePresenceAvatarStackView(records: records, size: 30, width: 60, maximumVisibleCount: records.count)

            Text("People")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Home Assistant Settings View
struct HomeAssistantSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isConfirmingSignOut = false

    var body: some View {
        Form {
            accountSection

            serverNavigationSection

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
                        isConfirmingSignOut = true
                    } label: {
                        Text("Sign Out")
                    }
                    .disabled(!canSignOut)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Account")
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

    private var serverNavigationSection: some View {
        Section {
            NavigationLink {
                HomeAssistantServerSettingsView()
            } label: {
                Label {
                    HStack(spacing: AppSpacing.medium) {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text("Server")
                                .foregroundStyle(.primary)

                            Text(serverDisplayText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(accountStatusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accountStatusTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accountStatusTint.opacity(0.12), in: Capsule())
                    }
                } icon: {
                    Image(systemName: "server.rack")
                        .foregroundStyle(Color.accentColor)
                }
            }
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
            case .connected, .preparing, .connecting, .reconnecting:
                return nil
            }
        }
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

    private var shouldShowSupport: Bool {
        connectionSettings.hasServerURL || homeAssistantService.authState.isSignedIn || homeAssistantService.hasCompletedInitialCacheLoad
    }

    private var authRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title
        ].joined(separator: "|")
    }
}

// MARK: - Home Assistant Server Settings View
private struct HomeAssistantServerSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @FocusState private var focusedField: Field?

    var body: some View {
        @Bindable var connectionSettings = connectionSettings

        Form {
            Section("Status") {
                Label {
                    HStack(spacing: AppSpacing.medium) {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text(serverDisplayText)
                                .font(.headline)

                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Circle()
                            .fill(statusTint)
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, AppSpacing.xSmall)
                } icon: {
                    Image(systemName: "server.rack")
                        .foregroundStyle(Color.accentColor)
                }
            }

            Section {
                LabeledContent("Current URL", value: configuredValue(connectionSettings.baseURL))

                TextField("Internal URL", text: $connectionSettings.internalURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("External URL", text: $connectionSettings.externalURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("Home Network", text: $connectionSettings.homeNetworkName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                LabeledContent("Active Route", value: activeRouteText)
                LabeledContent("Automatic Switching", value: automaticSwitchingText)
            } header: {
                Text("Connection Routing")
            } footer: {
                Text("Homestead chooses between saved internal and external URLs in the connection lifecycle when route metadata is available.")
            }

            Section("Session") {
                LabeledContent("Display Name", value: serverDisplayText)
                LabeledContent("Authentication", value: homeAssistantService.authState.diagnosticTitle)
                LabeledContent("WebSocket", value: homeAssistantService.connectionStatus.title)
                LabeledContent("Mobile App", value: mobileAppStatusTitle)

                if let signedInServerDisplayText {
                    LabeledContent("Signed-In Server", value: signedInServerDisplayText)
                }

                if let mobileAppStatusMessage {
                    Text(mobileAppStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("Config", value: homeAssistantService.serverConfigurationStatus.title)
                LabeledContent("Version", value: configValue(homeAssistantService.serverConfiguration?.homeAssistantVersion))
                LabeledContent("Status", value: configValue(homeAssistantService.serverConfiguration?.state))
                LabeledContent("Location", value: configValue(homeAssistantService.serverConfiguration?.locationName))
                LabeledContent("Time Zone", value: configValue(homeAssistantService.serverConfiguration?.timeZone))
                LabeledContent("Internal URL", value: configValue(homeAssistantService.serverConfiguration?.internalURL))
                LabeledContent("External URL", value: configValue(homeAssistantService.serverConfiguration?.externalURL))

                if let unitSystemSummary = homeAssistantService.serverConfiguration?.unitSystemSummary {
                    LabeledContent("Units", value: unitSystemSummary)
                }

                if let configSource = homeAssistantService.serverConfiguration?.configSource {
                    LabeledContent("Config Source", value: configSource)
                }

                if let message = homeAssistantService.serverConfigurationStatus.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Home Assistant Config")
            } footer: {
                Text("These values come from Home Assistant's official WebSocket get_config command when connected.")
            }

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
            } footer: {
                Text("Use the address you normally use to open Home Assistant.")
            }

            if shouldShowSignIn || canRetryConnection || shouldShowRegistrationAction {
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
                                await homeAssistantService.connect(settings: connectionSettings)
                            }
                        } label: {
                            Text("Retry Connection")
                        }
                        .disabled(homeAssistantService.connectionStatus == .preparing ||
                                  homeAssistantService.connectionStatus == .connecting ||
                                  homeAssistantService.connectionStatus == .reconnecting)
                        .frame(maxWidth: .infinity)
                    }

                    if shouldShowRegistrationAction {
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
                                  !homeAssistantService.authState.isSignedIn ||
                                  homeAssistantService.mobileAppRegistrationState.isRegistering)
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    if shouldShowRegistrationAction {
                        Text("Homestead normally handles mobile app registration automatically after sign-in.")
                    }
                }
            }
        }
        .navigationTitle("Server")
        .toolbarTitleDisplayMode(.inline)
        .task(id: serverRefreshTaskID) {
            await homeAssistantService.refreshAuthState()
            await homeAssistantService.refreshServerConfiguration()
        }
    }

    private var serverDisplayText: String {
        SettingsHomeAssistantStatus.serverDisplayText(connectionSettings.baseURL)
    }

    private var activeRouteText: String {
        guard let route = homeAssistantService.activeRouteSummary else {
            return "Not selected"
        }

        return "\(route.title) - \(configuredValue(route.baseURLString))"
    }

    private var automaticSwitchingText: String {
        connectionSettings.hasAutomaticRouteCandidates ? "Enabled" : "Add routes"
    }

    private var statusMessage: String {
        if hasServerMismatch {
            return "This server is different from the saved Home Assistant sign-in."
        }

        return SettingsHomeAssistantStatus.detailMessage(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            serviceError: homeAssistantService.lastErrorMessage,
            storageError: connectionSettings.authStorageErrorMessage
        )
    }

    private var statusTint: Color {
        SettingsHomeAssistantStatus.tint(
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus
        )
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
        case .connected, .preparing, .connecting, .reconnecting:
            return false
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
            return nil
        case .registering:
            return "Homestead is registering with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return message
        }
    }

    private var shouldShowRegistrationAction: Bool {
        guard homeAssistantService.authState.isSignedIn else {
            return false
        }

        if case .failed = homeAssistantService.mobileAppRegistrationState {
            return true
        }

        return false
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

    private var serverRefreshTaskID: String {
        [
            authRefreshTaskID,
            homeAssistantService.connectionStatus.title
        ].joined(separator: "|")
    }

    private func configuredValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not set" : trimmed
    }

    private func configValue(_ value: String?) -> String {
        guard let value else {
            return "Not returned"
        }

        return value
    }

    private enum Field {
        case baseURL
    }
}

// MARK: - Action Confirmation Settings View
private struct ActionConfirmationSettingsView: View {
    @Environment(ActionConfirmationSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Mode", selection: $settings.mode) {
                    ForEach(ActionConfirmationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.navigationLink)

                HStack {
                    Text("Behavior")
                    Spacer()
                    Text(settings.mode.summary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Toggle("Unlocking Locks", isOn: $settings.confirmsLockUnlocks)
                Toggle("Opening Security Covers", isOn: $settings.confirmsSecurityCoverOpens)
                Toggle("Activating Scenes", isOn: $settings.confirmsScenes)
                Toggle("Running Scripts", isOn: $settings.confirmsScripts)
                Toggle("Other Impactful Actions", isOn: $settings.confirmsOtherImpactfulActions)
            } header: {
                Text("Smart Confirmations")
            } footer: {
                Text("Smart Confirmations keeps everyday controls fast while asking before actions that may unlock, open, or trigger larger changes.")
            }
        }
        .navigationTitle("Action Confirmations")
        .toolbarTitleDisplayMode(.inline)
    }
}

// MARK: - Native Notification Settings View
private struct NativeNotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativeNotificationService.self) private var nativeNotificationService

    var body: some View {
        Form {
            Section {
                notificationStatusHeader

                if let message = nativeNotificationService.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Use iOS Settings to adjust banners, sounds, badges, lock screen visibility, and notification grouping.")
            }

            Section {
                if shouldShowAllowNotificationsAction {
                    Button {
                        Task { await nativeNotificationService.requestAuthorization() }
                    } label: {
                        Text(nativeNotificationService.isRequestingAuthorization ? "Requesting Permission" : "Allow Notifications")
                    }
                    .disabled(nativeNotificationService.isRequestingAuthorization)
                    .frame(maxWidth: .infinity)
                }

                Button {
                    openIOSNotificationSettings()
                } label: {
                    Label("Open Homestead in iOS Settings", systemImage: "gearshape")
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                homeAssistantStatusHeader

                if shouldShowMobileAppRegistrationAction {
                    Button {
                        Task { await homeAssistantService.registerMobileApp(settings: connectionSettings) }
                    } label: {
                        Text(mobileAppButtonTitle)
                    }
                    .disabled(!canRegisterMobileApp)
                    .frame(maxWidth: .infinity)
                }

            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Homestead receives Home Assistant notifications while connected to your server.")
            }

            Section {
                DisclosureGroup("Details") {
                    LabeledContent("Permission", value: permissionBadgeText)
                    LabeledContent("Alerts", value: nativeNotificationService.status.alertSetting.settingsTitle)
                    LabeledContent("Sounds", value: nativeNotificationService.status.soundSetting.settingsTitle)
                    LabeledContent("Badges", value: nativeNotificationService.status.badgeSetting.settingsTitle)
                    LabeledContent("Account", value: accountReadinessTitle)
                    LabeledContent("Mobile App", value: mobileAppReadinessTitle)
                    LabeledContent("Delivery Channel", value: homeAssistantService.mobileAppPushNotificationState.settingsTitle)

                    if let mobileAppMessage {
                        Text(mobileAppMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let pushDeliveryMessage {
                        Text(pushDeliveryMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await nativeNotificationService.refreshAuthorizationStatus()
                            homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
                        }
                    } label: {
                        Text(nativeNotificationService.isRefreshing ? "Refreshing" : "Refresh Status")
                    }
                    .disabled(nativeNotificationService.isRefreshing)
                }
            }
        }
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.inline)
        .task(id: notificationRefreshTaskID) {
            await nativeNotificationService.refreshAuthorizationStatus()
            homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
        }
    }

    private var notificationStatusHeader: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(permissionTitle)
                        .font(.headline)

                    Spacer()

                    Text(permissionBadgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(nativePermissionTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(nativePermissionTint.opacity(0.12), in: Capsule())
                }

                Text(permissionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: permissionSystemImage)
                .foregroundStyle(nativePermissionTint)
        }
    }

    private var nativePermissionTint: Color {
        nativeNotificationService.status.authorizationStatus.settingsTint
    }

    private var permissionTitle: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications Enabled"
        case .denied:
            return "Notifications Off"
        case .notDetermined:
            return "Set Up Notifications"
        case .unknown:
            return "Checking Notifications"
        }
    }

    private var permissionBadgeText: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Permission Granted"
        case .provisional:
            return "Quietly Allowed"
        case .ephemeral:
            return "Temporarily Allowed"
        case .denied:
            return "Permission Off"
        case .notDetermined:
            return "Not Set Up"
        case .unknown:
            return "Checking"
        }
    }

    private var permissionMessage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Homestead can show Home Assistant notifications on this iPhone."
        case .provisional:
            return "Homestead can deliver Home Assistant notifications quietly."
        case .ephemeral:
            return "Homestead has temporary permission to show notifications."
        case .denied:
            return "Turn on notifications in iOS Settings to receive Home Assistant alerts."
        case .notDetermined:
            return "Allow Homestead to show notifications from Home Assistant."
        case .unknown:
            return "Homestead is checking iOS notification permission."
        }
    }

    private var permissionSystemImage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined, .unknown:
            return "bell.badge"
        }
    }

    private var shouldShowAllowNotificationsAction: Bool {
        nativeNotificationService.status.authorizationStatus.canRequestInApp
    }

    private var homeAssistantStatusHeader: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(homeAssistantStatusTitle)
                        .font(.headline)

                    Spacer()

                    Text(homeAssistantStatusBadgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(homeAssistantStatusTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(homeAssistantStatusTint.opacity(0.12), in: Capsule())
                }

                Text(homeAssistantStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: "house.badge.wifi")
                .foregroundStyle(homeAssistantStatusTint)
        }
    }

    private var homeAssistantStatusTitle: String {
        if homeAssistantService.mobileAppPushNotificationState.isSubscribed,
           homeAssistantService.mobileAppRegistrationState.isRegistered,
           homeAssistantService.authState.isSignedIn,
           !hasServerMismatch {
            return "Connected and Ready"
        }

        if hasServerMismatch {
            return "Server Needs Attention"
        }

        if homeAssistantService.mobileAppPushNotificationState == .subscribing {
            return "Connecting Notifications"
        }

        switch homeAssistantService.mobileAppRegistrationState {
        case .failed:
            return "Registration Issue"
        case .unregistered:
            return "Registration Needed"
        case .registering:
            return "Registering"
        case .registered:
            return homeAssistantService.authState.isSignedIn ? "Delivery Not Connected" : "Sign In Needed"
        }
    }

    private var homeAssistantStatusBadgeText: String {
        if homeAssistantService.mobileAppPushNotificationState.isSubscribed,
           homeAssistantService.mobileAppRegistrationState.isRegistered,
           homeAssistantService.authState.isSignedIn,
           !hasServerMismatch {
            return "Ready"
        }

        switch homeAssistantService.mobileAppPushNotificationState {
        case .subscribing:
            return "Connecting"
        case .failed:
            return "Action Needed"
        case .unavailable, .subscribed:
            return "Not Ready"
        }
    }

    private var homeAssistantStatusMessage: String {
        if let homeAssistantSetupMessage {
            return homeAssistantSetupMessage
        }

        return "Home Assistant notifications are ready for this device."
    }

    private var homeAssistantStatusTint: Color {
        if homeAssistantService.mobileAppPushNotificationState.isSubscribed,
           homeAssistantService.mobileAppRegistrationState.isRegistered,
           homeAssistantService.authState.isSignedIn,
           !hasServerMismatch {
            return .green
        }

        switch homeAssistantService.mobileAppPushNotificationState {
        case .failed:
            return .red
        case .subscribing:
            return .orange
        case .unavailable, .subscribed:
            return .secondary
        }
    }

    private var homeAssistantSetupMessage: String? {
        if hasServerMismatch {
            return "Sign in again for the selected Home Assistant server."
        }

        guard homeAssistantService.authState.isSignedIn else {
            return "Sign in with Home Assistant before receiving notifications."
        }

        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Register Homestead with Home Assistant to receive notifications."
        case .registering:
            return "Homestead is registering this device with Home Assistant."
        case .failed(let message):
            return message
        case .registered:
            break
        }

        switch homeAssistantService.mobileAppPushNotificationState {
        case .unavailable:
            return "Connect to Home Assistant to start notification delivery."
        case .subscribing:
            return "Homestead is opening the Home Assistant notification channel."
        case .subscribed:
            return nil
        case .failed(let message):
            return message
        }
    }

    private var accountReadinessTitle: String {
        if hasServerMismatch {
            return "Server mismatch"
        }

        guard connectionSettings.hasServerURL else {
            return "Server needed"
        }

        switch homeAssistantService.authState {
        case .signedIn:
            return "Signed in"
        case .signingIn, .refreshing:
            return "Checking"
        case .accessTokenExpired, .refreshFailed:
            return "Needs sign-in"
        case .signedOut:
            return "Signed out"
        }
    }

    private var mobileAppReadinessTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            return "Not registered"
        case .registering:
            return "Registering"
        case .registered:
            return "Ready"
        case .failed:
            return "Needs attention"
        }
    }

    private var mobileAppMessage: String? {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            guard homeAssistantService.authState.isSignedIn else {
                return "Sign in with Home Assistant before registering Homestead as a mobile app."
            }
            return "Register Homestead with this Home Assistant server before notification delivery can be enabled."
        case .registering:
            return "Homestead is registering with Home Assistant."
        case .registered(let summary):
            let date = summary.registeredAt.formatted(date: .abbreviated, time: .shortened)
            return "Registered as \(summary.deviceName) on \(date)."
        case .failed(let message):
            return message
        }
    }

    private var pushDeliveryMessage: String? {
        switch homeAssistantService.mobileAppPushNotificationState {
        case .unavailable:
            return "Connect to Home Assistant to start notification delivery."
        case .subscribing:
            return "Homestead is opening Home Assistant's mobile-app notification channel."
        case .subscribed(let date):
            return "Ready since \(date.formatted(date: .abbreviated, time: .shortened))."
        case .failed(let message):
            return message
        }
    }

    private var shouldShowMobileAppRegistrationAction: Bool {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered, .failed:
            return true
        case .registering, .registered:
            return false
        }
    }

    private var canRegisterMobileApp: Bool {
        connectionSettings.hasServerURL &&
            !hasServerMismatch &&
            homeAssistantService.authState.isSignedIn &&
            !homeAssistantService.mobileAppRegistrationState.isRegistering
    }

    private var mobileAppButtonTitle: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .registering:
            return "Registering"
        case .registered:
            return "Register Again"
        case .unregistered, .failed:
            return "Register Mobile App"
        }
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

    private var notificationRefreshTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.mobileAppRegistrationState.settingsTaskID
        ].joined(separator: "|")
    }

    private func openIOSNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }
}

// MARK: - Native Permissions Settings View
private struct NativePermissionsSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(NativeNotificationService.self) private var nativeNotificationService
    @Environment(NativePermissionService.self) private var nativePermissionService

    var body: some View {
        Form {
            Section {
                NativePermissionStatusRow(
                    title: "Notifications",
                    message: notificationMessage,
                    badgeText: notificationBadgeText,
                    systemImage: notificationSystemImage,
                    tint: nativeNotificationService.status.authorizationStatus.permissionTint
                )

                NativePermissionStatusRow(
                    title: "Local Network",
                    message: "Needed for Home Assistant servers on your home network.",
                    badgeText: nativePermissionService.status.localNetwork.permissionBadgeText,
                    systemImage: "network",
                    tint: nativePermissionService.status.localNetwork.permissionTint
                )

                NativePermissionStatusRow(
                    title: "Location",
                    message: locationMessage,
                    badgeText: nativePermissionService.status.location.permissionBadgeText,
                    systemImage: "location.fill",
                    tint: nativePermissionService.status.location.permissionTint
                )

                NativePermissionStatusRow(
                    title: "Camera",
                    message: cameraMessage,
                    badgeText: nativePermissionService.status.camera.permissionBadgeText,
                    systemImage: "camera.fill",
                    tint: nativePermissionService.status.camera.permissionTint
                )

                if let message = nativePermissionService.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("iOS controls permission decisions. Homestead only requests access when a native feature needs it.")
            }

            if showsPermissionActions {
                Section {
                    if nativePermissionService.status.location.canRequestInApp {
                        Button {
                            Task { await nativePermissionService.requestLocationAccess() }
                        } label: {
                            Label(
                                nativePermissionService.isRequestingLocationAccess ? "Requesting Location" : "Allow Location",
                                systemImage: "location.fill"
                            )
                        }
                        .disabled(nativePermissionService.isRequestingLocationAccess)
                    }

                    if nativePermissionService.status.camera.canRequestInApp {
                        Button {
                            Task { await nativePermissionService.requestCameraAccess() }
                        } label: {
                            Label(
                                nativePermissionService.isRequestingCameraAccess ? "Requesting Camera" : "Allow Camera",
                                systemImage: "camera.fill"
                            )
                        }
                        .disabled(nativePermissionService.isRequestingCameraAccess)
                    }
                }
            }

            Section {
                NavigationLink {
                    NativeNotificationSettingsView()
                } label: {
                    Label("Notification Settings", systemImage: "bell.badge")
                }

                Button {
                    openIOSSettings()
                } label: {
                    Label("Open Homestead in iOS Settings", systemImage: "gearshape")
                }

                Button {
                    Task {
                        await nativeNotificationService.refreshAuthorizationStatus()
                        await nativePermissionService.refreshStatus()
                    }
                } label: {
                    Label(refreshButtonTitle, systemImage: "arrow.clockwise")
                }
                .disabled(nativeNotificationService.isRefreshing || nativePermissionService.isRefreshing)
            }
        }
        .navigationTitle("Permissions")
        .toolbarTitleDisplayMode(.inline)
        .task {
            await nativeNotificationService.refreshAuthorizationStatus()
            await nativePermissionService.refreshStatus()
        }
    }

    private var showsPermissionActions: Bool {
        nativePermissionService.status.location.canRequestInApp ||
            nativePermissionService.status.camera.canRequestInApp
    }

    private var refreshButtonTitle: String {
        nativeNotificationService.isRefreshing || nativePermissionService.isRefreshing ? "Refreshing" : "Refresh Status"
    }

    private var notificationBadgeText: String {
        nativeNotificationService.status.authorizationStatus.permissionBadgeText
    }

    private var notificationSystemImage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined, .unknown:
            return "bell.badge"
        }
    }

    private var notificationMessage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Home Assistant alerts can appear on this iPhone."
        case .provisional:
            return "Home Assistant alerts can be delivered quietly."
        case .ephemeral:
            return "Notification access is temporarily allowed."
        case .denied:
            return "Turn on notifications in iOS Settings."
        case .notDetermined:
            return "Set up alerts from Notification Settings."
        case .unknown:
            return "Homestead is checking notification access."
        }
    }

    private var locationMessage: String {
        switch nativePermissionService.status.location {
        case .allowed:
            return "Ready for presence features that use this iPhone."
        case .limited:
            return "Location access is limited."
        case .denied:
            return "Turn on location in iOS Settings."
        case .restricted:
            return "Location access is restricted on this device."
        case .notDetermined:
            return "Allow when a presence feature needs this iPhone's location."
        case .unavailable:
            return "Location Services are off or unavailable."
        case .managedBySystem:
            return "Managed by iOS."
        case .unknown:
            return "Homestead is checking location access."
        }
    }

    private var cameraMessage: String {
        switch nativePermissionService.status.camera {
        case .allowed:
            return "Ready for camera-based setup and scanning features."
        case .limited:
            return "Camera access is limited."
        case .denied:
            return "Turn on camera access in iOS Settings."
        case .restricted:
            return "Camera access is restricted on this device."
        case .notDetermined:
            return "Allow when a native setup feature needs the camera."
        case .unavailable:
            return "Camera access is unavailable on this device."
        case .managedBySystem:
            return "Managed by iOS."
        case .unknown:
            return "Homestead is checking camera access."
        }
    }

    private func openIOSSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }
}

private struct NativePermissionStatusRow: View {
    let title: String
    let message: String
    let badgeText: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.small)

                Text(badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

private extension NativeNotificationAuthorizationStatus {
    var permissionBadgeText: String {
        switch self {
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Quiet"
        case .ephemeral:
            return "Temporary"
        case .denied:
            return "Off"
        case .notDetermined:
            return "Ask"
        case .unknown:
            return "Checking"
        }
    }

    var permissionTint: Color {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined, .unknown:
            return .secondary
        }
    }
}

private extension NativeCapabilityAuthorizationStatus {
    var permissionBadgeText: String {
        switch self {
        case .allowed:
            return "Allowed"
        case .limited:
            return "Limited"
        case .denied:
            return "Off"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Ask"
        case .unavailable:
            return "Unavailable"
        case .managedBySystem:
            return "iOS"
        case .unknown:
            return "Checking"
        }
    }

    var permissionTint: Color {
        switch self {
        case .allowed, .limited:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined, .unknown, .unavailable, .managedBySystem:
            return .secondary
        }
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

// MARK: - Devices and Services Management
private struct DevicesAndServicesManagementView: View {
    var body: some View {
        Form {
            Section {
                ForEach(DevicesAndServicesSection.allCases) { section in
                    NavigationLink {
                        destination(for: section)
                    } label: {
                        SettingsManagementOverviewRow(
                            title: section.title,
                            subtitle: section.subtitle,
                            systemImage: section.systemImage
                        )
                    }
                }
            } footer: {
                Text("Registry views use Home Assistant data already available to Homestead. Unsupported management categories are placeholders until official API support is added.")
            }
        }
        .navigationTitle("Devices & Services")
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for section: DevicesAndServicesSection) -> some View {
        switch section {
        case .integrations:
            SettingsManagementPlaceholderView(
                title: section.title,
                systemImage: section.systemImage,
                message: "Native integration details are not available in Homestead yet."
            )
        case .devices:
            DeviceRegistryManagementList()
        case .entities:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Entities",
                emptySystemImage: section.systemImage
            )
        case .helpers:
            SettingsManagementPlaceholderView(
                title: section.title,
                systemImage: section.systemImage,
                message: "Native helper management will be added after Homestead supports the right Home Assistant APIs."
            )
        }
    }
}

private enum DevicesAndServicesSection: CaseIterable, Identifiable {
    case integrations
    case devices
    case entities
    case helpers

    var id: Self { self }

    var title: String {
        switch self {
        case .integrations:
            "Integrations"
        case .devices:
            "Devices"
        case .entities:
            "Entities"
        case .helpers:
            "Helpers"
        }
    }

    var subtitle: String {
        switch self {
        case .integrations:
            "Installed integrations and setup details"
        case .devices:
            "Registered hardware, bridges, and entity counts"
        case .entities:
            "Entity registry, status, area, and device details"
        case .helpers:
            "Home Assistant helper management"
        }
    }

    var systemImage: String {
        switch self {
        case .integrations:
            "puzzlepiece.extension"
        case .devices:
            "laptopcomputer.and.iphone"
        case .entities:
            "square.grid.2x2"
        case .helpers:
            "wrench.and.screwdriver"
        }
    }
}

private struct DeviceRegistryManagementList: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""
    @State private var grouping: DeviceManagementGrouping = .name

    var body: some View {
        let devices = stateStore.deviceManagementSummaries()
        let presentation = DeviceManagementPresentation.make(
            devices: devices,
            searchText: searchText,
            grouping: grouping
        )

        List {
            ForEach(presentation.groups) { group in
                if grouping == .name || presentation.groups.count == 1 {
                    Section {
                        deviceRows(group.devices)
                    }
                } else {
                    Section(group.title) {
                        deviceRows(group.devices)
                    }
                }
            }
        }
        .overlay {
            if devices.isEmpty {
                ContentUnavailableView("No Devices", systemImage: "laptopcomputer.and.iphone")
            } else if presentation.groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("Devices")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !devices.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    groupingMenu
                }
            }
        }
    }

    @ViewBuilder
    private func deviceRows(_ devices: [HADeviceManagementSummary]) -> some View {
        ForEach(devices) { device in
            Label {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(device.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(device.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(entityCountText(for: device.entityCount))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, AppSpacing.xSmall)
            } icon: {
                Image(systemName: "laptopcomputer.and.iphone")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(DeviceManagementGrouping.allCases) { option in
                Button {
                    grouping = option
                } label: {
                    Label(option.title, systemImage: grouping == option ? "checkmark" : option.systemImage)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Group devices")
    }

    private func entityCountText(for count: Int) -> String {
        count == 1 ? "1 entity" : "\(count) entities"
    }
}

private enum DeviceManagementGrouping: CaseIterable, Identifiable {
    case name
    case area
    case manufacturer

    var id: Self { self }

    var title: String {
        switch self {
        case .name:
            "Name"
        case .area:
            "Area"
        case .manufacturer:
            "Manufacturer"
        }
    }

    var systemImage: String {
        switch self {
        case .name:
            "textformat"
        case .area:
            "square.grid.3x3"
        case .manufacturer:
            "building.2"
        }
    }
}

private struct DeviceManagementPresentation {
    struct Group: Identifiable {
        let id: String
        let title: String
        let devices: [HADeviceManagementSummary]
    }

    let groups: [Group]

    static func make(
        devices: [HADeviceManagementSummary],
        searchText: String,
        grouping: DeviceManagementGrouping
    ) -> DeviceManagementPresentation {
        let matchingDevices = devices.filter { $0.matches(query: searchText) }

        switch grouping {
        case .name:
            return DeviceManagementPresentation(groups: [
                Group(id: "name", title: "Devices", devices: matchingDevices)
            ].filter { !$0.devices.isEmpty })
        case .area:
            return DeviceManagementPresentation(
                groups: groupedDevices(
                    matchingDevices,
                    key: { $0.areaName ?? "No Area" },
                    fallbackID: "no-area"
                )
            )
        case .manufacturer:
            return DeviceManagementPresentation(
                groups: groupedDevices(
                    matchingDevices,
                    key: { $0.manufacturer ?? "Unknown Manufacturer" },
                    fallbackID: "unknown-manufacturer"
                )
            )
        }
    }

    private static func groupedDevices(
        _ devices: [HADeviceManagementSummary],
        key: (HADeviceManagementSummary) -> String,
        fallbackID: String
    ) -> [Group] {
        Dictionary(grouping: devices, by: key)
            .map { title, devices in
                Group(
                    id: title == "No Area" || title == "Unknown Manufacturer" ? fallbackID : title,
                    title: title,
                    devices: devices.sortedByDeviceTitle
                )
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
}

private extension Array where Element == HADeviceManagementSummary {
    var sortedByDeviceTitle: [HADeviceManagementSummary] {
        sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

// MARK: - Automations and Scenes Management
private struct AutomationsAndScenesManagementView: View {
    var body: some View {
        Form {
            Section {
                ForEach(AutomationsAndScenesSection.allCases) { section in
                    NavigationLink {
                        destination(for: section)
                    } label: {
                        SettingsManagementOverviewRow(
                            title: section.title,
                            subtitle: section.subtitle,
                            systemImage: section.systemImage
                        )
                    }
                }
            } footer: {
                Text("Automations, scenes, and scripts use entity data already available to Homestead. Blueprint browsing is a placeholder until official API support is added.")
            }
        }
        .navigationTitle("Automations & Scenes")
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for section: AutomationsAndScenesSection) -> some View {
        switch section {
        case .automations:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Automations",
                emptySystemImage: section.systemImage,
                allowedDomains: [.automation]
            )
        case .scenes:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Scenes",
                emptySystemImage: section.systemImage,
                allowedDomains: [.scene]
            )
        case .scripts:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Scripts",
                emptySystemImage: section.systemImage,
                allowedDomains: [.script]
            )
        case .blueprints:
            SettingsManagementPlaceholderView(
                title: section.title,
                systemImage: section.systemImage,
                message: "Native blueprint browsing will be added after Homestead supports an official Home Assistant API for it."
            )
        }
    }
}

private enum AutomationsAndScenesSection: CaseIterable, Identifiable {
    case automations
    case scenes
    case scripts
    case blueprints

    var id: Self { self }

    var title: String {
        switch self {
        case .automations:
            "Automations"
        case .scenes:
            "Scenes"
        case .scripts:
            "Scripts"
        case .blueprints:
            "Blueprints"
        }
    }

    var subtitle: String {
        switch self {
        case .automations:
            "Rules and triggers exposed as Home Assistant entities"
        case .scenes:
            "Scene entities available for native activation"
        case .scripts:
            "Script entities available for native runs"
        case .blueprints:
            "Reusable automation and script templates"
        }
    }

    var systemImage: String {
        switch self {
        case .automations:
            EntityDomain.automation.systemImage
        case .scenes:
            EntityDomain.scene.systemImage
        case .scripts:
            EntityDomain.script.systemImage
        case .blueprints:
            "doc.badge.gearshape"
        }
    }
}

private struct EntityRegistryManagementBrowser: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var selectedEntity: SettingsSelectedEntity?

    let title: String
    let emptyTitle: String
    let emptySystemImage: String
    var allowedDomains: Set<EntityDomain>?

    var body: some View {
        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            includesUnavailableByDefault: true,
            showsGroupingMenu: allowedDomains == nil,
            showsSingleGroupHeaders: false,
            allowedDomains: allowedDomains,
            initialGrouping: allowedDomains == nil ? .device : .type,
            rowAction: { entityBox in
                selectedEntity = SettingsSelectedEntity(entityID: entityBox.entityID)
            },
            allowsDashboardMembershipEditing: false,
            rowDetail: { entityBox in
                stateStore.entityRegistryAdminDetail(for: entityBox.entityID)
            },
            accessory: { entityBox in
                EntityRegistryStatusAccessory(entityBox: entityBox)
            }
        )
        .sheet(item: $selectedEntity) { selectedEntity in
            if let entityBox = stateStore.entityBox(for: selectedEntity.entityID) {
                NavigationStack {
                    EntityDiagnosticsView(entityBox: entityBox)
                }
            }
        }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct EntityRegistryStatusAccessory: View {
    let entityBox: HAEntityState

    var body: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entityBox.homeEntity.isAvailable ? .secondary : Color.red)
            .lineLimit(1)
            .frame(width: 88, alignment: .trailing)
    }

    private var statusText: String {
        guard entityBox.homeEntity.isAvailable else {
            return "Unavailable"
        }

        return entityBox.homeEntity.domain.displayName
    }
}

private struct SettingsManagementOverviewRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}

private struct SettingsFeaturePlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        SettingsManagementPlaceholderView(
            title: title,
            systemImage: systemImage,
            message: message
        )
    }
}

private struct SettingsManagementPlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct SettingsSelectedEntity: Identifiable {
    let entityID: String

    var id: String { entityID }
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

private extension NativeNotificationAuthorizationStatus {
    var settingsTitle: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .notDetermined:
            return "Not Set Up"
        case .denied:
            return "Off"
        case .authorized:
            return "On"
        case .provisional:
            return "Quietly Allowed"
        case .ephemeral:
            return "Temporarily Allowed"
        }
    }

    var settingsMessage: String {
        switch self {
        case .unknown:
            return "Homestead has not checked iOS notification permission yet."
        case .notDetermined:
            return "Allow notifications before Home Assistant notification delivery is enabled."
        case .denied:
            return "Notifications are turned off for Homestead in iOS Settings."
        case .authorized:
            return "iOS allows Homestead to show notifications on this device."
        case .provisional:
            return "iOS allows Homestead to deliver notifications quietly."
        case .ephemeral:
            return "iOS has granted temporary notification permission."
        }
    }

    var settingsTint: Color {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .notDetermined, .unknown:
            return .orange
        case .denied:
            return .red
        }
    }
}

private extension NativeNotificationDeliverySetting {
    var settingsTitle: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .unavailable:
            return "Unavailable"
        case .disabled:
            return "Off"
        case .enabled:
            return "On"
        }
    }
}

private extension HAMobileAppPushNotificationState {
    var settingsTitle: String {
        switch self {
        case .unavailable:
            return "Not connected"
        case .subscribing:
            return "Connecting"
        case .subscribed:
            return "Ready"
        case .failed:
            return "Needs attention"
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

    var settingsTaskID: String {
        switch self {
        case .unregistered:
            return "unregistered"
        case .registering:
            return "registering"
        case .registered(let summary):
            return "registered-\(summary.deviceName)-\(summary.registeredAt.timeIntervalSince1970)"
        case .failed(let message):
            return "failed-\(message)"
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
//                    .font(.headline)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                
                Text(server)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
//            .fontDesign(.rounded)
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
struct HomeAssistantAvatarView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray)
            }
        }
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

        guard let uiImage = await HomeAssistantImageCache.shared.image(for: request) else {
            image = nil
            return
        }

        image = Image(uiImage: uiImage)
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
            case .preparing, .connecting:
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
            case .preparing, .connecting:
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
            case .preparing, .connecting:
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
        case .preparing, .connecting, .reconnecting:
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

#Preview("Account Settings") {
    NavigationStack {
        HomeAssistantSettingsView()
    }
    .withPreviewEnvironment()
}

#Preview("Notification Settings") {
    NavigationStack {
        NativeNotificationSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
