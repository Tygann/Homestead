import SwiftUI

// MARK: - Presentation Models

nonisolated enum WidgetSensorBoardCompactPresentation: String, Codable, Equatable, Sendable {
    case automatic
    case gauge
    case reading
}

nonisolated struct WidgetSensorBoardCompactItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let icon: ResolvedIcon
    let valueText: String
    let isAvailable: Bool
    let requestedPresentation: WidgetSensorBoardCompactPresentation
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
        presentation: WidgetSensorBoardCompactPresentation = .automatic
    ) -> Self {
        let trimmedName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Self(
            id: snapshot.entityID,
            displayName: trimmedName.isEmpty ? snapshot.displayName : trimmedName,
            icon: snapshot.resolvedIcon,
            valueText: snapshot.valueText,
            isAvailable: snapshot.isAvailable,
            requestedPresentation: presentation,
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
            gauge: updatedGauge
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

struct WidgetSensorBoardFace: View {
    let items: [WidgetSensorBoardItem?]
    var destinationsByEntityID: [String: URL] = [:]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                slot(at: index)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        let item = items.indices.contains(index) ? items[index] : nil

        switch item {
        case let .compact(item):
            linkedContent(entityID: item.id) {
                WidgetSensorBoardCompactTile(item: item)
            }
        case let .chart(item):
            linkedContent(entityID: item.id) {
                WidgetSensorBoardChartTile(item: item)
            }
        case nil:
            WidgetSensorBoardEmptyTile(title: "Choose Item", systemImage: "plus")
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

    var body: some View {
        Group {
            if item.resolvedPresentation == .gauge, let gauge = item.gauge {
                WidgetGaugeInstrumentView(
                    gauge: item.isAvailable ? gauge : gauge.updating(value: gauge.value, valueText: "—"),
                    tint: item.isAvailable ? widgetGaugeColor(for: gauge.currentColor) : .secondary,
                    title: item.displayName,
                    icon: item.icon,
                    style: .compactSegmented
                )
            } else {
                reading
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.displayName)
        .accessibilityValue(item.isAvailable ? item.valueText : "Unavailable")
    }

    private var reading: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomesteadIconView(icon: item.icon, pointSize: 16, weight: .semibold)
                .foregroundStyle(item.isAvailable ? Color.blue : .secondary)

            Text(item.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)

            Text(item.isAvailable ? item.valueText : "—")
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(item.isAvailable ? Color.primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetSensorBoardChartTile: View {
    let item: WidgetSensorBoardChartItem

    var body: some View {
        HomesteadWidgetChartFace(
            presentation: item.chartPresentation,
            accentColor: widgetGaugeColor(for: item.accentColor),
            density: .sensorBoard
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

private struct WidgetSensorBoardEmptyTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
            Text(title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
