import Charts
import SwiftUI

struct SensorDetailView: View {
    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedHistoryRange: HAHistoryRangePreset = .day
    @State private var historyPhase: SensorHistoryPhase = .idle
    @State private var timelinePhase: SensorTimelinePhase = .idle

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            header
            currentReading
            if supportsHistory {
                historyPanel
            }
            if supportsTimeline {
                timelinePanel
            }
            detailMetrics
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
            iconName: presentation.iconName,
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
            Text(primaryValue)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                        historyUnavailableView("No numeric history for \(selectedHistoryRange.accessibilityTitle.lowercased()).")
                    } else {
                        historyChart(series)
                    }
                case .failed:
                    historyUnavailableView("History unavailable")
                }
            }
        }
    }

    private var historyRangePicker: some View {
        rangePicker(isLoading: historyPhase.isLoading, refreshAccessibilityLabel: "Refresh history") {
            Task { await refreshHistory() }
        }
    }

    private var timelineRangePicker: some View {
        rangePicker(isLoading: timelinePhase.isLoading, refreshAccessibilityLabel: "Refresh activity") {
            Task { await refreshTimeline() }
        }
    }

    private func rangePicker(
        isLoading: Bool,
        refreshAccessibilityLabel: String,
        refreshAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AppSpacing.small) {
            ForEach(HAHistoryRangePreset.allCases) { range in
                EntityDetailPillButton(
                    title: range.title,
                    isSelected: selectedHistoryRange == range,
                    isDisabled: isLoading,
                    tint: presentation.accentColor
                ) {
                    selectedHistoryRange = range
                }
                .accessibilityLabel(range.accessibilityTitle)
            }

            Button {
                refreshAction()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(Color(.tertiarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel(refreshAccessibilityLabel)
        }
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
            Chart(series.samples) { sample in
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
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
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
                    Text(latestSample.occurredAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func historyUnavailableView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 132)
                .overlay {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var timelinePanel: some View {
        EntityControlPanel(title: "Recent Activity", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                timelineRangePicker

                switch timelinePhase {
                case .idle, .loading:
                    timelineLoadingView
                case .loaded(let timeline):
                    if timeline.isEmpty {
                        timelineUnavailableView(timeline.summaryText)
                    } else {
                        timelineList(timeline)
                    }
                case .failed:
                    timelineUnavailableView("Activity unavailable")
                }
            }
        }
    }

    private var timelineLoadingView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 132)
                .overlay {
                    ProgressView()
                }

            Text("Loading activity")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func timelineList(_ timeline: HAHistoryTimeline) -> some View {
        let entries = Array(timeline.entries.suffix(8).reversed())

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    timelineRow(entry, showsConnector: index < entries.count - 1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                Text(timeline.summaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: AppSpacing.small)

                if timeline.entries.count > entries.count {
                    Text("+\(timeline.entries.count - entries.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(timeline.displayName) activity")
        .accessibilityValue(timeline.summaryText)
    }

    private func timelineRow(_ entry: HAHistoryTimelineEntry, showsConnector: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: entry.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(timelineToneColor(entry.tone))
                    .frame(width: 28, height: 28)
                    .background(timelineToneColor(entry.tone).opacity(0.12), in: Circle())

                if showsConnector {
                    Rectangle()
                        .fill(Color(.tertiaryLabel).opacity(0.3))
                        .frame(width: 2, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, showsConnector ? AppSpacing.small : 0)

            Spacer(minLength: AppSpacing.small)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title), \(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))")
    }

    private func timelineUnavailableView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 112)
                .overlay {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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
        switch entity.domain {
        case .binarySensor:
            "Binary Sensor"
        case .sensor:
            "Sensor"
        default:
            "Entity"
        }
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

    private func timelineToneColor(_ tone: HAHistoryTimelineTone) -> Color {
        switch tone {
        case .active:
            presentation.accentColor
        case .inactive:
            .secondary
        case .unavailable:
            .red
        }
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
        } catch {
            timelinePhase = .failed
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

private enum SensorTimelinePhase: Equatable {
    case idle
    case loading
    case loaded(HAHistoryTimeline)
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

#Preview("Binary Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "binary_sensor.front_door") {
        SensorDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
