import SwiftUI

nonisolated struct HomeAssistantOnboardingPresentation: Equatable {
    let shouldShow: Bool
    let title: String
    let message: String
    let statusTitle: String
    let statusMessage: String
    let buttonTitle: String
    let isButtonEnabled: Bool
    let isBusy: Bool
    let statusSystemImage: String
    let showsStatusRow: Bool
    let footerMessage: String

    static func make(
        hasServerURL: Bool,
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        serviceError: String?,
        storageError: String?
    ) -> HomeAssistantOnboardingPresentation {
        let shouldShow = !hasServerURL || !authState.isSignedIn
        let isBusy = authState == .signingIn || isRefreshing(authState)

        return HomeAssistantOnboardingPresentation(
            shouldShow: shouldShow,
            title: "Connect Home Assistant",
            message: "Enter the address you use to open Home Assistant, then sign in.",
            statusTitle: statusTitle(
                hasServerURL: hasServerURL,
                authState: authState,
                connectionStatus: connectionStatus
            ),
            statusMessage: statusMessage(
                hasServerURL: hasServerURL,
                authState: authState,
                connectionStatus: connectionStatus,
                serviceError: serviceError,
                storageError: storageError
            ),
            buttonTitle: buttonTitle(authState: authState),
            isButtonEnabled: hasServerURL && !isBusy,
            isBusy: isBusy,
            statusSystemImage: statusSystemImage(authState: authState, connectionStatus: connectionStatus),
            showsStatusRow: showsStatusRow(authState: authState, storageError: storageError),
            footerMessage: footerMessage(hasServerURL: hasServerURL, authState: authState)
        )
    }

    private static func isRefreshing(_ authState: HAAuthState) -> Bool {
        if case .refreshing = authState {
            return true
        }

        return false
    }

    private static func statusTitle(
        hasServerURL: Bool,
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus
    ) -> String {
        guard hasServerURL else {
            return "Server Needed"
        }

        switch authState {
        case .signedOut:
            return "Ready to Sign In"
        case .signingIn:
            return "Signing In"
        case .refreshing:
            return "Refreshing Sign-In"
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Connected"
            case .preparing, .connecting, .reconnecting:
                return "Connecting"
            case .failed:
                return "Connection Issue"
            case .disconnected:
                return "Signed In"
            }
        case .accessTokenExpired:
            return "Sign-In Needed"
        case .refreshFailed:
            return "Sign-In Failed"
        }
    }

    private static func statusMessage(
        hasServerURL: Bool,
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        serviceError: String?,
        storageError: String?
    ) -> String {
        if let storageError {
            return storageError
        }

        guard hasServerURL else {
            return "Use a local or remote Home Assistant address."
        }

        switch authState {
        case .signedOut:
            return "Homestead will open Home Assistant to authorize this device."
        case .signingIn:
            return "Finish authorization in the Home Assistant sign-in window."
        case .refreshing:
            return "Checking the saved Home Assistant session."
        case .signedIn:
            switch connectionStatus {
            case .connected:
                return "Homestead is connected to Home Assistant."
            case .preparing, .connecting:
                return "Homestead is loading your Home Assistant dashboard."
            case .reconnecting:
                return "Homestead is restoring the live connection."
            case .failed(let message):
                return serviceError ?? message
            case .disconnected:
                return serviceError ?? "Homestead is signed in and ready to connect."
            }
        case .accessTokenExpired:
            return "Sign in again to continue using Home Assistant."
        case .refreshFailed(let message):
            return message
        }
    }

    private static func buttonTitle(authState: HAAuthState) -> String {
        switch authState {
        case .signingIn:
            return "Signing In"
        case .refreshing:
            return "Refreshing"
        case .signedOut, .signedIn, .accessTokenExpired, .refreshFailed:
            return "Continue"
        }
    }

    private static func showsStatusRow(authState: HAAuthState, storageError: String?) -> Bool {
        if storageError != nil {
            return true
        }

        switch authState {
        case .signedOut:
            return false
        case .signingIn, .refreshing, .signedIn, .accessTokenExpired, .refreshFailed:
            return true
        }
    }

    private static func footerMessage(hasServerURL: Bool, authState: HAAuthState) -> String {
        guard hasServerURL else {
            return "Use the address you normally use to open Home Assistant."
        }

        switch authState {
        case .signedOut:
            return "Homestead will open Home Assistant to authorize this device."
        case .signingIn:
            return "Finish authorization in the Home Assistant sign-in window."
        case .refreshing:
            return "Checking the saved Home Assistant session."
        case .signedIn:
            return "Homestead is loading your Home Assistant dashboard."
        case .accessTokenExpired:
            return "Sign in again to continue using Home Assistant."
        case .refreshFailed(let message):
            return message
        }
    }

    private static func statusSystemImage(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus
    ) -> String {
        switch authState {
        case .signingIn, .refreshing:
            return "arrow.triangle.2.circlepath"
        case .refreshFailed, .accessTokenExpired:
            return "exclamationmark.triangle.fill"
        case .signedIn:
            if case .connected = connectionStatus {
                return "checkmark.circle.fill"
            }

            return "network"
        case .signedOut:
            return "server.rack"
        }
    }
}

