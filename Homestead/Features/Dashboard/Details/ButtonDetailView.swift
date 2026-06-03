import SwiftUI

struct ButtonDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        DashboardEntityDetailScaffold(title: "Button", presentationStyle: presentationStyle) {
            header
            actionPanel
            contextDetails
        }
    }

    private var header: some View {
        DashboardEntityDetailHeader(
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
        DashboardControlPanel(title: "Action", systemImage: "button.programmable") {
            DashboardDetailActionButton(
                title: entityBox.pendingCommand != nil ? "Pressing..." : "Press",
                systemImage: "button.programmable",
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "button", service: "press")
            ) {
                Task { await homeAssistantService.pressButton(entityID: entity.entityID) }
            }
        }
    }

    private var contextDetails: some View {
        DashboardEntityMetadataDisclosure(
            title: "Home Assistant",
            systemImage: "button.programmable",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                DashboardEntityDetailRow(title: "Service", value: "button.press"),
                DashboardEntityDetailRow(title: "State", value: entity.state.displayStateText)
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
