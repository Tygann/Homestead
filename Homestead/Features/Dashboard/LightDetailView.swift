import SwiftUI

struct LightDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var brightnessPercentage = 100.0
    @State private var isEditingBrightness = false

    let entityBox: HAEntityState
    private let brightnessPresets = [25.0, 50.0, 75.0, 100.0]

    var body: some View {
        NavigationStack {
            if let light = entityBox.lightEntity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        lightStatusCard(light)
                        powerControls(light)
                        brightnessControls(light)
                    }
                    .padding(AppSpacing.large)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Light")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
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
            } else {
                ContentUnavailableView("Light Unavailable", systemImage: "lightbulb.slash")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func lightStatusCard(_ light: LightEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: light.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(light.isOn ? Color.accentColor : Color.secondary)
                    .frame(width: 64, height: 64)
                    .background(light.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(light.isOn ? "On" : "Off")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(light.isOn ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(light.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(light.displayName)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(lightStatusText(light))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func powerControls(_ light: LightEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Button {
                Task {
                    if light.isOn {
                        await homeAssistantService.turnOffLight(entityID: entityBox.entityID)
                    } else {
                        await homeAssistantService.turnOnLight(entityID: entityBox.entityID)
                    }
                }
            } label: {
                Label(light.isOn ? "Turn Off" : "Turn On", systemImage: light.isOn ? "power" : "lightbulb.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
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

            Slider(
                value: $brightnessPercentage,
                in: 1...100,
                step: 1,
                onEditingChanged: { editing in
                    isEditingBrightness = editing
                    guard !editing else { return }

                    Task {
                        await homeAssistantService.setLightBrightness(
                            entityID: entityBox.entityID,
                            brightnessPercentage: brightnessPercentage
                        )
                    }
                }
            )

            HStack(spacing: AppSpacing.small) {
                ForEach(brightnessPresets, id: \.self) { preset in
                    Button {
                        setBrightness(preset)
                    } label: {
                        Text("\(Int(preset))%")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelectedPreset(preset) ? Color.white : Color.primary)
                    .background(presetBackground(for: preset), in: Capsule())
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

    private func lightStatusText(_ light: LightEntity) -> String {
        guard light.isOn else { return "Ready to turn on" }
        guard let brightnessPercentage = light.brightnessPercentage else { return "On" }

        return "\(brightnessPercentage)% brightness"
    }

    private func setBrightness(_ preset: Double) {
        brightnessPercentage = preset

        Task {
            await homeAssistantService.setLightBrightness(
                entityID: entityBox.entityID,
                brightnessPercentage: preset
            )
        }
    }

    private func isSelectedPreset(_ preset: Double) -> Bool {
        abs(brightnessPercentage - preset) < 0.5
    }

    private func presetBackground(for preset: Double) -> Color {
        isSelectedPreset(preset) ? Color.accentColor : Color(.tertiarySystemGroupedBackground)
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
