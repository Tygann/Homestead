import SwiftUI

struct ClimateDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    if dynamicTypeSize.isAccessibilitySize {
                        controlSectionDivider
                    } else {
                        Color.clear
                            .frame(height: AppSpacing.large)
                    }
                }

                if showsOptions(climate) {
                    optionControls(climate)
                }
            }
        }
    }

    @ViewBuilder
    private func temperatureControls(_ climate: ClimateEntity) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            temperatureAdjustmentRow(
                title: temperatureControlLabel(climate),
                value: targetTemperature,
                tint: temperatureControlTint(climate),
                climate: climate,
                canDecrease: targetTemperature > climate.resolvedMinimumTemperature,
                canIncrease: targetTemperature < climate.resolvedMaximumTemperature,
                decreaseAction: { adjustTemperature(by: -climate.resolvedTemperatureStep, climate: climate) },
                increaseAction: { adjustTemperature(by: climate.resolvedTemperatureStep, climate: climate) }
            )
        } else {
            ClimateThermostatInstrument(
                lowerValue: $targetTemperature,
                upperValue: $targetTemperature,
                minimumValue: climate.resolvedMinimumTemperature,
                maximumValue: climate.resolvedMaximumTemperature,
                step: climate.resolvedTemperatureStep,
                mode: .single(
                    label: temperatureControlLabel(climate),
                    tint: temperatureControlTint(climate)
                ),
                isDisabled: detailState.blocksControlInteraction,
                formatValue: climate.formatTemperature(_:),
                commitSingleValue: {
                    setTargetTemperature(climate: climate)
                },
                commitRange: {}
            )
        }
    }

    @ViewBuilder
    private func temperatureRangeControls(_ climate: ClimateEntity) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.small) {
                temperatureAdjustmentRow(
                    title: "Heat to",
                    value: targetLowTemperature,
                    tint: .blue,
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
                    tint: .orange,
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
        } else {
            ClimateThermostatInstrument(
                lowerValue: $targetLowTemperature,
                upperValue: $targetHighTemperature,
                minimumValue: climate.resolvedMinimumTemperature,
                maximumValue: climate.resolvedMaximumTemperature,
                step: climate.resolvedTemperatureStep,
                mode: .range,
                isDisabled: detailState.blocksControlInteraction,
                formatValue: climate.formatTemperature(_:),
                commitSingleValue: {},
                commitRange: {
                    setTargetTemperatureRange(climate: climate)
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

    @ViewBuilder
    private func optionControls(_ climate: ClimateEntity) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            optionRows(climate)
        } else {
            optionCapsules(climate)
        }
    }

    private func optionRows(_ climate: ClimateEntity) -> some View {
        VStack(spacing: 0) {
            if showsHVACModeOptions(climate) {
                EntityDetailMenuRow(
                    title: "Mode",
                    systemImage: "dial.medium",
                    value: climate.displayName(forHVACMode: climate.state),
                    isDisabled: detailState.blocksControlInteraction
                ) {
                    hvacModeMenu(climate)
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
                    fanModeMenu(climate)
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
                    presetModeMenu(climate)
                }
            }
        }
    }

    @ViewBuilder
    private func optionCapsules(_ climate: ClimateEntity) -> some View {
        if showsHVACModeOptions(climate)
            && showsFanModeOptions(climate)
            && showsPresetModeOptions(climate) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.small) {
                    modeMenu(climate, prominence: .compact)
                    fanMenu(climate, prominence: .compact)
                    presetMenu(climate, prominence: .compact)
                }
                stackedOptionCapsules(climate)
            }
        } else {
            stackedOptionCapsules(climate)
        }
    }

    private func stackedOptionCapsules(_ climate: ClimateEntity) -> some View {
        VStack(spacing: AppSpacing.small) {
            if showsHVACModeOptions(climate) {
                modeMenu(climate, prominence: .primary)
            }

            if showsFanModeOptions(climate) || showsPresetModeOptions(climate) {
                HStack(spacing: AppSpacing.small) {
                    if showsFanModeOptions(climate) {
                        fanMenu(climate, prominence: .secondary)
                    }

                    if showsPresetModeOptions(climate) {
                        presetMenu(climate, prominence: .secondary)
                    }
                }
            }
        }
    }

    private func modeMenu(
        _ climate: ClimateEntity,
        prominence: ClimateFloatingMenuProminence
    ) -> some View {
        ClimateFloatingMenu(
            title: "Mode",
            systemImage: climate.iconName(forHVACMode: climate.state),
            value: climate.displayName(forHVACMode: climate.state),
            prominence: prominence,
            isDisabled: detailState.blocksControlInteraction
        ) {
            hvacModeMenu(climate)
        }
    }

    private func fanMenu(
        _ climate: ClimateEntity,
        prominence: ClimateFloatingMenuProminence
    ) -> some View {
        ClimateFloatingMenu(
            title: "Fan",
            systemImage: "fan.fill",
            value: climate.fanMode.map(climate.displayName(forFanMode:)) ?? "Auto",
            prominence: prominence,
            isDisabled: detailState.blocksControlInteraction
        ) {
            fanModeMenu(climate)
        }
    }

    private func presetMenu(
        _ climate: ClimateEntity,
        prominence: ClimateFloatingMenuProminence
    ) -> some View {
        ClimateFloatingMenu(
            title: "Preset",
            systemImage: "leaf",
            value: climate.presetMode.map(climate.displayName(forPresetMode:)) ?? "None",
            prominence: prominence,
            isDisabled: detailState.blocksControlInteraction
        ) {
            presetModeMenu(climate)
        }
    }

    @ViewBuilder
    private func hvacModeMenu(_ climate: ClimateEntity) -> some View {
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

    @ViewBuilder
    private func fanModeMenu(_ climate: ClimateEntity) -> some View {
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

    @ViewBuilder
    private func presetModeMenu(_ climate: ClimateEntity) -> some View {
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

    private func temperatureControlLabel(_ climate: ClimateEntity) -> String {
        switch climate.state {
        case "heat":
            "Heat to"
        case "cool":
            "Cool to"
        default:
            "Set to"
        }
    }

    private func temperatureControlTint(_ climate: ClimateEntity) -> Color {
        guard climate.isActive else { return .secondary }

        switch climate.state {
        case "heat":
            return .orange
        case "cool":
            return .blue
        default:
            return .accentColor
        }
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

// MARK: - Floating Climate Menus

private enum ClimateFloatingMenuProminence {
    case primary
    case secondary
    case compact
}

private struct ClimateFloatingMenu<MenuContent: View>: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let title: String
    let systemImage: String
    let value: String
    let prominence: ClimateFloatingMenuProminence
    let isDisabled: Bool
    private let menuContent: MenuContent

    init(
        title: String,
        systemImage: String,
        value: String,
        prominence: ClimateFloatingMenuProminence,
        isDisabled: Bool,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.prominence = prominence
        self.isDisabled = isDisabled
        self.menuContent = menuContent()
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            Group {
                switch prominence {
                case .primary:
                    primaryLabel
                case .secondary:
                    secondaryLabel
                case .compact:
                    compactLabel
                }
            }
            .background(
                HomesteadSurfaceStyle.controlBackground(
                    isWallpaperActive: isWallpaperSurfaceActive,
                    isActive: false
                ),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .contentShape(Capsule())
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var primaryLabel: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Spacer(minLength: AppSpacing.small)

            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: AppSpacing.small)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 24)
        }
        .padding(.horizontal, AppSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 48)
    }

    private var secondaryLabel: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: AppSpacing.xSmall)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 52)
    }

    private var compactLabel: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppSpacing.small)
        .frame(minWidth: 96, maxWidth: .infinity, minHeight: 48)
    }
}

