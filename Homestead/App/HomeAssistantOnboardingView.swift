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
        let displayAuthState = displayAuthState(authState, hasKnownSession: hasKnownSession)
        let shouldShow = !hasServerURL || (!hasKnownSession && shouldShowForAuthState(displayAuthState))
        let isBusy = displayAuthState == .signingIn || isRefreshing(displayAuthState)

        return HomeAssistantOnboardingPresentation(
            shouldShow: shouldShow,
            title: "Connect Home Assistant",
            message: "Enter the address you use to open Home Assistant, then sign in.",
            statusTitle: statusTitle(
                hasServerURL: hasServerURL,
                authState: displayAuthState,
                connectionStatus: connectionStatus
            ),
            statusMessage: statusMessage(
                hasServerURL: hasServerURL,
                authState: displayAuthState,
                connectionStatus: connectionStatus,
                serviceError: serviceError,
                storageError: storageError
            ),
            buttonTitle: buttonTitle(authState: displayAuthState),
            isButtonEnabled: hasServerURL && !isBusy,
            isBusy: isBusy,
            statusSystemImage: statusSystemImage(authState: displayAuthState, connectionStatus: connectionStatus),
            showsStatusRow: showsStatusRow(authState: displayAuthState, storageError: storageError),
            footerMessage: footerMessage(hasServerURL: hasServerURL, authState: displayAuthState)
        )
    }

    private static func displayAuthState(_ authState: HAAuthState, hasKnownSession: Bool) -> HAAuthState {
        if case .refreshing = authState, !hasKnownSession {
            return .signedOut
        }

        return authState
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
    enum Step {
        case welcome
        case setup
    }

    // MARK: - Properties

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantDiscoveryService.self) private var discoveryService
    @Environment(HomesteadSetupCoordinator.self) private var setupCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isURLFieldFocused: Bool
    @State private var isEnteringAddress = false
    @State private var draftBaseURL = ""
    @State private var selectedStep: Step?

    let authState: HAAuthState
    let connectionStatus: HAConnectionStatus
    let serviceError: String?
    let storageError: String?
    let signIn: () -> Void

    init(
        authState: HAAuthState,
        connectionStatus: HAConnectionStatus,
        serviceError: String?,
        storageError: String?,
        signIn: @escaping () -> Void,
        initialStep: Step? = nil
    ) {
        self.authState = authState
        self.connectionStatus = connectionStatus
        self.serviceError = serviceError
        self.storageError = storageError
        self.signIn = signIn
        _selectedStep = State(initialValue: initialStep)
    }

    // MARK: - Body

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

        Group {
            if currentStep == .welcome {
                welcomeScreen
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                setupScreen(presentation: presentation)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: currentStep)
    }

    // MARK: - Welcome

    private var welcomeScreen: some View {
        ZStack {
            HomesteadOnboardingBackground()

            ScrollView {
                VStack(spacing: AppSpacing.xLarge) {
                    welcomeBrand
                    OnboardingHomePreview()
                        .frame(maxWidth: 430)
                    welcomeMessage
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.medium)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                welcomeAction
            }
        }
        .preferredColorScheme(.dark)
    }

    private var welcomeBrand: some View {
        HStack(spacing: AppSpacing.small) {
            Image("HomesteadLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            Text("Homestead")
                .font(.headline.weight(.semibold))
        }
        .frame(maxWidth: 430, alignment: .leading)
    }

    private var welcomeMessage: some View {
        VStack(spacing: AppSpacing.medium) {
            Text("Your home, beautifully at hand.")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("A fast, native way to control and understand your Home Assistant home.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 430)
        .accessibilityElement(children: .combine)
    }

    private var welcomeAction: some View {
        Button {
            selectedStep = .setup
        } label: {
            HStack {
                Text("Get Started")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AppSpacing.medium)
            .foregroundStyle(.white)
        }
        .buttonStyle(.glass(.regular.tint(Color.accentColor.opacity(0.28))))
        .buttonBorderShape(.capsule)
        .tint(Color.accentColor)
        .padding(.horizontal, AppSpacing.large)
        .padding(.top, AppSpacing.medium)
        .padding(.bottom, AppSpacing.small)
        .accessibilityHint("Continues to Home Assistant setup")
    }

    // MARK: - Setup

    private func setupScreen(presentation: HomeAssistantOnboardingPresentation) -> some View {
        ZStack {
            HomesteadOnboardingBackground()

            ScrollView {
                VStack(spacing: AppSpacing.xLarge) {
                    setupHeader

                    setupGroup(presentation: presentation)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, 48)
                .padding(.bottom, 132)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar(presentation: presentation)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var setupHeader: some View {
        VStack(spacing: AppSpacing.large) {
            ZStack {
                Image(systemName: "house.and.flag.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 72, height: 72)
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.35)), in: .circle)
            .accessibilityHidden(true)

            VStack(spacing: AppSpacing.small) {
                Text(connectionSettings.hasServerURL ? "Connect Your Home" : "Find Your Home")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(setupHeaderMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 420)
        .accessibilityElement(children: .combine)
    }

    private var setupHeaderMessage: String {
        if connectionSettings.hasServerURL {
            return "Continue securely through Home Assistant to finish setup."
        }

        return "We’ll look for Home Assistant on your local network."
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
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glass(.regular.tint(Color.accentColor.opacity(0.28))))
                    .buttonBorderShape(.capsule)

                    discoveryResults

                    Button("Enter Address Manually") {
                        discoveryService.stop()
                        draftBaseURL = connectionSettings.baseURL
                        isEnteringAddress = true
                        isURLFieldFocused = true
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)

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
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: AppRadius.card))
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
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: AppRadius.card))
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
        .glassEffect(.regular, in: .capsule)
    }

    private func actionBar(presentation: HomeAssistantOnboardingPresentation) -> some View {
        HStack(spacing: AppSpacing.medium) {
            if canNavigateBackToWelcome {
                Button {
                    navigateBackToWelcome()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Back")
            }

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

                    if !presentation.isBusy {
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, AppSpacing.medium)
                .foregroundStyle(.white)
            }
            .buttonStyle(.glass(.regular.tint(Color.accentColor.opacity(0.28))))
            .buttonBorderShape(.capsule)
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

    private func navigateBackToWelcome() {
        isURLFieldFocused = false
        discoveryService.stop()
        selectedStep = .welcome
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

    private var currentStep: Step {
        if let selectedStep {
            return selectedStep
        }

        guard !connectionSettings.hasServerURL else {
            return .setup
        }

        switch authState {
        case .signedOut:
            return .welcome
        case .signingIn, .refreshing, .signedIn, .accessTokenExpired, .refreshFailed:
            return .setup
        }
    }

    private var canNavigateBackToWelcome: Bool {
        selectedStep == .setup
    }
}

// MARK: - Welcome Artwork

private struct OnboardingHomePreview: View {
    var body: some View {
        VStack(spacing: AppSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Good evening")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Home")
                        .font(.title2.weight(.bold))
                }
                Spacer()
                Label("72°", systemImage: "cloud.sun.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }

            HStack(spacing: AppSpacing.small) {
                OnboardingPreviewTile(
                    title: "Living Room",
                    detail: "3 lights on",
                    systemImage: "lightbulb.fill",
                    tint: .yellow
                )
                OnboardingPreviewTile(
                    title: "Comfort",
                    detail: "72° · 45%",
                    systemImage: "thermometer.medium",
                    tint: .cyan
                )
            }

            HStack(spacing: AppSpacing.small) {
                OnboardingPreviewTile(
                    title: "Front Door",
                    detail: "Locked",
                    systemImage: "lock.fill",
                    tint: .green
                )
                OnboardingPreviewTile(
                    title: "Movie Night",
                    detail: "Ready",
                    systemImage: "play.tv.fill",
                    tint: .purple
                )
            }
        }
        .padding(AppSpacing.medium)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 24, y: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample Homestead dashboard showing lights, comfort, front door, and Movie Night")
    }
}

private struct OnboardingPreviewTile: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
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
                LabeledContent("Dashboards", value: restoreDashboardSummaryText)
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

    private var restoreDashboardSummaryText: String {
        let dashboardText = summary.dashboardCount == 1 ? "1 dashboard" : "\(summary.dashboardCount) dashboards"
        let itemText = summary.dashboardItemCount == 1 ? "1 item" : "\(summary.dashboardItemCount) items"
        return "\(dashboardText), \(itemText)"
    }
}

#if DEBUG
#Preview("Onboarding") {
    HomeAssistantOnboardingView(
        authState: .signedOut,
        connectionStatus: .disconnected,
        serviceError: nil,
        storageError: nil,
        signIn: {},
        initialStep: .welcome
    )
    .withPreviewEnvironment()
}
#endif
