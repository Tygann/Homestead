import SwiftUI

struct ToggleEntityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    statusCard
                    actionButton
                    stateDetails
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var statusCard: some View {
        DashboardEntityStatusCard(
            iconName: presentation.iconName,
            title: presentation.title,
            badge: presentation.subtitle,
            summary: statusSummary,
            iconColor: presentation.isActive ? presentation.accentColor : Color.secondary,
            badgeColor: presentation.isAvailable ? presentation.headlineColor : Color.red,
            iconBackground: iconBackground,
            badgeBackground: badgeBackground
        )
    }

    private var actionButton: some View {
        DashboardPrimaryActionButton(
            title: actionTitle,
            systemImage: actionSystemImage,
            isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !isActionServiceAvailable
        ) {
            Task { await performPrimaryAction() }
        }
    }

    private var stateDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Current State", systemImage: "waveform.path.ecg")
                .font(.headline)

            HStack {
                Text(entity.state.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.body.weight(.medium))

                Spacer()

                Text(entity.entityID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var navigationTitle: String {
        switch entity.domain {
        case .switch:
            "Switch"
        case .fan:
            "Fan"
        case .lock:
            "Lock"
        case .automation:
            "Automation"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            "Entity"
        }
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "\(navigationTitle) unavailable" }

        if entityBox.pendingCommand != nil {
            return "Waiting for Home Assistant confirmation"
        }

        switch entity.domain {
        case .lock:
            return entity.state == "locked" ? "Secured" : "Needs attention"
        case .switch, .fan, .automation:
            return presentation.isActive ? "Currently active" : "Currently idle"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            return presentation.subtitle
        }
    }

    private var actionTitle: String {
        if entityBox.pendingCommand != nil {
            return "Updating..."
        }

        switch entity.domain {
        case .lock:
            return entity.state == "locked" ? "Unlock" : "Lock"
        case .switch, .fan, .automation:
            return presentation.isActive ? "Turn Off" : "Turn On"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            return "Update"
        }
    }

    private var actionSystemImage: String {
        switch entity.domain {
        case .lock:
            return entity.state == "locked" ? "lock.open.fill" : "lock.fill"
        case .fan:
            return "fan.fill"
        case .switch:
            return entity.iconName
        case .automation:
            return "calendar.badge.clock"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            return "checkmark"
        }
    }

    private var isActionServiceAvailable: Bool {
        switch entity.domain {
        case .switch:
            return homeAssistantService.serviceActionAvailable(domain: "switch", service: presentation.isActive ? "turn_off" : "turn_on")
        case .fan:
            return homeAssistantService.serviceActionAvailable(domain: "fan", service: presentation.isActive ? "turn_off" : "turn_on")
        case .lock:
            return homeAssistantService.serviceActionAvailable(domain: "lock", service: entity.state == "locked" ? "unlock" : "lock")
        case .automation:
            return homeAssistantService.serviceActionAvailable(domain: "automation", service: presentation.isActive ? "turn_off" : "turn_on")
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            return false
        }
    }

    private var iconBackground: Color {
        presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var badgeBackground: Color {
        guard presentation.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func performPrimaryAction() async {
        switch entity.domain {
        case .switch:
            await homeAssistantService.toggleSwitch(entityID: entity.entityID)
        case .fan:
            await homeAssistantService.toggleFan(entityID: entity.entityID)
        case .lock:
            await homeAssistantService.toggleLock(entityID: entity.entityID)
        case .automation:
            await homeAssistantService.toggleAutomation(entityID: entity.entityID)
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            break
        }
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
