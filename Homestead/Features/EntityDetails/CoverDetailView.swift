import SwiftUI

struct CoverDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var position = 100.0
    @State private var isEditingPosition = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }
    private var features: EntityDetailFeatureSet {
        EntityDetailFeatureProvider.features(for: entityBox)
    }

    @ViewBuilder
    var body: some View {
        if let cover = entityBox.coverEntity {
            EntityDetailScaffold(title: cover.displayName, presentationStyle: presentationStyle) {
                header(cover)
                controls(cover)

                timelinePanel(cover)
                contextDetails
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
                title: entityBox.homeEntity.displayName,
                systemImage: "blinds.horizontal.closed",
                presentationStyle: presentationStyle
            )
        }
    }

    private func header(_ cover: CoverEntity) -> some View {
        EntityDetailHeroCard(
            icon: entityBox.homeEntity.resolvedIcon,
            title: "Cover",
            subtitle: EntityDetailHeroSubtitle.updated(entityBox.homeEntity),
            status: coverHeroStatus(cover),
            iconColor: coverIconColor(cover),
            statusColor: coverBadgeColor(cover),
            iconBackground: coverStatusBackground(cover),
            statusBackground: coverHeroStatus(cover) == "Unavailable" ? Color.red.opacity(0.12) : coverStatusBackground(cover),
            statePresentation: detailState,
            accessory: {
                Text(cover.positionPercentage.map { "\($0)%" } ?? cover.displayState)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(coverIconColor(cover))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(cover.positionPercentage == nil ? "State" : "Position")
                    .accessibilityValue(cover.positionPercentage.map { "\($0) percent" } ?? cover.displayState)
            }
        ) {
            EmptyView()
        }
    }

    private func controls(_ cover: CoverEntity) -> some View {
        EntityControlPanel(title: "Controls", systemImage: "slider.horizontal.3") {
            movementControls(cover)

            if canSetPosition(cover) {
                Divider()
                positionControls(cover)
            }
        }
    }

    private func movementControls(_ cover: CoverEntity) -> some View {
        let blocksInteraction = detailState.blocksControlInteraction

        return VStack(spacing: AppSpacing.small) {
            HStack(spacing: AppSpacing.small) {
                EntityDetailActionButton(
                    title: "Open",
                    systemImage: "arrow.up",
                    isDisabled: blocksInteraction || cover.state == "open" || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "open_cover")
                ) {
                    confirmOrPerform(domain: "cover", service: "open_cover") {
                        Task { await homeAssistantService.openCover(entityID: entityBox.entityID) }
                    }
                }

                EntityDetailActionButton(
                    title: "Close",
                    systemImage: "arrow.down",
                    style: .secondary,
                    isDisabled: blocksInteraction || cover.state == "closed" || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "close_cover")
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
                isDisabled: blocksInteraction || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "stop_cover")
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
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(Int(position))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(cover.isOpen ? Color.accentColor : Color.secondary)
            }

            EntityDetailLevelSlider(
                value: $position,
                range: 0...100,
                step: 1,
                isDisabled: detailState.blocksControlInteraction,
                accessibilityLabel: "Cover position",
                accessibilityValue: "\(Int(position)) percent",
                onEditingChanged: { editing in
                    isEditingPosition = editing
                },
                onCommit: { value in
                    setPosition(value)
                }
            )
        }
    }

    private func canSetPosition(_ cover: CoverEntity) -> Bool {
        cover.positionPercentage != nil
            && homeAssistantService.serviceActionAvailable(domain: "cover", service: "set_cover_position")
    }

    @ViewBuilder
    private func timelinePanel(_ cover: CoverEntity) -> some View {
        if let source = features.activitySource {
            EntityActivityPreview(
                entityID: entityBox.entityID,
                source: source,
                tint: cover.isOpen ? Color.accentColor : Color.secondary
            )
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

    private func coverHeroStatus(_ cover: CoverEntity) -> String? {
        if !entityBox.homeEntity.isAvailable { return "Unavailable" }
        if entityBox.pendingCommand != nil { return "Updating" }
        switch cover.state {
        case "opening": return "Opening"
        case "closing": return "Closing"
        default: return nil
        }
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

}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "cover.primary_shades") {
        CoverDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
