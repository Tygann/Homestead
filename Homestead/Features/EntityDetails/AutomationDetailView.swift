import SwiftUI

struct AutomationDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var selectedHistoryRange: HAHistoryRangePreset = .day
    @State private var timelinePhase: EntityHistoryTimelinePhase = .idle
    @State private var overviewPhase: OverviewPhase = .loading

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity { entityBox.homeEntity }
    private var presentation: DashboardEntityPresentation { DashboardEntityPresentation(entityBox: entityBox) }

    var body: some View {
        EntityDetailScaffold(title: "Automation", presentationStyle: presentationStyle) {
            header
            actionPanel
            overviewPanel
            timelinePanel
            stateDetails
        }
        .task(id: entity.entityID) {
            await refreshOverview()
        }
        .task(id: "\(entity.entityID)-\(selectedHistoryRange.rawValue)") {
            await refreshTimeline()
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeader(
            icon: presentation.icon,
            title: presentation.title,
            subtitle: statusSummary,
            badge: statusLabel,
            iconColor: presentation.isActive ? presentation.accentColor : Color.secondary,
            badgeColor: entity.isAvailable ? (presentation.isActive ? presentation.accentColor : .secondary) : .red,
            iconBackground: presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            badgeBackground: entity.isAvailable ? (presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)) : Color.red.opacity(0.12)
        )
    }

    private var actionPanel: some View {
        EntityControlPanel(title: "Control", systemImage: "calendar.badge.clock") {
            EntityDetailActionButton(
                title: actionTitle,
                systemImage: presentation.isActive ? "pause.fill" : "play.fill",
                style: presentation.isActive ? .secondary : .primary,
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !isActionServiceAvailable
            ) {
                Task { await confirmOrPerform() }
            }
        }
    }

    @ViewBuilder
    private var overviewPanel: some View {
        switch overviewPhase {
        case .loading:
            EntityControlPanel(title: "Automation", systemImage: "list.bullet.rectangle") {
                ProgressView("Loading automation")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .loaded(let overview):
            AutomationOverviewView(overview: overview)
        case .unavailable:
            EmptyView()
        }
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

    private var stateDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "waveform.path.ecg",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "Status", value: statusLabel)
            ]
        )
    }

    private var statusLabel: String {
        guard entity.isAvailable else { return "Unavailable" }
        return presentation.isActive ? "Enabled" : "Disabled"
    }

    private var statusSummary: String {
        if entityBox.pendingCommand != nil { return "Updating in Home Assistant" }
        if !entity.isAvailable { return "Automation unavailable" }
        return presentation.isActive ? "Ready to run" : "Paused"
    }

    private var actionTitle: String {
        if entityBox.pendingCommand != nil { return "Updating..." }
        return presentation.isActive ? "Disable" : "Enable"
    }

    private var isActionServiceAvailable: Bool {
        homeAssistantService.serviceActionAvailable(
            domain: "automation",
            service: presentation.isActive ? "turn_off" : "turn_on"
        )
    }

    @MainActor
    private func refreshOverview() async {
        overviewPhase = .loading
        do {
            overviewPhase = .loaded(try await homeAssistantService.fetchAutomationOverview(entityID: entity.entityID))
        } catch {
            overviewPhase = .unavailable
        }
    }

    @MainActor
    private func refreshTimeline() async {
        timelinePhase = .loading
        do {
            timelinePhase = .loaded(try await homeAssistantService.fetchAutomationTimeline(entityID: entity.entityID, range: selectedHistoryRange))
        } catch {
            timelinePhase = .failed
        }
    }

    private func confirmOrPerform() async {
        let service = presentation.isActive ? "turn_off" : "turn_on"
        guard let confirmation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: "automation",
            service: service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            await homeAssistantService.toggleAutomation(entityID: entity.entityID)
            return
        }

        confirmationRequest = ActionConfirmationRequest(presentation: confirmation) {
            Task { await homeAssistantService.toggleAutomation(entityID: entity.entityID) }
        }
    }

    private enum OverviewPhase: Equatable {
        case loading
        case loaded(HAAutomationOverview)
        case unavailable
    }
}

private struct AutomationOverviewView: View {
    let overview: HAAutomationOverview

    var body: some View {
        EntityControlPanel(title: "Automation", systemImage: "point.3.connected.trianglepath.dotted") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    if index > 0 { sectionDivider }
                    flowSection(title: section.title, systemImage: section.systemImage, steps: section.steps)
                }
            }
        }
    }

    private var sections: [(title: String, systemImage: String, steps: [HAAutomationStep])] {
        [
            ("When", "bolt.fill", overview.triggers),
            ("And If", "checkmark.seal.fill", overview.conditions),
            ("Then Do", "play.fill", overview.actions)
        ].filter { !$0.steps.isEmpty }
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, AppSpacing.medium)
    }

    private func flowSection(title: String, systemImage: String, steps: [HAAutomationStep]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step)

                    if index < steps.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private func stepRow(_ step: HAAutomationStep) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            HomesteadIconView(icon: step.icon, pointSize: 15, weight: .semibold)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = step.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.small)
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "automation.good_night") {
        AutomationDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
