import SwiftUI

struct DashboardCardFeatureActions {
    var setLightBrightness: ((Double) -> Void)?
    var setClimateTemperature: ((Double) -> Void)?
    var setClimateTemperatureRange: ((Double, Double) -> Void)?
    var openCover: (() -> Void)?
    var stopCover: (() -> Void)?
    var closeCover: (() -> Void)?
    var setCoverPosition: ((Double) -> Void)?
    var lock: (() -> Void)?
    var unlock: (() -> Void)?
    var selectOption: ((String) -> Void)?

    func canRender(_ feature: DashboardCardFeature) -> Bool {
        switch feature.content {
        case .level(let level):
            return levelAction(for: level.action) != nil
        case .setpoint(let setpoint):
            switch setpoint.action {
            case .setClimateTemperature:
                return setClimateTemperature != nil
            case .setClimateTemperatureRange:
                return setClimateTemperatureRange != nil
            }
        case .commandGroup(let group):
            return group.commands.contains { commandAction(for: $0.action) != nil }
        case .options(let options):
            return selectOption != nil && !options.options.isEmpty
        case .gauge:
            return true
        }
    }

    func levelAction(for action: DashboardCardLevelAction) -> ((Double) -> Void)? {
        switch action {
        case .setLightBrightness:
            setLightBrightness
        case .setCoverPosition:
            setCoverPosition
        }
    }

    func commandAction(for action: DashboardCardCommandAction) -> (() -> Void)? {
        switch action {
        case .openCover:
            openCover
        case .stopCover:
            stopCover
        case .closeCover:
            closeCover
        case .lock:
            lock
        case .unlock:
            unlock
        }
    }
}

struct DashboardCardFeatureView: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let feature: DashboardCardFeature
    let isPending: Bool
    let isActive: Bool
    let fillColor: Color
    let trackColor: Color
    let gaugeStyle: GaugePresentationStyle
    let isInteractionEnabled: Bool
    let actions: DashboardCardFeatureActions

    var body: some View {
        Group {
            switch feature.content {
            case .level(let level):
                levelControl(level)
            case .setpoint(let setpoint):
                setpointControl(setpoint)
            case .commandGroup(let group):
                commandGroupControl(group)
            case .options(let options):
                optionsControl(options)
            case .gauge(let gauge):
                gaugePresentation(gauge)
            }
        }
        .allowsHitTesting(isInteractionEnabled)
    }

    private func levelControl(_ level: DashboardCardLevelFeature) -> some View {
        InlineLevelSliderControl(
            value: level.value,
            range: level.range,
            step: level.step,
            fillColor: fillColor,
            trackColor: trackColor,
            isDisabled: isPending || actions.levelAction(for: level.action) == nil,
            accessibilityLabel: level.accessibilityLabel,
            accessibilityValue: level.valueLabel,
            setValue: { value in
                actions.levelAction(for: level.action)?(value)
            }
        )
    }

    private func setpointControl(_ setpoint: DashboardCardSetpointFeature) -> some View {
        HStack(spacing: AppSpacing.small) {
            ForEach(setpoint.values) { value in
                InlineStepperControl(
                    value: value.displayValue,
                    isActive: isActive,
                    decrementAccessibilityLabel: value.decrementAccessibilityLabel,
                    incrementAccessibilityLabel: value.incrementAccessibilityLabel,
                    isDecrementDisabled: isPending || value.value <= value.minimumValue,
                    isIncrementDisabled: isPending || value.value >= value.maximumValue,
                    decrement: {
                        perform(setpoint, changing: value, to: value.value - value.step)
                    },
                    increment: {
                        perform(setpoint, changing: value, to: value.value + value.step)
                    }
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(value.accessibilityLabel)
                .accessibilityValue(value.formattedValue)
            }
        }
    }

    private func commandGroupControl(_ group: DashboardCardCommandGroupFeature) -> some View {
        HStack(spacing: AppSpacing.small) {
            ForEach(group.commands) { command in
                Button {
                    perform(command)
                } label: {
                    Image(systemName: command.systemImage)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(command.isDisabled ? .secondary : .primary)
                .background(controlBackground, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
                .disabled(isPending || command.isDisabled || actions.commandAction(for: command.action) == nil)
                .accessibilityLabel(command.title)
            }
        }
    }

    private func optionsControl(_ options: DashboardCardOptionsFeature) -> some View {
        Menu {
            ForEach(options.options) { option in
                Toggle(
                    option.displayValue,
                    isOn: Binding(
                        get: { option.isSelected },
                        set: { isSelected in
                            guard isSelected, !option.isSelected else { return }
                            HapticFeedback.selection()
                            actions.selectOption?(option.value)
                        }
                    )
                )
            }
        } label: {
            HStack(spacing: AppSpacing.small) {
                Text(options.selectedDisplayValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: AppSpacing.xSmall)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.medium)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(controlBackground, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPending || actions.selectOption == nil || options.options.isEmpty)
        .accessibilityLabel("Options")
        .accessibilityValue(options.selectedDisplayValue)
    }

    private func gaugePresentation(_ gauge: DashboardCardGaugeFeature) -> some View {
        GaugePresentationView(
            presentation: gauge.presentation,
            style: gaugeStyle,
            tint: fillColor
        )
        .frame(maxWidth: .infinity)
    }

    private func perform(_ command: DashboardCardCommand) {
        actions.commandAction(for: command.action)?()
    }

    private func perform(
        _ setpoint: DashboardCardSetpointFeature,
        changing value: DashboardCardSetpointValue,
        to updatedValue: Double
    ) {
        switch setpoint.action {
        case .setClimateTemperature:
            actions.setClimateTemperature?(updatedValue)
        case .setClimateTemperatureRange:
            let lowValue = setpoint.value(for: .low, changing: value, to: updatedValue)
            let highValue = setpoint.value(for: .high, changing: value, to: updatedValue)
            actions.setClimateTemperatureRange?(lowValue, highValue)
        }
    }

    private var controlBackground: Color {
        HomesteadSurfaceStyle.controlBackground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: isActive
        )
    }
}

private extension DashboardCardSetpointFeature {
    func value(
        for role: DashboardCardSetpointRole,
        changing changedValue: DashboardCardSetpointValue,
        to updatedValue: Double
    ) -> Double {
        if changedValue.role == role {
            return updatedValue
        }

        return values.first { $0.role == role }?.value ?? updatedValue
    }
}

private struct InlineStepperControl: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let value: String
    let isActive: Bool
    let decrementAccessibilityLabel: String
    let incrementAccessibilityLabel: String
    let isDecrementDisabled: Bool
    let isIncrementDisabled: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 1) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .frame(width: 18, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(isDecrementDisabled)
            .accessibilityLabel(decrementAccessibilityLabel)

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 18, maxWidth: .infinity)

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 18, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(isIncrementDisabled)
            .accessibilityLabel(incrementAccessibilityLabel)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .frame(height: 44)
        .background(controlBackground, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
    }

    private var controlBackground: Color {
        HomesteadSurfaceStyle.controlBackground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: isActive
        )
    }
}

