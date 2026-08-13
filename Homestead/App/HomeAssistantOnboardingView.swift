import SwiftUI
import UIKit

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

    static func isValidServerAddress(_ address: String) -> Bool {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            return false
        }

        return (try? HomeAssistantEndpointBuilder.authTokenURL(from: trimmedAddress)) != nil
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
        case .accessTokenExpired, .refreshFailed:
            return "Sign In Again"
        case .signedOut, .signedIn:
            return "Sign In"
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isURLFieldFocused: Bool
    @State private var isEnteringAddress = false
    @State private var draftBaseURL = ""
    @State private var draftDiscoveredSignInURL = ""
    @State private var draftDiscoveredName = ""
    @State private var draftInternalURL = ""
    @State private var draftExternalURL = ""
    @State private var hasAttemptedInvalidAddress = false
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
        initialStep: Step? = nil,
        initiallyEditingServer: Bool = false,
        initialDraftBaseURL: String = ""
    ) {
        self.authState = authState
        self.connectionStatus = connectionStatus
        self.serviceError = serviceError
        self.storageError = storageError
        self.signIn = signIn
        _selectedStep = State(initialValue: initialStep)
        _isEnteringAddress = State(initialValue: initiallyEditingServer)
        _draftBaseURL = State(initialValue: initialDraftBaseURL)
    }

    // MARK: - Body

    var body: some View {
        @Bindable var connectionSettings = connectionSettings
        let hasPresentedServerURL = showsServerEditor
            ? hasValidDraftServerURL
            : connectionSettings.hasServerURL
        let presentation = HomeAssistantOnboardingPresentation.make(
            hasServerURL: hasPresentedServerURL,
            authState: authState,
            connectionStatus: connectionStatus,
            serviceError: serviceError,
            storageError: storageError
        )

        Group {
            if currentStep == .welcome {
                welcomeScreen
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                setupScreen(presentation: presentation)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .onChange(of: draftBaseURL) { _, newValue in
            if HomeAssistantOnboardingPresentation.isValidServerAddress(newValue) {
                hasAttemptedInvalidAddress = false
            }

            guard newValue.trimmingCharacters(in: .whitespacesAndNewlines) != draftDiscoveredSignInURL else {
                return
            }

            draftDiscoveredName = ""
            draftDiscoveredSignInURL = ""
            draftInternalURL = ""
            draftExternalURL = ""
        }
        .onChange(of: isURLFieldFocused) { _, isFocused in
            let hasAddress = !draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !isFocused, hasAddress, !hasValidDraftServerURL {
                hasAttemptedInvalidAddress = true
            }
        }
    }

    // MARK: - Welcome

    private var welcomeScreen: some View {
        ZStack {
            HomesteadOnboardingBackground()

            ScrollView {
                VStack(spacing: AppSpacing.xLarge) {
                    VStack(spacing: AppSpacing.medium) {
                        onboardingBrandMark
                        welcomeMessage
                    }
                    OnboardingHomePreview()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, onboardingContentTopPadding)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                welcomeAction
            }
        }
        .preferredColorScheme(.dark)
    }

    private var onboardingBrandMark: some View {
        Image("HomesteadLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .accessibilityHidden(true)
    }

    private var welcomeMessage: some View {
        VStack(spacing: AppSpacing.medium) {
            Text("Your home at a glance")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("A fast, native way to control and\nunderstand your Home Assistant home.")
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
            navigateToSetup()
        } label: {
            ZStack {
                Text("Get Started")
                    .fontWeight(.semibold)

                HStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AppSpacing.medium)
            .foregroundStyle(.white)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
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
                .padding(.top, onboardingContentTopPadding)
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
            onboardingBrandMark

            VStack(spacing: AppSpacing.small) {
                Text(showsServerEditor ? "Find Your Home" : "Connect Your Home")
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
        if !showsServerEditor {
            return "Continue securely through Home Assistant to finish setup."
        }

        return "We’ll look for Home Assistant on your local network."
    }

    private func setupGroup(
        presentation: HomeAssistantOnboardingPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if showsServerEditor {
                VStack(spacing: AppSpacing.medium) {
                    Button {
                        isURLFieldFocused = false
                        discoveryService.start()
                    } label: {
                        HStack(spacing: AppSpacing.small) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundStyle(Color.accentColor)
                            Text("Search Local Network")
                                .foregroundStyle(.white)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)

                    if draftDiscoveredName.isEmpty {
                        discoveryResults
                    } else {
                        selectedDiscoveredServer
                    }

                    HStack(spacing: AppSpacing.small) {
                        Rectangle()
                            .fill(.white.opacity(0.16))
                            .frame(height: 1)
                        Text("or")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(.white.opacity(0.16))
                            .frame(height: 1)
                    }

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

                        if hasAttemptedInvalidAddress {
                            Label(
                                "Enter a valid Home Assistant address, such as homeassistant.local:8123.",
                                systemImage: "exclamationmark.circle.fill"
                            )
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(AppSpacing.medium)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: AppRadius.card))
                }
            } else {
                selectedServerCard(presentation: presentation)
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
                        draftBaseURL = instance.signInURL
                        draftDiscoveredSignInURL = instance.signInURL
                        draftDiscoveredName = instance.name
                        draftInternalURL = instance.internalURL ?? ""
                        draftExternalURL = instance.externalURL ?? ""
                        isURLFieldFocused = false
                        discoveryService.stop()
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
            VStack(spacing: AppSpacing.small) {
                Label("Couldn’t Search the Local Network", systemImage: "wifi.exclamationmark")
                    .font(.subheadline.weight(.semibold))
                Text("Check Local Network access in Settings, retry, or enter the address below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
        }
    }

    private var selectedDiscoveredServer: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "house.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(draftDiscoveredName)
                    .font(.subheadline.weight(.semibold))
                Text(draftDiscoveredSignInURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Selected")
        }
        .padding(AppSpacing.medium)
        .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.card))
        .accessibilityElement(children: .combine)
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
                        draftDiscoveredName = ""
                        draftDiscoveredSignInURL = ""
                        draftInternalURL = ""
                        draftExternalURL = ""
                        isEnteringAddress = true
                        isURLFieldFocused = false
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
                    navigateBack()
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
                    } else {
                        Image(systemName: "house.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }

                    Text(presentation.buttonTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, AppSpacing.medium)
                .foregroundStyle(.white)
            }
            .buttonStyle(.glass)
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
            if showsServerEditor {
                hasAttemptedInvalidAddress = true
                isURLFieldFocused = false
            }
            return
        }

        isURLFieldFocused = false
        commitDraftBaseURLIfNeeded()
        signIn()
    }

    private func navigateBack() {
        isURLFieldFocused = false
        discoveryService.stop()

        if isEnteringAddress, connectionSettings.hasServerURL {
            draftBaseURL = connectionSettings.baseURL
            draftDiscoveredName = ""
            draftDiscoveredSignInURL = ""
            draftInternalURL = ""
            draftExternalURL = ""
            isEnteringAddress = false
            return
        }

        updateStep(.welcome)
    }

    private func navigateToSetup() {
        updateStep(.setup)
    }

    private func updateStep(_ step: Step) {
        if reduceMotion {
            selectedStep = step
        } else {
            withAnimation(.smooth(duration: 0.35)) {
                selectedStep = step
            }
        }
    }

    private func commitDraftBaseURLIfNeeded() {
        guard showsServerEditor else {
            return
        }

        let trimmedBaseURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else {
            return
        }

        let previousBaseURL = connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        connectionSettings.baseURL = trimmedBaseURL

        if trimmedBaseURL == draftDiscoveredSignInURL {
            connectionSettings.internalURL = draftInternalURL
            connectionSettings.externalURL = draftExternalURL
        } else if trimmedBaseURL != previousBaseURL {
            connectionSettings.internalURL = ""
            connectionSettings.externalURL = ""
        }

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

    private var showsServerEditor: Bool {
        isEnteringAddress || !connectionSettings.hasServerURL
    }

    private var hasValidDraftServerURL: Bool {
        HomeAssistantOnboardingPresentation.isValidServerAddress(draftBaseURL)
    }

    private var onboardingContentTopPadding: CGFloat {
        72
    }

}

// MARK: - Welcome Artwork

private struct OnboardingHomePreview: View {
    private static let designSize: CGFloat = 390
    private static let cardSpacing: CGFloat = AppSpacing.medium
    private static let cardPadding: CGFloat = AppSpacing.medium

    var body: some View {
        GeometryReader { proxy in
            let sideLength = proxy.size.width

            ZStack(alignment: .topLeading) {
                previewShape
                    .fill(Color.white.opacity(0.065))

                dashboardContent
                    .frame(width: Self.designSize, height: Self.designSize, alignment: .topLeading)
                    .scaleEffect(sideLength / Self.designSize, anchor: .topLeading)
                    .frame(width: sideLength, height: sideLength, alignment: .topLeading)
            }
            .frame(width: sideLength, height: sideLength)
            .clipShape(previewShape)
            .overlay {
                previewShape
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 20, y: 12)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample Homestead dashboard with summary chips and Home controls")
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: Self.cardSpacing) {
            HStack(spacing: AppSpacing.small) {
                chip(title: "Climate", value: "72°", image: "thermometer.medium", active: true, tint: .climate)
                chip(title: "Lights", value: "3 On", image: "lightbulb.fill", active: true, tint: .lights)
                chip(title: "Security", value: "All Secure", image: "lock.fill", active: true, tint: .security)
                chip(title: "Media", value: "All Idle", image: "play.rectangle.fill", active: false, tint: .media)
            }

            DashboardCardView(
                entityID: "climate.gallery",
                size: .row,
                presentationKind: .control,
                displayNameOverride: "Thermostat",
                isPreview: true
            )
            .frame(height: rowCardHeight)

            HStack(spacing: AppSpacing.small) {
                DashboardCardView(
                    entityID: "lock.gallery",
                    size: .square,
                    presentationKind: .control,
                    isPreview: true
                )

                DashboardCardView(
                    entityID: "sensor.gallery_temperature",
                    size: .square,
                    presentationKind: .chart,
                    displayNameOverride: "Temperature",
                    isPreview: true
                )
            }
            .frame(height: squareCardHeight)

            HStack(spacing: AppSpacing.small) {
                DashboardCardView(
                    entityID: "light.gallery",
                    size: .compact,
                    presentationKind: .control,
                    isPreview: true
                )

                DashboardCardView(
                    entityID: "cover.gallery",
                    size: .compact,
                    presentationKind: .control,
                    isPreview: true
                )
            }
            .frame(height: compactCardHeight)

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.medium)
        .environment(DashboardPresentationGallerySamples.stateStore)
        .environment(\.homesteadWallpaperSurfaceActive, true)
        .allowsHitTesting(false)
    }

    private var previewShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
    }

    private var previewCornerRadius: CGFloat {
        24
    }

    private func chip(
        title: String,
        value: String,
        image: String,
        active: Bool,
        tint: DashboardChipIconTint
    ) -> some View {
        DashboardChipView(presentation: DashboardChipPresentation(
            title: title,
            value: value,
            systemImage: image,
            isActive: active,
            isAvailable: true,
            iconTint: tint
        ))
        .frame(maxWidth: .infinity)
    }

    private var rowCardHeight: CGFloat {
        DashboardCardSize.row.renderedHeight(
            rowSpacing: Self.cardSpacing,
            cardPadding: Self.cardPadding
        )
    }

    private var squareCardHeight: CGFloat {
        DashboardCardSize.square.renderedHeight(
            rowSpacing: Self.cardSpacing,
            cardPadding: Self.cardPadding
        )
    }

    private var compactCardHeight: CGFloat {
        DashboardCardSize.compact.renderedHeight(
            rowSpacing: Self.cardSpacing,
            cardPadding: Self.cardPadding
        )
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
