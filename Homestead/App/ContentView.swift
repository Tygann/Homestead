import SwiftUI

struct ContentView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HomesteadICloudSyncService.self) private var iCloudSyncService
    @Environment(HomesteadSetupCoordinator.self) private var setupCoordinator
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(HomesteadTabSettings.self) private var tabSettings
    @Environment(NativeNotificationService.self) private var nativeNotificationService
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("homestead.notificationSetupPromptHandled") private var hasHandledNotificationSetupPrompt = false
    @State private var presentedAppSheet: AppSheetDestination?
    @State private var isShowingNotificationSetupPrompt = false
    @State private var widgetEntityDestination: WidgetEntityDestination?

    var body: some View {
        let chrome = AppChromePresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            dataFreshness: homeAssistantService.dataFreshness,
            serviceFeedback: homeAssistantService.serviceFeedback,
            suppressTransientConnectionHealth: homeAssistantService.suppressesTransientConnectionHealth
        )
        let onboarding = HomeAssistantOnboardingPresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            hasKnownSession: homeAssistantService.hasKnownSession || homeAssistantService.hasCompletedInitialCacheLoad,
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            serviceError: homeAssistantService.lastErrorMessage,
            storageError: connectionSettings.authStorageErrorMessage
        )
        let hasSignedInSession = connectionSettings.hasServerURL && homeAssistantService.hasKnownSession
        let shouldShowICloudRestore: Bool = {
            guard case .restoreAvailable = iCloudSyncService.bootstrapState else {
                return false
            }

            return !hasSignedInSession
        }()

        Group {
            if shouldShowICloudRestore,
               case .restoreAvailable(let summary) = iCloudSyncService.bootstrapState {
                ICloudSetupRestoreView(
                    summary: summary,
                    restore: restoreFromICloud,
                    setUpAnotherHome: setUpAnotherHome
                )
            } else if setupCoordinator.phase != .ready, !hasSignedInSession {
                LaunchContinuityView()
            } else if onboarding.shouldShow {
                HomeAssistantOnboardingView(
                    authState: homeAssistantService.authState,
                    connectionStatus: homeAssistantService.connectionStatus,
                    serviceError: homeAssistantService.lastErrorMessage,
                    storageError: connectionSettings.authStorageErrorMessage,
                    signIn: {
                        Task {
                            await homeAssistantService.signInWithHomeAssistant(settings: connectionSettings)
                        }
                    }
                )
            } else {
                mainTabs(chrome: chrome)
            }
        }
        .environment(\.openSettings, { presentedAppSheet = .settings })
        .environment(\.openAddServer, { presentedAppSheet = .addServer })
        .sheet(item: $presentedAppSheet) { destination in
            switch destination {
            case .settings:
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                presentedAppSheet = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close Settings")
                        }
                    }
            }
            .preferredColorScheme(settingsSheetColorScheme)
            case .addServer:
                NavigationStack {
                    AddHomeAssistantServerView()
                }
                .preferredColorScheme(settingsSheetColorScheme)
            }
        }
        .sheet(item: $widgetEntityDestination) { destination in
            if let entityBox = stateStore.entityBox(for: destination.entityID) {
                NavigationStack {
                    EntityDetailSheet(entityBox: entityBox)
                }
            } else {
                ContentUnavailableView(
                    "Entity Unavailable",
                    systemImage: "questionmark.circle",
                    description: Text(destination.entityID)
                )
            }
        }
        .alert("Finish Notification Setup", isPresented: $isShowingNotificationSetupPrompt) {
            Button("Not Now", role: .cancel) {
                hasHandledNotificationSetupPrompt = true
            }

            Button("Allow Notifications") {
                hasHandledNotificationSetupPrompt = true
                Task { await nativeNotificationService.requestAuthorization() }
            }
        } message: {
            Text("Homestead can show alerts sent by Home Assistant on this device.")
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                guard setupCoordinator.phase == .ready || hasSignedInSession else { return }
                homeAssistantService.applicationWillEnterForeground()
                Task { await homeAssistantService.resume(settings: connectionSettings) }
            case .background:
                homeAssistantService.applicationDidEnterBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onOpenURL { url in
            guard let reference = HomesteadWidgetDeepLink.entityReference(
                from: url,
                fallbackProfileID: connectionSettings.activeProfileID
            ) else {
                return
            }
            Task {
                if reference.profileID != connectionSettings.activeProfileID {
                    _ = await homeAssistantService.switchActiveProfile(
                        to: reference.profileID,
                        settings: connectionSettings,
                        dashboardConfiguration: dashboardConfiguration
                    )
                }
                widgetEntityDestination = WidgetEntityDestination(entityID: reference.entityID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homesteadNotificationDestination)) { notification in
            guard let profileString = notification.userInfo?["profile_id"] as? String,
                  let profileID = UUID(uuidString: profileString) else { return }
            let entityID = notification.userInfo?["entity_id"] as? String
            Task {
                if profileID != connectionSettings.activeProfileID {
                    _ = await homeAssistantService.switchActiveProfile(
                        to: profileID,
                        settings: connectionSettings,
                        dashboardConfiguration: dashboardConfiguration
                    )
                }
                if let entityID { widgetEntityDestination = WidgetEntityDestination(entityID: entityID) }
            }
        }
        .onChange(of: homeAssistantService.serviceFeedback?.id) { _, _ in
            playServiceFeedbackHaptic()
        }
        .onChange(of: notificationSetupPromptEvaluationID) { _, _ in
            presentNotificationSetupPromptIfNeeded()
        }
        .onChange(of: nativeNotificationService.remoteRegistrationState) { _, state in
            guard state.isRegistered else { return }
            Task {
                await homeAssistantService.refreshMobileAppPushRegistrationIfNeeded(settings: connectionSettings)
            }
        }
        .task(id: notificationSetupRefreshTaskID) {
            await refreshNotificationSetupStatusIfNeeded()
        }
        .task(id: homeAssistantService.serviceFeedback?.id) {
            guard let feedback = homeAssistantService.serviceFeedback else {
                return
            }

            try? await Task.sleep(for: feedback.displayDuration)
            homeAssistantService.clearServiceFeedback(id: feedback.id)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: chrome.statusAccessoryState)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            if homeAssistantService.isSwitchingServer {
                ServerSwitchingOverlay(serverName: connectionSettings.activeProfile.resolvedDisplayName)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(!homeAssistantService.isSwitchingServer)
    }

    private func restoreFromICloud() {
        Task {
            await setupCoordinator.restoreAndSignIn(
                iCloud: iCloudSyncService,
                connectionSettings: connectionSettings,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings,
                homeAssistantService: homeAssistantService
            )
        }
    }

    private var settingsSheetColorScheme: ColorScheme {
        switch appearanceSettings.appearanceMode {
        case .system:
            systemColorScheme
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    private func setUpAnotherHome() {
        Task {
            await setupCoordinator.setUpAnotherHome(
                iCloud: iCloudSyncService,
                connectionSettings: connectionSettings,
                homeAssistantService: homeAssistantService
            )
        }
    }

    private func mainTabs(chrome: AppChromePresentation) -> some View {
        TabView {
            if tabSettings.primaryTab == .home {
                Tab("Home", systemImage: "house.fill") {
                    tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                        DashboardView()
                    }
                }

                Tab("Areas", systemImage: "square.split.bottomrightquarter") {
                    tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                        AreasView()
                    }
                }
            } else {
                Tab("Areas", systemImage: "square.split.bottomrightquarter") {
                    tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                        AreasView()
                    }
                }

                Tab("Home", systemImage: "house.fill") {
                    tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                        DashboardView()
                    }
                }
            }

            if #available(iOS 27.0, *) {
                Tab("Browse", systemImage: "magnifyingglass", role: .prominent) {
                    tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                        DevicesView()
                    }
                }
            } else {
                Tab("Browse", systemImage: "magnifyingglass", role: .search) {
                    tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                        DevicesView()
                    }
                }
            }
        }
        .id(connectionSettings.activeProfileID)
    }

    private func tabContent<Content: View>(
        statusAccessoryState: AppStatusAccessoryState?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
        }
        .safeAreaInset(edge: .bottom, spacing: AppSpacing.small) {
            if let statusAccessoryState {
                AppStatusAccessory(state: statusAccessoryState) {
                    Task {
                        await homeAssistantService.refreshOrReconnect(settings: connectionSettings)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.bottom, AppSpacing.small)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func playServiceFeedbackHaptic() {
        guard let feedback = homeAssistantService.serviceFeedback else {
            return
        }

        HapticFeedback.notification(for: feedback.style)
    }

    private var notificationSetupPromptEvaluationID: String {
        let onboarding = HomeAssistantOnboardingPresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            serviceError: homeAssistantService.lastErrorMessage,
            storageError: connectionSettings.authStorageErrorMessage
        )

        return [
            connectionSettings.hasServerURL.description,
            homeAssistantService.authState.title,
            mobileAppRegistrationPromptID,
            nativeNotificationService.status.authorizationStatus.promptID,
            hasHandledNotificationSetupPrompt.description,
            (presentedAppSheet != nil).description,
            onboarding.shouldShow.description
        ].joined(separator: "|")
    }

    private var notificationSetupRefreshTaskID: String {
        [
            connectionSettings.hasServerURL.description,
            homeAssistantService.authState.title,
            mobileAppRegistrationPromptID,
            nativeNotificationService.status.authorizationStatus.promptID,
            hasHandledNotificationSetupPrompt.description
        ].joined(separator: "|")
    }

    private var mobileAppRegistrationPromptID: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            "unregistered"
        case .registering:
            "registering"
        case .registered(let summary):
            "registered-\(summary.registeredAt.timeIntervalSince1970)"
        case .failed(let message):
            "failed-\(message)"
        }
    }

    private func refreshNotificationSetupStatusIfNeeded() async {
        guard CompanionNotificationSetupPromptPresentation.shouldRefreshNotificationStatus(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            mobileAppRegistrationState: homeAssistantService.mobileAppRegistrationState,
            notificationStatus: nativeNotificationService.status.authorizationStatus,
            hasHandledPrompt: hasHandledNotificationSetupPrompt
        ) else {
            presentNotificationSetupPromptIfNeeded()
            return
        }

        await nativeNotificationService.refreshAuthorizationStatus()
        presentNotificationSetupPromptIfNeeded()
    }

    private func presentNotificationSetupPromptIfNeeded() {
        let onboarding = HomeAssistantOnboardingPresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            serviceError: homeAssistantService.lastErrorMessage,
            storageError: connectionSettings.authStorageErrorMessage
        )

        guard CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            mobileAppRegistrationState: homeAssistantService.mobileAppRegistrationState,
            notificationStatus: nativeNotificationService.status.authorizationStatus,
            hasHandledPrompt: hasHandledNotificationSetupPrompt,
            isShowingSettings: presentedAppSheet != nil || onboarding.shouldShow
        ) else {
            return
        }

        isShowingNotificationSetupPrompt = true
    }

}

