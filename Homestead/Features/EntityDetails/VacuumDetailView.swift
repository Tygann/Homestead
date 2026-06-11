import SwiftUI

struct VacuumDetailView: View {
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
        EntityDetailScaffold(title: "Vacuum", presentationStyle: presentationStyle) {
            header
            vacuumControls
            contextDetails
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: statusSummary,
            badge: presentation.subtitle,
            iconColor: iconColor,
            badgeColor: statusColor,
            iconBackground: iconBackground,
            badgeBackground: statusBackground
        )
    }

    private var vacuumControls: some View {
        let isPending = entityBox.pendingCommand != nil

        return EntityControlPanel(title: "Control", systemImage: "washer.fill") {
            HStack(spacing: AppSpacing.small) {
                EntityDetailActionButton(
                    title: "Start",
                systemImage: "play.fill",
                isDisabled: isPending || !entity.isAvailable || entity.state == "cleaning" || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "start")
            ) {
                confirmOrPerform(domain: "vacuum", service: "start") {
                    Task { await homeAssistantService.startVacuum(entityID: entity.entityID) }
                }
            }

                EntityDetailActionButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                style: .secondary,
                isDisabled: isPending || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "stop")
            ) {
                confirmOrPerform(domain: "vacuum", service: "stop") {
                    Task { await homeAssistantService.stopVacuum(entityID: entity.entityID) }
                }
            }
            }

            EntityDetailActionButton(
                title: "Return to Base",
                systemImage: "house.fill",
                style: .secondary,
                isDisabled: isPending || !entity.isAvailable || entity.state == "docked" || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "return_to_base")
            ) {
                confirmOrPerform(domain: "vacuum", service: "return_to_base") {
                    Task { await homeAssistantService.returnVacuumToBase(entityID: entity.entityID) }
                }
            }
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "washer.fill",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Vacuum unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return presentation.isActive ? "Cleaning now" : "Ready for command"
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
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "vacuum.downstairs") {
        VacuumDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
