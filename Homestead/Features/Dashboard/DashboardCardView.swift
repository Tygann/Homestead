import SwiftUI

struct DashboardCardView: View {
    let entityID: String
    let size: DashboardCardSize
    var displayNameOverride: String?
    var iconNameOverride: String?
    var contextualAreaName: String?
    var isEditing = false

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedDetail: DashboardCardDetail?

    var body: some View {
        if let entityBox = stateStore.entityBox(for: entityID) {
            let presentation = DashboardEntityPresentation(
                entityBox: entityBox,
                displayNameOverride: resolvedDisplayNameOverride(for: entityBox),
                iconNameOverride: iconNameOverride
            )

            DashboardEntityCard(
                entityBox: entityBox,
                presentation: presentation,
                size: size,
                isPending: entityBox.pendingCommand != nil,
                isPrimaryActionAvailable: primaryActionAvailability(for: entityBox),
                toggle: isEditing ? nil : primaryAction(for: entityBox),
                showDetails: isEditing ? nil : detailsAction(for: entityBox),
                setLightBrightness: isEditing ? nil : setLightBrightnessAction(for: entityBox),
                setClimateTemperature: isEditing ? nil : setClimateTemperatureAction(for: entityBox),
                setClimateTemperatureRange: isEditing ? nil : setClimateTemperatureRangeAction(for: entityBox)
            )
            .sheet(item: $selectedDetail) { detail in
                if let selectedEntityBox = stateStore.entityBox(for: detail.entityID) {
                    DashboardEntityDetailSheet(entityBox: selectedEntityBox)
                } else {
                    ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                }
            }
        }
    }

    private func resolvedDisplayNameOverride(for entityBox: HAEntityState) -> String? {
        EntityDisplayNameResolver.displayName(
            canonicalName: entityBox.homeEntity.displayName,
            overrideName: displayNameOverride ?? dashboardConfiguration.entityDisplayNameOverride(for: entityID),
            contextualAreaName: contextualAreaName
        )
    }

    private func primaryAction(for entityBox: HAEntityState) -> (() -> Void)? {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)

        if let primaryAction = presentation.primaryAction {
            return {
                HapticFeedback.selection()
                Task {
                    await homeAssistantService.perform(primaryAction, entityID: entityBox.entityID)
                }
            }
        }

        return nil
    }

    private func primaryActionAvailability(for entityBox: HAEntityState) -> Bool {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        guard let primaryAction = presentation.primaryAction else {
            return true
        }

        return homeAssistantService.serviceActionAvailable(primaryAction, entityID: entityBox.entityID)
    }

    private func detailsAction(for entityBox: HAEntityState) -> (() -> Void)? {
        return {
            selectedDetail = DashboardCardDetail(
                entityID: entityBox.entityID,
                kind: detailKind(for: entityBox)
            )
        }
    }

    private func setLightBrightnessAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.lightEntity?.supportsBrightness == true,
              homeAssistantService.serviceActionAvailable(domain: "light", service: "turn_on") else {
            return nil
        }

        return { brightnessPercentage in
            HapticFeedback.selection()
            Task {
                await homeAssistantService.setLightBrightness(
                    entityID: entityBox.entityID,
                    brightnessPercentage: brightnessPercentage
                )
            }
        }
    }

    private func setClimateTemperatureAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.climateEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature") else {
            return nil
        }

        return { temperature in
            HapticFeedback.selection()
            Task {
                await homeAssistantService.setClimateTemperature(
                    entityID: entityBox.entityID,
                    temperature: temperature
                )
            }
        }
    }

    private func setClimateTemperatureRangeAction(for entityBox: HAEntityState) -> ((Double, Double) -> Void)? {
        guard entityBox.climateEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature") else {
            return nil
        }

        return { lowTemperature, highTemperature in
            HapticFeedback.selection()
            Task {
                await homeAssistantService.setClimateTemperatureRange(
                    entityID: entityBox.entityID,
                    lowTemperature: lowTemperature,
                    highTemperature: highTemperature
                )
            }
        }
    }

    private func detailKind(for entityBox: HAEntityState) -> DashboardCardDetail.Kind {
        switch DashboardEntityPresentation(entityBox: entityBox).detailKind {
        case .light:
            .light
        case .cover:
            .cover
        case .climate:
            .climate
        case .fan:
            .fan
        case .lock:
            .lock
        case .toggle:
            .toggle
        case .action:
            .action
        case .sensor:
            .sensor
        case .mediaPlayer:
            .mediaPlayer
        case .camera:
            .camera
        case .vacuum:
            .vacuum
        case .entity:
            .entity
        }
    }
}

