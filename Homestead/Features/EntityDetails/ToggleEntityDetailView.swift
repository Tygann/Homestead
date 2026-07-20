import SwiftUI

struct ToggleEntityDetailView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var selectedHistoryRange: HAHistoryRangePreset = .day
    @State private var timelinePhase: EntityHistoryTimelinePhase = .idle

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

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            header
            actionPanel
            if supportsTimeline {
                timelinePanel
            }
            stateDetails
        }
        .task(id: timelineTaskID) {
            await refreshTimeline()
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: presentation.icon,
            category: entityCategory,
            summary: nil,
            status: nil,
            iconColor: presentation.isActive ? presentation.accentColor : Color.secondary,
            iconBackground: iconBackground
        )
    }

    private var actionPanel: some View {
        EntityControlPanel(title: "Control", systemImage: actionSystemImage) {
            EntityDetailActionButton(
                title: actionTitle,
                systemImage: actionSystemImage,
                style: presentation.isActive ? .secondary : .primary,
                isDisabled: detailState.blocksControlInteraction || !isActionServiceAvailable
            ) {
                Task { await performPrimaryAction() }
            }
        }
    }

    private var stateDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "waveform.path.ecg",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var timelinePanel: some View {
        EntityHistoryTimelinePanel(
            selectedRange: $selectedHistoryRange,
            phase: timelinePhase,
            tint: presentation.accentColor
        ) {
            Task { await refreshTimeline() }
        }
    }

    private var navigationTitle: String {
        entity.displayName
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "\(entityCategory) unavailable" }

        if entityBox.pendingCommand != nil {
            return "Waiting for Home Assistant confirmation"
        }

        switch entity.domain {
        case .lock:
            return entity.state == "locked" ? "Secured" : "Needs attention"
        case .switch, .fan, .automation:
            return presentation.isActive ? "Currently active" : "Currently idle"
        default:
            return presentation.subtitle
        }
    }

    private var entityCategory: String {
        EntityCapabilityRegistry.profile(for: entity.domain).categoryTitle
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
        default:
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
        default:
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
        default:
            return false
        }
    }

    private var supportsTimeline: Bool {
        entity.domain == .switch || entity.domain == .automation
    }

    private var timelineTaskID: String {
        guard supportsTimeline else {
            return "timeline-disabled-\(entity.entityID)"
        }

        return "\(entity.entityID)-\(selectedHistoryRange.rawValue)"
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
            await confirmOrPerform(domain: "switch", service: presentation.isActive ? "turn_off" : "turn_on") {
                await homeAssistantService.toggleSwitch(entityID: entity.entityID)
            }
        case .fan:
            await confirmOrPerform(domain: "fan", service: presentation.isActive ? "turn_off" : "turn_on") {
                await homeAssistantService.toggleFan(entityID: entity.entityID)
            }
        case .lock:
            await confirmOrPerform(domain: "lock", service: entity.state == "locked" ? "unlock" : "lock") {
                await homeAssistantService.toggleLock(entityID: entity.entityID)
            }
        case .automation:
            await confirmOrPerform(domain: "automation", service: presentation.isActive ? "turn_off" : "turn_on") {
                await homeAssistantService.toggleAutomation(entityID: entity.entityID)
            }
        default:
            break
        }
    }

    private func confirmOrPerform(
        domain: String,
        service: String,
        perform: @escaping () async -> Void
    ) async {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: domain,
            service: service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            await perform()
            return
        }

        confirmationRequest = ActionConfirmationRequest(
            presentation: presentation,
            perform: {
                Task { await perform() }
            }
        )
    }

    @MainActor
    private func refreshTimeline() async {
        guard supportsTimeline else {
            timelinePhase = .idle
            return
        }

        timelinePhase = .loading
        let interval = selectedHistoryRange.interval()
        let request = HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: entity.entityID
        )

        do {
            timelinePhase = .loaded(
                try await homeAssistantService.fetchTimeline(
                    settings: connectionSettings,
                    request: request,
                    range: selectedHistoryRange
                )
            )
        } catch {
            timelinePhase = .failed
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