struct HomeAssistantOnboardingView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @FocusState private var isURLFieldFocused: Bool
    @State private var isShowingAdvancedSetup = false

    let authState: HAAuthState
    let connectionStatus: HAConnectionStatus
    let serviceError: String?
    let storageError: String?
    let signIn: () -> Void

    var body: some View {
        @Bindable var connectionSettings = connectionSettings
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: connectionSettings.hasServerURL,
            authState: authState,
            connectionStatus: connectionStatus,
            serviceError: serviceError,
            storageError: storageError
        )

        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header

                    setupGroup(
                        baseURL: $connectionSettings.baseURL,
                        presentation: presentation
                    )
                    .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, 76)
                .padding(.bottom, 132)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar(presentation: presentation)
                    .background(Color(.systemGroupedBackground))
            }
            .sheet(isPresented: $isShowingAdvancedSetup) {
                NavigationStack {
                    HomeAssistantAdvancedOnboardingSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    isShowingAdvancedSetup = false
                                }
                                .buttonStyle(.plain)
                            }
                        }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.large) {
            Image("HomesteadLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: AppSpacing.small) {
                Text("Set Up Homestead")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Connect to Home Assistant to control your home.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 420)
        .accessibilityElement(children: .combine)
    }

    private func setupGroup(
        baseURL: Binding<String>,
        presentation: HomeAssistantOnboardingPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Home Assistant Address")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("homeassistant.local:8123", text: baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .focused($isURLFieldFocused)
                        .submitLabel(.go)
                        .onSubmit {
                            attemptSignIn(presentation: presentation)
                        }
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)

                if presentation.showsStatusRow {
                    Divider()
                        .padding(.leading, AppSpacing.medium)

                    statusRow(presentation: presentation)
                        .padding(.horizontal, AppSpacing.medium)
                        .padding(.vertical, AppSpacing.medium)
                }
            }
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
            )

            Text(presentation.footerMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.large)
        }
    }

    private func actionBar(presentation: HomeAssistantOnboardingPresentation) -> some View {
        VStack(spacing: AppSpacing.small) {
            Button {
                attemptSignIn(presentation: presentation)
            } label: {
                HStack(spacing: AppSpacing.small) {
                    if presentation.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    Text(presentation.buttonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: AppRadius.control))
            .disabled(!presentation.isButtonEnabled)

            Button {
                isURLFieldFocused = false
                isShowingAdvancedSetup = true
            } label: {
                Text("Configure Advanced Settings")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.top, AppSpacing.medium)
        .padding(.bottom, AppSpacing.small)
    }

    private func statusRow(presentation: HomeAssistantOnboardingPresentation) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Image(systemName: presentation.statusSystemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(statusTint(for: presentation))
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(presentation.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func statusTint(for presentation: HomeAssistantOnboardingPresentation) -> Color {
        if presentation.statusSystemImage == "exclamationmark.triangle.fill" {
            return .orange
        }

        if presentation.statusSystemImage == "checkmark.circle.fill" {
            return .green
        }

        return .secondary
    }

    private func attemptSignIn(presentation: HomeAssistantOnboardingPresentation) {
        guard presentation.isButtonEnabled else {
            return
        }

        isURLFieldFocused = false
        signIn()
    }
}

private struct HomeAssistantAdvancedOnboardingSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings

    var body: some View {
        @Bindable var connectionSettings = connectionSettings

        Form {
            Section {
                TextField("Internal URL", text: $connectionSettings.internalURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()

                TextField("External URL", text: $connectionSettings.externalURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
            } header: {
                Text("Addresses")
            } footer: {
                Text("Homestead can switch between internal and external addresses after sign-in.")
            }

            Section {
                TextField("Wi-Fi Network Name", text: $connectionSettings.homeNetworkName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Home Network")
            } footer: {
                Text("Enter the Wi-Fi network Homestead should treat as home.")
            }
        }
        .navigationTitle("Advanced Setup")
        .toolbarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Onboarding") {
    HomeAssistantOnboardingView(
        authState: .signedOut,
        connectionStatus: .disconnected,
        serviceError: nil,
        storageError: nil,
        signIn: {}
    )
    .withPreviewEnvironment()
}
#endif
