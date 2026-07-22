import SwiftUI

struct GenericEntityDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedAction: HAEntityAction?
    @State private var availableActions: [HAEntityAction] = []

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: EntityDetailPresentationModel {
        EntityDetailPresentationModel(entityBox: entityBox)
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }
    private var features: EntityDetailFeatureSet {
        EntityDetailFeatureProvider.features(for: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            header
            if !availableActions.isEmpty {
                actionsPanel
            }
            if let source = features.activitySource {
                EntityActivityPanel(
                    entityID: entity.entityID,
                    source: source,
                    tint: presentation.accentColor
                )
            }
            contextDetails
        }
        .task(id: entity.entityID) {
            availableActions = await homeAssistantService.actions(for: entity.entityID)
        }
        .sheet(item: $selectedAction) { action in
            GenericEntityActionSheet(action: action, entity: entity)
        }
    }

    private var header: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: EntityCapabilityRegistry.profile(for: entity.domain).categoryTitle,
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: iconColor,
            statusColor: entity.isAvailable ? iconColor : .red,
            iconBackground: iconBackground,
            statusBackground: entity.isAvailable ? iconBackground : Color.red.opacity(0.12),
            statePresentation: detailState
        ) {
            Text(presentation.subtitle)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(stateColor)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionsPanel: some View {
        EntityControlPanel(title: "Actions", systemImage: "bolt.fill") {
            VStack(spacing: AppSpacing.small) {
                ForEach(availableActions) { action in
                    Button {
                        if action.fields.isEmpty {
                            Task {
                                await homeAssistantService.callService(
                                    domain: action.domain,
                                    service: action.service,
                                    entityID: entity.entityID,
                                    successTitle: action.displayName
                                )
                            }
                        } else {
                            selectedAction = action
                        }
                    } label: {
                        HStack(spacing: AppSpacing.medium) {
                            Image(systemName: "play.fill")
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.displayName)
                                    .font(.subheadline.weight(.semibold))
                                if !action.fields.isEmpty {
                                    Text("Configure options")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(detailState.blocksControlInteraction)
                }
            }
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var navigationTitle: String {
        entity.displayName
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        return presentation.isActive ? presentation.accentColor : .secondary
    }

    private var stateColor: Color {
        guard entity.isAvailable else { return .red }
        return presentation.isActive ? presentation.accentColor : .primary
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var badgeBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

}

#if DEBUG
#Preview {
    GenericEntityDetailView(
        entityBox: HAEntityState(
            homeEntity: HomeEntity(
                entityID: "weather.home",
                domain: .weather,
                displayName: "Home Weather",
                state: "partlycloudy",
                iconName: "cloud.sun.fill",
                isAvailable: true,
                lastUpdated: .now
            )
        )
    )
    .withPreviewEnvironment()
}
#endif
