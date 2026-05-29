import SwiftUI

struct FanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var percentage = 100.0
    @State private var isEditingPercentage = false

    let entityBox: HAEntityState

    var body: some View {
        NavigationStack {
            if let fan = entityBox.fanEntity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        statusCard(fan)
                        powerControls(fan)

                        if fan.percentage != nil {
                            percentageControls(fan)
                        }

                        if !fan.presetModes.isEmpty {
                            presetControls(fan)
                        }
                    }
                    .padding(AppSpacing.large)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Fan")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", role: .close) {
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    syncPercentage(with: fan)
                }
                .onChange(of: fan.percentage) { _, _ in
                    guard !isEditingPercentage else { return }
                    syncPercentage(with: fan)
                }
            } else {
                ContentUnavailableView("Fan Unavailable", systemImage: "fan")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func statusCard(_ fan: FanEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: entityBox.homeEntity.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(fan.isOn ? Color.accentColor : Color.secondary)
                    .frame(width: 64, height: 64)
                    .background(fan.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(fan.displaySubtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(fan.isOn ? Color.accentColor : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(fan.isOn ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(fan.displayName)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(statusSummary(fan))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func powerControls(_ fan: FanEntity) -> some View {
        let isPending = entityBox.pendingCommand != nil

        return Button {
            Task { await homeAssistantService.toggleFan(entityID: entityBox.entityID) }
        } label: {
            Label(
                isPending ? "Updating..." : (fan.isOn ? "Turn Off" : "Turn On"),
                systemImage: fan.isOn ? "power" : "fan.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isPending || !fan.isAvailable)
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

            Slider(
                value: $percentage,
                in: 0...100,
                step: fan.resolvedPercentageStep,
                onEditingChanged: { editing in
                    isEditingPercentage = editing
                    guard !editing else { return }
                    setPercentage()
                }
            )
            .disabled(entityBox.pendingCommand != nil || !fan.isAvailable)
            .accessibilityLabel("Fan speed")
            .accessibilityValue("\(Int(percentage)) percent")

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
                    Button {
                        Task {
                            await homeAssistantService.setFanPresetMode(
                                entityID: fan.entityID,
                                presetMode: presetMode
                            )
                        }
                    } label: {
                        Text(fan.displayName(forPresetMode: presetMode))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(presetMode == fan.presetMode ? Color.white : Color.primary)
                    .background(presetMode == fan.presetMode ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
                    .disabled(entityBox.pendingCommand != nil || presetMode == fan.presetMode || !fan.isAvailable)
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func statusSummary(_ fan: FanEntity) -> String {
        guard fan.isAvailable else { return "Fan unavailable" }
        guard fan.isOn else { return "Currently idle" }
        return fan.percentage.map { "Running at \($0)%" } ?? "Currently active"
    }

    private func setPercentage() {
        Task {
            await homeAssistantService.setFanPercentage(
                entityID: entityBox.entityID,
                percentage: percentage
            )
        }
    }

    private func syncPercentage(with fan: FanEntity) {
        percentage = Double(fan.percentage ?? (fan.isOn ? 100 : 0))
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
