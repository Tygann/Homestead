import SwiftUI

@main
struct HomesteadApp: App {
    @State private var stateStore: HAStateStore
    @State private var connectionSettings: HAConnectionSettings
    @State private var homeAssistantService: HomeAssistantService
    @State private var dashboardConfiguration: DashboardConfiguration

    init() {
        let stateStore = HAStateStore()
        _stateStore = State(initialValue: stateStore)
        _connectionSettings = State(initialValue: HAConnectionSettings())
        _homeAssistantService = State(initialValue: HomeAssistantService(stateStore: stateStore))
        _dashboardConfiguration = State(initialValue: DashboardConfiguration())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(stateStore)
                .environment(connectionSettings)
                .environment(homeAssistantService)
                .environment(dashboardConfiguration)
        }
    }
}
