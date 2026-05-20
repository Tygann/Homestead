import SwiftUI

struct ContentView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                DevicesView()
            }
            .tabItem {
                Label("Devices", systemImage: "square.grid.2x2.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .task {
            guard !RuntimeEnvironment.isRunningForPreviews else {
                return
            }

            await homeAssistantService.connectIfPossible(settings: connectionSettings)
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    ContentView()
        .withPreviewEnvironment()
}
#endif
