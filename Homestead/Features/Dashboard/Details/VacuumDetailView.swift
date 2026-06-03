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
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                statusCard
                vacuumControls
                contextDetails
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .dashboardDetailPresentation(title: "Vacuum", style: presentationStyle)
    }

    private var statusCard: some View {
        DashboardEntityStatusCard(
            iconName: presentation.iconName,
            title: presentation.title,
            badge: presentation.subtitle,
            summary: statusSummary,
            iconColor: iconColor,
            badgeColor: statusColor,
            iconBackground: iconBackground,
            badgeBackground: statusBackground
        )
    }

    private var vacuumControls: some View {
        let isPending = entityBox.pendingCommand != nil

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.small) {
                Button {
                    Task { await homeAssistantService.startVacuum(entityID: entity.entityID) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPending || !entity.isAvailable || entity.state == "cleaning" || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "start"))

                Button {
                    Task { await homeAssistantService.stopVacuum(entityID: entity.entityID) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .disabled(isPending || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "stop"))
            }

            Button {
                Task { await homeAssistantService.returnVacuumToBase(entityID: entity.entityID) }
            } label: {
                Label("Return to Base", systemImage: "house.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.bordered)
            .disabled(isPending || !entity.isAvailable || entity.state == "docked" || !homeAssistantService.serviceActionAvailable(domain: "vacuum", service: "return_to_base"))
        }
        .controlSize(.large)
    }

    private var contextDetails: some View {
        DashboardEntityContextPanel(
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
