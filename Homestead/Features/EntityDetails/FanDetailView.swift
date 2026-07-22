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

                if showsSpeedControl(fan) || showsPresetControl(fan) {
                    controls(fan)
                }

                EntityActivityHistoryPreview(entityBox: entityBox, tint: .accentColor)
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
        let service = fan.isOn ? "turn_off" : "turn_on"

        return EntityDetailHeroCard(
            icon: entityBox.homeEntity.resolvedIcon,
            title: "Fan",
            subtitle: EntityDetailHeroSubtitle.updated(entityBox.homeEntity),
            status: nil,
            iconColor: fan.isOn ? Color.accentColor : Color.secondary,
            iconBackground: fan.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            statePresentation: detailState,
            accessory: {
                EntityDetailStateToggle(
                    isOn: fan.isOn,
                    accessibilityLabel: "Fan power",
                    isDisabled: detailState.blocksControlInteraction
                        || !homeAssistantService.serviceActionAvailable(domain: "fan", service: service)
                ) { requestedState in
                    setPower(requestedState)
                }
            }
        ) {
            EmptyView()
        }
    }

    private func setPower(_ isOn: Bool) {
        confirmOrPerform(domain: "fan", service: isOn ? "turn_on" : "turn_off") {
            Task { await homeAssistantService.toggleFan(entityID: entityBox.entityID) }
        }
    }

    private func controls(_ fan: FanEntity) -> some View {
        EntityControlPanel(title: "Controls", systemImage: "slider.horizontal.3") {
            if showsSpeedControl(fan) {
                percentageControls(fan)
            }

            if showsSpeedControl(fan) && showsPresetControl(fan) {
                Divider()
            }

            if showsPresetControl(fan) {
                presetControls(fan)
            }
        }
    }

    private func percentageControls(_ fan: FanEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Text("Speed")
                    .font(.body)

                Spacer()

                Text("\(Int(percentage))%")
                    .font(.headline.monospacedDigit())
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
    }

    private func presetControls(_ fan: FanEntity) -> some View {
        EntityDetailMenuRow(
            title: "Preset",
            systemImage: "dial.medium",
            value: fan.presetMode.map(fan.displayName(forPresetMode:)) ?? "None",
            isDisabled: detailState.blocksControlInteraction
        ) {
            ForEach(fan.presetModes, id: \.self) { presetMode in
                Button {
                    confirmOrPerform(domain: "fan", service: "set_preset_mode") {
                        Task {
                            await homeAssistantService.setFanPresetMode(
                                entityID: fan.entityID,
                                presetMode: presetMode
                            )
                        }
                    }
                } label: {
                    Label(
                        fan.displayName(forPresetMode: presetMode),
                        systemImage: presetMode == fan.presetMode ? "checkmark" : "dial.medium"
                    )
                }
                .disabled(presetMode == fan.presetMode)
            }
        }
    }

    private func showsSpeedControl(_ fan: FanEntity) -> Bool {
        fan.percentage != nil
            && homeAssistantService.serviceActionAvailable(domain: "fan", service: "set_percentage")
    }

    private func showsPresetControl(_ fan: FanEntity) -> Bool {
        !fan.presetModes.isEmpty
            && homeAssistantService.serviceActionAvailable(domain: "fan", service: "set_preset_mode")
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
