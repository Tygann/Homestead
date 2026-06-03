import SwiftUI

struct ClimateDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var targetTemperature = 70.0
    @State private var targetLowTemperature = 68.0
    @State private var targetHighTemperature = 76.0
    @State private var isEditingTemperature = false
    @State private var isEditingTemperatureRange = false

    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    @ViewBuilder
    var body: some View {
        if let climate = entityBox.climateEntity {
            DashboardEntityDetailScaffold(title: "Climate", presentationStyle: presentationStyle) {
                header(climate)

                if climate.currentTemperatureText != nil {
                    currentTemperaturePanel(climate)
                }

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

                if showsSecondaryOptions(climate) {
                    secondaryOptionControls(climate)
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
            DashboardUnavailableDetailView(
                title: "Climate",
                systemImage: "thermometer.medium",
                presentationStyle: presentationStyle
            )
        }
    }

    private func header(_ climate: ClimateEntity) -> some View {
        DashboardEntityDetailHeader(
            iconName: entityBox.homeEntity.iconName,
            title: climate.displayName,
            subtitle: climate.displaySubtitle,
            badge: climate.displayState,
            iconColor: climateIconColor(climate),
            badgeColor: climateBadgeColor(climate),
            iconBackground: climateStatusBackground(climate),
            badgeBackground: climateStatusBackground(climate)
        )
    }

    private func currentTemperaturePanel(_ climate: ClimateEntity) -> some View {
        DashboardEntityContextPanel(
            title: "Current",
            systemImage: "thermometer.medium",
            rows: [
                DashboardEntityDetailRow(title: "Temperature", value: climate.currentTemperatureText ?? "-")
            ]
        )
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
                DashboardDetailIconButton(
                    systemImage: "minus",
                    accessibilityLabel: "Decrease temperature",
                    isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate) || targetTemperature <= climate.resolvedMinimumTemperature
                ) {
                    adjustTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                }

                DashboardDetailLevelSlider(
                    value: $targetTemperature,
                    range: climate.resolvedMinimumTemperature...climate.resolvedMaximumTemperature,
                    step: climate.resolvedTemperatureStep,
                    isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate),
                    accessibilityLabel: "Target temperature",
                    accessibilityValue: climate.formatTemperature(targetTemperature),
                    onEditingChanged: { editing in
                        isEditingTemperature = editing
                    },
                    onCommit: { value in
                        setTargetTemperature(value)
                    }
                )

                DashboardDetailIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Increase temperature",
                    isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate) || targetTemperature >= climate.resolvedMaximumTemperature
                ) {
                    adjustTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                }
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
                DashboardDetailIconButton(
                    systemImage: "minus",
                    accessibilityLabel: "Decrease \(title.lowercased())",
                    isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate) || value.wrappedValue <= range.lowerBound,
                    action: decreaseAction
                )

                DashboardDetailLevelSlider(
                    value: value,
                    range: range,
                    step: climate.resolvedTemperatureStep,
                    isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate),
                    accessibilityLabel: title,
                    accessibilityValue: climate.formatTemperature(value.wrappedValue),
                    onEditingChanged: { editing in
                        isEditingTemperatureRange = editing
                    },
                    onCommit: { _ in
                        setTargetTemperatureRange()
                    }
                )

                DashboardDetailIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Increase \(title.lowercased())",
                    isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate) || value.wrappedValue >= range.upperBound,
                    action: increaseAction
                )
            }
        }
    }

    private func modeControls(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Mode", systemImage: "dial.medium")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: AppSpacing.small)], spacing: AppSpacing.small) {
                ForEach(climate.hvacModes, id: \.self) { mode in
                    DashboardDetailPillButton(
                        title: climate.displayName(forHVACMode: mode),
                        systemImage: climate.iconName(forHVACMode: mode),
                        isSelected: mode == climate.state,
                        isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate) || mode == climate.state
                    ) {
                        Task {
                            await homeAssistantService.setClimateHVACMode(
                                entityID: entityBox.entityID,
                                hvacMode: mode
                            )
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func secondaryOptionControls(_ climate: ClimateEntity) -> some View {
        DashboardControlPanel(title: "Options", systemImage: "slider.horizontal.3") {
            VStack(spacing: AppSpacing.small) {
                if showsFanModeOptions(climate) {
                    DashboardDetailMenuRow(
                        title: "Fan",
                        systemImage: "fan.fill",
                        value: climate.fanMode.map(climate.displayName(forFanMode:)) ?? "Auto",
                        isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate)
                    ) {
                        ForEach(climate.fanModes, id: \.self) { fanMode in
                            Button {
                                Task {
                                    await homeAssistantService.setClimateFanMode(
                                        entityID: entityBox.entityID,
                                        fanMode: fanMode
                                    )
                                }
                            } label: {
                                Label(
                                    climate.displayName(forFanMode: fanMode),
                                    systemImage: fanMode == climate.fanMode ? "checkmark" : "fan.fill"
                                )
                            }
                            .disabled(fanMode == climate.fanMode)
                        }
                    }
                }

                if showsPresetModeOptions(climate) {
                    DashboardDetailMenuRow(
                        title: "Preset",
                        systemImage: "leaf",
                        value: climate.presetMode.map(climate.displayName(forPresetMode:)) ?? "None",
                        isDisabled: entityBox.pendingCommand != nil || !isClimateAvailable(climate)
                    ) {
                        ForEach(climate.presetModes, id: \.self) { presetMode in
                            Button {
                                Task {
                                    await homeAssistantService.setClimatePresetMode(
                                        entityID: entityBox.entityID,
                                        presetMode: presetMode
                                    )
                                }
                            } label: {
                                Label(
                                    climate.displayName(forPresetMode: presetMode),
                                    systemImage: presetMode == climate.presetMode ? "checkmark" : "leaf"
                                )
                            }
                            .disabled(presetMode == climate.presetMode)
                        }
                    }
                }
            }
        }
    }

    private func showsSecondaryOptions(_ climate: ClimateEntity) -> Bool {
        showsFanModeOptions(climate) || showsPresetModeOptions(climate)
    }

    private func showsFanModeOptions(_ climate: ClimateEntity) -> Bool {
        !climate.fanModes.isEmpty && homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_fan_mode")
    }

    private func showsPresetModeOptions(_ climate: ClimateEntity) -> Bool {
        !climate.presetModes.isEmpty && homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_preset_mode")
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

    private func setTargetTemperature(_ updatedTemperature: Double? = nil) {
        if let updatedTemperature {
            targetTemperature = updatedTemperature
        }

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

    private func isClimateAvailable(_ climate: ClimateEntity) -> Bool {
        !["unavailable", "unknown"].contains(climate.state)
    }

    private func climateIconColor(_ climate: ClimateEntity) -> Color {
        guard isClimateAvailable(climate) else { return .secondary }
        return climate.isActive ? Color.accentColor : Color.secondary
    }

    private func climateBadgeColor(_ climate: ClimateEntity) -> Color {
        guard isClimateAvailable(climate) else { return .red }
        return climate.isActive ? Color.accentColor : Color.secondary
    }

    private func climateStatusBackground(_ climate: ClimateEntity) -> Color {
        guard isClimateAvailable(climate) else { return Color.red.opacity(0.12) }
        return climate.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
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
