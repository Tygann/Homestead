import SwiftUI

struct FanDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var percentage = 100.0
    @State private var isEditingPercentage = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    @ViewBuilder
    var body: some View {
        if let fan = entityBox.fanEntity {
            EntityDetailScaffold(title: fan.displayName, presentationStyle: presentationStyle) {
                header(fan)
                powerControls(fan)

                if fan.percentage != nil,
                   homeAssistantService.serviceActionAvailable(domain: "fan", service: "set_percentage") {
                    percentageControls(fan)
                }

                if !fan.presetModes.isEmpty,
                   homeAssistantService.serviceActionAvailable(domain: "fan", service: "set_preset_mode") {
                    presetControls(fan)
                }

                contextDetails
            }
            .onAppear {
                syncPercentage(with: fan)
            }
            .onChange(of: fan.percentage) { _, _ in
                guard !isEditingPercentage else { return }
                syncPercentage(with: fan)
            }
            .actionConfirmationDialog(request: $confirmationRequest)
        } else {
            EntityUnavailableDetailView(
                title: entityBox.homeEntity.displayName,
                systemImage: "fan.fill",
                presentationStyle: presentationStyle
            )
        }
    }

    private func header(_ fan: FanEntity) -> some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: entityBox.homeEntity.resolvedIcon,
            category: "Fan",
            summary: nil,
            status: nil,
            iconColor: fan.isOn ? Color.accentColor : Color.secondary,
            iconBackground: fan.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
        )
    }

    private func powerControls(_ fan: FanEntity) -> some View {
        return EntityControlPanel(title: "Control", systemImage: "power") {
            EntityDetailActionButton(
                title: detailState.operationalState == .pending ? "Updating..." : (fan.isOn ? "Turn Off" : "Turn On"),
                systemImage: "power",
                style: fan.isOn ? .secondary : .primary,
                isDisabled: detailState.blocksControlInteraction || !homeAssistantService.serviceActionAvailable(domain: "fan", service: fan.isOn ? "turn_off" : "turn_on")
            ) {
                confirmOrPerform(domain: "fan", service: fan.isOn ? "turn_off" : "turn_on") {
                    Task { await homeAssistantService.toggleFan(entityID: entityBox.entityID) }
                }
            }
        }
    }

    private func percentageControls(_ fan: FanEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Label("Speed", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Spacer()

                Text("\(Int(percentage))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(fan.isOn ? Color.accentColor : Color.secondary)
            }

            EntityDetailLevelSlider(
                value: $percentage,
                range: 0...100,
                step: fan.resolvedPercentageStep,
                isDisabled: detailState.blocksControlInteraction,
                accessibilityLabel: "Fan speed",
                accessibilityValue: "\(Int(percentage)) percent",
                onEditingChanged: { editing in
                    isEditingPercentage = editing
                },
                onCommit: { value in
                    setPercentage(value)
                }
            )

            Text(percentage == 0 ? "Setting speed to 0% may turn this fan off." : "Speed changes are confirmed from Home Assistant live state.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func presetControls(_ fan: FanEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Preset", systemImage: "dial.medium")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: AppSpacing.small)], spacing: AppSpacing.small) {
                ForEach(fan.presetModes, id: \.self) { presetMode in
                    EntityDetailPillButton(
                        title: fan.displayName(forPresetMode: presetMode),
                        isSelected: presetMode == fan.presetMode,
                        isDisabled: detailState.blocksControlInteraction || presetMode == fan.presetMode
                    ) {
                        confirmOrPerform(domain: "fan", service: "set_preset_mode") {
                            Task {
                                await homeAssistantService.setFanPresetMode(
                                    entityID: fan.entityID,
                                    presetMode: presetMode
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "fan.fill",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entityBox.entityID),
                EntityMetadataRow(title: "Domain", value: entityBox.domain.displayName),
                EntityMetadataRow(title: "State", value: entityBox.homeEntity.state.displayStateText)
            ]
        )
    }

    private func statusSummary(_ fan: FanEntity) -> String {
        guard fan.isAvailable else { return "Fan unavailable" }
        guard fan.isOn else { return "Currently idle" }
        return fan.percentage.map { "Running at \($0)%" } ?? "Currently active"
    }

    private func setPercentage(_ updatedPercentage: Double? = nil) {
        if let updatedPercentage {
            percentage = updatedPercentage
        }

        confirmOrPerform(domain: "fan", service: "set_percentage") {
            Task {
                await homeAssistantService.setFanPercentage(
                    entityID: entityBox.entityID,
                    percentage: percentage
                )
            }
        }
    }

    private func syncPercentage(with fan: FanEntity) {
        percentage = Double(fan.percentage ?? (fan.isOn ? 100 : 0))
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
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "fan.bedroom") {
        FanDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