private struct DashboardCardDetail: Identifiable {
    enum Kind {
        case light
        case cover
        case climate
        case fan
        case lock
        case toggle
        case action
        case sensor
        case mediaPlayer
        case camera
        case vacuum
        case entity
    }

    let entityID: String
    let kind: Kind

    var id: String {
        "\(kind)-\(entityID)"
    }
}

struct DashboardEntityDetailSheet: View {
    let entityBox: HAEntityState

    var body: some View {
        switch DashboardEntityPresentation(entityBox: entityBox).detailKind {
        case .light:
            LightDetailView(entityBox: entityBox)
        case .cover:
            CoverDetailView(entityBox: entityBox)
        case .climate:
            ClimateDetailView(entityBox: entityBox)
        case .fan:
            FanDetailView(entityBox: entityBox)
        case .lock:
            LockDetailView(entityBox: entityBox)
        case .toggle:
            ToggleEntityDetailView(entityBox: entityBox)
        case .action:
            ActionEntityDetailView(entityBox: entityBox)
        case .sensor:
            SensorDetailView(entityBox: entityBox)
        case .mediaPlayer:
            MediaPlayerDetailView(entityBox: entityBox)
        case .camera:
            CameraDetailView(entityBox: entityBox)
        case .vacuum:
            VacuumDetailView(entityBox: entityBox)
        case .entity:
            EntityDetailView(entityBox: entityBox)
        }
    }
}

private struct DashboardEntityCard: View {
    let entityBox: HAEntityState
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let isPending: Bool
    let isPrimaryActionAvailable: Bool
    let toggle: (() -> Void)?
    let showDetails: (() -> Void)?
    let setLightBrightness: ((Double) -> Void)?
    let setClimateTemperature: ((Double) -> Void)?
    let setClimateTemperatureRange: ((Double, Double) -> Void)?

