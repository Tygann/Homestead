import SwiftUI

struct ToggleEntityDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?

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
            if let source = features.activitySource {
                EntityActivityPreview(
                    entityID: entity.entityID,
                    source: source,
                    tint: presentation.accentColor
                )
            }
            stateDetails
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: entityCategory,
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: presentation.isActive ? presentation.accentColor : Color.secondary,
            iconBackground: iconBackground,
            statePresentation: detailState,
            accessory: {
                EntityDetailStateToggle(
                    isOn: presentation.isActive,
                    accessibilityLabel: "\(entityCategory) power",
                    isDisabled: detailState.blocksControlInteraction || !isActionServiceAvailable
                ) { requestedState in
                    Task { await performPrimaryAction(requestedState: requestedState) }
                }
            }
        ) {
            EmptyView()
        }
    }

    private var stateDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "waveform.path.ecg",
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

    private var entityCategory: String {
        EntityCapabilityRegistry.profile(for: entity.domain).categoryTitle
    }

    private var isActionServiceAvailable: Bool {
        entity.domain == .switch
            && homeAssistantService.serviceActionAvailable(
                domain: "switch",
                service: presentation.isActive ? "turn_off" : "turn_on"
            )
    }

    private var iconBackground: Color {
        presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func performPrimaryAction(requestedState: Bool) async {
        guard entity.domain == .switch else { return }
        let service = requestedState ? "turn_on" : "turn_off"
        await confirmOrPerform(domain: "switch", service: service) {
            await homeAssistantService.toggleSwitch(entityID: entity.entityID)
        }
    }

    private func confirmOrPerform(
        domain: String,
        service: String,
        perform: @escaping () async -> Void
    ) async {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: domain,
            service: service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            await perform()
            return
        }

        confirmationRequest = ActionConfirmationRequest(
            presentation: presentation,
            perform: {
                Task { await perform() }
            }
        )
    }

}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "switch.coffee_maker") {
        ToggleEntityDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
