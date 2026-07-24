import SwiftUI

// MARK: - Operational State

nonisolated enum EntityDetailOperationalState: Equatable, Sendable {
    case live
    case pending
    case stale
    case unavailable
    case failed
    case unsupported
}

enum EntityDetailStatusTone: Equatable {
    case accent
    case neutral
    case positive
    case warning
    case critical

    var foregroundColor: Color {
        switch self {
        case .accent: .accentColor
        case .neutral: .secondary
        case .positive: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

struct EntityDetailStatusPresentation: Equatable {
    let text: String
    let tone: EntityDetailStatusTone
}

@MainActor
struct EntityDetailStatePresentation: Equatable {
    let operationalState: EntityDetailOperationalState
    let status: EntityDetailStatusPresentation?
    let message: String?
    let blocksControlInteraction: Bool

    init(
        entityBox: HAEntityState,
        dataFreshness: HADataFreshness,
        connectionStatus: HAConnectionStatus,
        serviceFeedback: HAServiceFeedback?
    ) {
        let entity = entityBox.homeEntity
        let matchingFailure = serviceFeedback.flatMap { feedback in
            feedback.style == .failure && feedback.entityID == entity.entityID ? feedback : nil
        }

        if !entity.isAvailable {
            operationalState = .unavailable
            status = EntityDetailStatusPresentation(text: "Unavailable", tone: .critical)
            message = nil
            blocksControlInteraction = true
        } else if entityBox.pendingCommand != nil {
            operationalState = .pending
            status = EntityDetailStatusPresentation(text: "Updating", tone: .accent)
            message = "Waiting for Home Assistant confirmation."
            blocksControlInteraction = true
        } else if let matchingFailure {
            operationalState = .failed
            status = EntityDetailStatusPresentation(text: "Action Failed", tone: .critical)
            message = matchingFailure.message ?? "The action could not be completed. Try again."
            blocksControlInteraction = false
        } else if let stalePresentation = Self.stalePresentation(
            dataFreshness: dataFreshness,
            connectionStatus: connectionStatus
        ) {
            operationalState = .stale
            status = stalePresentation.status
            message = stalePresentation.message
            blocksControlInteraction = connectionStatus != .connected
        } else {
            operationalState = .live
            status = nil
            message = nil
            blocksControlInteraction = false
        }
    }

    static func resolve(
        entityBox: HAEntityState,
        service: HomeAssistantService
    ) -> EntityDetailStatePresentation {
        EntityDetailStatePresentation(
            entityBox: entityBox,
            dataFreshness: service.dataFreshness,
            connectionStatus: service.connectionStatus,
            serviceFeedback: service.serviceFeedback
        )
    }

    private static func stalePresentation(
        dataFreshness: HADataFreshness,
        connectionStatus: HAConnectionStatus
    ) -> (status: EntityDetailStatusPresentation, message: String)? {
        switch dataFreshness {
        case .cached:
            return (
                EntityDetailStatusPresentation(text: "Cached", tone: .warning),
                "Showing saved Home Assistant data."
            )
        case .refreshing(let lastUpdated) where lastUpdated != nil:
            return (
                EntityDetailStatusPresentation(text: "Refreshing", tone: .accent),
                "Refreshing while the last-known state remains visible."
            )
        case .stale:
            return (
                EntityDetailStatusPresentation(text: "Offline", tone: .warning),
                "Showing the last-known state while Home Assistant reconnects."
            )
        case .empty where connectionStatus != .connected:
            return (
                EntityDetailStatusPresentation(text: "Offline", tone: .warning),
                "Home Assistant is not currently connected."
            )
        case .empty, .refreshing, .live:
            return nil
        }
    }
}

enum EntityDetailHeroSubtitle {
    static func updated(
        _ entity: HomeEntity,
        summary: String? = nil,
        now: Date = .now
    ) -> Text? {
        let trimmedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let lastUpdated = entity.lastUpdated {
            let freshness = freshnessText(since: lastUpdated, now: now)
            if let trimmedSummary, !trimmedSummary.isEmpty {
                return Text("\(trimmedSummary) · Updated \(freshness)")
            }
            return Text("Updated \(freshness)")
        }

        if let trimmedSummary, !trimmedSummary.isEmpty {
            return Text(trimmedSummary)
        }
        return nil
    }

    static func freshnessText(since date: Date, now: Date = .now) -> String {
        let elapsed = max(now.timeIntervalSince(date), 0)

        switch elapsed {
        case ..<60:
            return "just now"
        case ..<3_600:
            return "\(max(Int(elapsed / 60), 1)) min ago"
        case ..<86_400:
            return "\(max(Int(elapsed / 3_600), 1)) hr ago"
        case ..<604_800:
            return "\(max(Int(elapsed / 86_400), 1)) d ago"
        default:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Hero Components

struct EntityDetailHeroCard<Content: View, Accessory: View>: View {
    let icon: ResolvedIcon
    let title: String
    let subtitle: Text?
    let status: String?
    let iconColor: Color
    let statusColor: Color
    let iconBackground: Color
    let statusBackground: Color
    let statePresentation: EntityDetailStatePresentation?
    private let content: Content
    private let accessory: Accessory

    init(
        icon: ResolvedIcon,
        title: String,
        subtitle: Text?,
        status: String?,
        iconColor: Color,
        statusColor: Color? = nil,
        iconBackground: Color? = nil,
        statusBackground: Color? = nil,
        statePresentation: EntityDetailStatePresentation? = nil,
        @ViewBuilder content: () -> Content
    ) where Accessory == EmptyView {
        self.init(
            icon: icon,
            title: title,
            subtitle: subtitle,
            status: status,
            iconColor: iconColor,
            statusColor: statusColor,
            iconBackground: iconBackground,
            statusBackground: statusBackground,
            statePresentation: statePresentation,
            accessory: { EmptyView() },
            content: content
        )
    }

    init(
        icon: ResolvedIcon,
        title: String,
        subtitle: Text?,
        status: String?,
        iconColor: Color,
        statusColor: Color? = nil,
        iconBackground: Color? = nil,
        statusBackground: Color? = nil,
        statePresentation: EntityDetailStatePresentation? = nil,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        let exceptionalStatus = statePresentation?.status

        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.status = exceptionalStatus?.text ?? status
        self.iconColor = iconColor
        self.statusColor = exceptionalStatus?.tone.foregroundColor ?? statusColor ?? iconColor
        self.iconBackground = iconBackground ?? iconColor.opacity(0.12)
        self.statusBackground = exceptionalStatus?.tone.backgroundColor ?? statusBackground ?? iconColor.opacity(0.12)
        self.statePresentation = statePresentation
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            EntityDetailHeroHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                status: status,
                iconColor: iconColor,
                statusColor: statusColor,
                iconBackground: iconBackground,
                statusBackground: statusBackground,
                accessory: { accessory }
            )

            content

            if let statePresentation,
               let message = statePresentation.message {
                EntityDetailStateMessage(
                    state: statePresentation.operationalState,
                    message: message
                )
            }
        }
        .padding(AppSpacing.large)
        .homesteadCardSurface()
    }
}

private struct EntityDetailHeroHeader<Accessory: View>: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let icon: ResolvedIcon
    let title: String
    let subtitle: Text?
    let status: String?
    let iconColor: Color
    let statusColor: Color
    let iconBackground: Color
    let statusBackground: Color
    @ViewBuilder let accessory: Accessory

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                identity
                    .layoutPriority(1)
                Spacer(minLength: AppSpacing.medium)
                trailingContent
            }

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .center, spacing: AppSpacing.medium) {
                    identity
                        .layoutPriority(1)
                    Spacer(minLength: AppSpacing.medium)
                    accessory
                }

                statusBadge
            }
        }
    }

    private var trailingContent: some View {
        HStack(spacing: AppSpacing.medium) {
            statusBadge
            accessory
        }
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            HomesteadIconView(icon: icon, pointSize: 25)
                .foregroundStyle(iconColor)
                .frame(width: 52, height: 52)
                .background(
                    isWallpaperSurfaceActive ? iconColor.opacity(0.12) : iconBackground,
                    in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    subtitle
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let status, !status.isEmpty {
            Text(status)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
                .background(
                    isWallpaperSurfaceActive ? statusColor.opacity(0.12) : statusBackground,
                    in: Capsule()
                )
        }
    }
}

