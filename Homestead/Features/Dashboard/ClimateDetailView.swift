import SwiftUI

struct ClimateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var targetTemperature = 70.0
    @State private var isEditingTemperature = false

    let entityBox: HAEntityState

    var body: some View {
        NavigationStack {
            if let climate = entityBox.climateEntity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        climateStatusCard(climate)

                        if climate.targetTemperature != nil {
                            temperatureControls(climate)
                        }

                        if !climate.hvacModes.isEmpty {
                            modeControls(climate)
                        }

                        if !climate.fanModes.isEmpty {
                            fanModeControls(climate)
                        }

                        if !climate.presetModes.isEmpty {
                            presetModeControls(climate)
                        }
                    }
                    .padding(AppSpacing.large)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Climate")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", role: .close) {
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    syncTargetTemperature(with: climate)
                }
                .onChange(of: climate.targetTemperature) { _, _ in
                    guard !isEditingTemperature else { return }
                    syncTargetTemperature(with: climate)
                }
            } else {
                ContentUnavailableView("Climate Unavailable", systemImage: "thermometer.medium")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func climateStatusCard(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: entityBox.homeEntity.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(climate.isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 64, height: 64)
                    .background(climate.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(climate.displayState)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(climate.isActive ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(climate.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(climate.displayName)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(climate.displaySubtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let currentTemperatureText = climate.currentTemperatureText {
                HStack {
                    Label("Current", systemImage: "thermometer.medium")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(currentTemperatureText)
                        .font(.headline.monospacedDigit())
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func temperatureControls(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Label("Set Temperature", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Spacer()

                Text(climate.formatTemperature(targetTemperature))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(climate.isActive ? Color.accentColor : Color.secondary)
            }

            HStack(spacing: AppSpacing.medium) {
                Button {
                    adjustTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(entityBox.pendingCommand != nil || targetTemperature <= climate.resolvedMinimumTemperature)
                .accessibilityLabel("Decrease temperature")

                Slider(
                    value: $targetTemperature,
                    in: climate.resolvedMinimumTemperature...climate.resolvedMaximumTemperature,
                    step: climate.resolvedTemperatureStep,
                    onEditingChanged: { editing in
                        isEditingTemperature = editing
                        guard !editing else { return }
                        setTargetTemperature()
                    }
                )
                .disabled(entityBox.pendingCommand != nil)

                Button {
                    adjustTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(entityBox.pendingCommand != nil || targetTemperature >= climate.resolvedMaximumTemperature)
                .accessibilityLabel("Increase temperature")
            }

            Text("Temperature changes are sent to Home Assistant and confirmed from live state.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func modeControls(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Mode", systemImage: "dial.medium")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: AppSpacing.small)], spacing: AppSpacing.small) {
                ForEach(climate.hvacModes, id: \.self) { mode in
                    Button {
                        Task {
                            await homeAssistantService.setClimateHVACMode(
                                entityID: entityBox.entityID,
                                hvacMode: mode
                            )
                        }
                    } label: {
                        Label(climate.displayName(forHVACMode: mode), systemImage: climate.iconName(forHVACMode: mode))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mode == climate.state ? Color.white : Color.primary)
                    .background(modeBackground(for: mode, climate: climate), in: Capsule())
                    .disabled(entityBox.pendingCommand != nil || mode == climate.state)
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func fanModeControls(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Fan", systemImage: "fan")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: AppSpacing.small)], spacing: AppSpacing.small) {
                ForEach(climate.fanModes, id: \.self) { fanMode in
                    Button {
                        Task {
                            await homeAssistantService.setClimateFanMode(
                                entityID: entityBox.entityID,
                                fanMode: fanMode
                            )
                        }
                    } label: {
                        Text(climate.displayName(forFanMode: fanMode))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(fanMode == climate.fanMode ? Color.white : Color.primary)
                    .background(fanMode == climate.fanMode ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
                    .disabled(entityBox.pendingCommand != nil || fanMode == climate.fanMode)
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func presetModeControls(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Preset", systemImage: "leaf")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: AppSpacing.small)], spacing: AppSpacing.small) {
                ForEach(climate.presetModes, id: \.self) { presetMode in
                    Button {
                        Task {
                            await homeAssistantService.setClimatePresetMode(
                                entityID: entityBox.entityID,
                                presetMode: presetMode
                            )
                        }
                    } label: {
                        Text(climate.displayName(forPresetMode: presetMode))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(presetMode == climate.presetMode ? Color.white : Color.primary)
                    .background(presetMode == climate.presetMode ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
                    .disabled(entityBox.pendingCommand != nil || presetMode == climate.presetMode)
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func adjustTemperature(by delta: Double, climate: ClimateEntity) {
        targetTemperature = min(
            max(targetTemperature + delta, climate.resolvedMinimumTemperature),
            climate.resolvedMaximumTemperature
        )
        setTargetTemperature()
    }

    private func setTargetTemperature() {
        Task {
            await homeAssistantService.setClimateTemperature(
                entityID: entityBox.entityID,
                temperature: targetTemperature
            )
        }
    }

    private func modeBackground(for mode: String, climate: ClimateEntity) -> Color {
        mode == climate.state ? Color.accentColor : Color(.tertiarySystemGroupedBackground)
    }

    private func syncTargetTemperature(with climate: ClimateEntity) {
        targetTemperature = climate.targetTemperature ?? climate.currentTemperature ?? 70
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "climate.downstairs") {
        ClimateDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
