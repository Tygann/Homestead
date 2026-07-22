import SwiftUI

struct LightDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var brightnessPercentage = 100.0
    @State private var isEditingBrightness = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    @ViewBuilder
    var body: some View {
        if let light = entityBox.lightEntity {
            EntityDetailScaffold(title: light.displayName, presentationStyle: presentationStyle) {
                header(light)

                if light.supportsBrightness,
                   homeAssistantService.serviceActionAvailable(domain: "light", service: "turn_on") {
                    brightnessControls(light)
                }

                EntityActivityHistoryPreview(entityBox: entityBox, tint: .accentColor)
                contextDetails
            }
            .onAppear {
                syncBrightness(with: light)
            }
            .onChange(of: light.brightness) { _, _ in
                guard !isEditingBrightness else { return }
                syncBrightness(with: light)
            }
            .onChange(of: light.isOn) { _, _ in
                guard !isEditingBrightness else { return }
                syncBrightness(with: light)
            }
            .actionConfirmationDialog(request: $confirmationRequest)
        } else {
            EntityUnavailableDetailView(
                title: entityBox.homeEntity.displayName,
                systemImage: "lightbulb.slash",
                presentationStyle: presentationStyle
            )
        }
    }

    private func header(_ light: LightEntity) -> some View {
        let service = light.isOn ? "turn_off" : "turn_on"

        return EntityDetailHeroCard(
            icon: entityBox.homeEntity.resolvedIcon,
            title: "Light",
            subtitle: EntityDetailHeroSubtitle.updated(entityBox.homeEntity),
            status: nil,
            iconColor: lightIconColor(light),
            iconBackground: lightIconBackground(light),
            statePresentation: detailState,
            accessory: {
                EntityDetailStateToggle(
                    isOn: light.isOn,
                    accessibilityLabel: "Light power",
                    isDisabled: detailState.blocksControlInteraction
                        || !homeAssistantService.serviceActionAvailable(domain: "light", service: service)
                ) { requestedState in
                    setPower(requestedState)
                }
            }
        ) {
            EmptyView()
        }
    }

    private func setPower(_ isOn: Bool) {
        let service = isOn ? "turn_on" : "turn_off"

        confirmOrPerform(domain: "light", service: service) {
            Task {
                if isOn {
                    await homeAssistantService.turnOnLight(entityID: entityBox.entityID)
                } else {
                    await homeAssistantService.turnOffLight(entityID: entityBox.entityID)
                }
            }
        }
    }

    private func brightnessControls(_ light: LightEntity) -> some View {
        EntityControlPanel(title: "Controls", systemImage: "slider.horizontal.3") {
            HStack {
                Text("Brightness")
                    .font(.body)

                Spacer()

                Text("\(Int(brightnessPercentage))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(light.isOn ? Color.accentColor : Color.secondary)
            }

            EntityDetailLevelSlider(
                value: $brightnessPercentage,
                range: 1...100,
                step: 1,
                isDisabled: detailState.blocksControlInteraction,
                accessibilityLabel: "Brightness",
                accessibilityValue: "\(Int(brightnessPercentage)) percent",
                onEditingChanged: { editing in
                    isEditingBrightness = editing
                },
                onCommit: { value in
                    setBrightness(value)
                }
            )

            Text(light.isOn ? "Adjusting brightness keeps this light on." : "Adjusting brightness will turn this light on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "lightbulb.fill",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entityBox.entityID),
                EntityMetadataRow(title: "Domain", value: entityBox.domain.displayName),
                EntityMetadataRow(title: "State", value: entityBox.homeEntity.state.displayStateText)
            ]
        )
    }

    private func lightIconColor(_ light: LightEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return .secondary }
        return light.isOn ? Color.accentColor : Color.secondary
    }

    private func lightIconBackground(_ light: LightEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return light.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func setBrightness(_ preset: Double) {
        brightnessPercentage = preset

        confirmOrPerform(domain: "light", service: "turn_on") {
            Task {
                await homeAssistantService.setLightBrightness(
                    entityID: entityBox.entityID,
                    brightnessPercentage: preset
                )
            }
        }
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

    private func syncBrightness(with light: LightEntity) {
        brightnessPercentage = Double(light.brightnessPercentage ?? 100)
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "light.living_room_lamps") {
        LightDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
