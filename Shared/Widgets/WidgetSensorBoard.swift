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

nonisolated struct WidgetSensorBoardTrendSample: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let value: Double

    init(occurredAt: Date, value: Double) {
        id = "\(occurredAt.timeIntervalSince1970)-\(value)"
        self.occurredAt = occurredAt
        self.value = value
    }
}

nonisolated struct WidgetSensorBoardTrendItem: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let icon: ResolvedIcon
    let valueText: String
    let supportingText: String
    let isAvailable: Bool
    let samples: [WidgetSensorBoardTrendSample]
    let valueDomain: ClosedRange<Double>
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

            WidgetSensorBoardLineChart(
                samples: item.samples,
                valueDomain: item.valueDomain,
                accentColor: item.isAvailable ? .blue : .secondary
            )

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

private struct WidgetSensorBoardLineChart: View {
    let samples: [WidgetSensorBoardTrendSample]
    let valueDomain: ClosedRange<Double>
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.fill.quaternary)

                if samples.count < 2 {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    fillPath(in: proxy.size)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.22), accentColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(in: proxy.size)
                        .stroke(
                            accentColor,
                            style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round)
                        )
                }
            }
        }
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            points(in: size).enumerated().forEach { index, point in
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func fillPath(in size: CGSize) -> Path {
        Path { path in
            let resolvedPoints = points(in: size)
            guard let first = resolvedPoints.first, let last = resolvedPoints.last else { return }

            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            resolvedPoints.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard let firstDate = samples.first?.occurredAt,
              let lastDate = samples.last?.occurredAt else {
            return []
        }

        let duration = max(lastDate.timeIntervalSince(firstDate), 1)
        let valueSpan = max(valueDomain.upperBound - valueDomain.lowerBound, 0.000_001)
        let inset: CGFloat = 5
        let drawableWidth = max(size.width - (inset * 2), 0)
        let drawableHeight = max(size.height - (inset * 2), 0)

        return samples.map { sample in
            let xFraction = sample.occurredAt.timeIntervalSince(firstDate) / duration
            let yFraction = (sample.value - valueDomain.lowerBound) / valueSpan
            return CGPoint(
                x: inset + (drawableWidth * xFraction),
                y: inset + (drawableHeight * (1 - yFraction))
            )
        }
    }
}
