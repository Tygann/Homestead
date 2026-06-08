import SwiftUI

struct DashboardHeaderCardView: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: AppSpacing.medium)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, AppSpacing.small)
        .padding(.top, AppSpacing.small)
        .padding(.bottom, AppSpacing.xSmall)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.32))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DashboardSection<Content: View>: View {
    let isEmpty: Bool
    @ViewBuilder var content: Content

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                content
            }
        }
    }
}

struct DashboardSetupCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "house")
                Text("Connect Home Assistant")
                    .font(.headline)
                Text("Add your server URL in Settings, then sign in with Home Assistant.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DashboardInitialSyncView: View {
    let connectionStatus: HAConnectionStatus
    let errorMessage: String?
    let reconnect: () -> Void

    var body: some View {
        switch connectionStatus {
        case .failed:
            DashboardInitialSyncFailureCard(
                errorMessage: errorMessage,
                reconnect: reconnect
            )
        case .disconnected, .connecting, .connected, .reconnecting:
            DashboardLoadingPlaceholderView(connectionStatus: connectionStatus)
        }
    }
}

private struct DashboardLoadingPlaceholderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let connectionStatus: HAConnectionStatus
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                    .controlSize(.small)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .accessibilityElement(children: .combine)

            VStack(spacing: AppSpacing.medium) {
                DashboardSkeletonCard(size: .wide)

                CardGrid {
                    DashboardSkeletonCard(size: .square)
                        .cardGridSpan(DashboardCardSize.square.layoutMetadata)
                    DashboardSkeletonCard(size: .compact)
                        .cardGridSpan(DashboardCardSize.compact.layoutMetadata)
                    DashboardSkeletonCard(size: .compact)
                        .cardGridSpan(DashboardCardSize.compact.layoutMetadata)
                    DashboardSkeletonCard(size: .square)
                        .cardGridSpan(DashboardCardSize.square.layoutMetadata)
                    DashboardSkeletonCard(size: .compact)
                        .cardGridSpan(DashboardCardSize.compact.layoutMetadata)
                    DashboardSkeletonCard(size: .square)
                        .cardGridSpan(DashboardCardSize.square.layoutMetadata)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(skeletonOpacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.large)
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else {
                isPulsing = false
                return
            }

            isPulsing = true
        }
    }

    private var skeletonOpacity: Double {
        reduceMotion ? 0.72 : (isPulsing ? 0.46 : 0.72)
    }

    private var title: String {
        switch connectionStatus {
        case .reconnecting:
            "Reconnecting"
        case .connecting:
            "Connecting"
        case .connected:
            "Loading Dashboard"
        case .disconnected, .failed:
            "Loading Dashboard"
        }
    }

    private var message: String {
        switch connectionStatus {
        case .reconnecting:
            "Restoring live state"
        case .disconnected:
            "Preparing"
        case .connecting, .connected, .failed:
            "Fetching latest state"
        }
    }
}

private struct DashboardSkeletonCard: View {
    let size: DashboardCardSize

    var body: some View {
        CardContainer(minHeight: cardContainerMinHeight) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .center, spacing: AppSpacing.medium) {
                    RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        skeletonLine(width: titleWidth, height: 13)
                        skeletonLine(width: 54, height: 11)
                    }
                }

                if size.rowSpan > 1 {
                    skeletonLine(width: 96, height: 24)
                }
            }
            .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
        }
    }

    private var cardContainerMinHeight: CGFloat {
        size.contentMinHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }

    private var cardContentMinHeight: CGFloat {
        max(0, cardContainerMinHeight - (AppSpacing.medium * 2))
    }

    private var titleWidth: CGFloat {
        switch size {
        case .mini:
            0
        case .compact:
            86
        case .row:
            154
        case .square:
            112
        case .wide:
            154
        case .large:
            180
        }
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
            .frame(width: width, height: height)
    }
}

private struct DashboardInitialSyncFailureCard: View {
    let errorMessage: String?
    let reconnect: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "exclamationmark.triangle.fill")

                Text("Unable to load Home Assistant")
                    .font(.headline)

                Text(errorMessage ?? "Check your connection settings and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Reconnect", systemImage: "arrow.triangle.2.circlepath", action: reconnect)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, AppSpacing.small)
            }
        }
    }
}

struct EmptyDashboardCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "square.grid.2x2")
                Text("No Home Assistant entities found")
                    .font(.headline)
                Text("Home Assistant loaded successfully, but did not return any entities.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct EmptyConfiguredDashboardCard: View {
    let isEditing: Bool
    let addCards: () -> Void
    let addHeader: () -> Void
    let reset: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "square.grid.2x2")
                Text("No cards selected")
                    .font(.headline)
                Text(isEditing ? "Use the plus button to add dashboard items or section headers." : "Choose Edit Home View to add cards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: AppSpacing.small) {
                    if isEditing {
                        Button("Add to Dashboard", systemImage: "plus", action: addCards)
                            .buttonStyle(.borderedProminent)

                        Button("Add Section Header", systemImage: "textformat.size", action: addHeader)
                            .buttonStyle(.bordered)

                        Button("Restore Suggested Cards", action: reset)
                            .buttonStyle(.bordered)
                    } else {
                        Button("Restore Suggested Cards", action: reset)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, AppSpacing.small)
            }
        }
    }
}
