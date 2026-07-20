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

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header
            actionPanel
            contextDetails
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: presentation.icon,
            category: "Button",
            summary: nil,
            status: nil,
            iconColor: presentation.isAvailable ? .accentColor : .secondary,
            iconBackground: presentation.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
        )
    }

    private var actionPanel: some View {
        EntityControlPanel(title: "Action", systemImage: "button.programmable") {
            EntityDetailActionButton(
                title: entityBox.pendingCommand != nil ? "Pressing..." : "Press",
                systemImage: "button.programmable",
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "button", service: "press")
            ) {
                confirmOrPerform(domain: "button", service: "press") {
                    Task { await homeAssistantService.pressButton(entityID: entity.entityID) }
                }
            }
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

    private var statusSummary: String {
        guard entity.isAvailable else { return "Button unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return entity.state == "unknown" ? "Ready for command" : entity.state.displayStateText
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
