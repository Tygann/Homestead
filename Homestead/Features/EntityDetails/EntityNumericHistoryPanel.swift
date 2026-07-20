import Accessibility
import Charts
import SwiftUI

struct EntityNumericHistoryPanel: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedRange: HAHistoryRangePreset = .day
    @State private var phase: EntityNumericHistoryPhase = .idle

    let entityBox: HAEntityState
    let displayName: String
    let unit: String?
    let accentColor: Color
    let preferredRange: ClosedRange<Double>?

    var body: some View {
        EntityDetailSection(title: "History", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                rangePicker

                switch phase {
                case .idle, .loading:
                    EntityDetailLoadingPlaceholder(title: "Loading history", height: 160)
                case .loaded(let series):
                    if series.isEmpty {
                        unavailableView(
                            "No history for \(selectedRange.accessibilityTitle.lowercased()).",
                            showsRetry: false
                        )
                    } else {
                        EntityNumericHistoryChart(
                            series: series,
                            selectedRange: selectedRange,
                            accentColor: accentColor,
                            preferredRange: preferredRange
                        )
                    }
                case .failed:
                    unavailableView("History unavailable", showsRetry: true)
                }
            }
        }
        .task(id: taskID) {
            await refresh()
        }
    }

    private var rangePicker: some View {
        Picker("History range", selection: $selectedRange) {
            ForEach(HAHistoryRangePreset.sensorChartPresets) { range in
                Text(range.title)
                    .tag(range)
                    .accessibilityLabel(range.accessibilityTitle)
            }
        }
        .pickerStyle(.segmented)
        .disabled(phase.isLoading)
        .accessibilityLabel("History range")
    }

    private var taskID: String {
        "\(entityBox.entityID)-\(selectedRange.rawValue)"
    }

    private func unavailableView(_ message: String, showsRetry: Bool) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.small)

            if showsRetry {
                Button("Retry") {
                    Task { await refresh() }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(phase.isLoading)
            }
        }
        .padding(AppSpacing.medium)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
    }

    @MainActor
    private func refresh() async {
        phase = .loading
        let interval = selectedRange.interval()
        let request = HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: entityBox.entityID
        )

        do {
            let fetchedSeries = try await homeAssistantService.fetchHistory(
                settings: connectionSettings,
                request: request,
                range: selectedRange
            )
            phase = .loaded(
                HAHistoryChartSeries(
                    entityID: fetchedSeries.entityID,
                    displayName: displayName,
                    unit: unit ?? fetchedSeries.unit,
                    range: fetchedSeries.range,
                    samples: fetchedSeries.samples,
                    requestedInterval: fetchedSeries.requestedInterval
                )
            )
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}

private struct EntityNumericHistoryChart: View {
    let series: HAHistoryChartSeries
    let selectedRange: HAHistoryRangePreset
    let accentColor: Color
    let preferredRange: ClosedRange<Double>?

    private var valueDomain: ClosedRange<Double> {
        series.valueDomain(preferredRange: preferredRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Chart(series.chartSamples()) { sample in
                LineMark(
                    x: .value("Time", sample.occurredAt),
                    y: .value("Value", sample.value)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accentColor)

                AreaMark(
                    x: .value("Time", sample.occurredAt),
                    yStart: .value("Baseline", valueDomain.lowerBound),
                    yEnd: .value("Value", sample.value)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor.opacity(0.22), accentColor.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: valueDomain)
            .chartPlotStyle { $0.clipped() }
            .chartXAxis { xAxisMarks }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
            .clipped()
            .accessibilityChartDescriptor(
                EntityNumericHistoryChartDescriptor(series: series, valueDomain: valueDomain)
            )
            .accessibilityLabel("\(series.displayName) history")
            .accessibilityValue(series.summaryText)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                    summary
                    Spacer(minLength: AppSpacing.small)
                    latestDate
                }

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    summary
                    latestDate
                }
            }

            if let coverageNotice = series.coverageNotice {
                Text(coverageNotice)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        switch selectedRange {
        case .oneHour, .sixHours, .day:
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        case .week:
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        case .month:
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }

    private var summary: some View {
        Text(series.summaryText)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var latestDate: some View {
        if let latestSample = series.latestSample {
            Text(latestSampleDateText(latestSample.occurredAt))
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private func latestSampleDateText(_ date: Date) -> String {
        switch selectedRange {
        case .oneHour, .sixHours, .day:
            date.formatted(date: .omitted, time: .shortened)
        case .week, .month:
            date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

private struct EntityDetailLoadingPlaceholder: View {
    let title: String
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: height)
                .overlay { ProgressView() }

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct EntityNumericHistoryChartDescriptor: AXChartDescriptorRepresentable {
    let series: HAHistoryChartSeries
    let valueDomain: ClosedRange<Double>

    func makeChartDescriptor() -> AXChartDescriptor {
        let samples = series.chartSamples()
        let firstTimestamp = samples.first?.occurredAt.timeIntervalSince1970 ?? 0
        let lastTimestamp = samples.last?.occurredAt.timeIntervalSince1970 ?? firstTimestamp + 1
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Time",
            range: firstTimestamp...max(lastTimestamp, firstTimestamp + 1),
            gridlinePositions: []
        ) { timestamp in
            Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened)
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: series.unit.map { "Value in \($0)" } ?? "Value",
            range: valueDomain,
            gridlinePositions: []
        ) { value in
            series.formatValue(value)
        }
        let dataPoints = samples.map { sample in
            AXDataPoint(
                x: sample.occurredAt.timeIntervalSince1970,
                y: sample.value,
                label: series.formatValue(sample.value)
            )
        }

        return AXChartDescriptor(
            title: "\(series.displayName) history",
            summary: series.summaryText,
            xAxis: xAxis,
            yAxis: yAxis,
            series: [
                AXDataSeriesDescriptor(
                    name: series.displayName,
                    isContinuous: true,
                    dataPoints: dataPoints
                )
            ]
        )
    }
}

private enum EntityNumericHistoryPhase: Equatable {
    case idle
    case loading
    case loaded(HAHistoryChartSeries)
    case failed

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
