import SwiftUI

nonisolated struct ConnectionHealthAccessoryState: Equatable {
    enum Style: Equatable {
        case progress
        case warning
        case failure
    }

    let title: String
    let message: String
    let systemImage: String
    let style: Style
    let canRetry: Bool

    static func make(
        hasHomeAssistantSession: Bool,
        connectionStatus: HAConnectionStatus,
        dataFreshness: HADataFreshness
    ) -> ConnectionHealthAccessoryState? {
        guard hasHomeAssistantSession else {
            return nil
        }

        switch connectionStatus {
        case .reconnecting:
            return reconnecting
        case .failed:
            return failed
        case .disconnected:
            if let staleState = staleState(for: dataFreshness) {
                return staleState
            }

            return disconnected
        case .connecting, .connected:
            return staleState(for: dataFreshness)
        }
    }

    private static func staleState(for dataFreshness: HADataFreshness) -> ConnectionHealthAccessoryState? {
        if case .stale(_, let lastUpdated) = dataFreshness {
            return interrupted(lastUpdated: lastUpdated)
        }

        return nil
    }

    static let reconnecting = ConnectionHealthAccessoryState(
        title: "Reconnecting",
        message: "Restoring live Home Assistant state.",
        systemImage: "arrow.triangle.2.circlepath",
        style: .progress,
        canRetry: false
    )

    static let interrupted = interrupted(lastUpdated: nil)

    static func interrupted(lastUpdated: Date?) -> ConnectionHealthAccessoryState {
        ConnectionHealthAccessoryState(
            title: "Connection interrupted",
            message: staleMessage(lastUpdated: lastUpdated),
            systemImage: "wifi.exclamationmark",
            style: .warning,
            canRetry: true
        )
    }

    static let failed = ConnectionHealthAccessoryState(
        title: "Connection failed",
        message: "Tap to retry.",
        systemImage: "exclamationmark.triangle.fill",
        style: .failure,
        canRetry: true
    )

    static let disconnected = ConnectionHealthAccessoryState(
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
}

struct ConnectionHealthAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let state: ConnectionHealthAccessoryState
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
        .accessibilityAddTraits(state.canRetry ? .isButton : [])
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
        placement != .inline
    }

    private var tint: Color {
        switch state.style {
        case .progress:
            Color.accentColor
        case .warning:
            Color.orange
        case .failure:
            Color.red
        }
    }
}

#if DEBUG
#Preview("Connection Accessory - Reconnecting") {
    ConnectionHealthAccessoryPreview(state: .reconnecting)
}

#Preview("Connection Accessory - Interrupted") {
    ConnectionHealthAccessoryPreview(state: .interrupted)
}

#Preview("Connection Accessory - Failed") {
    ConnectionHealthAccessoryPreview(state: .failed)
}

#Preview("Connection Accessory - Disconnected") {
    ConnectionHealthAccessoryPreview(state: .disconnected)
}

private struct ConnectionHealthAccessoryPreview: View {
    let state: ConnectionHealthAccessoryState

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
        .tabViewBottomAccessory(isEnabled: true) {
            ConnectionHealthAccessory(state: state) {}
        }
    }
}
#endif