// MARK: - Thermostat Instrument

enum ClimateThermostatInstrumentMode {
    case single(label: String, tint: Color)
    case range
}

enum ClimateThermostatInstrumentStyle {
    case detail
    case dashboardLarge
}

private enum ClimateThermostatHandle {
    case lower
    case upper
}

struct ClimateThermostatInstrument: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    @State private var selectedHandle: ClimateThermostatHandle = .lower

    let minimumValue: Double
    let maximumValue: Double
    let step: Double
    let mode: ClimateThermostatInstrumentMode
    let isDisabled: Bool
    let formatValue: (Double) -> String
    let commitSingleValue: () -> Void
    let commitRange: () -> Void
    var style: ClimateThermostatInstrumentStyle = .detail

    private let arcStartAngle = 150.0
    private let arcLength = 240.0

    var body: some View {
        GeometryReader { proxy in
            let geometry = dialGeometry(in: proxy.size)

            ZStack {
                arcTrack

                selectedArc

                setpointReadout
                    .position(x: geometry.center.x, y: geometry.center.y - 10)

                handle(
                    .lower,
                    point: point(for: lowerFraction, geometry: geometry),
                    geometry: geometry,
                    tint: lowerTint
                )

                if usesRange {
                    handle(
                        .upper,
                        point: point(for: upperFraction, geometry: geometry),
                        geometry: geometry,
                        tint: .orange
                    )
                }

                precisionControls(geometry: geometry)
            }
            .coordinateSpace(name: "climateThermostatArc")
        }
        .frame(height: metrics.instrumentHeight)
        .accessibilityElement(children: .contain)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var arcTrack: some View {
        ClimateThermostatArc(metrics: metrics)
            .stroke(
                Color.secondary.opacity(0.16),
                style: StrokeStyle(lineWidth: metrics.arcLineWidth, lineCap: .round)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var selectedArc: some View {
        if usesRange {
            ClimateThermostatArc(
                startFraction: lowerFraction,
                endFraction: upperFraction,
                metrics: metrics
            )
                .stroke(
                    AngularGradient(
                        colors: [.blue, .orange],
                        center: .center,
                        startAngle: .degrees(arcStartAngle + (arcLength * lowerFraction)),
                        endAngle: .degrees(arcStartAngle + (arcLength * upperFraction))
                    ),
                    style: StrokeStyle(lineWidth: metrics.arcLineWidth, lineCap: .round)
                )
                .accessibilityHidden(true)
        } else {
            ClimateThermostatArc(
                startFraction: 0,
                endFraction: lowerFraction,
                metrics: metrics
            )
                .stroke(
                    lowerTint,
                    style: StrokeStyle(lineWidth: metrics.arcLineWidth, lineCap: .round)
                )
                .accessibilityHidden(true)
        }
    }

    private var setpointReadout: some View {
        VStack(spacing: AppSpacing.xSmall) {
            Text(readoutLabel.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            if usesRange {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Text(displayValue(lowerValue))
                        .foregroundStyle(selectedHandle == .lower ? Color.blue : Color.primary)
                        .onTapGesture {
                            selectedHandle = .lower
                        }

                    Text("–")
                        .foregroundStyle(.secondary)

                    Text(displayValue(upperValue))
                        .foregroundStyle(selectedHandle == .upper ? Color.orange : Color.primary)
                        .onTapGesture {
                            selectedHandle = .upper
                        }
                }
                .font(
                    .system(
                        size: metrics.rangeReadoutFontSize,
                        weight: .semibold,
                        design: .rounded
                    )
                    .monospacedDigit()
                )
            } else {
                Text(displayValue(lowerValue))
                    .font(
                        .system(
                            size: metrics.singleReadoutFontSize,
                            weight: .semibold,
                            design: .rounded
                        )
                        .monospacedDigit()
                    )
                    .foregroundStyle(lowerTint)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .accessibilityHidden(true)
    }

    private func precisionControls(geometry: DialGeometry) -> some View {
        let leftEndpoint = point(for: 0, geometry: geometry)
        let rightEndpoint = point(for: 1, geometry: geometry)
        let controlY = leftEndpoint.y + metrics.precisionControlVerticalOffset
        let controlWidth = min(
            max(
                rightEndpoint.x - leftEndpoint.x - metrics.precisionControlHorizontalInset,
                metrics.minimumPrecisionControlWidth
            ),
            metrics.maximumPrecisionControlWidth
        )

        return HStack(spacing: 0) {
            precisionButton(systemImage: "minus", direction: -1)

            Text(adjustmentLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())

            precisionButton(systemImage: "plus", direction: 1)
        }
        .frame(width: controlWidth, height: metrics.precisionControlHeight)
        .background(
            HomesteadSurfaceStyle.controlBackground(
                isWallpaperActive: isWallpaperSurfaceActive,
                isActive: false
            ),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .position(x: geometry.center.x, y: controlY)
    }

    private func precisionButton(systemImage: String, direction: Double) -> some View {
        let canAdjust = direction < 0 ? canDecreaseSelectedValue : canIncreaseSelectedValue
        let actionName = direction < 0 ? "Decrease" : "Increase"

        return Button {
            adjustSelectedValue(by: direction * resolvedStep)
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 52, height: metrics.precisionControlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(canAdjust ? Color.primary : Color.secondary.opacity(0.4))
        .disabled(isDisabled || !canAdjust)
        .accessibilityLabel("\(actionName) \(adjustmentLabel)")
    }

    private func handle(
        _ handle: ClimateThermostatHandle,
        point: CGPoint,
        geometry: DialGeometry,
        tint: Color
    ) -> some View {
        let isSelected = !usesRange || selectedHandle == handle

        return Button {
            selectedHandle = handle
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: metrics.handleDiameter, height: metrics.handleDiameter)
                    .shadow(color: Color.black.opacity(0.18), radius: 3, y: 1)

                Circle()
                    .stroke(tint.opacity(0.92), lineWidth: 1.5)
                    .frame(width: metrics.handleDiameter, height: metrics.handleDiameter)

                if usesRange && isSelected {
                    Circle()
                        .fill(tint)
                        .frame(
                            width: metrics.selectedIndicatorDiameter,
                            height: metrics.selectedIndicatorDiameter
                        )
                }
            }
            .frame(width: metrics.interactionDiameter, height: metrics.interactionDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
        .position(point)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("climateThermostatArc"))
                .onChanged { value in
                    guard !isDisabled else { return }
                    selectedHandle = handle
                    update(handle, from: value.location, geometry: geometry)
                }
                .onEnded { value in
                    guard !isDisabled else { return }
                    update(handle, from: value.location, geometry: geometry)
                    commitUpdatedValue()
                }
        )
        .accessibilityLabel(accessibilityLabel(for: handle))
        .accessibilityValue(formatValue(value(for: handle)))
        .accessibilityAdjustableAction { direction in
            guard !isDisabled else { return }
            selectedHandle = handle

            switch direction {
            case .increment:
                adjust(handle, by: resolvedStep)
            case .decrement:
                adjust(handle, by: -resolvedStep)
            @unknown default:
                break
            }
        }
    }

    private var usesRange: Bool {
        if case .range = mode {
            return true
        }
        return false
    }

    private var readoutLabel: String {
        switch mode {
        case let .single(label, _):
            label
        case .range:
            "Keep between"
        }
    }

    private var lowerTint: Color {
        switch mode {
        case let .single(_, tint):
            tint
        case .range:
            .blue
        }
    }

    private var adjustmentLabel: String {
        if !usesRange {
            return readoutLabel
        }

        return selectedHandle == .lower ? "Heat to" : "Cool to"
    }

    private var lowerFraction: Double {
        fraction(for: lowerValue)
    }

    private var upperFraction: Double {
        fraction(for: upperValue)
    }

    private var resolvedStep: Double {
        max(step, 0.1)
    }

    private var canDecreaseSelectedValue: Bool {
        switch effectiveSelectedHandle {
        case .lower:
            return lowerValue > minimumValue
        case .upper:
            return upperValue > lowerValue
        }
    }

    private var canIncreaseSelectedValue: Bool {
        switch effectiveSelectedHandle {
        case .lower:
            return usesRange ? lowerValue < upperValue : lowerValue < maximumValue
        case .upper:
            return upperValue < maximumValue
        }
    }

    private func adjustSelectedValue(by delta: Double) {
        adjust(effectiveSelectedHandle, by: delta)
    }

    private var effectiveSelectedHandle: ClimateThermostatHandle {
        usesRange ? selectedHandle : .lower
    }

    private func adjust(_ handle: ClimateThermostatHandle, by delta: Double) {
        let previousValue = value(for: handle)

        switch handle {
        case .lower:
            let upperLimit = usesRange ? upperValue : maximumValue
            lowerValue = steppedValue(min(max(lowerValue + delta, minimumValue), upperLimit))
        case .upper:
            upperValue = steppedValue(min(max(upperValue + delta, lowerValue), maximumValue))
        }

        if value(for: handle) != previousValue {
            HapticFeedback.selection()
        }
        commitUpdatedValue()
    }

    private func update(
        _ handle: ClimateThermostatHandle,
        from location: CGPoint,
        geometry: DialGeometry
    ) {
        let updatedValue = value(at: location, geometry: geometry)
        let previousValue = value(for: handle)

        switch handle {
        case .lower:
            let upperLimit = usesRange ? upperValue : maximumValue
            lowerValue = min(updatedValue, upperLimit)
        case .upper:
            upperValue = max(updatedValue, lowerValue)
        }

        if value(for: handle) != previousValue {
            HapticFeedback.selection()
        }
    }

    private func commitUpdatedValue() {
        if usesRange {
            commitRange()
        } else {
            commitSingleValue()
        }
    }

    private func value(for handle: ClimateThermostatHandle) -> Double {
        handle == .lower ? lowerValue : upperValue
    }

    private func accessibilityLabel(for handle: ClimateThermostatHandle) -> String {
        if !usesRange {
            return "\(readoutLabel) temperature"
        }
        return handle == .lower ? "Heat setpoint" : "Cool setpoint"
    }

    private func displayValue(_ value: Double) -> String {
        let value = formatValue(value)
        if value.hasSuffix("°F") || value.hasSuffix("°C") {
            return String(value.dropLast(2))
        }
        if value.hasSuffix("°") {
            return String(value.dropLast())
        }
        return value
    }

    private func fraction(for value: Double) -> Double {
        guard maximumValue > minimumValue else { return 0 }
        return min(max((value - minimumValue) / (maximumValue - minimumValue), 0), 1)
    }

    private func steppedValue(_ value: Double) -> Double {
        let stepped = (value / resolvedStep).rounded() * resolvedStep
        return min(max(stepped, minimumValue), maximumValue)
    }

    private func value(at location: CGPoint, geometry: DialGeometry) -> Double {
        var angle = atan2(
            location.y - geometry.center.y,
            location.x - geometry.center.x
        ) * 180 / .pi

        if angle < 0 {
            angle += 360
        }

        if angle <= 30 {
            angle += 360
        } else if angle < arcStartAngle {
            angle = angle < 90 ? arcStartAngle + arcLength : arcStartAngle
        }

        let fraction = min(max((angle - arcStartAngle) / arcLength, 0), 1)
        return steppedValue(minimumValue + (fraction * (maximumValue - minimumValue)))
    }

    private func dialGeometry(in size: CGSize) -> DialGeometry {
        let radius = min(
            max((size.width - metrics.horizontalDialInset) / 2, 1),
            metrics.maximumRadius
        )
        return DialGeometry(
            center: CGPoint(x: size.width / 2, y: radius + metrics.centerVerticalInset),
            radius: radius
        )
    }

    private func point(for fraction: Double, geometry: DialGeometry) -> CGPoint {
        let angle = (arcStartAngle + (arcLength * fraction)) * .pi / 180
        return CGPoint(
            x: geometry.center.x + (geometry.radius * cos(angle)),
            y: geometry.center.y + (geometry.radius * sin(angle))
        )
    }

    private var metrics: ClimateThermostatInstrumentMetrics {
        switch style {
        case .detail:
            ClimateThermostatInstrumentMetrics(
                instrumentHeight: 230,
                maximumRadius: 108,
                horizontalDialInset: 44,
                centerVerticalInset: 12,
                arcLineWidth: 22,
                handleDiameter: 20,
                selectedIndicatorDiameter: 6,
                interactionDiameter: 48,
                rangeReadoutFontSize: 36,
                singleReadoutFontSize: 44,
                precisionControlHeight: 48,
                precisionControlVerticalOffset: 32,
                precisionControlHorizontalInset: 32,
                minimumPrecisionControlWidth: 164,
                maximumPrecisionControlWidth: 176
            )
        case .dashboardLarge:
            ClimateThermostatInstrumentMetrics(
                instrumentHeight: 210,
                maximumRadius: 92,
                horizontalDialInset: 52,
                centerVerticalInset: 8,
                arcLineWidth: 20,
                handleDiameter: 18,
                selectedIndicatorDiameter: 5,
                interactionDiameter: 48,
                rangeReadoutFontSize: 31,
                singleReadoutFontSize: 38,
                precisionControlHeight: 44,
                precisionControlVerticalOffset: 27,
                precisionControlHorizontalInset: 28,
                minimumPrecisionControlWidth: 152,
                maximumPrecisionControlWidth: 168
            )
        }
    }
}

private struct DialGeometry {
    let center: CGPoint
    let radius: CGFloat
}

private struct ClimateThermostatArc: Shape {
    var startFraction = 0.0
    var endFraction = 1.0
    let metrics: ClimateThermostatInstrumentMetrics

    func path(in rect: CGRect) -> Path {
        let radius = min(
            max((rect.width - metrics.horizontalDialInset) / 2, 1),
            metrics.maximumRadius
        )
        let center = CGPoint(x: rect.midX, y: radius + metrics.centerVerticalInset)
        let startAngle = 150 + (240 * startFraction)
        let endAngle = 150 + (240 * endFraction)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}

private struct ClimateThermostatInstrumentMetrics {
    let instrumentHeight: CGFloat
    let maximumRadius: CGFloat
    let horizontalDialInset: CGFloat
    let centerVerticalInset: CGFloat
    let arcLineWidth: CGFloat
    let handleDiameter: CGFloat
    let selectedIndicatorDiameter: CGFloat
    let interactionDiameter: CGFloat
    let rangeReadoutFontSize: CGFloat
    let singleReadoutFontSize: CGFloat
    let precisionControlHeight: CGFloat
    let precisionControlVerticalOffset: CGFloat
    let precisionControlHorizontalInset: CGFloat
    let minimumPrecisionControlWidth: CGFloat
    let maximumPrecisionControlWidth: CGFloat
}

// MARK: - Accessibility Setpoint Row

private struct ClimateSetpointControl: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

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
                .background(
                    HomesteadSurfaceStyle.controlBackground(
                        isWallpaperActive: isWallpaperSurfaceActive,
                        isActive: false
                    ),
                    in: Circle()
                )
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
