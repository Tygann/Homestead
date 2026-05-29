import SwiftUI

@main
struct HomesteadApp: App {
    @State private var stateStore: HAStateStore
    @State private var connectionSettings: HAConnectionSettings
    @State private var homeAssistantService: HomeAssistantService
    @State private var dashboardConfiguration: DashboardConfiguration
    @State private var pinnedEntityStore: PinnedEntityStore

    init() {
        let stateStore = HAStateStore()
        let connectionSettings = HAConnectionSettings()
        let homeAssistantService = HomeAssistantService(stateStore: stateStore)

        _stateStore = State(initialValue: stateStore)
        _connectionSettings = State(initialValue: connectionSettings)
        _homeAssistantService = State(initialValue: homeAssistantService)
        _dashboardConfiguration = State(initialValue: DashboardConfiguration())
        _pinnedEntityStore = State(initialValue: PinnedEntityStore())

        guard !RuntimeEnvironment.isRunningForPreviews else {
            return
        }

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
                .environment(dashboardConfiguration)
                .environment(pinnedEntityStore)
        }
    }
}
