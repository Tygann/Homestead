import SwiftUI

// MARK: - Presentation Models

nonisolated enum WidgetSensorBoardCompactPresentation: String, Codable, Equatable, Sendable {
    case automatic
    case gauge
    case reading
}

nonisolated enum WidgetSensorBoardGaugeStyle: String, Codable, Equatable, Sendable {
    case circular
    case segmented
    case bar
}

nonisolated struct WidgetSensorBoardCompactItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let icon: ResolvedIcon
    let valueText: String
    let isAvailable: Bool
    let requestedPresentation: WidgetSensorBoardCompactPresentation
    let gaugeStyle: WidgetSensorBoardGaugeStyle
    let gauge: WidgetGaugePresentation?

    var resolvedPresentation: WidgetSensorBoardCompactPresentation {
        switch requestedPresentation {
        case .automatic:
            gauge == nil ? .reading : .gauge
        case .gauge:
            gauge == nil ? .reading : .gauge
        case .reading:
            .reading
        }
    }

    static func sensor(
        from snapshot: WidgetSensorSnapshot,
        customDisplayName: String? = nil,
        presentation: WidgetSensorBoardCompactPresentation = .automatic,
        gaugeStyle: WidgetSensorBoardGaugeStyle = .segmented
    ) -> Self {
        let trimmedName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Self(
            id: snapshot.entityID,
            displayName: trimmedName.isEmpty ? snapshot.displayName : trimmedName,
            icon: snapshot.resolvedIcon,
            valueText: snapshot.valueText,
            isAvailable: snapshot.isAvailable,
            requestedPresentation: presentation,
            gaugeStyle: gaugeStyle,
            gauge: snapshot.gauge
        )
    }

    func updating(with reading: WidgetSensorLiveReading) -> Self {
        guard reading.entityID == id else { return self }

        let updatedGauge = reading.numericValue.flatMap { value in
            gauge?.updating(value: value, valueText: reading.valueText)
        } ?? gauge
        let updatedIcon: ResolvedIcon
        switch icon.provenance {
        case .dashboardOverride, .appOverride, .haRegistryIcon:
            updatedIcon = icon
        case .haExplicitIcon, .haSemanticMapping, .homesteadSemanticMapping, .fallback:
            updatedIcon = reading.icon
        }

        return Self(
            id: id,
            displayName: displayName,
            icon: updatedIcon,
            valueText: reading.valueText,
            isAvailable: reading.isAvailable,
            requestedPresentation: requestedPresentation,
            gaugeStyle: gaugeStyle,
            gauge: updatedGauge
        )
    }

    func scoped(to reference: EntityPresentationReference) -> Self {
        Self(
            id: reference.encodedID,
            displayName: displayName,
            icon: icon,
            valueText: valueText,
            isAvailable: isAvailable,
            requestedPresentation: requestedPresentation,
            gaugeStyle: gaugeStyle,
            gauge: gauge
        )
    }
}

nonisolated struct WidgetSensorBoardChartItem: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let icon: ResolvedIcon
    let valueText: String
    let unitText: String?
    let supportingText: String
    let isAvailable: Bool
    let samples: [HomesteadChartSample]
    let valueDomain: ClosedRange<Double>
    let interpolationStyle: HomesteadChartInterpolationStyle
    let accentColor: WidgetGaugeColor

    var chartPresentation: HomesteadWidgetChartPresentation {
        HomesteadWidgetChartPresentation(
            title: displayName,
            valueText: valueText,
            unitText: unitText,
            icon: icon,
            isAvailable: isAvailable,
            samples: samples,
            valueDomain: valueDomain,
            interpolationStyle: interpolationStyle,
            rangeTitle: "6H",
            changeSummaryText: nil,
            emptyLabel: supportingText
        )
    }

    var hasChart: Bool {
        samples.count >= 2
    }

    var chartStatusText: String {
        if supportingText == WidgetStateText.needsConnection {
            return WidgetStateText.needsConnection
        }
        if !isAvailable {
            return WidgetStateText.unavailable
        }
        return WidgetStateText.noHistory
    }
}

nonisolated enum WidgetSensorBoardItem: Identifiable, Equatable, Sendable {
    case compact(WidgetSensorBoardCompactItem)
    case chart(WidgetSensorBoardChartItem)

    var id: String {
        switch self {
        case let .compact(item): item.id
        case let .chart(item): item.id
        }
    }
}

