import SwiftUI

struct LockDetailView: View {
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

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }
    private var features: EntityDetailFeatureSet {
        EntityDetailFeatureProvider.features(for: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header
            actionPanel
            activityPanel
            contextDetails
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: presentation.icon,
            category: "Lock",
            summary: nil,
            status: entity.state == "locked"
                ? nil
                : EntityDetailStatusPresentation(text: entity.state.displayStateText, tone: .warning),
            iconColor: iconColor,
            iconBackground: iconBackground
        )
    }

    private var actionPanel: some View {
        EntityControlPanel(title: "Control", systemImage: actionSystemImage) {
            EntityDetailActionButton(
                title: actionTitle,
                systemImage: actionSystemImage,
                style: entity.state == "locked" ? .secondary : .primary,
                isDisabled: detailState.blocksControlInteraction || !isActionServiceAvailable
            ) {
                let service = entity.state == "locked" ? "unlock" : "lock"
                confirmOrPerform(domain: "lock", service: service) {
                    Task { await homeAssistantService.toggleLock(entityID: entity.entityID) }
                }
            }
        }
    }

    @ViewBuilder
    private var activityPanel: some View {
        if let source = features.activitySource {
            EntityActivityPanel(
                entityID: entity.entityID,
                source: source,
                tint: presentation.accentColor
            )
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "lock.fill",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Lock unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return entity.state == "locked" ? "Secured" : "Needs attention"
    }

    private var actionTitle: String {
        if entityBox.pendingCommand != nil { return "Updating..." }
        return entity.state == "locked" ? "Unlock" : "Lock"
    }

    private var actionSystemImage: String {
        entity.state == "locked" ? "lock.open.fill" : "lock.fill"
    }

    private var isActionServiceAvailable: Bool {
        homeAssistantService.serviceActionAvailable(domain: "lock", service: entity.state == "locked" ? "unlock" : "lock")
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        return presentation.isActive ? presentation.accentColor : .secondary
    }

    private var statusColor: Color {
        guard entity.isAvailable else { return .red }
        return presentation.isActive ? presentation.accentColor : .primary
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var statusBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
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
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "lock.front_door") {
        LockDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