    var body: some View {
        CardContainer(isActive: presentation.isActive, minHeight: cardContainerMinHeight) {
            ZStack(alignment: .topLeading) {
                if usesInlineControls {
                    cardContent
                        .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                } else if let showDetails {
                    Button(action: showDetails) {
                        cardContent
                            .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .accessibilityLabel(presentation.accessibilityDetailLabel)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.accessibilityDetailHint)
                } else {
                    cardContent
                        .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                }

                if let toggle {
                    Button(action: toggle) {
                        CardIconView(
                            systemName: presentation.iconName,
                            isActive: presentation.isActive
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending || !isPrimaryActionAvailable)
                    .accessibilityLabel(presentation.primaryActionAccessibilityLabel ?? presentation.title)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.primaryActionAccessibilityHint)
                }

            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch size {
        case .mini:
            miniContent
        case .compact, .row:
            compactContent
        case .square:
            if let climate = entityBox.climateEntity {
                climateSquareContent(climate)
            } else if let light = entityBox.lightEntity, light.supportsBrightness {
                lightSquareContent(light)
            } else {
                largeContent
            }
        case .wide, .large:
            largeContent
        }
    }

    private var miniContent: some View {
        iconPlaceholder
    }

    private var compactContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(presentation.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        }
    }

    private var largeContent: some View {
        let contentModel = DashboardEntityCardContentModel.make(
            presentation: presentation,
            size: size
        )

        return VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                iconPlaceholder
                
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(presentation.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(presentation.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(presentation.subtitleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            if let headline = contentModel.headline {
                Text(headline)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if !contentModel.metrics.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    ForEach(contentModel.metrics) { metric in
                        DashboardCardMetricRow(metric: metric)
                    }
                }
            }
        }
    }

    private func climateSquareContent(_ climate: ClimateEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if let showDetails {
                Button(action: showDetails) {
                    climateHeader
                        .contentShape(Rectangle())
                }
                .buttonStyle(HomeCardButtonStyle())
                .accessibilityLabel(presentation.accessibilityDetailLabel)
                .accessibilityValue(presentation.accessibilityValue)
                .accessibilityHint(presentation.accessibilityDetailHint)
            } else {
                climateHeader
            }

            Spacer(minLength: AppSpacing.xSmall)

            if climate.usesTemperatureRange,
               let setClimateTemperatureRange {
                climateRangeStepperControls(
                    climate,
                    setTemperatureRange: setClimateTemperatureRange
                )
            } else if climate.targetTemperature != nil,
                      let setClimateTemperature {
                climateSingleStepperControl(
                    climate,
                    setTemperature: setClimateTemperature
                )
            }
        }
    }

    private func lightSquareContent(_ light: LightEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if let showDetails {
                Button(action: showDetails) {
                    lightHeader
                        .contentShape(Rectangle())
                }
                .buttonStyle(HomeCardButtonStyle())
                .accessibilityLabel(presentation.accessibilityDetailLabel)
                .accessibilityValue(presentation.accessibilityValue)
                .accessibilityHint(presentation.accessibilityDetailHint)
            } else {
                lightHeader
            }

            Spacer(minLength: AppSpacing.xSmall)

            if let setLightBrightness {
                brightnessSliderControl(
                    light,
                    setBrightness: setLightBrightness
                )
            }
        }
    }

