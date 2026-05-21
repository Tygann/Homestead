import SwiftUI

struct LightCard: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isShowingDetails = false

    let entityBox: HAEntityState

    var body: some View {
        if let light = entityBox.lightEntity {
            CardContainer(isActive: light.isOn) {
                ZStack(alignment: .topTrailing) {
                    Button {
                        Task { await homeAssistantService.toggleLight(entityID: entityBox.entityID) }
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

                    Button {
                        isShowingDetails = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                    }
                    .accessibilityLabel("Show controls for \(light.displayName)")
                }
            }
            .sheet(isPresented: $isShowingDetails) {
                LightDetailView(entityBox: entityBox)
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
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "light.living_room_lamps") {
        LightCard(entityBox: entityBox)
            .padding()
            .background(Color(.systemGroupedBackground))
            .withPreviewEnvironment()
    }
}
#endif
