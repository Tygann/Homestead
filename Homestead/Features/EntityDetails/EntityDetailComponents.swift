import SwiftUI

struct EntityDetailScaffold<Content: View>: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let title: String
    let presentationStyle: EntityDetailPresentationStyle
    private let content: Content

    init(
        title: String,
        presentationStyle: EntityDetailPresentationStyle,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.presentationStyle = presentationStyle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                content
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, presentationStyle.scrollBottomClearance)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(
            isWallpaperSurfaceActive
                ? Color.clear
                : Color(.systemGroupedBackground)
        )
        .entityDetailPresentation(title: title, style: presentationStyle)
    }
}

struct EntityUnavailableDetailView: View {
    let title: String
    let systemImage: String
    let presentationStyle: EntityDetailPresentationStyle

    var body: some View {
        ContentUnavailableView("\(title) Unavailable", systemImage: systemImage)
            .entityDetailPresentation(title: title, style: presentationStyle)
    }
}

enum EntityDetailActionButtonStyle {
    case primary
    case secondary
    case destructive
}

struct EntityDetailActionButton: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let title: String
    let systemImage: String
    let style: EntityDetailActionButtonStyle
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        style: EntityDetailActionButtonStyle = .primary,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(role: style == .destructive ? .destructive : nil, action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isDisabled { return .secondary.opacity(0.65) }

        switch style {
        case .primary:
            return .white
        case .secondary:
            return .accentColor
        case .destructive:
            return .red
        }
    }

    private var backgroundColor: Color {
        if isDisabled {
            return HomesteadSurfaceStyle.controlBackground(
                isWallpaperActive: isWallpaperSurfaceActive,
                isActive: false
            )
            .opacity(0.8)
        }

        switch style {
        case .primary:
            return .accentColor
        case .secondary:
            return HomesteadSurfaceStyle.controlBackground(
                isWallpaperActive: isWallpaperSurfaceActive,
                isActive: false
            )
        case .destructive:
            return Color.red.opacity(0.12)
        }
    }
}

struct EntityDetailIconButton: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let systemImage: String
    let accessibilityLabel: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
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
        .foregroundStyle(.primary)
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct EntityDetailStateToggle: View {
    let isOn: Bool
    let accessibilityLabel: String
    let isDisabled: Bool
    let action: (Bool) -> Void

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { isOn },
                set: { newValue in
                    guard newValue != isOn else { return }
                    action(newValue)
                }
            )
        ) {
            Text(accessibilityLabel)
        }
        .labelsHidden()
        .toggleStyle(.switch)
        .frame(minWidth: 52, minHeight: 44)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct EntityDetailHeroActionButton: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if isWallpaperSurfaceActive {
            if #available(iOS 26.0, *) {
                button
                    .buttonStyle(.glass)
            } else {
                button
                    .buttonStyle(.bordered)
            }
        } else {
            button
                .buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(title, systemImage: systemImage, action: action)
            .font(.subheadline.weight(.semibold))
            .controlSize(.regular)
            .frame(minHeight: 44)
            .disabled(isDisabled)
    }
}