// MARK: - Sensor Board Face

enum WidgetSensorBoardLayout {
    case medium
    case large
}

struct WidgetSensorBoardFace: View {
    let items: [WidgetSensorBoardItem?]
    var layout: WidgetSensorBoardLayout = .medium
    var destinationsByEntityID: [String: URL] = [:]

    @ViewBuilder
    var body: some View {
        switch layout {
        case .medium:
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    slot(at: index)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 6)
        case .large:
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            slot(at: (row * 3) + column)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10)
        }
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        let item = items.indices.contains(index) ? items[index] : nil

        switch item {
        case let .compact(item):
            linkedContent(entityID: item.id) {
                WidgetSensorBoardCompactTile(item: item, usesSquareDensity: layout == .large)
            }
        case let .chart(item):
            linkedContent(entityID: item.id) {
                WidgetSensorBoardChartTile(item: item, usesSquareDensity: layout == .large)
            }
        case nil:
            WidgetSensorBoardEmptyTile(
                title: "Choose Item",
                systemImage: "plus",
                usesSquareDensity: layout == .large
            )
        }
    }

    @ViewBuilder
    private func linkedContent<Content: View>(
        entityID: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let destination = destinationsByEntityID[entityID] {
            Link(destination: destination) {
                content()
            }
        } else {
            content()
        }
    }
}

private struct WidgetSensorBoardCompactTile: View {
    let item: WidgetSensorBoardCompactItem
    let usesSquareDensity: Bool

