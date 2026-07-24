import SwiftUI
import UIKit
import UserNotifications

@main
struct HomesteadApp: App {
    @UIApplicationDelegateAdaptor(HomesteadAppDelegate.self) private var appDelegate
    @State private var stateStore: HAStateStore
    @State private var connectionProfileStore: HAConnectionProfileStore
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
            let dependencies = previewScreen == .home
                ? PreviewDependencies.dashboardPagingSample
                : PreviewDependencies.sample
            HomesteadAppDelegate.nativeNotificationService = dependencies.nativeNotificationService
            _stateStore = State(initialValue: dependencies.stateStore)
            _connectionProfileStore = State(initialValue: dependencies.connectionSettings.profileStore)
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
            _connectionProfileStore = State(initialValue: dependencies.connectionSettings.profileStore)
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

        let legacyTokenStore = KeychainHAOAuthTokenStore()
        let stateStore = HAStateStore()
        let connectionSettings = HAConnectionSettings(tokenStore: legacyTokenStore)
        let connectionProfileStore = connectionSettings.profileStore
        try? KeychainHAOAuthTokenStore.migrateLegacyCredentialIfNeeded(to: connectionProfileStore.activeProfileID)
        try? KeychainHAMobileAppRegistrationStore.migrateLegacyRegistrationIfNeeded(to: connectionProfileStore.activeProfileID)
        let tokenStore = KeychainHAOAuthTokenStore(profileID: connectionProfileStore.activeProfileID)
        let nativeNotificationService = NativeNotificationService()
        HomesteadAppDelegate.nativeNotificationService = nativeNotificationService
        let nativePermissionService = NativePermissionService()
        let actionConfirmationSettings = ActionConfirmationSettings()
        let appearanceSettings = HomesteadAppearanceSettings(profileID: connectionProfileStore.activeProfileID)
        let tabSettings = HomesteadTabSettings()
        let dashboardConfiguration = DashboardConfiguration(profileID: connectionProfileStore.activeProfileID)
        let iCloudSyncService = HomesteadICloudSyncService()
        let setupCoordinator = HomesteadSetupCoordinator()
        let homeAssistantService = HomeAssistantService(
            stateStore: stateStore,
            authState: HAOAuthManager.status(tokenStore: tokenStore),
            mobileAppRegistrationStore: KeychainHAMobileAppRegistrationStore(
                profileID: connectionProfileStore.activeProfileID
            ),
            nativeNotificationService: nativeNotificationService,
            authManager: HAOAuthManager(
                tokenStore: tokenStore,
                profileID: connectionProfileStore.activeProfileID
            )
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
        _connectionProfileStore = State(initialValue: connectionProfileStore)
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
                .environment(connectionProfileStore)
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
                .onChange(of: connectionProfileStore.activeProfileID) { _, profileID in
                    appearanceSettings.activateProfile(profileID)
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
                AppearanceSettingsPreviewHost()
            }
        case .dashboardChangeEntity:
            DashboardChangeEntityPreviewScreen()
        case .dashboardCardEditor:
            DashboardCardEditorPreviewScreen()
        case .dashboardCards:
            DashboardCardReferenceGallery()
        case .entityDetailCard:
            EntityDetailCardContextPreviewScreen()
        case .entityDetails:
            EntityDetailReferenceGallery()
        case .home:
            ContentView()
        case .settings:
            SettingsReferenceGallery()
        case .widgets:
            WidgetReferenceGallery()
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
        let size = RuntimeEnvironment.livePreviewCardSize
        let kind = RuntimeEnvironment.livePreviewPresentationKind ?? .status
        let card = DashboardPresentationCatalog.cardConfiguration(kind: kind, layout: size)
            ?? .status(layout: size)
        _ = dashboardConfiguration.add(source: .entity(entityID), presentation: .card(card))
    }
#endif
}

extension HomesteadAppearanceMode {
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let profileID = userInfo["profile_id"] as? String
        let entityID = userInfo["entity_id"] as? String
        await MainActor.run {
            NotificationCenter.default.post(
                name: .homesteadNotificationDestination,
                object: nil,
                userInfo: ["profile_id": profileID, "entity_id": entityID].compactMapValues { $0 }
            )
        }
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

extension Notification.Name {
    static let homesteadNotificationDestination = Notification.Name("homestead.notificationDestination")
}
