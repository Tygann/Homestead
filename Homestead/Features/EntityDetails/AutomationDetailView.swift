import SwiftUI

struct AutomationDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var overviewPhase: OverviewPhase = .loading

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity { entityBox.homeEntity }
    private var presentation: EntityDetailPresentationModel { EntityDetailPresentationModel(entityBox: entityBox) }
    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }
    private var features: EntityDetailFeatureSet {
        EntityDetailFeatureProvider.features(for: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header
            overviewPanel
            activityPanel
            stateDetails
        }
        .task(id: entity.entityID) {
            await refreshOverview()
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: "Automation",
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: presentation.isActive ? presentation.accentColor : Color.secondary,
            iconBackground: presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            statePresentation: detailState,
            accessory: {
                EntityDetailStateToggle(
                    isOn: presentation.isActive,
                    accessibilityLabel: "Automation enabled",
                    isDisabled: detailState.blocksControlInteraction || !isActionServiceAvailable
                ) { requestedState in
                    Task { await confirmOrPerform(requestedState: requestedState) }
                }
            }
        ) {
            EmptyView()
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
            AutomationLogicOverviewView(overview: overview)
        case .unavailable:
            EmptyView()
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

    private func confirmOrPerform(requestedState: Bool) async {
        let service = requestedState ? "turn_on" : "turn_off"
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

struct AutomationLogicOverviewView: View {
    enum Kind: Equatable {
        case automation
        case script
    }

    let overview: HAAutomationOverview
    var kind: Kind = .automation
    @State private var collapsedChoiceIDs: Set<String> = []

    var body: some View {
        EntityControlPanel(title: panelTitle, systemImage: panelIcon) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    if index > 0 { sectionDivider }
                    flowSection(title: section.title, systemImage: section.systemImage, steps: section.steps)
                }
            }
        }
    }

    private var sections: [(title: String, systemImage: String, steps: [HAAutomationStep])] {
        switch kind {
        case .automation:
            [
            ("When", "bolt.fill", overview.triggers),
            ("And If", "checkmark.seal.fill", overview.conditions),
            ("Then Do", "play.fill", overview.actions)
            ].filter { !$0.steps.isEmpty }
        case .script:
            [
                ("And If", "checkmark.seal.fill", overview.conditions),
                ("Sequence", "play.fill", overview.actions)
            ].filter { !$0.steps.isEmpty }
        }
    }

    private var panelTitle: String {
        kind == .automation ? "Automation" : "Script Logic"
    }

    private var panelIcon: String {
        kind == .automation ? "point.3.connected.trianglepath.dotted" : "list.bullet.rectangle"
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

                    if !step.children.isEmpty {
                        choiceOutline(step.children)
                    }

                    if !step.groups.isEmpty {
                        inlineGroups(step.groups)
                    }

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

    private func choiceOutline(_ options: [HAAutomationStep]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                DisclosureGroup(isExpanded: choiceExpansion(for: option.id)) {
                    ForEach(option.groups) { group in
                        choiceGroup(group)
                    }
                    .padding(.leading, AppSpacing.medium)
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(.accentColor)

                if index < options.count - 1 {
                    Divider().padding(.leading, 30)
                }
            }
        }
        .padding(.leading, 40)
        .padding(.top, AppSpacing.small)
    }

    private func inlineGroups(_ groups: [HAAutomationStepGroup]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            ForEach(groups) { group in
                choiceGroup(group)
            }
        }
        .padding(.leading, 40)
        .padding(.top, AppSpacing.small)
    }

    private func choiceExpansion(for id: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedChoiceIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    collapsedChoiceIDs.remove(id)
                } else {
                    collapsedChoiceIDs.insert(id)
                }
            }
        )
    }

    private func choiceGroup(_ group: HAAutomationStepGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, AppSpacing.small)

            ForEach(Array(group.steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step)

                if index < group.steps.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
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