    var body: some View {
        Group {
            if item.resolvedPresentation == .gauge, let gauge = item.gauge {
                WidgetSensorBoardSlotScaffold(
                    title: item.displayName,
                    icon: item.icon,
                    tint: item.isAvailable ? widgetGaugeColor(for: gauge.currentColor) : .secondary,
                    density: density
                ) {
                    gaugeContent(gauge)
                }
            } else {
                WidgetSensorBoardSlotScaffold(
                    title: item.displayName,
                    icon: item.icon,
                    tint: item.isAvailable ? .blue : .secondary,
                    density: density
                ) {
                    if item.isAvailable {
                        WidgetSensorBoardValueLabel(
                            valueText: item.valueText,
                            unitText: nil,
                            isAvailable: true,
                            density: density,
                            centersContent: true
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        VStack(alignment: .leading, spacing: density.contentSpacing) {
                            WidgetSensorBoardValueLabel(
                                valueText: "—",
                                unitText: nil,
                                isAvailable: false,
                                density: density
                            )

                            WidgetSensorBoardStatusBadge(
                                text: WidgetStateText.unavailable,
                                systemImage: "exclamationmark.circle",
                                density: density
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.displayName)
        .accessibilityValue(item.isAvailable ? item.valueText : "Unavailable")
    }

    private var density: WidgetSensorBoardSlotDensity {
        usesSquareDensity ? .square : .medium
    }

    @ViewBuilder
    private func gaugeContent(_ gauge: WidgetGaugePresentation) -> some View {
        let resolvedGauge = item.isAvailable
            ? gauge
            : gauge.updating(value: gauge.value, valueText: "—")
        let tint = item.isAvailable ? widgetGaugeColor(for: gauge.currentColor) : .secondary

        switch item.gaugeStyle {
        case .circular:
            WidgetGaugeInstrumentView(gauge: resolvedGauge, tint: tint, style: .standard)
                .padding(.top, 2)
        case .segmented:
            WidgetGaugeInstrumentView(gauge: resolvedGauge, tint: tint, style: .compactSegmented)
                .padding(.top, 2)
        case .bar:
            VStack(alignment: .leading, spacing: density.contentSpacing) {
                Spacer(minLength: 0)

                WidgetSensorBoardValueLabel(
                    valueText: resolvedGauge.valueText,
                    unitText: resolvedGauge.unitText,
                    isAvailable: item.isAvailable,
                    density: density
                )

                WidgetGaugeBarView(gauge: resolvedGauge)
                    .frame(height: GaugeVisualMetrics.barTotalHeight)
            }
            .padding(.bottom, density.chartBottomPadding)
        }
    }
}

private struct WidgetSensorBoardChartTile: View {
    let item: WidgetSensorBoardChartItem
    let usesSquareDensity: Bool

    var body: some View {
        WidgetSensorBoardSlotScaffold(
            title: item.displayName,
            icon: item.icon,
            tint: item.isAvailable ? widgetGaugeColor(for: item.accentColor) : .secondary,
            trailingText: "6H",
            density: density
        ) {
            VStack(alignment: .leading, spacing: density.contentSpacing) {
                WidgetSensorBoardValueLabel(
                    valueText: item.isAvailable ? item.valueText : "—",
                    unitText: item.unitText,
                    isAvailable: item.isAvailable,
                    density: density
                )

                chartContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.displayName) chart")
        .accessibilityValue(
            item.hasChart
                ? "\(item.valueText), six hour chart"
                : "\(item.valueText), \(item.chartStatusText.lowercased())"
        )
    }

    @ViewBuilder
    private var chartContent: some View {
        if item.hasChart {
            HomesteadChartPlot(
                samples: item.samples,
                valueDomain: item.valueDomain,
                accentColor: item.isAvailable ? widgetGaugeColor(for: item.accentColor) : .secondary,
                interpolationStyle: item.interpolationStyle,
                highlightsLatestSample: true
            )
            .padding(.bottom, density.chartBottomPadding)
        } else {
            WidgetSensorBoardStatusBadge(
                text: item.chartStatusText,
                systemImage: item.chartStatusText == WidgetStateText.needsConnection
                    ? "wifi.slash"
                    : "clock.arrow.circlepath",
                density: density
            )
        }
    }

    private var density: WidgetSensorBoardSlotDensity {
        usesSquareDensity ? .square : .medium
    }
}

private struct WidgetSensorBoardEmptyTile: View {
    let title: String
    let systemImage: String
    let usesSquareDensity: Bool

    var body: some View {
        let density: WidgetSensorBoardSlotDensity = usesSquareDensity ? .square : .medium

        VStack(spacing: density.contentSpacing) {
            Image(systemName: systemImage)
                .font(density.titleFont)

            Text(title)
                .font(density.titleFont)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
}

// MARK: - Shared Slot Structure

private enum WidgetSensorBoardSlotDensity {
    case medium
    case square

    var iconPointSize: CGFloat { self == .medium ? 13 : 11 }
    var titleFont: Font { self == .medium ? .caption.weight(.semibold) : .caption2.weight(.semibold) }
    var valueFontSize: CGFloat { self == .medium ? 26 : 20 }
    var unitFont: Font { self == .medium ? .caption.weight(.semibold) : .caption2.weight(.semibold) }
    var contentSpacing: CGFloat { self == .medium ? 4 : 2 }
    var chartBottomPadding: CGFloat { self == .medium ? 18 : 6 }
}

private struct WidgetSensorBoardSlotScaffold<Content: View>: View {
    let title: String
    let icon: ResolvedIcon
    let tint: Color
    var trailingText: String? = nil
    let density: WidgetSensorBoardSlotDensity
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: density.contentSpacing) {
            HStack(spacing: 6) {
                HomesteadIconView(
                    icon: icon,
                    pointSize: density.iconPointSize,
                    weight: .semibold
                )
                .foregroundStyle(tint)

                Text(title)
                    .font(density.titleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 3)

                if let trailingText {
                    Text(trailingText)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetSensorBoardValueLabel: View {
    let valueText: String
    let unitText: String?
    let isAvailable: Bool
    let density: WidgetSensorBoardSlotDensity
    var centersContent = false

    var body: some View {
        let parts = gaugeValueParts(from: valueText, unitText: unitText)

        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(parts.value)
                .font(.system(
                    size: density.valueFontSize,
                    weight: .regular,
                    design: .rounded
                ))
                .foregroundStyle(isAvailable ? Color.primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .monospacedDigit()

            if let unit = parts.unit, isAvailable {
                Text(unit)
                    .font(density.unitFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !centersContent {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: centersContent ? nil : .infinity)
    }
}

private struct WidgetSensorBoardStatusBadge: View {
    let text: String
    let systemImage: String
    let density: WidgetSensorBoardSlotDensity

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, density == .medium ? 8 : 6)
            .padding(.vertical, density == .medium ? 6 : 4)
            .background(.fill.quaternary, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