private struct InlineLevelSliderControl: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let fillColor: Color
    let trackColor: Color
    let isDisabled: Bool
    let accessibilityLabel: String
    let accessibilityValue: String
    let setValue: (Double) -> Void
    @State private var currentValue: Double
    @State private var isEditing = false

    init(
        value: Double,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        fillColor: Color,
        trackColor: Color,
        isDisabled: Bool,
        accessibilityLabel: String,
        accessibilityValue: String,
        setValue: @escaping (Double) -> Void
    ) {
        self.value = value
        self.range = range
        self.step = step
        self.fillColor = fillColor
        self.trackColor = trackColor
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.setValue = setValue
        _currentValue = State(initialValue: value)
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = fillWidth(in: proxy.size.width)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    .fill(isWallpaperSurfaceActive ? Color(.tertiarySystemGroupedBackground).opacity(0.72) : trackColor)

                RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    .fill(fillColor.opacity(isWallpaperSurfaceActive ? 0.34 : 1))
                    .frame(width: fillWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isEditing = true
                        currentValue = steppedValue(sliderValue(at: value.location.x, width: proxy.size.width))
                    }
                    .onEnded { value in
                        let finalValue = steppedValue(sliderValue(at: value.location.x, width: proxy.size.width))
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
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustValue(by: step)
            case .decrement:
                adjustValue(by: -step)
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

    private func steppedValue(_ value: Double) -> Double {
        guard step > 0 else {
            return min(max(value, range.lowerBound), range.upperBound)
        }

        let stepped = (value / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }

    private func adjustValue(by delta: Double) {
        let updatedValue = steppedValue(currentValue + delta)
        currentValue = updatedValue
        setValue(updatedValue)
    }
}
