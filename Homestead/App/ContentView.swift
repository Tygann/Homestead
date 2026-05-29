import SwiftUI

struct ContentView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let chrome = AppChromePresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            dataFreshness: homeAssistantService.dataFreshness
        )

        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                AreasView()
            }
            .tabItem {
                Label("Areas", systemImage: "square.split.bottomrightquarter")
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
                    .padding(.bottom, chrome.serviceFeedbackBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: feedback.id) {
                        try? await Task.sleep(for: feedback.displayDuration)
                        homeAssistantService.clearServiceFeedback(id: feedback.id)
                    }
            }
        }
        .onChange(of: homeAssistantService.serviceFeedback?.id) { _, _ in
            playServiceFeedbackHaptic()
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: homeAssistantService.serviceFeedback?.id)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: chrome.connectionAccessoryState != nil) {
            if let connectionAccessoryState = chrome.connectionAccessoryState {
                ConnectionHealthAccessory(state: connectionAccessoryState) {
                    Task {
                        await homeAssistantService.refreshOrReconnect(settings: connectionSettings)
                    }
                }
            }
        }
    }

    private func playServiceFeedbackHaptic() {
        guard let feedback = homeAssistantService.serviceFeedback else {
            return
        }

        HapticFeedback.notification(for: feedback.style)
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
