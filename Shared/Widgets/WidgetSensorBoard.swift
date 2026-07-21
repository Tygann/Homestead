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

nonisolated struct WidgetSensorBoardTrendItem: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let icon: ResolvedIcon
    let valueText: String
    let supportingText: String
    let isAvailable: Bool
    let samples: [HomesteadTrendChartSample]
    let valueDomain: ClosedRange<Double>
    let interpolationStyle: HomesteadTrendChartInterpolationStyle
}

// MARK: - Sensor Board Face

struct WidgetSensorBoardFace: View {
    let compactItems: [WidgetSensorBoardCompactItem?]
    let trendItem: WidgetSensorBoardTrendItem?
    var destinationsByEntityID: [String: URL] = [:]

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 10
            let compactRegionWidth = min(proxy.size.width * 0.56, proxy.size.height * 1.35)
            let compactWidth = max((compactRegionWidth - spacing) / 2, 0)

            HStack(spacing: spacing) {
                ForEach(0..<2, id: \.self) { index in
                    compactSlot(at: index)
                        .frame(width: compactWidth)
                }

                trendSlot
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    @ViewBuilder
    private func compactSlot(at index: Int) -> some View {
        let item = compactItems.indices.contains(index) ? compactItems[index] : nil

        if let item {
            linkedContent(entityID: item.id) {
                WidgetSensorBoardCompactTile(item: item)
            }
        } else {
            WidgetSensorBoardEmptyTile(title: "Choose Sensor", systemImage: "plus")
        }
    }

    @ViewBuilder
    private var trendSlot: some View {
        if let trendItem {
            linkedContent(entityID: trendItem.id) {
                WidgetSensorBoardTrendTile(item: trendItem)
            }
        } else {
            WidgetSensorBoardEmptyTile(title: "Choose Trend", systemImage: "chart.xyaxis.line")
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

private struct WidgetSensorBoardTrendTile: View {
    let item: WidgetSensorBoardTrendItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                HomesteadIconView(icon: item.icon, pointSize: 13, weight: .semibold)
                    .foregroundStyle(item.isAvailable ? Color.blue : .secondary)

                Text(item.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(item.isAvailable ? item.valueText : "—")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .monospacedDigit()

            chart

            Text(item.supportingText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.displayName), six hour trend")
        .accessibilityValue(item.isAvailable ? item.valueText : "Unavailable")
    }

    @ViewBuilder
    private var chart: some View {
        if item.samples.count >= 2 {
            HomesteadTrendChartPlot(
                samples: item.samples,
                valueDomain: item.valueDomain,
                accentColor: item.isAvailable ? .blue : .secondary,
                interpolationStyle: item.interpolationStyle
            )
        } else {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color.secondary.opacity(0.10),
                        Color.secondary.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(Color.secondary.opacity(0.30))
                    .frame(height: 2)

                Image(systemName: "chart.xyaxis.line")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 7)
            }
        }
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
