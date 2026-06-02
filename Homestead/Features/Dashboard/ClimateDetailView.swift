import SwiftUI

struct ClimateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var targetTemperature = 70.0
    @State private var targetLowTemperature = 68.0
    @State private var targetHighTemperature = 76.0
    @State private var isEditingTemperature = false
    @State private var isEditingTemperatureRange = false

    let entityBox: HAEntityState

    var body: some View {
        NavigationStack {
            if let climate = entityBox.climateEntity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        climateStatusCard(climate)

                        if climate.usesTemperatureRange,
                           homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature") {
                            temperatureRangeControls(climate)
                        } else if climate.targetTemperature != nil,
                                  homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature") {
                            temperatureControls(climate)
                        }

                        if !climate.hvacModes.isEmpty,
                           homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_hvac_mode") {
                            modeControls(climate)
                        }

                        if !climate.fanModes.isEmpty,
                           homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_fan_mode") {
                            fanModeControls(climate)
                        }

                        if !climate.presetModes.isEmpty,
                           homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_preset_mode") {
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
                    syncTargetTemperatureRange(with: climate)
                }
                .onChange(of: climate.targetTemperature) { _, _ in
                    guard !isEditingTemperature else { return }
                    syncTargetTemperature(with: climate)
                }
                .onChange(of: climate.targetTemperatureLow) { _, _ in
                    guard !isEditingTemperatureRange else { return }
                    syncTargetTemperatureRange(with: climate)
                }
                .onChange(of: climate.targetTemperatureHigh) { _, _ in
                    guard !isEditingTemperatureRange else { return }
                    syncTargetTemperatureRange(with: climate)
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
                .accessibilityLabel("Target temperature")
                .accessibilityValue(climate.formatTemperature(targetTemperature))

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

    private func temperatureRangeControls(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Label("Temperature Range", systemImage: "slider.horizontal.below.sun.max")
                    .font(.headline)

                Spacer()

                Text("\(climate.formatTemperature(targetLowTemperature))-\(climate.formatTemperature(targetHighTemperature))")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(climate.isActive ? Color.accentColor : Color.secondary)
            }

            temperatureRangeRow(
                title: "Heat to",
                systemImage: "flame.fill",
                value: $targetLowTemperature,
                range: climate.resolvedMinimumTemperature...targetHighTemperature,
                climate: climate,
                decreaseAction: {
                    adjustLowTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                },
                increaseAction: {
                    adjustLowTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                }
            )

            temperatureRangeRow(
                title: "Cool to",
                systemImage: "snowflake",
                value: $targetHighTemperature,
                range: targetLowTemperature...climate.resolvedMaximumTemperature,
                climate: climate,
                decreaseAction: {
                    adjustHighTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                },
                increaseAction: {
                    adjustHighTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                }
            )

            Text("Auto mode uses Home Assistant's heating and cooling setpoints.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func temperatureRangeRow(
        title: String,
        systemImage: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        climate: ClimateEntity,
        decreaseAction: @escaping () -> Void,
        increaseAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(climate.formatTemperature(value.wrappedValue))
                    .font(.headline.monospacedDigit())
            }

            HStack(spacing: AppSpacing.medium) {
                Button(action: decreaseAction) {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(entityBox.pendingCommand != nil || value.wrappedValue <= range.lowerBound)
                .accessibilityLabel("Decrease \(title.lowercased())")

                Slider(
                    value: value,
                    in: range,
                    step: climate.resolvedTemperatureStep,
                    onEditingChanged: { editing in
                        isEditingTemperatureRange = editing
                        guard !editing else { return }
                        setTargetTemperatureRange()
                    }
                )
                .disabled(entityBox.pendingCommand != nil)
                .accessibilityLabel(title)
                .accessibilityValue(climate.formatTemperature(value.wrappedValue))

                Button(action: increaseAction) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(entityBox.pendingCommand != nil || value.wrappedValue >= range.upperBound)
                .accessibilityLabel("Increase \(title.lowercased())")
            }
        }
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
            Label("Fan", systemImage: "fan.fill")
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

    private func adjustLowTemperature(by delta: Double, climate: ClimateEntity) {
        targetLowTemperature = min(
            max(targetLowTemperature + delta, climate.resolvedMinimumTemperature),
            targetHighTemperature
        )
        setTargetTemperatureRange()
    }

    private func adjustHighTemperature(by delta: Double, climate: ClimateEntity) {
        targetHighTemperature = min(
            max(targetHighTemperature + delta, targetLowTemperature),
            climate.resolvedMaximumTemperature
        )
        setTargetTemperatureRange()
    }

    private func setTargetTemperature() {
        Task {
            await homeAssistantService.setClimateTemperature(
                entityID: entityBox.entityID,
                temperature: targetTemperature
            )
        }
    }

    private func setTargetTemperatureRange() {
        Task {
            await homeAssistantService.setClimateTemperatureRange(
                entityID: entityBox.entityID,
                lowTemperature: targetLowTemperature,
                highTemperature: targetHighTemperature
            )
        }
    }

    private func modeBackground(for mode: String, climate: ClimateEntity) -> Color {
        mode == climate.state ? Color.accentColor : Color(.tertiarySystemGroupedBackground)
    }

    private func syncTargetTemperature(with climate: ClimateEntity) {
        targetTemperature = climate.targetTemperature ?? climate.currentTemperature ?? 70
    }

    private func syncTargetTemperatureRange(with climate: ClimateEntity) {
        targetLowTemperature = climate.targetTemperatureLow ?? climate.targetTemperature ?? climate.currentTemperature ?? 68
        targetHighTemperature = climate.targetTemperatureHigh ?? max(targetLowTemperature, climate.targetTemperature ?? climate.currentTemperature ?? 76)
        if targetHighTemperature < targetLowTemperature {
            targetHighTemperature = targetLowTemperature
        }
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
