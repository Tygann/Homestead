import Charts
import SwiftUI

struct SensorDetailView: View {
    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedHistoryRange: HAHistoryRangePreset = .day
    @State private var historyPhase: SensorHistoryPhase = .idle
    @State private var timelinePhase: EntityHistoryTimelinePhase = .idle

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    @MainActor
    private var heroPresentation: SensorDetailHeroPresentation? {
        entityBox.sensorEntity.map(SensorDetailHeroPresentation.init)
    }

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            if entity.domain == .sensor {
                sensorHero
            } else {
                header
                currentReading
            }
            if supportsHistory {
                historyPanel
            }
            if supportsTimeline {
                timelinePanel
            }
            if entity.domain != .sensor {
                detailMetrics
            }
            contextDetails
        }
        .task(id: historyTaskID) {
            await refreshHistory()
        }
        .task(id: timelineTaskID) {
            await refreshTimeline()
        }
    }

    private var header: some View {
        EntityDetailHeader(
            icon: presentation.icon,
            title: presentation.title,
            subtitle: presentation.subtitle,
            badge: statusBadgeText,
            iconColor: iconColor,
            badgeColor: statusColor,
            iconBackground: iconBackground,
            badgeBackground: statusBackground
        )
    }

    private var currentReading: some View {
        EntityControlPanel(title: "Current Reading", systemImage: "gauge.medium") {
            if let gauge = entityBox.sensorEntity?.gaugePresentation {
                GaugePresentationView(
                    presentation: gauge,
                    style: .detail,
                    tint: presentation.accentColor
                )
            } else {
                Text(primaryValue)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var sensorHero: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: heroPresentation?.category ?? "Sensor",
            subtitle: sensorFreshnessText,
            status: heroPresentation?.statusText,
            iconColor: sensorHeroColor
        ) {
            if let gauge = entityBox.sensorEntity?.gaugePresentation {
                GaugePresentationView(
                    presentation: gauge,
                    style: .detail,
                    tint: presentation.accentColor,
                    icon: presentation.icon
                )
            } else {
                Text(primaryValue)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var sensorFreshnessText: Text? {
        if entity.isAvailable, let lastUpdated = entity.lastUpdated {
            return Text("Updated \(lastUpdated, style: .relative)")
        }

        return nil
    }

    private var detailMetrics: some View {
        DashboardEntityContextPanel(
            title: "Reading",
            systemImage: "waveform.path.ecg",
            rows: readingRows
        )
    }

    private var readingRows: [EntityMetadataRow] {
        var rows = [EntityMetadataRow(title: "State", value: primaryValue)]

        if let sensor = entityBox.sensorEntity {
            if let valueText = nonEmpty(sensor.valueText), valueText != sensor.formattedValue {
                rows.append(EntityMetadataRow(title: "Value", value: valueText))
            }

            if let unit = sensor.unitText {
                rows.append(EntityMetadataRow(title: "Unit", value: unit))
            }

            if let deviceClass = sensor.formattedDeviceClass {
                rows.append(EntityMetadataRow(title: "Type", value: deviceClass))
            }
        } else if entity.domain == .binarySensor {
            rows.append(EntityMetadataRow(title: "Type", value: "Binary Sensor"))
        }

        return rows
    }

    private var historyPanel: some View {
        EntityControlPanel(title: "History", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                historyRangePicker

                switch historyPhase {
                case .idle, .loading:
                    historyLoadingView
                case .loaded(let series):
                    if series.isEmpty {
                        historyUnavailableView(
                            "No history for \(selectedHistoryRange.accessibilityTitle.lowercased()).",
                            showsRetry: false
                        )
                    } else {
                        historyChart(series)
                    }
                case .failed:
                    historyUnavailableView("History unavailable", showsRetry: true)
                }
            }
        }
    }

    private var historyRangePicker: some View {
        Picker("History range", selection: $selectedHistoryRange) {
            ForEach(HAHistoryRangePreset.sensorChartPresets) { range in
                Text(range.title)
                    .tag(range)
                    .accessibilityLabel(range.accessibilityTitle)
            }
        }
        .pickerStyle(.segmented)
        .disabled(historyPhase.isLoading)
        .accessibilityLabel("History range")
    }

    private var historyLoadingView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 160)
                .overlay {
                    ProgressView()
                }

            Text("Loading history")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func historyChart(_ series: HAHistoryChartSeries) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Chart(series.chartSamples()) { sample in
                LineMark(
                    x: .value("Time", sample.occurredAt),
                    y: .value("Value", sample.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(presentation.accentColor)

                AreaMark(
                    x: .value("Time", sample.occurredAt),
                    yStart: .value("Baseline", series.valueDomain.lowerBound),
                    yEnd: .value("Value", sample.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            presentation.accentColor.opacity(0.22),
                            presentation.accentColor.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: series.valueDomain)
            .chartPlotStyle { plotArea in
                plotArea.clipped()
            }
            .chartXAxis {
                switch selectedHistoryRange {
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
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
            .clipped()
            .accessibilityLabel("\(series.displayName) history")
            .accessibilityValue(series.summaryText)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                Text(series.summaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: AppSpacing.small)

                if let latestSample = series.latestSample {
                    Text(latestSampleDateText(latestSample.occurredAt))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if selectedHistoryRange == .month {
                Text("Shows available Home Assistant history.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func latestSampleDateText(_ date: Date) -> String {
        switch selectedHistoryRange {
        case .oneHour, .sixHours, .day:
            return date.formatted(date: .omitted, time: .shortened)
        case .week, .month:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private func historyUnavailableView(_ message: String, showsRetry: Bool) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.small)

            if showsRetry {
                Button("Retry") {
                    Task { await refreshHistory() }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(historyPhase.isLoading)
            }
        }
        .padding(AppSpacing.medium)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
    }

    private var timelinePanel: some View {
        EntityHistoryTimelinePanel(
            selectedRange: $selectedHistoryRange,
            phase: timelinePhase,
            tint: presentation.accentColor
        ) {
            Task { await refreshTimeline() }
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: contextRows
        )
    }

    private var contextRows: [EntityMetadataRow] {
        var rows = [
            EntityMetadataRow(title: "Entity ID", value: entity.entityID),
            EntityMetadataRow(title: "Domain", value: entity.domain.displayName)
        ]

        if let lastUpdated = entity.lastUpdated {
            rows.append(EntityMetadataRow(title: "Last Updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened)))
        }

        return rows
    }

    private var navigationTitle: String {
        presentation.title
    }

    private var primaryValue: String {
        if let sensor = entityBox.sensorEntity {
            return sensor.formattedValue
        }

        return binarySensorStateText
    }

    private var supportsHistory: Bool {
        entity.domain == .sensor && entityBox.sensorEntity?.numericValue != nil
    }

    private var supportsTimeline: Bool {
        entity.domain == .binarySensor
    }

    private var historyTaskID: String {
        guard supportsHistory else {
            return "history-disabled-\(entity.entityID)"
        }

        return "\(entity.entityID)-\(selectedHistoryRange.rawValue)"
    }

    private var timelineTaskID: String {
        guard supportsTimeline else {
            return "timeline-disabled-\(entity.entityID)"
        }

        return "\(entity.entityID)-\(selectedHistoryRange.rawValue)"
    }

    private var statusBadgeText: String {
        guard entity.isAvailable else { return "Unavailable" }

        if let sensor = entityBox.sensorEntity, sensor.isAlerting {
            return "Alert"
        }

        if entity.domain == .binarySensor {
            return entity.state == "on" ? "Detected" : "Clear"
        }

        return "Live"
    }

    private var sensorHeroColor: Color {
        guard entity.isAvailable else { return .red }
        guard let status = entityBox.sensorEntity?.gaugePresentation?.status else {
            return presentation.accentColor
        }
        return gaugeVisualStatusColor(for: status.visualStatus)
    }

    private var binarySensorStateText: String {
        guard entity.isAvailable else { return entity.state.displayStateText }

        switch entity.state {
        case "on":
            return "Detected"
        case "off":
            return "Clear"
        default:
            return entity.state.displayStateText
        }
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        return presentation.isActive ? presentation.accentColor : .secondary
    }

    private var statusColor: Color {
        guard entity.isAvailable else { return .red }
        return presentation.isActive ? presentation.accentColor : .primary
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var statusBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    @MainActor
    private func refreshHistory() async {
        guard supportsHistory else {
            historyPhase = .idle
            return
        }

        historyPhase = .loading
        let interval = selectedHistoryRange.interval()
        let request = HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: entity.entityID
        )

        do {
            historyPhase = .loaded(
                try await homeAssistantService.fetchHistory(
                    settings: connectionSettings,
                    request: request,
                    range: selectedHistoryRange
                )
            )
        } catch is CancellationError {
            return
        } catch {
            historyPhase = .failed
        }
    }

    @MainActor
    private func refreshTimeline() async {
        guard supportsTimeline else {
            timelinePhase = .idle
            return
        }

        timelinePhase = .loading
        let interval = selectedHistoryRange.interval()
        let request = HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: entity.entityID
        )

        do {
            timelinePhase = .loaded(
                try await homeAssistantService.fetchTimeline(
                    settings: connectionSettings,
                    request: request,
                    range: selectedHistoryRange
                )
            )
        } catch is CancellationError {
            return
        } catch {
            timelinePhase = .failed
        }
    }
}

struct SensorDetailHeroPresentation: Equatable, Sendable {
    let category: String
    let statusText: String?

    init(sensor: SensorEntity) {
        category = sensor.formattedDeviceClass ?? "Sensor"

        guard sensor.isAvailable else {
            statusText = "Unavailable"
            return
        }

        if let gauge = sensor.gaugePresentation, gauge.status != .nominal {
            statusText = gauge.statusDisplayText
        } else if sensor.isAlerting {
            statusText = "Alert"
        } else {
            statusText = nil
        }
    }
}

private enum SensorHistoryPhase: Equatable {
    case idle
    case loading
    case loaded(HAHistoryChartSeries)
    case failed

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

#if DEBUG
#Preview("Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "sensor.hallway_temperature") {
        SensorDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}

#Preview("Gauge Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "sensor.front_door_battery") {
        SensorDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}

#Preview("Binary Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "binary_sensor.front_door") {
        SensorDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
