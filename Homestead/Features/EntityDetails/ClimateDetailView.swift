import SwiftUI

struct ClimateDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var targetTemperature = 70.0
    @State private var targetLowTemperature = 68.0
    @State private var targetHighTemperature = 76.0
    @State private var isEditingTemperature = false
    @State private var isEditingTemperatureRange = false
    @State private var pendingTemperatureTask: Task<Void, Never>?
    @State private var pendingTemperatureRangeTask: Task<Void, Never>?
    @State private var isOptimisticTemperature = false
    @State private var isOptimisticTemperatureRange = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    @ViewBuilder
    var body: some View {
        if let climate = entityBox.climateEntity {
            EntityDetailScaffold(title: "Climate", presentationStyle: presentationStyle) {
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

                contextDetails
            }
            .onAppear {
                syncTargetTemperature(with: climate)
                syncTargetTemperatureRange(with: climate)
            }
            .onChange(of: climate.targetTemperature) { _, _ in
                guard !isEditingTemperature, !isOptimisticTemperature else { return }
                syncTargetTemperature(with: climate)
            }
            .onChange(of: climate.targetTemperatureLow) { _, _ in
                guard !isEditingTemperatureRange, !isOptimisticTemperatureRange else { return }
                syncTargetTemperatureRange(with: climate)
            }
            .onChange(of: climate.targetTemperatureHigh) { _, _ in
                guard !isEditingTemperatureRange, !isOptimisticTemperatureRange else { return }
                syncTargetTemperatureRange(with: climate)
            }
        } else {
            EntityUnavailableDetailView(
                title: "Climate",
                systemImage: "thermometer.medium",
                presentationStyle: presentationStyle
            )
        }
    }

    private func header(_ climate: ClimateEntity) -> some View {
        EntityDetailHeader(
            icon: entityBox.homeEntity.resolvedIcon,
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
                EntityMetadataRow(title: "Temperature", value: climate.currentTemperatureText ?? "-")
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
                EntityDetailIconButton(
                    systemImage: "minus",
                    accessibilityLabel: "Decrease temperature",
                    isDisabled: !isClimateAvailable(climate) || targetTemperature <= climate.resolvedMinimumTemperature
                ) {
                    adjustTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                }

                EntityDetailLevelSlider(
                    value: $targetTemperature,
                    range: climate.resolvedMinimumTemperature...climate.resolvedMaximumTemperature,
                    step: climate.resolvedTemperatureStep,
                    isDisabled: !isClimateAvailable(climate),
                    accessibilityLabel: "Target temperature",
                    accessibilityValue: climate.formatTemperature(targetTemperature),
                    onEditingChanged: { editing in
                        isEditingTemperature = editing
                    },
                    onCommit: { value in
                        setTargetTemperature(value, climate: climate)
                    }
                )

                EntityDetailIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Increase temperature",
                    isDisabled: !isClimateAvailable(climate) || targetTemperature >= climate.resolvedMaximumTemperature
                ) {
                    adjustTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                }
            }
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
                fillColor: .orange,
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
                fillColor: .cyan,
                decreaseAction: {
                    adjustHighTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                },
                increaseAction: {
                    adjustHighTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                }
            )
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
        fillColor: Color,
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
                EntityDetailIconButton(
                    systemImage: "minus",
                    accessibilityLabel: "Decrease \(title.lowercased())",
                    isDisabled: !isClimateAvailable(climate) || value.wrappedValue <= range.lowerBound,
                    action: decreaseAction
                )

                EntityDetailLevelSlider(
                    value: value,
                    range: range,
                    step: climate.resolvedTemperatureStep,
                    fillColor: fillColor,
                    showsFilledTrack: false,
                    isDisabled: !isClimateAvailable(climate),
                    accessibilityLabel: title,
                    accessibilityValue: climate.formatTemperature(value.wrappedValue),
                    onEditingChanged: { editing in
                        isEditingTemperatureRange = editing
                    },
                    onCommit: { _ in
                        setTargetTemperatureRange(climate: climate)
                    }
                )

                EntityDetailIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Increase \(title.lowercased())",
                    isDisabled: !isClimateAvailable(climate) || value.wrappedValue >= range.upperBound,
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
                    EntityDetailPillButton(
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
        EntityControlPanel(title: "Options", systemImage: "slider.horizontal.3") {
            VStack(spacing: AppSpacing.small) {
                if showsFanModeOptions(climate) {
                    EntityDetailMenuRow(
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
                    EntityDetailMenuRow(
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

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "thermometer.medium",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entityBox.entityID),
                EntityMetadataRow(title: "Domain", value: entityBox.domain.displayName),
                EntityMetadataRow(title: "State", value: entityBox.homeEntity.state.displayStateText)
            ]
        )
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
        targetTemperature = ClimateSetpointAdjustment(climate: climate)
            .clampedSingleTemperature(targetTemperature + delta)
        setTargetTemperature(climate: climate)
    }

    private func adjustLowTemperature(by delta: Double, climate: ClimateEntity) {
        let range = ClimateSetpointAdjustment(climate: climate).adjustedLowTemperature(
            currentLowTemperature: targetLowTemperature,
            currentHighTemperature: targetHighTemperature,
            delta: delta
        )
        targetLowTemperature = range.lowTemperature
        targetHighTemperature = range.highTemperature
        setTargetTemperatureRange(climate: climate)
    }

    private func adjustHighTemperature(by delta: Double, climate: ClimateEntity) {
        let range = ClimateSetpointAdjustment(climate: climate).adjustedHighTemperature(
            currentLowTemperature: targetLowTemperature,
            currentHighTemperature: targetHighTemperature,
            delta: delta
        )
        targetLowTemperature = range.lowTemperature
        targetHighTemperature = range.highTemperature
        setTargetTemperatureRange(climate: climate)
    }

    private func setTargetTemperature(_ updatedTemperature: Double? = nil, climate: ClimateEntity) {
        if let updatedTemperature {
            targetTemperature = ClimateSetpointAdjustment(climate: climate)
                .clampedSingleTemperature(updatedTemperature)
        }

        isOptimisticTemperature = true
        pendingTemperatureTask?.cancel()
        pendingTemperatureTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await homeAssistantService.setClimateTemperature(
                entityID: entityBox.entityID,
                temperature: targetTemperature
            )
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            isOptimisticTemperature = false
            pendingTemperatureTask = nil
        }
    }

    private func setTargetTemperatureRange(climate: ClimateEntity) {
        let range = ClimateSetpointAdjustment(climate: climate)
            .clampedRange(lowTemperature: targetLowTemperature, highTemperature: targetHighTemperature)
        targetLowTemperature = range.lowTemperature
        targetHighTemperature = range.highTemperature

        isOptimisticTemperatureRange = true
        pendingTemperatureRangeTask?.cancel()
        pendingTemperatureRangeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await homeAssistantService.setClimateTemperatureRange(
                entityID: entityBox.entityID,
                lowTemperature: targetLowTemperature,
                highTemperature: targetHighTemperature
            )
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            isOptimisticTemperatureRange = false
            pendingTemperatureRangeTask = nil
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
