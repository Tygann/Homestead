import SwiftUI

@main
struct HomesteadApp: App {
    @State private var stateStore: HAStateStore
    @State private var connectionSettings: HAConnectionSettings
    @State private var homeAssistantService: HomeAssistantService
    @State private var nativeNotificationService: NativeNotificationService
    @State private var dashboardConfiguration: DashboardConfiguration

    init() {
        let stateStore = HAStateStore()
        let connectionSettings = HAConnectionSettings()
        let homeAssistantService = HomeAssistantService(stateStore: stateStore)
        let nativeNotificationService = NativeNotificationService()

        _stateStore = State(initialValue: stateStore)
        _connectionSettings = State(initialValue: connectionSettings)
        _homeAssistantService = State(initialValue: homeAssistantService)
        _nativeNotificationService = State(initialValue: nativeNotificationService)
        _dashboardConfiguration = State(initialValue: DashboardConfiguration())

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
                .environment(dashboardConfiguration)
        }
    }
}
