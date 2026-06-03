import SwiftUI

struct DashboardEntityDetailScaffold<Content: View>: View {
    let title: String
    let presentationStyle: DashboardDetailPresentationStyle
    private let content: Content

    init(
        title: String,
        presentationStyle: DashboardDetailPresentationStyle,
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
            .padding(.vertical, AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .dashboardDetailPresentation(title: title, style: presentationStyle)
    }
}

struct DashboardUnavailableDetailView: View {
    let title: String
    let systemImage: String
    let presentationStyle: DashboardDetailPresentationStyle

    var body: some View {
        ContentUnavailableView("\(title) Unavailable", systemImage: systemImage)
            .dashboardDetailPresentation(title: title, style: presentationStyle)
    }
}

struct DashboardEntityDetailHeader: View {
    let iconName: String
    let title: String
    let subtitle: String
    let badge: String
    let iconColor: Color
    let badgeColor: Color
    let iconBackground: Color
    let badgeBackground: Color

    init(
        iconName: String,
        title: String,
        subtitle: String,
        badge: String,
        iconColor: Color,
        badgeColor: Color? = nil,
        iconBackground: Color? = nil,
        badgeBackground: Color? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.iconColor = iconColor
        self.badgeColor = badgeColor ?? iconColor
        self.iconBackground = iconBackground ?? iconColor.opacity(0.12)
        self.badgeBackground = badgeBackground ?? iconColor.opacity(0.12)
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: iconName)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 52, height: 52)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: AppSpacing.medium)

            Text(badge)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(badgeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
                .background(badgeBackground, in: Capsule())
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

enum DashboardDetailActionButtonStyle {
    case primary
    case secondary
    case destructive
}

struct DashboardDetailActionButton: View {
    let title: String
    let systemImage: String
    let style: DashboardDetailActionButtonStyle
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        style: DashboardDetailActionButtonStyle = .primary,
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
        if isDisabled { return Color(.tertiarySystemGroupedBackground).opacity(0.8) }

        switch style {
        case .primary:
            return .accentColor
        case .secondary:
            return Color(.tertiarySystemGroupedBackground)
        case .destructive:
            return Color.red.opacity(0.12)
        }
    }
}

struct DashboardDetailIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 38, height: 38)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct DashboardDetailLevelSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let fillColor: Color
    let trackColor: Color
    let isDisabled: Bool
    let accessibilityLabel: String
    let accessibilityValue: String
    let onEditingChanged: (Bool) -> Void
    let onCommit: (Double) -> Void

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
        _value = value
        self.range = range
        self.step = step
        self.fillColor = fillColor
        self.trackColor = trackColor
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
                    .fill(trackColor)

                RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        onEditingChanged(true)
                        value = steppedValue(sliderValue(at: dragValue.location.x, width: proxy.size.width))
                    }
                    .onEnded { dragValue in
                        let finalValue = steppedValue(sliderValue(at: dragValue.location.x, width: proxy.size.width))
                        value = finalValue
                        onEditingChanged(false)
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
}

struct DashboardDetailPillButton: View {
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
                .frame(height: 42)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? tint : Color(.tertiarySystemGroupedBackground), in: Capsule())
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

struct DashboardDetailMenuRow<MenuContent: View>: View {
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
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: AppSpacing.medium)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.medium)
            .frame(height: 44)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct DashboardEntityMetadataDisclosure: View {
    let title: String
    let systemImage: String
    let rows: [DashboardEntityDetailRow]

    var body: some View {
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct DashboardControlPanel<Content: View>: View {
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct DashboardEntityContextPanel: View {
    let title: String
    let systemImage: String
    let rows: [DashboardEntityDetailRow]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            ForEach(rows) { row in
                row
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

struct DashboardEntityDetailRow: View, Identifiable {
    let title: String
    let value: String

    var id: String { title }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.medium)

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}

extension String {
    var displayStateText: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}
