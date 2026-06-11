import SwiftUI

struct ContentView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(NativeNotificationService.self) private var nativeNotificationService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("homestead.notificationSetupPromptHandled") private var hasHandledNotificationSetupPrompt = false
    @State private var isShowingSettings = false
    @State private var isShowingNotificationSetupPrompt = false

    var body: some View {
        let chrome = AppChromePresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            connectionStatus: homeAssistantService.connectionStatus,
            dataFreshness: homeAssistantService.dataFreshness,
            serviceFeedback: homeAssistantService.serviceFeedback,
            suppressTransientConnectionHealth: homeAssistantService.suppressesTransientConnectionHealth
        )

        TabView {
            Tab("Home", systemImage: "house.fill") {
                tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                    DashboardView()
                }
            }

            Tab("Areas", systemImage: "square.split.bottomrightquarter") {
                tabContent(statusAccessoryState: chrome.statusAccessoryState) {
                    AreasView()
                }
            }

            Tab("Browse", systemImage: "magnifyingglass", role: .search) {
                tabContent(statusAccessoryState: chrome.statusAccessoryState) {
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
        .alert("Finish Notification Setup", isPresented: $isShowingNotificationSetupPrompt) {
            Button("Not Now", role: .cancel) {
                hasHandledNotificationSetupPrompt = true
            }

            Button("Allow Notifications") {
                hasHandledNotificationSetupPrompt = true
                Task { await nativeNotificationService.requestAuthorization() }
            }
        } message: {
            Text("Homestead can show alerts sent by Home Assistant on this iPhone.")
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                homeAssistantService.applicationWillEnterForeground()
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
        .onChange(of: notificationSetupPromptEvaluationID) { _, _ in
            presentNotificationSetupPromptIfNeeded()
        }
        .task(id: notificationSetupRefreshTaskID) {
            await refreshNotificationSetupStatusIfNeeded()
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
    }

    private func tabContent<Content: View>(
        statusAccessoryState: AppStatusAccessoryState?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
        }
        .safeAreaInset(edge: .bottom, spacing: AppSpacing.small) {
            if let statusAccessoryState {
                AppStatusAccessory(state: statusAccessoryState) {
                    Task {
                        await homeAssistantService.refreshOrReconnect(settings: connectionSettings)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.bottom, AppSpacing.small)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func playServiceFeedbackHaptic() {
        guard let feedback = homeAssistantService.serviceFeedback else {
            return
        }

        HapticFeedback.notification(for: feedback.style)
    }

    private var notificationSetupPromptEvaluationID: String {
        [
            connectionSettings.hasServerURL.description,
            homeAssistantService.authState.title,
            mobileAppRegistrationPromptID,
            nativeNotificationService.status.authorizationStatus.promptID,
            hasHandledNotificationSetupPrompt.description,
            isShowingSettings.description
        ].joined(separator: "|")
    }

    private var notificationSetupRefreshTaskID: String {
        [
            connectionSettings.hasServerURL.description,
            homeAssistantService.authState.title,
            mobileAppRegistrationPromptID,
            nativeNotificationService.status.authorizationStatus.promptID,
            hasHandledNotificationSetupPrompt.description
        ].joined(separator: "|")
    }

    private var mobileAppRegistrationPromptID: String {
        switch homeAssistantService.mobileAppRegistrationState {
        case .unregistered:
            "unregistered"
        case .registering:
            "registering"
        case .registered(let summary):
            "registered-\(summary.registeredAt.timeIntervalSince1970)"
        case .failed(let message):
            "failed-\(message)"
        }
    }

    private func refreshNotificationSetupStatusIfNeeded() async {
        guard CompanionNotificationSetupPromptPresentation.shouldRefreshNotificationStatus(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            mobileAppRegistrationState: homeAssistantService.mobileAppRegistrationState,
            notificationStatus: nativeNotificationService.status.authorizationStatus,
            hasHandledPrompt: hasHandledNotificationSetupPrompt
        ) else {
            presentNotificationSetupPromptIfNeeded()
            return
        }

        await nativeNotificationService.refreshAuthorizationStatus()
        presentNotificationSetupPromptIfNeeded()
    }

    private func presentNotificationSetupPromptIfNeeded() {
        guard CompanionNotificationSetupPromptPresentation.shouldShow(
            hasServerURL: connectionSettings.hasServerURL,
            authState: homeAssistantService.authState,
            mobileAppRegistrationState: homeAssistantService.mobileAppRegistrationState,
            notificationStatus: nativeNotificationService.status.authorizationStatus,
            hasHandledPrompt: hasHandledNotificationSetupPrompt,
            isShowingSettings: isShowingSettings
        ) else {
            return
        }

        isShowingNotificationSetupPrompt = true
    }
}

private extension NativeNotificationAuthorizationStatus {
    var promptID: String {
        switch self {
        case .unknown:
            "unknown"
        case .notDetermined:
            "notDetermined"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        case .provisional:
            "provisional"
        case .ephemeral:
            "ephemeral"
        }
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
                .frame(width: 44, height: 44)
                .padding(-6)
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
