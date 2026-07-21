import Accessibility
import Charts
import SwiftUI

struct EntityNumericHistoryPanel: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedRange: HAHistoryRangePreset
    @State private var phase: EntityNumericHistoryPhase = .idle
    @State private var selectedSampleDate: Date?

    let entityBox: HAEntityState
    let displayName: String
    let unit: String?
    var displayPrecision: Int? = nil
    let accentColor: Color
    let preferredRange: ClosedRange<Double>?
    var layout: EntityNumericHistoryLayout = .compact
    var interpolationStyle: HomesteadChartInterpolationStyle = .linear
    var onSelectionChange: (EntityHistorySelection?) -> Void = { _ in }

    init(
        entityBox: HAEntityState,
        displayName: String,
        unit: String?,
        displayPrecision: Int? = nil,
        accentColor: Color,
        preferredRange: ClosedRange<Double>?,
        initialRange: HAHistoryRangePreset = .day,
        layout: EntityNumericHistoryLayout = .compact,
        interpolationStyle: HomesteadChartInterpolationStyle = .linear,
        onSelectionChange: @escaping (EntityHistorySelection?) -> Void = { _ in }
    ) {
        self.entityBox = entityBox
        self.displayName = displayName
        self.unit = unit
        self.displayPrecision = displayPrecision
        self.accentColor = accentColor
        self.preferredRange = preferredRange
        self.layout = layout
        self.interpolationStyle = interpolationStyle
        self.onSelectionChange = onSelectionChange
        _selectedRange = State(initialValue: initialRange)
    }

    var body: some View {
        EntityDetailSection(title: "History", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                rangePicker

                switch phase {
                case .idle, .loading:
                    EntityDetailLoadingPlaceholder(title: "Loading history", height: layout.chartHeight)
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
                            preferredRange: preferredRange,
                            layout: layout,
                            interpolationStyle: interpolationStyle,
                            selectedSampleDate: $selectedSampleDate,
                            onSelectionChange: onSelectionChange
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
        .onChange(of: selectedRange) {
            selectedSampleDate = nil
            onSelectionChange(nil)
        }
        .onDisappear {
            onSelectionChange(nil)
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
                    displayPrecision: displayPrecision,
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

enum EntityNumericHistoryLayout: Equatable, Sendable {
    case compact
    case expanded

    var chartHeight: CGFloat {
        switch self {
        case .compact: 180
        case .expanded: 300
        }
    }
}

struct EntityHistorySelection: Equatable, Sendable {
    let occurredAt: Date
    let formattedValue: String
}

private struct EntityNumericHistoryChart: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let series: HAHistoryChartSeries
    let selectedRange: HAHistoryRangePreset
    let accentColor: Color
    let preferredRange: ClosedRange<Double>?
    let layout: EntityNumericHistoryLayout
    let interpolationStyle: HomesteadChartInterpolationStyle
    @Binding var selectedSampleDate: Date?
    let onSelectionChange: (EntityHistorySelection?) -> Void

    private var plottedSamples: [HAHistorySample] {
        series.chartSamples()
    }

    private var selectedSample: HAHistorySample? {
        guard let selectedSampleDate else { return nil }
        return plottedSamples.min {
            abs($0.occurredAt.timeIntervalSince(selectedSampleDate))
                < abs($1.occurredAt.timeIntervalSince(selectedSampleDate))
        }
    }

    private var chartInterpolationMethod: InterpolationMethod {
        interpolationStyle == .smooth ? .catmullRom : .linear
    }

    private var valueDomain: ClosedRange<Double> {
        series.valueDomain(preferredRange: preferredRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            statistics

            Chart {
                ForEach(plottedSamples) { sample in
                    LineMark(
                        x: .value("Time", sample.occurredAt),
                        y: .value("Value", sample.value)
                    )
                    .interpolationMethod(chartInterpolationMethod)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(accentColor)

                    AreaMark(
                        x: .value("Time", sample.occurredAt),
                        yStart: .value("Baseline", valueDomain.lowerBound),
                        yEnd: .value("Value", sample.value)
                    )
                    .interpolationMethod(chartInterpolationMethod)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor.opacity(0.22), accentColor.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                if let selectedSample {
                    RuleMark(x: .value("Selected time", selectedSample.occurredAt))
                        .foregroundStyle(.secondary.opacity(0.72))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    PointMark(
                        x: .value("Selected time", selectedSample.occurredAt),
                        y: .value("Selected value", selectedSample.value)
                    )
                    .symbolSize(64)
                    .foregroundStyle(accentColor)
                }
            }
            .chartYScale(domain: valueDomain)
            .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 0))
            .chartPlotStyle { $0.clipped() }
            .chartXAxis { xAxisMarks }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $selectedSampleDate)
            .frame(height: layout.chartHeight)
            .accessibilityChartDescriptor(
                EntityNumericHistoryChartDescriptor(series: series, valueDomain: valueDomain)
            )
            .accessibilityLabel("\(series.displayName) history")
            .accessibilityValue(series.summaryText)
            .sensoryFeedback(.selection, trigger: selectedSample?.occurredAt)
            .onChange(of: selectedSample) { _, sample in
                onSelectionChange(sample.map {
                    EntityHistorySelection(
                        occurredAt: $0.occurredAt,
                        formattedValue: series.formatValue($0.value)
                    )
                })
            }

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

    private var statistics: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                statisticRows
            } else {
                ViewThatFits(in: .horizontal) {
                    statisticColumns
                    statisticRows
                }
            }
        }
        .padding(.vertical, AppSpacing.small)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var statisticColumns: some View {
        HStack(spacing: 0) {
            statistic(title: "Minimum", value: series.minimumValue)
            Divider().padding(.vertical, 3)
            statistic(title: "Average", value: series.averageValue, emphasized: true)
            Divider().padding(.vertical, 3)
            statistic(title: "Maximum", value: series.maximumValue)
        }
    }

    private var statisticRows: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            statisticRow(title: "Minimum", value: series.minimumValue)
            statisticRow(title: "Average", value: series.averageValue, emphasized: true)
            statisticRow(title: "Maximum", value: series.maximumValue)
        }
    }

    private func statistic(title: String, value: Double?, emphasized: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.map(series.formatValue) ?? "--")
                .font(.subheadline.monospacedDigit().weight(emphasized ? .semibold : .medium))
                .foregroundStyle(emphasized ? accentColor : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func statisticRow(title: String, value: Double?, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.map(series.formatValue) ?? "--")
                .monospacedDigit()
                .foregroundStyle(emphasized ? accentColor : .primary)
        }
        .font(.subheadline.weight(emphasized ? .semibold : .regular))
        .padding(.horizontal, AppSpacing.medium)
    }

    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        switch selectedRange {
        case .oneHour:
            AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                AxisGridLine()
                AxisValueLabel(
                    format: .dateTime.hour().minute(),
                    anchor: .trailing,
                    collisionResolution: .greedy
                )
            }
        case .sixHours:
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour(), anchor: .trailing, collisionResolution: .greedy)
            }
        case .day:
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour(), anchor: .trailing, collisionResolution: .greedy)
            }
        case .week:
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(
                    format: .dateTime.weekday(.abbreviated),
                    anchor: .trailing,
                    collisionResolution: .greedy
                )
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(
                    format: .dateTime.month(.abbreviated).day(),
                    anchor: .trailing,
                    collisionResolution: .greedy
                )
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
            "Through \(date.formatted(date: .abbreviated, time: .omitted))"
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
