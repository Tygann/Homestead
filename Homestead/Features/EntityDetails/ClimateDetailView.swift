import SwiftUI

struct ClimateDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var targetTemperature = 70.0
    @State private var targetLowTemperature = 68.0
    @State private var targetHighTemperature = 76.0
    @State private var pendingTemperatureTask: Task<Void, Never>?
    @State private var pendingTemperatureRangeTask: Task<Void, Never>?
    @State private var isOptimisticTemperature = false
    @State private var isOptimisticTemperatureRange = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    @ViewBuilder
    var body: some View {
        if let climate = entityBox.climateEntity {
            EntityDetailScaffold(title: climate.displayName, presentationStyle: presentationStyle) {
                header(climate)

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
                guard !isOptimisticTemperature else { return }
                syncTargetTemperature(with: climate)
            }
            .onChange(of: climate.targetTemperatureLow) { _, _ in
                guard !isOptimisticTemperatureRange else { return }
                syncTargetTemperatureRange(with: climate)
            }
            .onChange(of: climate.targetTemperatureHigh) { _, _ in
                guard !isOptimisticTemperatureRange else { return }
                syncTargetTemperatureRange(with: climate)
            }
        } else {
            EntityUnavailableDetailView(
                title: entityBox.homeEntity.displayName,
                systemImage: "thermometer.medium",
                presentationStyle: presentationStyle
            )
        }
    }

    private func header(_ climate: ClimateEntity) -> some View {
        EntityDetailHeroCard(
            icon: entityBox.homeEntity.resolvedIcon,
            title: "Climate",
            subtitle: EntityDetailHeroSubtitle.updated(entityBox.homeEntity),
            status: nil,
            iconColor: climateIconColor(climate),
            iconBackground: climateStatusBackground(climate),
            statePresentation: detailState,
            accessory: {
                if let currentTemperatureText = climate.currentTemperatureText {
                    Text(currentTemperatureText)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(climateIconColor(climate))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .monospacedDigit()
                }
            }
        ) {
            EmptyView()
        }
    }

    private func temperatureControls(_ climate: ClimateEntity) -> some View {
        EntityControlPanel(title: "Temperature", systemImage: "thermometer.medium") {
            temperatureStepper(
                title: "Target",
                systemImage: "scope",
                value: targetTemperature,
                climate: climate,
                canDecrease: targetTemperature > climate.resolvedMinimumTemperature,
                canIncrease: targetTemperature < climate.resolvedMaximumTemperature,
                decreaseAction: { adjustTemperature(by: -climate.resolvedTemperatureStep, climate: climate) },
                increaseAction: { adjustTemperature(by: climate.resolvedTemperatureStep, climate: climate) }
            )
        }
    }

    private func temperatureRangeControls(_ climate: ClimateEntity) -> some View {
        EntityControlPanel(title: "Temperature", systemImage: "thermometer.medium") {
            VStack(spacing: AppSpacing.small) {
                temperatureStepper(
                title: "Heat to",
                systemImage: "flame.fill",
                value: targetLowTemperature,
                climate: climate,
                canDecrease: targetLowTemperature > climate.resolvedMinimumTemperature,
                canIncrease: targetLowTemperature < targetHighTemperature,
                decreaseAction: {
                    adjustLowTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                },
                increaseAction: {
                    adjustLowTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                }
            )

                Divider()

                temperatureStepper(
                    title: "Cool to",
                    systemImage: "snowflake",
                    value: targetHighTemperature,
                    climate: climate,
                    canDecrease: targetHighTemperature > targetLowTemperature,
                    canIncrease: targetHighTemperature < climate.resolvedMaximumTemperature,
                    decreaseAction: {
                        adjustHighTemperature(by: -climate.resolvedTemperatureStep, climate: climate)
                    },
                    increaseAction: {
                        adjustHighTemperature(by: climate.resolvedTemperatureStep, climate: climate)
                    }
                )
            }
        }
    }

    private func temperatureStepper(
        title: String,
        systemImage: String,
        value: Double,
        climate: ClimateEntity,
        canDecrease: Bool,
        canIncrease: Bool,
        decreaseAction: @escaping () -> Void,
        increaseAction: @escaping () -> Void
    ) -> some View {
        Stepper(
            onIncrement: {
                guard canIncrease else { return }
                increaseAction()
            },
            onDecrement: {
                guard canDecrease else { return }
                decreaseAction()
            }
        ) {
            HStack(spacing: AppSpacing.medium) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: AppSpacing.medium)

                Text(climate.formatTemperature(value))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(climate.isActive ? Color.accentColor : Color.secondary)
            }
        }
        .disabled(detailState.blocksControlInteraction || (!canDecrease && !canIncrease))
        .accessibilityValue(climate.formatTemperature(value))
        .frame(minHeight: 44)
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
                        isDisabled: detailState.blocksControlInteraction || mode == climate.state
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
                        isDisabled: detailState.blocksControlInteraction
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
                        isDisabled: detailState.blocksControlInteraction
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
