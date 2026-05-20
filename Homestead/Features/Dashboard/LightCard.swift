import SwiftUI

struct LightCard: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var brightnessPercentage = 100.0

    let entityID: String

    var body: some View {
        if let light = stateStore.lightEntity(for: entityID) {
            CardContainer(isActive: light.isOn) {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Button {
                        Task { await homeAssistantService.toggleLight(entityID: entityID) }
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.large) {
                            CardIconView(systemName: light.iconName, isActive: light.isOn)

                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text(light.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)

                                Text(lightSubtitle(for: light))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(HomeCardButtonStyle())

                    if light.isOn {
                        brightnessControl
                    }
                }
                .frame(minHeight: light.isOn ? 168 : 124, alignment: .topLeading)
            }
            .onAppear { syncBrightness(with: light) }
            .onChange(of: light.brightness) { _, _ in syncBrightness(with: light) }
            .onChange(of: light.isOn) { _, _ in syncBrightness(with: light) }
            .accessibilityLabel(light.displayName)
            .accessibilityValue(light.isOn ? "On" : "Off")
        }
    }

    private var brightnessControl: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack {
                Image(systemName: "sun.min")
                Slider(
                    value: $brightnessPercentage,
                    in: 1...100,
                    step: 1,
                    onEditingChanged: { editing in
                        guard !editing else { return }
                        Task {
                            await homeAssistantService.setLightBrightness(
                                entityID: entityID,
                                brightnessPercentage: brightnessPercentage
                            )
                        }
                    }
                )
                Image(systemName: "sun.max.fill")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Text("\(Int(brightnessPercentage))% brightness")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Brightness")
        .accessibilityValue("\(Int(brightnessPercentage)) percent")
    }

    private func lightSubtitle(for light: LightEntity) -> String {
        guard light.isOn else { return "Off" }
        guard let brightnessPercentage = light.brightnessPercentage else { return "On" }

        return "\(brightnessPercentage)%"
    }

    private func syncBrightness(with light: LightEntity) {
        brightnessPercentage = Double(light.brightnessPercentage ?? 100)
    }
}

#if DEBUG
#Preview {
    LightCard(entityID: "light.living_room_lamps")
        .padding()
        .background(Color(.systemGroupedBackground))
        .withPreviewEnvironment()
}
#endif
