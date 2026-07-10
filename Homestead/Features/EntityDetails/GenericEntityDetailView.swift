import SwiftUI

struct GenericEntityDetailView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedHistoryRange: HAHistoryRangePreset = .day
    @State private var timelinePhase: EntityHistoryTimelinePhase = .idle
    @State private var selectedAction: HAEntityAction?
    @State private var availableActions: [HAEntityAction] = []

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            header
            currentStatePanel
            if !availableActions.isEmpty {
                actionsPanel
            }
            if supportsTimeline {
                timelinePanel
            }
            contextDetails
        }
        .task(id: timelineTaskID) {
            await refreshTimeline()
        }
        .task(id: entity.entityID) {
            availableActions = await homeAssistantService.actions(for: entity.entityID)
        }
        .sheet(item: $selectedAction) { action in
            GenericEntityActionSheet(action: action, entity: entity)
        }
    }

    private var header: some View {
        EntityDetailHeader(
            icon: presentation.icon,
            title: presentation.title,
            subtitle: entity.entityID,
            badge: presentation.subtitle,
            iconColor: iconColor,
            badgeColor: entity.isAvailable ? iconColor : .red,
            iconBackground: iconBackground,
            badgeBackground: badgeBackground
        )
    }

    private var currentStatePanel: some View {
        EntityControlPanel(title: "Current State", systemImage: "waveform.path.ecg") {
            Text(presentation.subtitle)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(stateColor)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionsPanel: some View {
        EntityControlPanel(title: "Actions", systemImage: "bolt.fill") {
            VStack(spacing: AppSpacing.small) {
                ForEach(availableActions) { action in
                    Button {
                        if action.fields.isEmpty {
                            Task {
                                await homeAssistantService.callService(
                                    domain: action.domain,
                                    service: action.service,
                                    entityID: entity.entityID,
                                    successTitle: action.displayName
                                )
                            }
                        } else {
                            selectedAction = action
                        }
                    } label: {
                        HStack(spacing: AppSpacing.medium) {
                            Image(systemName: "play.fill")
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.displayName)
                                    .font(.subheadline.weight(.semibold))
                                if !action.fields.isEmpty {
                                    Text("Configure options")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(!entity.isAvailable)
                }
            }
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

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var navigationTitle: String {
        entity.domain == .other ? "Entity" : entity.domain.displayName
    }

    private var supportsTimeline: Bool {
        entity.domain == .person || entity.domain == .deviceTracker
    }

    private var timelineTaskID: String {
        guard supportsTimeline else {
            return "timeline-disabled-\(entity.entityID)"
        }

        return "\(entity.entityID)-\(selectedHistoryRange.rawValue)"
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        return presentation.isActive ? presentation.accentColor : .secondary
    }

    private var stateColor: Color {
        guard entity.isAvailable else { return .red }
        return presentation.isActive ? presentation.accentColor : .primary
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var badgeBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
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
    GenericEntityDetailView(
        entityBox: HAEntityState(
            homeEntity: HomeEntity(
                entityID: "weather.home",
                domain: .weather,
                displayName: "Home Weather",
                state: "partlycloudy",
                iconName: "cloud.sun.fill",
                isAvailable: true,
                lastUpdated: .now
            )
        )
    )
    .withPreviewEnvironment()
}
#endif
