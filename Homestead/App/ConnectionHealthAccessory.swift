import SwiftUI

nonisolated struct AppStatusAccessoryState: Equatable {
    enum Style: Equatable {
        case progress
        case success
        case warning
        case failure
    }

    let title: String
    let message: String
    let systemImage: String
    let style: Style
    let canRetry: Bool

    init(
        title: String,
        message: String,
        systemImage: String,
        style: Style,
        canRetry: Bool
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.style = style
        self.canRetry = canRetry
    }

    init(feedback: HAServiceFeedback) {
        self.init(
            title: feedback.title,
            message: feedback.message ?? Self.defaultMessage(for: feedback.style),
            systemImage: Self.systemImage(for: feedback.style),
            style: Self.style(for: feedback.style),
            canRetry: false
        )
    }

    private static func defaultMessage(for style: HAServiceFeedback.Style) -> String {
        switch style {
        case .success:
            ""
        case .failure:
            "Could not complete the action."
        }
    }

    private static func style(for feedbackStyle: HAServiceFeedback.Style) -> Style {
        switch feedbackStyle {
        case .success:
            .success
        case .failure:
            .failure
        }
    }

    private static func systemImage(for feedbackStyle: HAServiceFeedback.Style) -> String {
        switch feedbackStyle {
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }

    static func make(
        hasHomeAssistantSession: Bool,
        connectionStatus: HAConnectionStatus,
        dataFreshness: HADataFreshness,
        suppressTransientConnectionHealth: Bool = false
    ) -> AppStatusAccessoryState? {
        guard hasHomeAssistantSession else {
            return nil
        }

        let state: AppStatusAccessoryState?
        switch connectionStatus {
        case .reconnecting:
            state = reconnecting
        case .failed(let message):
            state = failed(message: message)
        case .disconnected:
            if let staleState = staleState(for: dataFreshness) {
                state = staleState
            } else {
                state = disconnected
            }
        case .preparing, .connecting:
            state = freshnessState(for: dataFreshness, suppressCached: true)
        case .connected:
            state = freshnessState(for: dataFreshness)
        }

        if suppressTransientConnectionHealth,
           state?.isTransientConnectionHealth == true {
            return nil
        }

        return state
    }

    private static func staleState(for dataFreshness: HADataFreshness) -> AppStatusAccessoryState? {
        guard case .stale = dataFreshness else {
            return nil
        }

        return freshnessState(for: dataFreshness)
    }

    private static func freshnessState(
        for dataFreshness: HADataFreshness,
        suppressCached: Bool = false
    ) -> AppStatusAccessoryState? {
        switch dataFreshness {
        case .cached(let date):
            guard !suppressCached else {
                return nil
            }

            return cached(lastUpdated: date)
        case .stale(_, let lastUpdated):
            return interrupted(lastUpdated: lastUpdated)
        case .empty, .refreshing, .live:
            return nil
        }
    }

    static func cached(lastUpdated: Date?) -> AppStatusAccessoryState {
        AppStatusAccessoryState(
            title: "Showing cached state",
            message: lastUpdatedMessage(lastUpdated: lastUpdated, fallback: "Waiting for live Home Assistant state."),
            systemImage: "clock.arrow.circlepath",
            style: .warning,
            canRetry: true
        )
    }

    private static func lastUpdatedMessage(lastUpdated: Date?, fallback: String) -> String {
        guard let lastUpdated else {
            return fallback
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeDate = formatter.localizedString(for: lastUpdated, relativeTo: Date())
        return "Last updated \(relativeDate)."
    }

    static let reconnecting = AppStatusAccessoryState(
        title: "Reconnecting",
        message: "Trying again automatically. Tap to retry now.",
        systemImage: "arrow.triangle.2.circlepath",
        style: .progress,
        canRetry: true
    )

    static let interrupted = interrupted(lastUpdated: nil)

    static func interrupted(lastUpdated: Date?) -> AppStatusAccessoryState {
        AppStatusAccessoryState(
            title: "Connection interrupted",
            message: staleMessage(lastUpdated: lastUpdated),
            systemImage: "wifi.exclamationmark",
            style: .warning,
            canRetry: true
        )
    }

    static let failed = AppStatusAccessoryState(
        title: "Connection failed",
        message: "Tap to retry or check Server settings.",
        systemImage: "exclamationmark.triangle.fill",
        style: .failure,
        canRetry: true
    )

    static func failed(message: String) -> AppStatusAccessoryState {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return failed
        }

        return AppStatusAccessoryState(
            title: "Connection failed",
            message: "Tap to retry. \(trimmed)",
            systemImage: "exclamationmark.triangle.fill",
            style: .failure,
            canRetry: true
        )
    }

    static let disconnected = AppStatusAccessoryState(
        title: "Disconnected",
        message: "Tap to reconnect.",
        systemImage: "wifi.slash",
        style: .warning,
        canRetry: true
    )

    private static func staleMessage(lastUpdated: Date?) -> String {
        guard let lastUpdated else {
            return "Using the latest cached state."
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeDate = formatter.localizedString(for: lastUpdated, relativeTo: Date())
        return "Last live update \(relativeDate)."
    }

    private var isTransientConnectionHealth: Bool {
        switch style {
        case .progress, .warning:
            true
        case .success, .failure:
            false
        }
    }
}

struct AppStatusAccessory: View {
    let state: AppStatusAccessoryState
    let retry: () -> Void

    var body: some View {
        Group {
            if state.canRetry {
                Button(action: retry) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(state.canRetry ? "Retries the Home Assistant connection." : "")
        .accessibilityAddTraits(state.canRetry ? .isButton : [])
        .background(.bar, in: Capsule())
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 6)
    }

    private var content: some View {
        HStack(spacing: AppSpacing.small) {
            statusIcon

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if showsMessage {
                    Text(state.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: AppSpacing.small)

            if state.canRetry {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if state.style == .progress {
            ProgressView()
                .controlSize(.small)
                .tint(tint)
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: state.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
        }
    }

    private var showsMessage: Bool {
        !state.message.isEmpty
    }

    private var tint: Color {
        switch state.style {
        case .progress:
            Color.accentColor
        case .success:
            Color.green
        case .warning:
            Color.orange
        case .failure:
            Color.red
        }
    }

    private var accessibilityLabel: String {
        guard !state.message.isEmpty else {
            return state.title
        }

        return "\(state.title), \(state.message)"
    }
}

#if DEBUG
#Preview("Connection Accessory - Reconnecting") {
    AppStatusAccessoryPreview(state: .reconnecting)
}

#Preview("Connection Accessory - Interrupted") {
    AppStatusAccessoryPreview(state: .interrupted)
}

#Preview("Connection Accessory - Failed") {
    AppStatusAccessoryPreview(state: .failed)
}

#Preview("Connection Accessory - Disconnected") {
    AppStatusAccessoryPreview(state: .disconnected)
}

private struct AppStatusAccessoryPreview: View {
    let state: AppStatusAccessoryState

    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Section("Preview") {
                        Text(state.title)
                        Text(state.message)
                    }
                }
                .navigationTitle("Homestead")
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                ContentUnavailableView("Areas", systemImage: "square.split.bottomrightquarter")
            }
            .tabItem {
                Label("Areas", systemImage: "square.split.bottomrightquarter")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .safeAreaInset(edge: .bottom, spacing: AppSpacing.small) {
            AppStatusAccessory(state: state) {}
                .padding(.horizontal, AppSpacing.large)
                .padding(.bottom, AppSpacing.small)
        }
    }
}
#endif
