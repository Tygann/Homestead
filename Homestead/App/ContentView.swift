import SwiftUI

struct ContentView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                RoomsView()
            }
            .tabItem {
                Label("Rooms", systemImage: "square.grid.3x3.fill")
            }

            NavigationStack {
                DevicesView()
            }
            .tabItem {
                Label("Devices", systemImage: "laptopcomputer.and.iphone")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await homeAssistantService.resume(settings: connectionSettings) }
            case .background:
                homeAssistantService.applicationDidEnterBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .overlay(alignment: .bottom) {
            if let feedback = homeAssistantService.serviceFeedback {
                ServiceFeedbackBanner(feedback: feedback)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.bottom, AppSpacing.xxLarge + AppSpacing.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: feedback.id) {
                        try? await Task.sleep(for: .seconds(3))
                        homeAssistantService.clearServiceFeedback(id: feedback.id)
                    }
            }
        }
        .animation(.smooth(duration: 0.22), value: homeAssistantService.serviceFeedback?.id)
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
                await dependencies.homeAssistantService.connectIfPossible(
                    settings: dependencies.connectionSettings
                )
            }
    } else {
        MissingLivePreviewCredentialsView()
    }
}
#endif
