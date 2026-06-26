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

    init() {
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
                dashboardConfiguration.reconcile(with: stateStore.allEntities)
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
                .preferredColorScheme(appearanceSettings.appearanceMode.colorScheme)
                .task {
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

    private func syncPreferencesToICloud(_ section: HomesteadSyncSection) {
        iCloudSyncService.noteLocalChange(
            section,
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
    }
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