    private var lightHeader: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(presentation.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var climateHeader: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(climateSquareSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var climateSquareSubtitle: String {
        guard let climate = entityBox.climateEntity else {
            return presentation.subtitle
        }

        let mode = climate.displayState
        guard let currentTemperatureText = climate.currentTemperatureText else {
            return mode
        }

        return "\(mode) • \(currentTemperatureText)"
    }

    private func brightnessSliderControl(
        _ light: LightEntity,
        setBrightness: @escaping (Double) -> Void
    ) -> some View {
        let brightnessPercentage = effectiveBrightnessPercentage(for: light)

        return InlineLevelSliderControl(
            value: brightnessPercentage,
            range: 0...100,
            fillColor: iconColor,
            trackColor: iconBackground,
            isDisabled: isPending,
            accessibilityLabel: "Brightness",
            setValue: setBrightness
        )
    }

    private func climateSingleStepperControl(
        _ climate: ClimateEntity,
        setTemperature: @escaping (Double) -> Void
    ) -> some View {
        let targetTemperature = effectiveTargetTemperature(for: climate)

        return InlineStepperControl(
            value: climateStepperText(targetTemperature),
            isActive: presentation.isActive,
            decrementAccessibilityLabel: "Decrease temperature",
            incrementAccessibilityLabel: "Increase temperature",
            isDecrementDisabled: isPending || targetTemperature <= climate.resolvedMinimumTemperature,
            isIncrementDisabled: isPending || targetTemperature >= climate.resolvedMaximumTemperature,
            decrement: {
                setTemperature(targetTemperature - climate.resolvedTemperatureStep)
            },
            increment: {
                setTemperature(targetTemperature + climate.resolvedTemperatureStep)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Target temperature")
        .accessibilityValue(climate.formatTemperature(targetTemperature))
    }

    private func climateRangeStepperControls(
        _ climate: ClimateEntity,
        setTemperatureRange: @escaping (Double, Double) -> Void
    ) -> some View {
        let lowTemperature = effectiveTargetLowTemperature(for: climate)
        let highTemperature = effectiveTargetHighTemperature(for: climate, lowTemperature: lowTemperature)

        return HStack(spacing: AppSpacing.xSmall) {
            InlineStepperControl(
                value: climateStepperText(lowTemperature),
                isActive: presentation.isActive,
                decrementAccessibilityLabel: "Decrease heat setpoint",
                incrementAccessibilityLabel: "Increase heat setpoint",
                isDecrementDisabled: isPending || lowTemperature <= climate.resolvedMinimumTemperature,
                isIncrementDisabled: isPending || lowTemperature >= highTemperature,
                decrement: {
                    setTemperatureRange(lowTemperature - climate.resolvedTemperatureStep, highTemperature)
                },
                increment: {
                    setTemperatureRange(lowTemperature + climate.resolvedTemperatureStep, highTemperature)
                }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heat setpoint")
            .accessibilityValue(climate.formatTemperature(lowTemperature))

            InlineStepperControl(
                value: climateStepperText(highTemperature),
                isActive: presentation.isActive,
                decrementAccessibilityLabel: "Decrease cool setpoint",
                incrementAccessibilityLabel: "Increase cool setpoint",
                isDecrementDisabled: isPending || highTemperature <= lowTemperature,
                isIncrementDisabled: isPending || highTemperature >= climate.resolvedMaximumTemperature,
                decrement: {
                    setTemperatureRange(lowTemperature, highTemperature - climate.resolvedTemperatureStep)
                },
                increment: {
                    setTemperatureRange(lowTemperature, highTemperature + climate.resolvedTemperatureStep)
                }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cool setpoint")
            .accessibilityValue(climate.formatTemperature(highTemperature))
        }
    }

    private var iconPlaceholder: some View {
        Color.clear
            .frame(width: 44, height: 44)
            .overlay(alignment: .topLeading) {
                if toggle == nil {
                    CardIconView(systemName: presentation.iconName, isActive: presentation.isActive)
                }
            }
    }

    private var iconColor: Color {
        presentation.isActive ? Color.accentColor : Color.primary
    }

    private var iconBackground: Color {
        presentation.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }
    
    private var cardContentMinHeight: CGFloat {
        max(0, cardContainerMinHeight - (AppSpacing.medium * 2))
    }

    private var cardContainerMinHeight: CGFloat {
        size.contentMinHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }

    private var usesInlineControls: Bool {
        size == .square && (entityBox.climateEntity != nil || entityBox.lightEntity?.supportsBrightness == true)
    }

    private func effectiveBrightnessPercentage(for light: LightEntity) -> Double {
        if let pendingBrightness = entityBox.pendingCommand?.expectedAttributes["brightness"]?.doubleValue {
            return min(max((pendingBrightness / 255.0) * 100.0, 0), 100)
        }

        guard light.isOn else { return 0 }

        return Double(light.brightnessPercentage ?? 100)
    }

    private func effectiveTargetTemperature(for climate: ClimateEntity) -> Double {
        entityBox.pendingCommand?.expectedAttributes["temperature"]?.doubleValue
            ?? climate.targetTemperature
            ?? climate.currentTemperature
            ?? 70
    }

    private func effectiveTargetLowTemperature(for climate: ClimateEntity) -> Double {
        entityBox.pendingCommand?.expectedAttributes["target_temp_low"]?.doubleValue
            ?? climate.targetTemperatureLow
            ?? climate.targetTemperature
            ?? climate.currentTemperature
            ?? 68
    }

    private func effectiveTargetHighTemperature(for climate: ClimateEntity, lowTemperature: Double) -> Double {
        max(
            lowTemperature,
            entityBox.pendingCommand?.expectedAttributes["target_temp_high"]?.doubleValue
                ?? climate.targetTemperatureHigh
                ?? climate.targetTemperature
                ?? climate.currentTemperature
                ?? 76
        )
    }

    private func climateStepperText(_ temperature: Double) -> String {
        Self.climateStepperFormatter.string(from: NSNumber(value: temperature)) ?? "\(temperature)"
    }

    private static let climateStepperFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private struct InlineStepperControl: View {
    let value: String
    let isActive: Bool
    let decrementAccessibilityLabel: String
    let incrementAccessibilityLabel: String
    let isDecrementDisabled: Bool
    let isIncrementDisabled: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(isDecrementDisabled)
            .accessibilityLabel(decrementAccessibilityLabel)

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 22, maxWidth: .infinity)

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(isIncrementDisabled)
            .accessibilityLabel(incrementAccessibilityLabel)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.xSmall)
        .frame(height: 44)
        .background(controlBackground, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
    }

    private var controlBackground: Color {
        isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }
}

private struct InlineLevelSliderControl: View {
    let value: Double
    let range: ClosedRange<Double>
    let fillColor: Color
    let trackColor: Color
    let isDisabled: Bool
    let accessibilityLabel: String
    let setValue: (Double) -> Void
    @State private var currentValue: Double
    @State private var isEditing = false

    init(
        value: Double,
        range: ClosedRange<Double> = 0...100,
        fillColor: Color,
        trackColor: Color,
        isDisabled: Bool,
        accessibilityLabel: String,
        setValue: @escaping (Double) -> Void
    ) {
        self.value = value
        self.range = range
        self.fillColor = fillColor
        self.trackColor = trackColor
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.setValue = setValue
        _currentValue = State(initialValue: value)
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = fillWidth(in: proxy.size.width)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    .fill(trackColor)

                RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isEditing = true
                        currentValue = sliderValue(at: value.location.x, width: proxy.size.width)
                    }
                    .onEnded { value in
                        let finalValue = sliderValue(at: value.location.x, width: proxy.size.width)
                        currentValue = finalValue
                        isEditing = false
                        setValue(finalValue)
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
        .opacity(isDisabled ? 0.55 : 1)
        .disabled(isDisabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int(currentValue.rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustValue(by: 5)
            case .decrement:
                adjustValue(by: -5)
            @unknown default:
                break
            }
        }
        .onChange(of: value) { _, newValue in
            guard !isEditing else { return }
            currentValue = newValue
        }
    }

    private func fillWidth(in width: CGFloat) -> CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let normalizedValue = (clampedValue - range.lowerBound) / (range.upperBound - range.lowerBound)
        return width * CGFloat(normalizedValue)
    }

    private var clampedValue: Double {
        min(max(currentValue, range.lowerBound), range.upperBound)
    }

    private func sliderValue(at locationX: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return clampedValue }
        let normalized = min(max(locationX / width, 0), 1)
        return range.lowerBound + (Double(normalized) * (range.upperBound - range.lowerBound))
    }

    private func adjustValue(by delta: Double) {
        let updatedValue = min(max(currentValue + delta, range.lowerBound), range.upperBound)
        currentValue = updatedValue
        setValue(updatedValue)
    }
}

private struct DashboardCardMetricRow: View {
    let metric: DashboardEntityCardMetric

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Image(systemName: metric.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(metric.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.small)

            Text(metric.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.trailing)
        }
    }
}

#if DEBUG
private struct DashboardCardDisplaySizesPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
//            HStack(alignment: .top, spacing: AppSpacing.medium) {/
                DashboardCardView(entityID: "light.living_room_lamps", size: .mini)
                    .frame(width: 82)

                DashboardCardView(entityID: "light.living_room_lamps", size: .compact)
                    .frame(width: 180)

                DashboardCardView(entityID: "sensor.hallway_temperature", size: .square)
                    .frame(width: 180)
//            }

            DashboardCardView(entityID: "sensor.hallway_temperature", size: .row)
                .frame(width: 376)

            DashboardCardView(entityID: "sensor.hallway_temperature", size: .wide)
                .frame(width: 376)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Display Sizes") {
    DashboardCardDisplaySizesPreview()
        .withPreviewEnvironment()
}

private struct DashboardCardEditModePreview: View {
    @State private var size: DashboardCardSize = .square

    var body: some View {
        DashboardCardView(
            entityID: "light.living_room_lamps",
            size: size,
            isEditing: true
        )
        .frame(width: previewWidth)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var previewWidth: CGFloat {
        switch size {
        case .mini:
            82
        case .compact, .square:
            180
        case .row, .wide, .large:
            376
        }
    }
}

#Preview("Edit Mode") {
    DashboardCardEditModePreview()
        .withPreviewEnvironment()
}
#endif