private enum AppSheetDestination: String, Identifiable {
    case settings
    case addServer

    var id: String { rawValue }
}

private struct WidgetEntityDestination: Identifiable {
    let entityID: String

    var id: String { entityID }
}

private extension NativeNotificationAuthorizationStatus {
    var promptID: String {
        switch self {
        case .unknown:
            "unknown"
        case .notDetermined:
            "notDetermined"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        case .provisional:
            "provisional"
        case .ephemeral:
            "ephemeral"
        }
    }
}

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct OpenAddServerKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }

    var openAddServer: () -> Void {
        get { self[OpenAddServerKey.self] }
        set { self[OpenAddServerKey.self] = newValue }
    }

}

struct SettingsAccountButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(action: openSettings) {
            HomeAssistantAvatarView()
                .frame(width: 44, height: 44)
                .padding(-6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}

private struct ServerSwitchingOverlay: View {
    let serverName: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.medium) {
                ProgressView()
                Text("Switching to \(serverName)")
                    .font(.headline)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LaunchContinuityView: View {
    var body: some View {
        Color("LaunchBackground")
            .ignoresSafeArea()
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Sample Data") {
    ContentView()
        .withPreviewEnvironment()
}

#Preview("Live Home Assistant") {
    if let dependencies = PreviewDependencies.liveHomeAssistant {
        ContentView()
            .withPreviewEnvironment(dependencies)
            .task {
                await dependencies.homeAssistantService.refreshAuthState()
                await dependencies.homeAssistantService.connectIfPossible(
                    settings: dependencies.connectionSettings
                )
            }
    } else {
        MissingLivePreviewCredentialsView()
    }
}
#endif
