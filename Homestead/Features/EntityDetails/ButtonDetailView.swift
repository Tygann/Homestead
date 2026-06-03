import SwiftUI

struct ButtonDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: "Button", presentationStyle: presentationStyle) {
            header
            actionPanel
            contextDetails
        }
    }

    private var header: some View {
        EntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: statusSummary,
            badge: presentation.isAvailable ? "Ready" : "Unavailable",
            iconColor: presentation.isAvailable ? .accentColor : .secondary,
            badgeColor: presentation.isAvailable ? .accentColor : .red,
            iconBackground: presentation.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            badgeBackground: presentation.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12)
        )
    }

    private var actionPanel: some View {
        EntityControlPanel(title: "Action", systemImage: "button.programmable") {
            EntityDetailActionButton(
                title: entityBox.pendingCommand != nil ? "Pressing..." : "Press",
                systemImage: "button.programmable",
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "button", service: "press")
            ) {
                Task { await homeAssistantService.pressButton(entityID: entity.entityID) }
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
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "button.restart_router") {
        ButtonDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
