import SwiftUI

struct DashboardCardView: View {
    let entityID: String
    let size: DashboardCardSize
    var displayNameOverride: String?
    var iconNameOverride: String?
    var contextualAreaName: String?
    var isEditing = false

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedDetail: DashboardCardDetail?

    var body: some View {
        if let entityBox = stateStore.entityBox(for: entityID) {
            let presentation = DashboardEntityPresentation(
                entityBox: entityBox,
                displayNameOverride: resolvedDisplayNameOverride(for: entityBox),
                iconNameOverride: iconNameOverride
            )

            DashboardEntityCard(
                presentation: presentation,
                size: size,
                isPending: entityBox.pendingCommand != nil,
                isPrimaryActionAvailable: primaryActionAvailability(for: entityBox),
                toggle: isEditing ? nil : primaryAction(for: entityBox),
                showDetails: isEditing ? nil : detailsAction(for: entityBox)
            )
            .sheet(item: $selectedDetail) { detail in
                if let selectedEntityBox = stateStore.entityBox(for: detail.entityID) {
                    DashboardEntityDetailSheet(entityBox: selectedEntityBox)
                } else {
                    ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                }
            }
        }
    }

    private func resolvedDisplayNameOverride(for entityBox: HAEntityState) -> String? {
        EntityDisplayNameResolver.displayName(
            canonicalName: entityBox.homeEntity.displayName,
            overrideName: displayNameOverride ?? dashboardConfiguration.entityDisplayNameOverride(for: entityID),
            contextualAreaName: contextualAreaName
        )
    }

    private func primaryAction(for entityBox: HAEntityState) -> (() -> Void)? {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)

        if let primaryAction = presentation.primaryAction {
            return {
                HapticFeedback.selection()
                Task {
                    await homeAssistantService.perform(primaryAction, entityID: entityBox.entityID)
                }
            }
        }

        return nil
    }

    private func primaryActionAvailability(for entityBox: HAEntityState) -> Bool {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        guard let primaryAction = presentation.primaryAction else {
            return true
        }

        return homeAssistantService.serviceActionAvailable(primaryAction, entityID: entityBox.entityID)
    }

    private func detailsAction(for entityBox: HAEntityState) -> (() -> Void)? {
        return {
            selectedDetail = DashboardCardDetail(
                entityID: entityBox.entityID,
                kind: detailKind(for: entityBox)
            )
        }
    }

    private func detailKind(for entityBox: HAEntityState) -> DashboardCardDetail.Kind {
        switch DashboardEntityPresentation(entityBox: entityBox).detailKind {
        case .light:
            .light
        case .cover:
            .cover
        case .climate:
            .climate
        case .fan:
            .fan
        case .lock:
            .lock
        case .toggle:
            .toggle
        case .action:
            .action
        case .sensor:
            .sensor
        case .mediaPlayer:
            .mediaPlayer
        case .camera:
            .camera
        case .vacuum:
            .vacuum
        case .entity:
            .entity
        }
    }
}

private struct DashboardCardDetail: Identifiable {
    enum Kind {
        case light
        case cover
        case climate
        case fan
        case lock
        case toggle
        case action
        case sensor
        case mediaPlayer
        case camera
        case vacuum
        case entity
    }

    let entityID: String
    let kind: Kind

    var id: String {
        "\(kind)-\(entityID)"
    }
}

struct DashboardEntityDetailSheet: View {
    let entityBox: HAEntityState

    var body: some View {
        switch DashboardEntityPresentation(entityBox: entityBox).detailKind {
        case .light:
            LightDetailView(entityBox: entityBox)
        case .cover:
            CoverDetailView(entityBox: entityBox)
        case .climate:
            ClimateDetailView(entityBox: entityBox)
        case .fan:
            FanDetailView(entityBox: entityBox)
        case .lock:
            LockDetailView(entityBox: entityBox)
        case .toggle:
            ToggleEntityDetailView(entityBox: entityBox)
        case .action:
            ActionEntityDetailView(entityBox: entityBox)
        case .sensor:
            SensorDetailView(entityBox: entityBox)
        case .mediaPlayer:
            MediaPlayerDetailView(entityBox: entityBox)
        case .camera:
            CameraDetailView(entityBox: entityBox)
        case .vacuum:
            VacuumDetailView(entityBox: entityBox)
        case .entity:
            EntityDetailView(entityBox: entityBox)
        }
    }
}

