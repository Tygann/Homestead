import SwiftUI

struct LightDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var brightnessPercentage = 100.0
    @State private var isEditingBrightness = false

    let entityBox: HAEntityState

    var body: some View {
        NavigationStack {
            if let light = entityBox.lightEntity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        lightHeader(light)
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

    private func lightHeader(_ light: LightEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            CardIconView(systemName: light.iconName, isActive: light.isOn)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(light.displayName)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(light.isOn ? "On" : "Off")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func powerControls(_ light: LightEntity) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Button {
                Task { await homeAssistantService.turnOffLight(entityID: entityBox.entityID) }
            } label: {
                Label("Off", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!light.isOn)

            Button {
                Task { await homeAssistantService.turnOnLight(entityID: entityBox.entityID) }
            } label: {
                Label("On", systemImage: "lightbulb.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(light.isOn)
        }
        .controlSize(.large)
    }

    private func brightnessControls(_ light: LightEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Label("Brightness", systemImage: "sun.max.fill")
                    .font(.headline)

                Spacer()

                Text("\(Int(brightnessPercentage))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
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

            Text(light.isOn ? "Adjusting brightness keeps this light on." : "Adjusting brightness will turn this light on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
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
