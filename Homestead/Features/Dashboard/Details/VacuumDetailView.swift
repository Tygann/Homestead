import SwiftUI

struct VacuumDetailView: View {
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
        DashboardEntityDetailScaffold(title: "Vacuum", presentationStyle: presentationStyle) {
            header
            vacuumControls
            contextDetails
        }
    }

    private var header: some View {
        DashboardEntityDetailHeader(
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

        return DashboardControlPanel(title: "Control", systemImage: "washer.fill") {
            HStack(spacing: AppSpacing.small) {
                DashboardDetailActionButton(
                    title: "Start",
                    systemImage: "play.fill",
                    isDisabled: isPending || !entity.isAvailable || entity.state == "cleaning" || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "start")
                ) {
                    Task { await homeAssistantService.startVacuum(entityID: entity.entityID) }
                }

                DashboardDetailActionButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    style: .secondary,
                    isDisabled: isPending || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "stop")
                ) {
                    Task { await homeAssistantService.stopVacuum(entityID: entity.entityID) }
                }
            }

            DashboardDetailActionButton(
                title: "Return to Base",
                systemImage: "house.fill",
                style: .secondary,
                isDisabled: isPending || !entity.isAvailable || entity.state == "docked" || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "return_to_base")
            ) {
                Task { await homeAssistantService.returnVacuumToBase(entityID: entity.entityID) }
            }
        }
    }

    private var contextDetails: some View {
        DashboardEntityMetadataDisclosure(
            title: "Home Assistant",
            systemImage: "washer.fill",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                DashboardEntityDetailRow(title: "State", value: entity.state.displayStateText)
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
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "vacuum.downstairs") {
        VacuumDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
