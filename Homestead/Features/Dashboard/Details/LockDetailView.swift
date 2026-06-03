import SwiftUI

struct LockDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isShowingUnlockConfirmation = false

    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        DashboardEntityDetailScaffold(title: "Lock", presentationStyle: presentationStyle) {
            header
            actionPanel
            contextDetails
        }
        .confirmationDialog(
            "Unlock \(presentation.title)?",
            isPresented: $isShowingUnlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unlock", role: .destructive) {
                Task { await homeAssistantService.toggleLock(entityID: entity.entityID) }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will send an unlock command to Home Assistant.")
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

    private var actionPanel: some View {
        DashboardControlPanel(title: "Control", systemImage: actionSystemImage) {
            DashboardDetailActionButton(
                title: actionTitle,
                systemImage: actionSystemImage,
                style: entity.state == "locked" ? .secondary : .primary,
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !isActionServiceAvailable
            ) {
                if entity.state == "locked" {
                    isShowingUnlockConfirmation = true
                } else {
                    Task { await homeAssistantService.toggleLock(entityID: entity.entityID) }
                }
            }
        }
    }

    private var contextDetails: some View {
        DashboardEntityMetadataDisclosure(
            title: "Home Assistant",
            systemImage: "lock.fill",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                DashboardEntityDetailRow(title: "State", value: entity.state.displayStateText)
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
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "lock.front_door") {
        LockDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
