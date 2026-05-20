import SwiftUI

struct LightCard: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityID: String

    var body: some View {
        if let light = stateStore.lightEntity(for: entityID) {
            CardContainer(isActive: light.isOn) {
                Button {
                    Task { await homeAssistantService.toggleLight(entityID: entityID) }
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        CardIconView(systemName: light.iconName, isActive: light.isOn)

                        Spacer(minLength: AppSpacing.small)

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
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                }
                .buttonStyle(HomeCardButtonStyle())
            }
            .accessibilityLabel(light.displayName)
            .accessibilityValue(light.isOn ? "On" : "Off")
        }
    }

    private func lightSubtitle(for light: LightEntity) -> String {
        guard light.isOn else { return "Off" }
        guard let brightnessPercentage = light.brightnessPercentage else { return "On" }

        return "\(brightnessPercentage)%"
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