struct EntityDetailLevelSlider: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let fillColor: Color
    let trackColor: Color
    let showsFilledTrack: Bool
    let isDisabled: Bool
    let accessibilityLabel: String
    let accessibilityValue: String
    let onEditingChanged: (Bool) -> Void
    let onCommit: (Double) -> Void
    @State private var dragAxis: DetailSliderDragAxis = .undecided

    init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        fillColor: Color = .accentColor,
        trackColor: Color = Color(.tertiarySystemGroupedBackground),
        isDisabled: Bool,
        accessibilityLabel: String,
        accessibilityValue: String,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping (Double) -> Void
    ) {
        self.init(
            value: value,
            range: range,
            step: step,
            fillColor: fillColor,
            trackColor: trackColor,
            showsFilledTrack: true,
            isDisabled: isDisabled,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: accessibilityValue,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }

    init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        fillColor: Color = .accentColor,
        trackColor: Color = Color(.tertiarySystemGroupedBackground),
        showsFilledTrack: Bool,
        isDisabled: Bool,
        accessibilityLabel: String,
        accessibilityValue: String,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping (Double) -> Void
    ) {
        _value = value
        self.range = range
        self.step = step
        self.fillColor = fillColor
        self.trackColor = trackColor
        self.showsFilledTrack = showsFilledTrack
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = fillWidth(in: proxy.size.width)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    .fill(
                        isWallpaperSurfaceActive
                            ? HomesteadSurfaceStyle.controlBackground(
                                isWallpaperActive: true,
                                isActive: false
                            )
                            : trackColor
                    )

                if showsFilledTrack {
                    RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                        .fill(fillColor)
                        .frame(width: fillWidth)
                } else {
                    Capsule()
                        .fill(fillColor)
                        .frame(width: 22, height: 22)
                        .shadow(color: fillColor.opacity(0.24), radius: 4, y: 1)
                        .offset(x: min(max(fillWidth - 11, 0), max(proxy.size.width - 22, 0)))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { tapValue in
                        let finalValue = steppedValue(sliderValue(at: tapValue.location.x, width: proxy.size.width))
                        value = finalValue
                        onCommit(finalValue)
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { dragValue in
                        guard resolveAxis(for: dragValue.translation) == .horizontal else { return }
                        onEditingChanged(true)
                        value = steppedValue(sliderValue(at: dragValue.location.x, width: proxy.size.width))
                    }
                    .onEnded { dragValue in
                        defer {
                            dragAxis = .undecided
                            onEditingChanged(false)
                        }
                        guard dragAxis == .horizontal else { return }
                        let finalValue = steppedValue(sliderValue(at: dragValue.location.x, width: proxy.size.width))
                        value = finalValue
                        onCommit(finalValue)
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
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
    }

    private func fillWidth(in width: CGFloat) -> CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let normalizedValue = (clampedValue - range.lowerBound) / (range.upperBound - range.lowerBound)
        return width * CGFloat(normalizedValue)
    }

    private var clampedValue: Double {
        min(max(value, range.lowerBound), range.upperBound)
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
        let updatedValue = steppedValue(value + delta)
        value = updatedValue
        onCommit(updatedValue)
    }

    private func resolveAxis(for translation: CGSize) -> DetailSliderDragAxis {
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

private enum DetailSliderDragAxis {
    case undecided
    case horizontal
    case vertical
}

struct EntityDetailPillButton: View {
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let title: String
    let systemImage: String?
    let isSelected: Bool
    let isDisabled: Bool
    let tint: Color
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        isSelected: Bool,
        isDisabled: Bool,
        tint: Color = .accentColor,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            isSelected
                ? tint
                : HomesteadSurfaceStyle.controlBackground(
                    isWallpaperActive: isWallpaperSurfaceActive,
                    isActive: false
                ),
            in: Capsule()
        )
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

struct EntityDetailMenuRow<MenuContent: View>: View {
    let title: String
    let systemImage: String
    let value: String
    let isDisabled: Bool
    private let menuContent: MenuContent

    init(
        title: String,
        systemImage: String,
        value: String,
        isDisabled: Bool,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.isDisabled = isDisabled
        self.menuContent = menuContent()
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Label(title, systemImage: systemImage)
                    .font(.body)

                Spacer(minLength: AppSpacing.medium)

                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct EntityMetadataDisclosure: View {
    @Environment(\.homesteadEntityDetailSurfaceContext) private var surfaceContext

    let entityBox: HAEntityState?
    let title: String
    let systemImage: String
    let rows: [EntityMetadataRow]

    init(
        entityBox: HAEntityState? = nil,
        title: String,
        systemImage: String,
        rows: [EntityMetadataRow]
    ) {
        self.entityBox = entityBox
        self.title = title
        self.systemImage = systemImage
        self.rows = rows
    }

    var body: some View {
        Group {
            if let entityBox {
                NavigationLink {
                    EntityDiagnosticsView(
                        entityBox: entityBox,
                        presentationStyle: .navigation,
                        surfaceContext: surfaceContext
                    )
                } label: {
                    EntityDetailNavigationRowLabel(
                        title: "Entity Details",
                        systemImage: "info.circle"
                    )
                    .padding(.horizontal, AppSpacing.large)
                    .frame(height: 52)
                    .homesteadCardSurface()
                }
                .buttonStyle(.plain)
            } else {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        ForEach(rows) { row in
                            row
                        }
                    }
                    .padding(.top, AppSpacing.medium)
                } label: {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                }
                .padding(AppSpacing.large)
                .homesteadCardSurface()
            }
        }
    }
}

struct EntityDetailNavigationRowLabel: View {
    let title: String
    let systemImage: String
    var showsDisclosureIndicator = true

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: AppSpacing.medium)

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct EntityDetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content
        }
        .padding(AppSpacing.large)
        .homesteadCardSurface()
    }
}

struct EntityControlPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        EntityDetailSection(title: title, systemImage: systemImage) {
            content
        }
    }
}

struct DashboardEntityContextPanel: View {
    let title: String
    let systemImage: String
    let rows: [EntityMetadataRow]

    var body: some View {
        EntityDetailSection(title: title, systemImage: systemImage) {
            ForEach(rows) { row in
                row
            }
        }
    }
}

struct EntityMetadataRow: View, Identifiable {
    enum Layout {
        case automatic
        case stacked
    }

    let title: String
    let value: String
    var layout: Layout = .automatic

    var id: String { title }

    var body: some View {
        Group {
            if layout == .stacked {
                stackedContent
            } else {
                automaticContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    private var automaticContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            valueText
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var valueText: some View {
        if title == "Entity ID" {
            Text(value)
                .font(.caption.monospaced().weight(.medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        } else if title == "Last Updated" {
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        } else {
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .textSelection(.enabled)
        }
    }
}

extension String {
    var displayStateText: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}
