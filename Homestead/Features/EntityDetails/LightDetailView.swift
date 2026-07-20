import SwiftUI

struct LightDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var brightnessPercentage = 100.0
    @State private var isEditingBrightness = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private let brightnessPresets = [25.0, 50.0, 75.0, 100.0]

    @ViewBuilder
    var body: some View {
        if let light = entityBox.lightEntity {
            EntityDetailScaffold(title: light.displayName, presentationStyle: presentationStyle) {
                header(light)
                powerControls(light)

                if light.supportsBrightness,
                   homeAssistantService.serviceActionAvailable(domain: "light", service: "turn_on") {
                    brightnessControls(light)
                }

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
        EntityDetailHeader(
            entityBox: entityBox,
            icon: entityBox.homeEntity.resolvedIcon,
            category: "Light",
            summary: nil,
            status: nil,
            iconColor: lightIconColor(light),
            iconBackground: lightIconBackground(light)
        )
    }

    private func powerControls(_ light: LightEntity) -> some View {
        let isPending = entityBox.pendingCommand != nil
        let service = light.isOn ? "turn_off" : "turn_on"

        return EntityControlPanel(title: "Control", systemImage: "power") {
            EntityDetailActionButton(
                title: isPending ? "Updating..." : (light.isOn ? "Turn Off" : "Turn On"),
                systemImage: "power",
                style: light.isOn ? .secondary : .primary,
                isDisabled: isPending || !entityBox.homeEntity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "light", service: service)
            ) {
                confirmOrPerform(domain: "light", service: service) {
                    Task {
                    if light.isOn {
                        await homeAssistantService.turnOffLight(entityID: entityBox.entityID)
                    } else {
                        await homeAssistantService.turnOnLight(entityID: entityBox.entityID)
                    }
                    }
                }
            }
        }
    }

    private func brightnessControls(_ light: LightEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Label("Brightness", systemImage: "sun.max.fill")
                    .font(.headline)

                Spacer()

                Text("\(Int(brightnessPercentage))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(light.isOn ? Color.accentColor : Color.secondary)
            }

            EntityDetailLevelSlider(
                value: $brightnessPercentage,
                range: 1...100,
                step: 1,
                isDisabled: entityBox.pendingCommand != nil || !entityBox.homeEntity.isAvailable,
                accessibilityLabel: "Brightness",
                accessibilityValue: "\(Int(brightnessPercentage)) percent",
                onEditingChanged: { editing in
                    isEditingBrightness = editing
                },
                onCommit: { value in
                    setBrightness(value)
                }
            )

            HStack(spacing: AppSpacing.small) {
                ForEach(brightnessPresets, id: \.self) { preset in
                    EntityDetailPillButton(
                        title: "\(Int(preset))%",
                        isSelected: isSelectedPreset(preset),
                        isDisabled: entityBox.pendingCommand != nil || !entityBox.homeEntity.isAvailable
                    ) {
                        setBrightness(preset)
                    }
                    .accessibilityLabel("Set brightness to \(Int(preset)) percent")
                }
            }

            Text(light.isOn ? "Adjusting brightness keeps this light on." : "Adjusting brightness will turn this light on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
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

    private func lightStatusText(_ light: LightEntity) -> String {
        guard light.isOn else { return "Ready to turn on" }
        guard let brightnessPercentage = light.brightnessPercentage else { return "On" }

        return "\(brightnessPercentage)% brightness"
    }

    private func lightBadgeText(_ light: LightEntity) -> String {
        guard entityBox.homeEntity.isAvailable else { return "Unavailable" }
        return light.isOn ? "On" : "Off"
    }

    private func lightIconColor(_ light: LightEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return .secondary }
        return light.isOn ? Color.accentColor : Color.secondary
    }

    private func lightBadgeColor(_ light: LightEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return .red }
        return light.isOn ? Color.accentColor : Color.secondary
    }

    private func lightIconBackground(_ light: LightEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return light.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func lightBadgeBackground(_ light: LightEntity) -> Color {
        guard entityBox.homeEntity.isAvailable else { return Color.red.opacity(0.12) }
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

    private func isSelectedPreset(_ preset: Double) -> Bool {
        abs(brightnessPercentage - preset) < 0.5
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