struct EntityDetailStateMessage: View {
    let state: EntityDetailOperationalState
    let message: String

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(foregroundColor)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.medium)
            .background(foregroundColor.opacity(0.1), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private var systemImage: String {
        switch state {
        case .pending, .stale: "arrow.triangle.2.circlepath"
        case .failed, .unavailable: "exclamationmark.triangle.fill"
        case .live: "checkmark.circle.fill"
        case .unsupported: "nosign"
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .pending: .accentColor
        case .stale: .orange
        case .failed, .unavailable: .red
        case .live: .green
        case .unsupported: .secondary
        }
    }
}

struct EntityDetailHeader: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState?
    let icon: ResolvedIcon
    let title: String
    let heroSubtitle: Text?
    let normalStatus: EntityDetailStatusPresentation?
    let iconColor: Color
    let iconBackground: Color
    let legacyBadgeColor: Color?
    let legacyBadgeBackground: Color?

    init(
        entityBox: HAEntityState,
        icon: ResolvedIcon,
        category: String? = nil,
        summary: String? = nil,
        status: EntityDetailStatusPresentation? = nil,
        iconColor: Color,
        iconBackground: Color? = nil
    ) {
        self.entityBox = entityBox
        self.icon = icon
        title = category ?? EntityCapabilityRegistry.profile(for: entityBox.domain).categoryTitle
        heroSubtitle = EntityDetailHeroSubtitle.updated(entityBox.homeEntity, summary: summary)
        normalStatus = status
        self.iconColor = iconColor
        self.iconBackground = iconBackground ?? iconColor.opacity(0.12)
        legacyBadgeColor = nil
        legacyBadgeBackground = nil
    }

    init(
        icon: ResolvedIcon,
        title: String,
        subtitle: String,
        badge: String,
        iconColor: Color,
        badgeColor: Color? = nil,
        iconBackground: Color? = nil,
        badgeBackground: Color? = nil
    ) {
        entityBox = nil
        self.icon = icon
        self.title = title
        heroSubtitle = Text(subtitle)
        normalStatus = badge.isEmpty ? nil : EntityDetailStatusPresentation(text: badge, tone: .accent)
        self.iconColor = iconColor
        self.iconBackground = iconBackground ?? iconColor.opacity(0.12)
        legacyBadgeColor = badgeColor
        legacyBadgeBackground = badgeBackground
    }

    init(
        iconName: String,
        title: String,
        subtitle: String,
        badge: String,
        iconColor: Color,
        badgeColor: Color? = nil,
        iconBackground: Color? = nil,
        badgeBackground: Color? = nil
    ) {
        self.init(
            icon: .sfSymbol(iconName, provenance: .homesteadSemanticMapping),
            title: title,
            subtitle: subtitle,
            badge: badge,
            iconColor: iconColor,
            badgeColor: badgeColor,
            iconBackground: iconBackground,
            badgeBackground: badgeBackground
        )
    }

    var body: some View {
        EntityDetailHeroCard(
            icon: icon,
            title: title,
            subtitle: heroSubtitle,
            status: normalStatus?.text,
            iconColor: iconColor,
            statusColor: legacyBadgeColor ?? normalStatus?.tone.foregroundColor,
            iconBackground: iconBackground,
            statusBackground: legacyBadgeBackground ?? normalStatus?.tone.backgroundColor,
            statePresentation: statePresentation
        ) {
            EmptyView()
        }
    }

    private var statePresentation: EntityDetailStatePresentation? {
        entityBox.map {
            EntityDetailStatePresentation.resolve(
                entityBox: $0,
                service: homeAssistantService
            )
        }
    }
}
