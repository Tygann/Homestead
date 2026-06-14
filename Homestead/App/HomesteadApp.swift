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
    @State private var iCloudSyncService: HomesteadICloudSyncService

    init() {
        let stateStore = HAStateStore()
        let connectionSettings = HAConnectionSettings()
        let nativeNotificationService = NativeNotificationService()
        let nativePermissionService = NativePermissionService()
        let actionConfirmationSettings = ActionConfirmationSettings()
        let appearanceSettings = HomesteadAppearanceSettings()
        let dashboardConfiguration = DashboardConfiguration()
        let iCloudSyncService = HomesteadICloudSyncService()
        let homeAssistantService = HomeAssistantService(
            stateStore: stateStore,
            nativeNotificationService: nativeNotificationService
        )

        _stateStore = State(initialValue: stateStore)
        _connectionSettings = State(initialValue: connectionSettings)
        _homeAssistantService = State(initialValue: homeAssistantService)
        _nativeNotificationService = State(initialValue: nativeNotificationService)
        _nativePermissionService = State(initialValue: nativePermissionService)
        _dashboardConfiguration = State(initialValue: dashboardConfiguration)
        _actionConfirmationSettings = State(initialValue: actionConfirmationSettings)
        _appearanceSettings = State(initialValue: appearanceSettings)
        _iCloudSyncService = State(initialValue: iCloudSyncService)

        guard !RuntimeEnvironment.isRunningForPreviews else {
            return
        }

        homeAssistantService.startNetworkMonitoring(settings: connectionSettings)

        Task { @MainActor in
            await homeAssistantService.refreshAuthState()
            homeAssistantService.refreshMobileAppRegistrationState(settings: connectionSettings)
            await homeAssistantService.loadCachedStatesIfPossible(settings: connectionSettings)
            await homeAssistantService.connectIfPossible(settings: connectionSettings)
        }
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
                .environment(iCloudSyncService)
                .task {
                    iCloudSyncService.startObserving(
                        connectionSettings: connectionSettings,
                        dashboardConfiguration: dashboardConfiguration,
                        actionConfirmationSettings: actionConfirmationSettings,
                        appearanceSettings: appearanceSettings
                    )
                    iCloudSyncService.applyRemoteIfNewer(
                        connectionSettings: connectionSettings,
                        dashboardConfiguration: dashboardConfiguration,
                        actionConfirmationSettings: actionConfirmationSettings,
                        appearanceSettings: appearanceSettings
                    )
                }
                .onChange(of: connectionSettings.syncSnapshot) { _, _ in
                    syncPreferencesToICloud()
                }
                .onChange(of: dashboardConfiguration.syncSnapshot) { _, _ in
                    syncPreferencesToICloud()
                }
                .onChange(of: actionConfirmationSettings.syncSnapshot) { _, _ in
                    syncPreferencesToICloud()
                }
                .onChange(of: appearanceSettings.syncSnapshot) { _, _ in
                    syncPreferencesToICloud()
                }
        }
    }

    private func syncPreferencesToICloud() {
        iCloudSyncService.syncNow(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
    }
}

final class HomesteadAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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
}
