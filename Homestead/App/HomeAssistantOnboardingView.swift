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
            statusSystemImage: statusSystemImage(authState: authState, connectionStatus: connectionStatus)
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
            return "Homestead will open Home Assistant to authorize this iPhone."
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
        case .accessTokenExpired, .refreshFailed:
            return "Sign in again"
        case .signedOut, .signedIn:
            return "Sign in with Home Assistant"
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

    let presentation: HomeAssistantOnboardingPresentation
    let signIn: () -> Void
    let openSettings: () -> Void

    var body: some View {
        @Bindable var connectionSettings = connectionSettings

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    header

                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        TextField("homeassistant.local:8123", text: $connectionSettings.baseURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .focused($isURLFieldFocused)
                            .padding(.horizontal, AppSpacing.medium)
                            .frame(minHeight: 54)
                            .background(
                                Color(.tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                            )
                            .submitLabel(.go)
                            .onSubmit {
                                attemptSignIn()
                            }

                        statusRow

                        Button {
                            attemptSignIn()
                        } label: {
                            HStack(spacing: AppSpacing.small) {
                                if presentation.isBusy {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "person.badge.key.fill")
                                }

                                Text(presentation.buttonTitle)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!presentation.isButtonEnabled)

                        Button {
                            isURLFieldFocused = false
                            openSettings()
                        } label: {
                            Text("Open Settings")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(AppSpacing.large)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    )
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.xLarge)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Homestead")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Image("HomesteadLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(presentation.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text(presentation.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Image(systemName: presentation.statusSystemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusTint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(presentation.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusTint: Color {
        if presentation.statusSystemImage == "exclamationmark.triangle.fill" {
            return .orange
        }

        if presentation.statusSystemImage == "checkmark.circle.fill" {
            return .green
        }

        return .accentColor
    }

    private func attemptSignIn() {
        guard presentation.isButtonEnabled else {
            return
        }

        isURLFieldFocused = false
        signIn()
    }
}

#if DEBUG
#Preview("Onboarding") {
    HomeAssistantOnboardingView(
        presentation: .make(
            hasServerURL: false,
            authState: .signedOut,
            connectionStatus: .disconnected,
            serviceError: nil,
            storageError: nil
        ),
        signIn: {},
        openSettings: {}
    )
    .withPreviewEnvironment()
}
#endif