private struct DashboardEntityCard: View {
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let isPending: Bool
    let isPrimaryActionAvailable: Bool
    let toggle: (() -> Void)?
    let showDetails: (() -> Void)?

    var body: some View {
        CardContainer(isActive: presentation.isActive, minHeight: cardContainerMinHeight) {
            ZStack(alignment: .topLeading) {
                if let showDetails {
                    Button(action: showDetails) {
                        cardContent
                            .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .accessibilityLabel(presentation.accessibilityDetailLabel)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.accessibilityDetailHint)
                } else {
                    cardContent
                        .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                }

                if let toggle {
                    Button(action: toggle) {
                        CardIconView(
                            systemName: presentation.iconName,
                            isActive: presentation.isActive
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending || !isPrimaryActionAvailable)
                    .accessibilityLabel(presentation.primaryActionAccessibilityLabel ?? presentation.title)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.primaryActionAccessibilityHint)
                }

            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch size {
        case .mini:
            miniContent
        case .compact, .row:
            compactContent
        case .square, .wide, .large:
            largeContent
        }
    }

    private var miniContent: some View {
        iconPlaceholder
    }

    private var compactContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(presentation.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        }
    }

    private var largeContent: some View {
        let contentModel = DashboardEntityCardContentModel.make(
            presentation: presentation,
            size: size
        )

        return VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                iconPlaceholder
                
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(presentation.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(presentation.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(presentation.subtitleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            if let headline = contentModel.headline {
                Text(headline)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if !contentModel.metrics.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    ForEach(contentModel.metrics) { metric in
                        DashboardCardMetricRow(metric: metric)
                    }
                }
            }
        }
    }

    private var iconPlaceholder: some View {
        Color.clear
            .frame(width: 44, height: 44)
            .overlay(alignment: .topLeading) {
                if toggle == nil {
                    CardIconView(systemName: presentation.iconName, isActive: presentation.isActive)
                }
            }
    }
    
    private var cardContentMinHeight: CGFloat {
        max(0, cardContainerMinHeight - (AppSpacing.medium * 2))
    }

    private var cardContainerMinHeight: CGFloat {
        size.contentMinHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }
}

private struct DashboardCardMetricRow: View {
    let metric: DashboardEntityCardMetric

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Image(systemName: metric.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(metric.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.small)

            Text(metric.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.trailing)
        }
    }
}

#if DEBUG
private struct DashboardCardDisplaySizesPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
//            HStack(alignment: .top, spacing: AppSpacing.medium) {/
                DashboardCardView(entityID: "light.living_room_lamps", size: .mini)
                    .frame(width: 82)

                DashboardCardView(entityID: "light.living_room_lamps", size: .compact)
                    .frame(width: 180)

                DashboardCardView(entityID: "sensor.hallway_temperature", size: .square)
                    .frame(width: 180)
//            }

            DashboardCardView(entityID: "sensor.hallway_temperature", size: .row)
                .frame(width: 376)

            DashboardCardView(entityID: "sensor.hallway_temperature", size: .wide)
                .frame(width: 376)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Display Sizes") {
    DashboardCardDisplaySizesPreview()
        .withPreviewEnvironment()
}

private struct DashboardCardEditModePreview: View {
    @State private var size: DashboardCardSize = .square

    var body: some View {
        DashboardCardView(
            entityID: "light.living_room_lamps",
            size: size,
            isEditing: true
        )
        .frame(width: previewWidth)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var previewWidth: CGFloat {
        switch size {
        case .mini:
            82
        case .compact, .square:
            180
        case .row, .wide, .large:
            376
        }
    }
}

#Preview("Edit Mode") {
    DashboardCardEditModePreview()
        .withPreviewEnvironment()
}
#endif
