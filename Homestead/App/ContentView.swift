import SwiftUI

struct ContentView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSettings = false

    var body: some View {
        let chrome = AppChromePresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            dataFreshness: homeAssistantService.dataFreshness,
            serviceFeedback: homeAssistantService.serviceFeedback
        )

        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Areas", systemImage: "square.split.bottomrightquarter") {
                NavigationStack {
                    AreasView()
                }
            }

            Tab("Browse", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    DevicesView()
                }
            }
        }
        .environment(\.openSettings, { isShowingSettings = true })
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isShowingSettings = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close Settings")
                        }
                    }
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
        .onChange(of: homeAssistantService.serviceFeedback?.id) { _, _ in
            playServiceFeedbackHaptic()
        }
        .task(id: homeAssistantService.serviceFeedback?.id) {
            guard let feedback = homeAssistantService.serviceFeedback else {
                return
            }

            try? await Task.sleep(for: feedback.displayDuration)
            homeAssistantService.clearServiceFeedback(id: feedback.id)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: chrome.statusAccessoryState)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: chrome.statusAccessoryState != nil) {
            if let statusAccessoryState = chrome.statusAccessoryState {
                AppStatusAccessory(state: statusAccessoryState) {
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

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

struct SettingsAccountButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(action: openSettings) {
            HomeAssistantAvatarView()
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
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
