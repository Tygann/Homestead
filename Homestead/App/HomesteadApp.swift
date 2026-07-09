import SwiftUI
import UIKit
import UserNotifications

@main
struct HomesteadApp: App {
    @UIApplicationDelegateAdaptor(HomesteadAppDelegate.self) private var appDelegate
    @State private var stateStore: HAStateStore
    @State private var connectionSettings: HAConnectionSettings
    @State private var homeAssistantService: HomeAssistantService
    @State private var nativeNotificationService: NativeNotificationService
    @State private var nativePermissionService: NativePermissionService
    @State private var dashboardConfiguration: DashboardConfiguration
    @State private var actionConfirmationSettings: ActionConfirmationSettings
    @State private var appearanceSettings: HomesteadAppearanceSettings
    @State private var tabSettings: HomesteadTabSettings
    @State private var iCloudSyncService: HomesteadICloudSyncService
    @State private var setupCoordinator: HomesteadSetupCoordinator
    private let usesLivePreviewLaunch: Bool
    private let previewScreen: HomesteadPreviewScreen?

    init() {
#if DEBUG
        if let previewScreen = RuntimeEnvironment.previewScreen {
            let dependencies = PreviewDependencies.sample
            HomesteadAppDelegate.nativeNotificationService = dependencies.nativeNotificationService
            _stateStore = State(initialValue: dependencies.stateStore)
            _connectionSettings = State(initialValue: dependencies.connectionSettings)
            _homeAssistantService = State(initialValue: dependencies.homeAssistantService)
            _nativeNotificationService = State(initialValue: dependencies.nativeNotificationService)
            _nativePermissionService = State(initialValue: dependencies.nativePermissionService)
            _dashboardConfiguration = State(initialValue: dependencies.dashboardConfiguration)
            _actionConfirmationSettings = State(initialValue: dependencies.actionConfirmationSettings)
            _appearanceSettings = State(initialValue: dependencies.appearanceSettings)
            _tabSettings = State(initialValue: dependencies.tabSettings)
            _iCloudSyncService = State(initialValue: dependencies.iCloudSyncService)
            _setupCoordinator = State(initialValue: HomesteadSetupCoordinator(initialPhase: .ready))
            usesLivePreviewLaunch = false
            self.previewScreen = previewScreen
            return
        }

        if RuntimeEnvironment.isLivePreviewLaunch,
           let dependencies = PreviewDependencies.liveHomeAssistant {
            if let appearanceMode = RuntimeEnvironment.livePreviewAppearanceMode {
                dependencies.appearanceSettings.appearanceMode = appearanceMode
            }
            HomesteadAppDelegate.nativeNotificationService = dependencies.nativeNotificationService
            _stateStore = State(initialValue: dependencies.stateStore)
            _connectionSettings = State(initialValue: dependencies.connectionSettings)
            _homeAssistantService = State(initialValue: dependencies.homeAssistantService)
            _nativeNotificationService = State(initialValue: dependencies.nativeNotificationService)
            _nativePermissionService = State(initialValue: dependencies.nativePermissionService)
            _dashboardConfiguration = State(initialValue: dependencies.dashboardConfiguration)
            _actionConfirmationSettings = State(initialValue: dependencies.actionConfirmationSettings)
            _appearanceSettings = State(initialValue: dependencies.appearanceSettings)
            _tabSettings = State(initialValue: dependencies.tabSettings)
            _iCloudSyncService = State(initialValue: dependencies.iCloudSyncService)
            _setupCoordinator = State(initialValue: HomesteadSetupCoordinator(initialPhase: .ready))
            usesLivePreviewLaunch = true
            previewScreen = nil
            return
        }
#endif

        let tokenStore = KeychainHAOAuthTokenStore()
        let stateStore = HAStateStore()
        let connectionSettings = HAConnectionSettings(tokenStore: tokenStore)
        let nativeNotificationService = NativeNotificationService()
        HomesteadAppDelegate.nativeNotificationService = nativeNotificationService
        let nativePermissionService = NativePermissionService()
        let actionConfirmationSettings = ActionConfirmationSettings()
        let appearanceSettings = HomesteadAppearanceSettings()
        let tabSettings = HomesteadTabSettings()
        let dashboardConfiguration = DashboardConfiguration()
        let iCloudSyncService = HomesteadICloudSyncService()
        let setupCoordinator = HomesteadSetupCoordinator()
        let homeAssistantService = HomeAssistantService(
            stateStore: stateStore,
            authState: HAOAuthManager.status(tokenStore: tokenStore),
            nativeNotificationService: nativeNotificationService,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )
        if connectionSettings.hasServerURL, homeAssistantService.hasKnownSession {
            homeAssistantService.restoreCachedStatesSynchronouslyIfPossible(
                settings: connectionSettings,
                tokenStore: tokenStore
            )
            if stateStore.hasEntities {
                dashboardConfiguration.reconcile(with: stateStore.allEntityBoxes())
            }
            if !stateStore.hasLoadedInitialSnapshot {
                Task { @MainActor in
                    await homeAssistantService.loadCachedStatesIfPossible(settings: connectionSettings)
                }
            }
        }

        _stateStore = State(initialValue: stateStore)
        _connectionSettings = State(initialValue: connectionSettings)
        _homeAssistantService = State(initialValue: homeAssistantService)
        _nativeNotificationService = State(initialValue: nativeNotificationService)
        _nativePermissionService = State(initialValue: nativePermissionService)
        _dashboardConfiguration = State(initialValue: dashboardConfiguration)
        _actionConfirmationSettings = State(initialValue: actionConfirmationSettings)
        _appearanceSettings = State(initialValue: appearanceSettings)
        _tabSettings = State(initialValue: tabSettings)
        _iCloudSyncService = State(initialValue: iCloudSyncService)
        _setupCoordinator = State(initialValue: setupCoordinator)
        usesLivePreviewLaunch = false
        previewScreen = nil
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(stateStore)
                .environment(connectionSettings)
                .environment(homeAssistantService)
                .environment(nativeNotificationService)
                .environment(nativePermissionService)
                .environment(dashboardConfiguration)
                .environment(actionConfirmationSettings)
                .environment(appearanceSettings)
                .environment(tabSettings)
                .environment(iCloudSyncService)
                .environment(setupCoordinator)
                .environment(setupCoordinator.discoveryService)
                .accentColor(Color(appearanceSettings.appColor.uiColor))
                .preferredColorScheme(appearanceSettings.appearanceMode.colorScheme)
                .task {
#if DEBUG
                    if previewScreen != nil {
                        return
                    }

                    if usesLivePreviewLaunch {
                        await homeAssistantService.refreshAuthState()
                        await homeAssistantService.connectIfPossible(settings: connectionSettings)
                        focusLivePreviewDashboardIfRequested()
                        return
                    }
#endif

                    guard !RuntimeEnvironment.isRunningForPreviews else { return }
                    await setupCoordinator.start(
                        iCloud: iCloudSyncService,
                        connectionSettings: connectionSettings,
                        dashboardConfiguration: dashboardConfiguration,
                        actionConfirmationSettings: actionConfirmationSettings,
                        appearanceSettings: appearanceSettings,
                        homeAssistantService: homeAssistantService
                    )
                    await nativeNotificationService.refreshAuthorizationStatus()
                    await nativeNotificationService.registerForRemoteNotificationsIfAllowed()
                }
                .onChange(of: connectionSettings.syncSnapshot) { _, _ in
                    syncPreferencesToICloud(.connection)
                }
                .onChange(of: dashboardConfiguration.syncSnapshot) { _, _ in
                    syncPreferencesToICloud(.dashboard)
                }
                .onChange(of: actionConfirmationSettings.syncSnapshot) { _, _ in
                    syncPreferencesToICloud(.actionConfirmations)
                }
                .onChange(of: appearanceSettings.syncSnapshot) { _, _ in
                    syncPreferencesToICloud(.appearance)
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if let previewScreen {
            previewScreenView(previewScreen)
        } else {
            ContentView()
        }
#else
        ContentView()
#endif
    }

#if DEBUG
    @ViewBuilder
    private func previewScreenView(_ previewScreen: HomesteadPreviewScreen) -> some View {
        switch previewScreen {
        case .appearance:
            NavigationStack {
                AppearanceSettingsView()
            }
        case .gaugeWidget:
            GaugeWidgetComparisonPreviewScreen()
        }
    }
#endif

    private func syncPreferencesToICloud(_ section: HomesteadSyncSection) {
        iCloudSyncService.noteLocalChange(
            section,
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
    }

#if DEBUG
    private func focusLivePreviewDashboardIfRequested() {
        guard let entityID = RuntimeEnvironment.livePreviewEntityID else {
            return
        }

        for item in dashboardConfiguration.items {
            dashboardConfiguration.removeItem(id: item.id)
        }
        _ = dashboardConfiguration.add(
            source: .entity(entityID),
            presentation: .card(.status(layout: RuntimeEnvironment.livePreviewCardSize))
        )
    }
#endif
}

private extension HomesteadAppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

final class HomesteadAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor weak static var nativeNotificationService: NativeNotificationService?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await Self.nativeNotificationService?.handleRemoteNotificationDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            Self.nativeNotificationService?.handleRemoteNotificationRegistrationFailure(error)
        }
    }
}
