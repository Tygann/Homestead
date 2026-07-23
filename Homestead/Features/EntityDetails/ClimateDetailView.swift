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

                if showsTemperatureControls(climate) || showsOptions(climate) {
                    controls(climate)
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

    private func controls(_ climate: ClimateEntity) -> some View {
        EntityControlPanel(title: "Controls", systemImage: "slider.horizontal.3") {
            VStack(spacing: 0) {
                if showsTemperatureControls(climate) {
                    if climate.usesTemperatureRange {
                        temperatureRangeControls(climate)
                    } else {
                        temperatureControls(climate)
                    }
                }

                if showsTemperatureControls(climate) && showsOptions(climate) {
                    controlSectionDivider
                }

                if showsOptions(climate) {
                    optionControls(climate)
                }
            }
        }
    }

    private func temperatureControls(_ climate: ClimateEntity) -> some View {
        temperatureAdjustmentRow(
            title: "Target",
            value: targetTemperature,
            tint: .accentColor,
            climate: climate,
            canDecrease: targetTemperature > climate.resolvedMinimumTemperature,
            canIncrease: targetTemperature < climate.resolvedMaximumTemperature,
            decreaseAction: { adjustTemperature(by: -climate.resolvedTemperatureStep, climate: climate) },
            increaseAction: { adjustTemperature(by: climate.resolvedTemperatureStep, climate: climate) }
        )
    }

    private func temperatureRangeControls(_ climate: ClimateEntity) -> some View {
        VStack(spacing: AppSpacing.small) {
            temperatureAdjustmentRow(
                title: "Heat to",
                value: targetLowTemperature,
                tint: .orange,
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

            temperatureAdjustmentRow(
                title: "Cool to",
                value: targetHighTemperature,
                tint: .blue,
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

    private func temperatureAdjustmentRow(
        title: String,
        value: Double,
        tint: Color,
        climate: ClimateEntity,
        canDecrease: Bool,
        canIncrease: Bool,
        decreaseAction: @escaping () -> Void,
        increaseAction: @escaping () -> Void
    ) -> some View {
        ClimateSetpointControl(
            title: title,
            value: climate.formatTemperature(value),
            tint: climate.isActive ? tint : .secondary,
            canDecrease: canDecrease,
            canIncrease: canIncrease,
            isDisabled: detailState.blocksControlInteraction,
            decreaseAction: decreaseAction,
            increaseAction: increaseAction
        )
    }

    private func optionControls(_ climate: ClimateEntity) -> some View {
        VStack(spacing: 0) {
            if showsHVACModeOptions(climate) {
                EntityDetailMenuRow(
                    title: "Mode",
                    systemImage: "dial.medium",
                    value: climate.displayName(forHVACMode: climate.state),
                    isDisabled: detailState.blocksControlInteraction
                ) {
                    ForEach(climate.hvacModes, id: \.self) { mode in
                        Button {
                            Task {
                                await homeAssistantService.setClimateHVACMode(
                                    entityID: entityBox.entityID,
                                    hvacMode: mode
                                )
                            }
                        } label: {
                            Label(
                                climate.displayName(forHVACMode: mode),
                                systemImage: mode == climate.state ? "checkmark" : climate.iconName(forHVACMode: mode)
                            )
                        }
                        .disabled(mode == climate.state)
                    }
                }
            }

            if showsHVACModeOptions(climate)
                && (showsFanModeOptions(climate) || showsPresetModeOptions(climate)) {
                optionDivider
            }

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

            if showsFanModeOptions(climate) && showsPresetModeOptions(climate) {
                optionDivider
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

    private var controlSectionDivider: some View {
        Divider()
            .padding(.vertical, AppSpacing.small)
            .opacity(0.8)
    }

    private var optionDivider: some View {
        Divider()
            .padding(.leading, 32)
            .opacity(0.45)
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

    private func showsOptions(_ climate: ClimateEntity) -> Bool {
        showsHVACModeOptions(climate) || showsFanModeOptions(climate) || showsPresetModeOptions(climate)
    }

    private func showsTemperatureControls(_ climate: ClimateEntity) -> Bool {
        homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature")
            && (climate.usesTemperatureRange || climate.targetTemperature != nil)
    }

    private func showsHVACModeOptions(_ climate: ClimateEntity) -> Bool {
        !climate.hvacModes.isEmpty && homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_hvac_mode")
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

private struct ClimateSetpointControl: View {
    let title: String
    let value: String
    let tint: Color
    let canDecrease: Bool
    let canIncrease: Bool
    let isDisabled: Bool
    let decreaseAction: () -> Void
    let increaseAction: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Text(title)
                .font(.body)

            Spacer(minLength: AppSpacing.small)

            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: AppSpacing.small) {
                adjustmentButton(
                    systemImage: "minus",
                    isEnabled: canDecrease,
                    action: decreaseAction
                )

                adjustmentButton(
                    systemImage: "plus",
                    isEnabled: canIncrease,
                    action: increaseAction
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityAdjustableAction { direction in
            guard !isDisabled else { return }

            switch direction {
            case .increment where canIncrease:
                increaseAction()
            case .decrement where canDecrease:
                decreaseAction()
            default:
                break
            }
        }
    }

    private func adjustmentButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
        .disabled(isDisabled || !isEnabled)
        .accessibilityHidden(true)
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
