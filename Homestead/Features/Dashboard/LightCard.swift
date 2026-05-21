import SwiftUI

struct LightCard: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var isShowingDetails = false

    let entityBox: HAEntityState

    var body: some View {
        if let light = entityBox.lightEntity {
            CardContainer(isActive: light.isOn) {
                ZStack(alignment: .topLeading) {
                    Button {
                        isShowingDetails = true
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            Color.clear
                                .frame(width: 44, height: 44)

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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .accessibilityLabel("Show controls for \(light.displayName)")

                    Button {
                        Task { await homeAssistantService.toggleLight(entityID: entityBox.entityID) }
                    } label: {
                        CardIconView(systemName: light.iconName, isActive: light.isOn)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Toggle \(light.displayName)")
                    .accessibilityValue(light.isOn ? "On" : "Off")
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
