import SwiftUI

struct CoverDetailView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var position = 100.0
    @State private var isEditingPosition = false
    @State private var selectedHistoryRange: HAHistoryRangePreset = .day
    @State private var timelinePhase: EntityHistoryTimelinePhase = .idle

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    @ViewBuilder
    var body: some View {
        if let cover = entityBox.coverEntity {
            EntityDetailScaffold(title: "Cover", presentationStyle: presentationStyle) {
                header(cover)
                movementControls(cover)

                if cover.positionPercentage != nil,
                   homeAssistantService.serviceActionAvailable(domain: "cover", service: "set_cover_position") {
                    positionControls(cover)
                }

                timelinePanel(cover)
                contextDetails
            }
            .task(id: timelineTaskID) {
                await refreshTimeline()
            }
            .onAppear {
                syncPosition(with: cover)
            }
            .onChange(of: cover.position) { _, _ in
                guard !isEditingPosition else { return }
                syncPosition(with: cover)
            }
            .actionConfirmationDialog(request: $confirmationRequest)
        } else {
            EntityUnavailableDetailView(
                title: "Cover",
                systemImage: "blinds.horizontal.closed",
                presentationStyle: presentationStyle
            )
        }
    }

    private func header(_ cover: CoverEntity) -> some View {
        EntityDetailHeader(
            iconName: cover.iconName,
            title: cover.displayName,
            subtitle: cover.displaySubtitle,
            badge: statusBadgeText(for: cover),
            iconColor: coverIconColor(cover),
            badgeColor: coverBadgeColor(cover),
            iconBackground: coverStatusBackground(cover),
            badgeBackground: coverStatusBackground(cover)
        )
    }

    private func movementControls(_ cover: CoverEntity) -> some View {
        let isPending = entityBox.pendingCommand != nil

        return EntityControlPanel(title: "Control", systemImage: "arrow.up.and.down") {
            HStack(spacing: AppSpacing.small) {
                EntityDetailActionButton(
                    title: "Open",
                    systemImage: "arrow.up",
                    isDisabled: isPending || cover.state == "open" || !entityBox.homeEntity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "open_cover")
                ) {
                    confirmOrPerform(domain: "cover", service: "open_cover") {
                        Task { await homeAssistantService.openCover(entityID: entityBox.entityID) }
                    }
                }

                EntityDetailActionButton(
                    title: "Close",
                    systemImage: "arrow.down",
                    style: .secondary,
                    isDisabled: isPending || cover.state == "closed" || !entityBox.homeEntity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "close_cover")
                ) {
                    confirmOrPerform(domain: "cover", service: "close_cover") {
                        Task { await homeAssistantService.closeCover(entityID: entityBox.entityID) }
                    }
                }
            }

            EntityDetailActionButton(
                title: "Stop",
                systemImage: "stop.fill",
                style: .secondary,
                isDisabled: isPending || !entityBox.homeEntity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "stop_cover")
            ) {
                confirmOrPerform(domain: "cover", service: "stop_cover") {
                    Task { await homeAssistantService.stopCover(entityID: entityBox.entityID) }
                }
            }
        }
    }

    private func positionControls(_ cover: CoverEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Label("Position", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Spacer()

                Text("\(Int(position))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(cover.isOpen ? Color.accentColor : Color.secondary)
            }

            EntityDetailLevelSlider(
                value: $position,
                range: 0...100,
                step: 1,
                isDisabled: entityBox.pendingCommand != nil || !entityBox.homeEntity.isAvailable,
                accessibilityLabel: "Cover position",
                accessibilityValue: "\(Int(position)) percent",
                onEditingChanged: { editing in
                    isEditingPosition = editing
                },
                onCommit: { value in
                    setPosition(value)
                }
            )

            Text("Position is reported by Home Assistant when this cover supports it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func timelinePanel(_ cover: CoverEntity) -> some View {
        EntityHistoryTimelinePanel(
            selectedRange: $selectedHistoryRange,
            phase: timelinePhase,
            tint: cover.isOpen ? Color.accentColor : Color.secondary
        ) {
            Task { await refreshTimeline() }
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "blinds.horizontal.closed",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entityBox.entityID),
                EntityMetadataRow(title: "Domain", value: entityBox.domain.displayName),
                EntityMetadataRow(title: "State", value: entityBox.homeEntity.state.displayStateText)
            ]
        )
    }

    private var timelineTaskID: String {
        "\(entityBox.entityID)-\(selectedHistoryRange.rawValue)"
    }

    private func statusBadgeText(for cover: CoverEntity) -> String {
        if let position = cover.positionPercentage {
            return "\(position)%"
        }

        return cover.displayState
    }

    private func setPosition(_ updatedPosition: Double) {
        position = updatedPosition

        confirmOrPerform(domain: "cover", service: "set_cover_position") {
            Task {
                await homeAssistantService.setCoverPosition(
                    entityID: entityBox.entityID,
                    position: updatedPosition
                )
            }
        }
    }

    private func coverIconColor(_ cover: CoverEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return .secondary }
        return cover.isOpen ? Color.accentColor : Color.secondary
    }

    private func coverBadgeColor(_ cover: CoverEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return .red }
        return cover.isOpen ? Color.accentColor : Color.secondary
    }

    private func coverStatusBackground(_ cover: CoverEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return Color.red.opacity(0.12) }
        return cover.isOpen ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func syncPosition(with cover: CoverEntity) {
        position = Double(cover.positionPercentage ?? 100)
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

    @MainActor
    private func refreshTimeline() async {
        timelinePhase = .loading
        let interval = selectedHistoryRange.interval()
        let request = HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: entityBox.entityID
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
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "cover.primary_shades") {
        CoverDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
