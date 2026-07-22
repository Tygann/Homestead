import SwiftUI

struct DashboardCardFeatureActions {
    var setLightBrightness: ((Double) -> Void)?
    var setFanPercentage: ((Double) -> Void)?
    var setClimateTemperature: ((Double) -> Void)?
    var setClimateTemperatureRange: ((Double, Double) -> Void)?
    var openCover: (() -> Void)?
    var stopCover: (() -> Void)?
    var closeCover: (() -> Void)?
    var setCoverPosition: ((Double) -> Void)?
    var lock: (() -> Void)?
    var unlock: (() -> Void)?
    var selectOption: ((String) -> Void)?
    var playPauseMedia: (() -> Void)?
    var setMediaVolume: ((Double) -> Void)?
    var selectMediaSource: ((String) -> Void)?

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
        case .setFanPercentage:
            setFanPercentage
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
    @State private var localSetpointValues: [DashboardCardSetpointRole: Double] = [:]
    @State private var pendingSetpointTask: Task<Void, Never>?

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
        .onChange(of: feature) { _, _ in
            localSetpointValues = [:]
            pendingSetpointTask?.cancel()
            pendingSetpointTask = nil
        }
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
                let effectiveValue = localSetpointValue(for: value)
                let bounds = localSetpointBounds(for: value, in: setpoint)
                InlineStepperControl(
                    value: displayValue(for: effectiveValue),
                    isActive: isActive,
                    decrementAccessibilityLabel: value.decrementAccessibilityLabel,
                    incrementAccessibilityLabel: value.incrementAccessibilityLabel,
                    isDecrementDisabled: effectiveValue <= bounds.lowerBound,
                    isIncrementDisabled: effectiveValue >= bounds.upperBound,
                    decrement: {
                        perform(setpoint, changing: value, to: effectiveValue - value.step)
                    },
                    increment: {
                        perform(setpoint, changing: value, to: effectiveValue + value.step)
                    }
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(value.accessibilityLabel)
                .accessibilityValue(displayValue(for: effectiveValue))
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
        let helper = setpointAdjustment(for: setpoint)

        switch setpoint.action {
        case .setClimateTemperature:
            let targetValue = helper.clampedSingleTemperature(updatedValue)
            localSetpointValues[.target] = targetValue
            scheduleSetpointSend {
                actions.setClimateTemperature?(targetValue)
            }
        case .setClimateTemperatureRange:
            let currentLow = localSetpointValues[.low] ?? setpoint.value(for: .low, changing: value, to: updatedValue)
            let currentHigh = localSetpointValues[.high] ?? setpoint.value(for: .high, changing: value, to: updatedValue)
            let range: ClimateSetpointRange

            switch value.role {
            case .low:
                range = helper.clampedRange(lowTemperature: updatedValue, highTemperature: currentHigh)
            case .high:
                range = helper.clampedRange(lowTemperature: currentLow, highTemperature: updatedValue)
            case .target:
                range = helper.clampedRange(lowTemperature: updatedValue, highTemperature: currentHigh)
            }

            localSetpointValues[.low] = range.lowTemperature
            localSetpointValues[.high] = range.highTemperature
            scheduleSetpointSend {
                actions.setClimateTemperatureRange?(range.lowTemperature, range.highTemperature)
            }
        }
    }

    private func localSetpointValue(for value: DashboardCardSetpointValue) -> Double {
        localSetpointValues[value.role] ?? value.value
    }

    private func localSetpointBounds(
        for value: DashboardCardSetpointValue,
        in setpoint: DashboardCardSetpointFeature
    ) -> ClosedRange<Double> {
        switch value.role {
        case .low:
            return value.minimumValue...(localSetpointValues[.high] ?? value.maximumValue)
        case .high:
            return (localSetpointValues[.low] ?? value.minimumValue)...value.maximumValue
        case .target:
            return value.minimumValue...value.maximumValue
        }
    }

    private func setpointAdjustment(for setpoint: DashboardCardSetpointFeature) -> ClimateSetpointAdjustment {
        let values = setpoint.values
        let minimum = values.map(\.minimumValue).min() ?? 0
        let maximum = values.map(\.maximumValue).max() ?? 100
        let step = values.first?.step ?? 1

        return ClimateSetpointAdjustment(
            minimumTemperature: minimum,
            maximumTemperature: maximum,
            step: step
        )
    }

    private func scheduleSetpointSend(_ send: @escaping @MainActor () -> Void) {
        HapticFeedback.selection()
        pendingSetpointTask?.cancel()
        pendingSetpointTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            send()
            pendingSetpointTask = nil
        }
    }

    private func displayValue(for value: Double) -> String {
        Self.setpointFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let setpointFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

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
        ZStack {
            HStack(spacing: 0) {
                Button(action: decrement) {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDecrementDisabled)
                .accessibilityLabel(decrementAccessibilityLabel)

                Button(action: increment) {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isIncrementDisabled)
                .accessibilityLabel(incrementAccessibilityLabel)
            }

            HStack(spacing: 0) {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isDecrementDisabled ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity)

                Text(value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: 24, maxWidth: .infinity)

                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isIncrementDisabled ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.xSmall)
            .allowsHitTesting(false)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(controlBackground, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
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
    @State private var dragAxis: SliderDragAxis = .undecided

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
            let sliderShape = RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)

            ZStack(alignment: .leading) {
                sliderShape
                    .fill(trackColor)

                Rectangle()
                    .fill(fillColor.opacity(isWallpaperSurfaceActive ? 0.34 : 1))
                    .frame(width: fillWidth)
                    .frame(maxHeight: .infinity)
            }
            .clipShape(sliderShape)
            .contentShape(sliderShape)
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let finalValue = steppedValue(sliderValue(at: value.location.x, width: proxy.size.width))
                        currentValue = finalValue
                        setValue(finalValue)
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard resolveAxis(for: value.translation) == .horizontal else { return }
                        isEditing = true
                        currentValue = steppedValue(sliderValue(at: value.location.x, width: proxy.size.width))
                    }
                    .onEnded { value in
                        defer {
                            dragAxis = .undecided
                            isEditing = false
                        }
                        guard dragAxis == .horizontal else { return }
                        let finalValue = steppedValue(sliderValue(at: value.location.x, width: proxy.size.width))
                        currentValue = finalValue
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

    private func resolveAxis(for translation: CGSize) -> SliderDragAxis {
        if dragAxis != .undecided {
            return dragAxis
        }

        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard max(horizontalDistance, verticalDistance) >= 8 else {
            return .undecided
        }

        dragAxis = horizontalDistance > verticalDistance + 4 ? .horizontal : .vertical
        return dragAxis
    }
}

private enum SliderDragAxis {
    case undecided
    case horizontal
    case vertical
}
