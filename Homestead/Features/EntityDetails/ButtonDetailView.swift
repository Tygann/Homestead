import SwiftUI

struct ButtonDetailView: View {
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

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header
            EntityActivityHistoryPreview(entityBox: entityBox, tint: presentation.accentColor)
            contextDetails
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: "Button",
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: presentation.isAvailable ? .accentColor : .secondary,
            iconBackground: presentation.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            statePresentation: detailState,
            accessory: {
                EntityDetailHeroActionButton(
                    title: "Press",
                    systemImage: "button.programmable",
                    isDisabled: detailState.blocksControlInteraction || !homeAssistantService.serviceActionAvailable(domain: "button", service: "press")
                ) {
                    confirmOrPerform(domain: "button", service: "press") {
                        Task { await homeAssistantService.pressButton(entityID: entity.entityID) }
                    }
                }
            }
        ) {
            EmptyView()
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "button.programmable",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "Service", value: "button.press"),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private func confirmOrPerform(domain: String, service: String, perform: @escaping () -> Void) {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: domain,
            service: service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            perform()
            return
        }

        confirmationRequest = ActionConfirmationRequest(
            presentation: presentation,
            perform: perform
        )
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "button.restart_router") {
        ButtonDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
