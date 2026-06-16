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
        hasKnownSession: Bool = false,
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        serviceError: String?,
        storageError: String?
    ) -> HomeAssistantOnboardingPresentation {
        let shouldShow = !hasServerURL || (!hasKnownSession && shouldShowForAuthState(authState))
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

    private static func shouldShowForAuthState(_ authState: HAAuthState) -> Bool {
        switch authState {
        case .signedOut, .signingIn, .refreshFailed:
            true
        case .refreshing, .signedIn, .accessTokenExpired:
            false
        }
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
    @Environment(HomeAssistantDiscoveryService.self) private var discoveryService
    @Environment(HomesteadSetupCoordinator.self) private var setupCoordinator
    @FocusState private var isURLFieldFocused: Bool
    @State private var isEnteringAddress = false
    @State private var draftBaseURL = ""

    let authState: HAAuthState
    let connectionStatus: HAConnectionStatus
    let serviceError: String?
    let storageError: String?
    let signIn: () -> Void

    var body: some View {
        @Bindable var connectionSettings = connectionSettings
        let hasDraftServerURL = isEnteringAddress &&
            !draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: connectionSettings.hasServerURL || hasDraftServerURL,
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
        presentation: HomeAssistantOnboardingPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if connectionSettings.hasServerURL {
                selectedServerCard(presentation: presentation)
            } else {
                VStack(spacing: AppSpacing.medium) {
                    Button {
                        isURLFieldFocused = false
                        isEnteringAddress = false
                        discoveryService.start()
                    } label: {
                        Label("Find Home Assistant", systemImage: "dot.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)

                    discoveryResults

                    Button("Enter Address Manually") {
                        discoveryService.stop()
                        draftBaseURL = connectionSettings.baseURL
                        isEnteringAddress = true
                        isURLFieldFocused = true
                    }
                    .buttonStyle(.plain)

                    if isEnteringAddress {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text("Home Assistant Address")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("homeassistant.local:8123", text: $draftBaseURL)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .textContentType(.URL)
                                .autocorrectionDisabled()
                                .focused($isURLFieldFocused)
                                .submitLabel(.go)
                                .onSubmit { attemptSignIn(presentation: presentation) }
                        }
                        .padding(AppSpacing.medium)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var discoveryResults: some View {
        switch discoveryService.state {
        case .idle:
            EmptyView()
        case .browsing:
            if discoveryService.instances.isEmpty {
                HStack { ProgressView(); Text("Looking on your local network...") }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(discoveryService.instances) { instance in
                    Button {
                        setupCoordinator.select(instance, settings: connectionSettings)
                    } label: {
                        HStack {
                            Image(systemName: "house.fill")
                            VStack(alignment: .leading) {
                                Text(instance.name).fontWeight(.semibold)
                                Text(instance.signInURL).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(AppSpacing.medium)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .failed:
            ContentUnavailableView(
                "Home Assistant Not Found",
                systemImage: "wifi.exclamationmark",
                description: Text("Check Local Network access, or enter the address manually.")
            )
        }
    }

    private func selectedServerCard(presentation: HomeAssistantOnboardingPresentation) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "house.fill").foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Home Assistant").font(.headline)
                    Text(connectionSettings.baseURL).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if canChangeSelectedServer {
                    Button("Change") {
                        draftBaseURL = connectionSettings.baseURL
                        isEnteringAddress = true
                        isURLFieldFocused = true
                        connectionSettings.baseURL = ""
                        connectionSettings.internalURL = ""
                        connectionSettings.externalURL = ""
                    }
                    .font(.subheadline)
                }
            }
            .padding(AppSpacing.medium)

            if presentation.showsStatusRow {
                Divider().padding(.leading, AppSpacing.medium)
                statusRow(presentation: presentation).padding(AppSpacing.medium)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card))
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
        commitDraftBaseURLIfNeeded()
        signIn()
    }

    private func commitDraftBaseURLIfNeeded() {
        guard isEnteringAddress else {
            return
        }

        let trimmedBaseURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else {
            return
        }

        connectionSettings.baseURL = trimmedBaseURL
        isEnteringAddress = false
    }

    private var canChangeSelectedServer: Bool {
        switch authState {
        case .signedOut, .refreshFailed:
            return true
        case .signingIn, .refreshing, .signedIn, .accessTokenExpired:
            return false
        }
    }
}

struct ICloudSetupRestoreView: View {
    let summary: HomesteadICloudRestoreSummary
    let restore: () -> Void
    let setUpAnotherHome: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: AppSpacing.small) {
                Text("Continue Your Homestead Setup").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("A saved setup was found in iCloud.").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                LabeledContent("Home Assistant", value: summary.serverDisplayName)
                LabeledContent("Dashboard", value: summary.dashboardItemCount == 1 ? "1 item" : "\(summary.dashboardItemCount) items")
            }
            .padding(AppSpacing.large)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card))
            .frame(maxWidth: 460)
            Spacer()
            Button("Continue") { restore() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 460)
            Button("Set Up Another Home") { setUpAnotherHome() }
                .buttonStyle(.plain)
        }
        .padding(AppSpacing.large)
        .background(Color(.systemGroupedBackground))
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
