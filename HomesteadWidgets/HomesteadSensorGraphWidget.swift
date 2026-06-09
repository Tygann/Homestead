import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadSensorGraphWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadSensorGraphWidget",
            intent: HomesteadSensorGraphWidgetConfigurationIntent.self,
            provider: HomesteadSensorGraphTimelineProvider()
        ) { entry in
            HomesteadSensorGraphWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Sensor Graph")
        .description("Show a 6-hour Home Assistant sensor trend on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HomesteadSensorGraphWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Sensor Graph"
    static var description = IntentDescription("Choose a numeric Home Assistant sensor.")

    @Parameter(title: "Sensor")
    var sensor: HomesteadGraphSensorEntity?
}

struct HomesteadGraphSensorEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sensor")
    static var defaultQuery = HomesteadGraphSensorEntityQuery()

    let id: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let unit: String?
    let areaName: String?
    let deviceName: String?
    let isAvailable: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(pickerDisplayName)",
            image: DisplayRepresentation.Image(systemName: systemImage)
        )
    }

    var pickerDisplayName: String {
        HomesteadWidgetEntityPickerText.contextualDisplayName(
            displayName,
            areaName: areaName,
            deviceName: deviceName
        )
    }

    var pickerGroupTitle: String {
        HomesteadWidgetEntityPickerText.groupName(
            areaName: areaName,
            deviceName: deviceName,
            fallback: "Numeric Sensors"
        )
    }

    func matches(_ query: String) -> Bool {
        HomesteadWidgetEntityPickerText.matches(
            query: query,
            values: [
                displayName,
                pickerDisplayName,
                valueText,
                subtitle,
                "sensor",
                "Numeric Sensor",
                areaName,
                deviceName,
                id
            ]
        )
    }
}

struct HomesteadGraphSensorEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    typealias Result = IntentItemCollection<HomesteadGraphSensorEntity>

    func entities(for identifiers: [HomesteadGraphSensorEntity.ID]) async throws -> [HomesteadGraphSensorEntity] {
        flatEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HomesteadGraphSensorEntity> {
        collection(from: flatEntities().filter { $0.matches(string) })
    }

    func allEntities() async throws -> IntentItemCollection<HomesteadGraphSensorEntity> {
        collection(from: flatEntities())
    }

    func suggestedEntities() async throws -> IntentItemCollection<HomesteadGraphSensorEntity> {
        try await allEntities()
    }

    func defaultResult() async -> HomesteadGraphSensorEntity? {
        nil
    }

    private func flatEntities() -> [HomesteadGraphSensorEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots
            .filter { $0.isNumeric == true }
            .map(Self.entity)
    }

    private func collection(from entities: [HomesteadGraphSensorEntity]) -> IntentItemCollection<HomesteadGraphSensorEntity> {
        HomesteadWidgetEntityPickerText.collection(
            from: entities,
            groupedBy: \.pickerGroupTitle,
            sortedBy: \.pickerDisplayName
        )
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadGraphSensorEntity {
        HomesteadGraphSensorEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            subtitle: snapshot.subtitle,
            systemImage: snapshot.systemImage,
            unit: snapshot.unit,
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName,
            isAvailable: snapshot.isAvailable
        )
    }
}

struct HomesteadSensorGraphEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let samples: [HAWidgetHistorySample]
    let valueDomain: ClosedRange<Double>
    let summaryText: String
    let isAvailable: Bool
    let isConfigured: Bool
}

struct HomesteadSensorGraphTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSensorGraphEntry {
        HomesteadSensorGraphEntry(
            date: Date(),
            entityID: "sensor.living_room_temperature",
            displayName: "Living Room",
            valueText: "72°F",
            subtitle: "6H Trend",
            systemImage: "thermometer.medium",
            samples: Self.placeholderSamples(),
            valueDomain: 67...74,
            summaryText: "Low 68°F • High 73°F",
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadSensorGraphWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadSensorGraphEntry {
        if context.isPreview, configuration.sensor == nil {
            return placeholder(in: context)
        }

        return await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadSensorGraphWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSensorGraphEntry> {
        if context.isPreview, configuration.sensor == nil {
            return Timeline(
                entries: [placeholder(in: context)],
                policy: .after(Date().addingTimeInterval(30 * 60))
            )
        }

        return Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(30 * 60))
        )
    }

    private func entry(for configuration: HomesteadSensorGraphWidgetConfigurationIntent) async -> HomesteadSensorGraphEntry {
        let configuredSensor = configuration.sensor
        let latestConfiguredSnapshot = configuredSensor.flatMap { sensor in
            HomesteadWidgetSharedStore.sensorSnapshot(entityID: sensor.id)
        }
        let selectedSensor = latestConfiguredSnapshot.flatMap(Self.entity) ?? configuredSensor

        guard let selectedSensor else {
            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose Sensor",
                valueText: "Open Homestead",
                subtitle: "",
                systemImage: "chart.xyaxis.line",
                samples: [],
                valueDomain: 0...1,
                summaryText: "",
                isAvailable: false,
                isConfigured: false
            )
        }

        do {
            let series = try await HAWidgetActionClient().fetchSensorHistory(
                entityID: selectedSensor.id,
                displayName: selectedSensor.displayName,
                unit: selectedSensor.unit
            )
            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: series.displayName,
                valueText: series.latestValueText ?? selectedSensor.valueText,
                subtitle: "6H Trend",
                systemImage: selectedSensor.systemImage,
                samples: series.samples,
                valueDomain: series.valueDomain,
                summaryText: series.summaryText,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true
            )
        } catch {
            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: selectedSensor.displayName,
                valueText: selectedSensor.valueText,
                subtitle: "Needs connection",
                systemImage: selectedSensor.systemImage,
                samples: [],
                valueDomain: 0...1,
                summaryText: "Needs connection",
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true
            )
        }
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadGraphSensorEntity? {
        guard snapshot.isNumeric == true else {
            return nil
        }

        return HomesteadGraphSensorEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            subtitle: snapshot.subtitle,
            systemImage: snapshot.systemImage,
            unit: snapshot.unit,
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName,
            isAvailable: snapshot.isAvailable
        )
    }

    private static func placeholderSamples() -> [HAWidgetHistorySample] {
        let now = Date()
        return [
            HAWidgetHistorySample(occurredAt: now.addingTimeInterval(-6 * 60 * 60), value: 68),
            HAWidgetHistorySample(occurredAt: now.addingTimeInterval(-5 * 60 * 60), value: 69.5),
            HAWidgetHistorySample(occurredAt: now.addingTimeInterval(-4 * 60 * 60), value: 69),
            HAWidgetHistorySample(occurredAt: now.addingTimeInterval(-3 * 60 * 60), value: 71),
            HAWidgetHistorySample(occurredAt: now.addingTimeInterval(-2 * 60 * 60), value: 73),
            HAWidgetHistorySample(occurredAt: now.addingTimeInterval(-60 * 60), value: 71.4),
            HAWidgetHistorySample(occurredAt: now, value: 72)
        ]
    }
}

struct HomesteadSensorGraphWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadSensorGraphEntry

    var body: some View {
        switch family {
        case .systemMedium:
            systemMedium
        default:
            systemSmall
        }
    }

    @ViewBuilder
    private var systemSmall: some View {
        if !entry.isConfigured {
            unconfigured
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header

                Text(entry.valueText)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                graph
                    .frame(height: 44)

                if let supportingText {
                    footerText(supportingText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var systemMedium: some View {
        if !entry.isConfigured {
            unconfigured
        } else {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    header

                    Spacer(minLength: 0)

                    Text(entry.valueText)
                        .font(.title.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    if let supportingText {
                        footerText(supportingText)
                    }
                }
                .frame(width: 118, alignment: .leading)

                graph
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var unconfigured: some View {
        VStack(alignment: .leading, spacing: 10) {
            graphIcon

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.valueText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 7) {
            graphIcon

            Text(entry.displayName)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var graphIcon: some View {
        Image(systemName: entry.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.isAvailable ? .blue : .secondary)
            .frame(width: 24, height: 24)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var graph: some View {
        HomesteadWidgetLineChart(
            samples: entry.samples,
            valueDomain: entry.valueDomain,
            accentColor: entry.isAvailable ? .blue : .secondary
        )
    }

    private var supportingText: String? {
        guard entry.isConfigured else {
            return entry.subtitle
        }

        if entry.samples.isEmpty {
            let trimmedSubtitle = entry.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSubtitle.isEmpty, trimmedSubtitle != "6H Trend" else {
                return nil
            }

            return trimmedSubtitle
        }

        return family == .systemMedium ? entry.summaryText : nil
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(family == .systemMedium ? 2 : 1)
            .minimumScaleFactor(0.8)
    }
}

struct HomesteadWidgetLineChart: View {
    let samples: [HAWidgetHistorySample]
    let valueDomain: ClosedRange<Double>
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.fill.quaternary)

                if samples.count < 2 {
                    VStack(spacing: 5) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.caption.weight(.semibold))
                        Text("No History")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    chartFillPath(in: proxy.size)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.22), accentColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    chartPath(in: proxy.size)
                        .stroke(
                            accentColor,
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
    }

    private func chartPath(in size: CGSize) -> Path {
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

    private func chartFillPath(in size: CGSize) -> Path {
        Path { path in
            let resolvedPoints = points(in: size)
            guard let first = resolvedPoints.first,
                  let last = resolvedPoints.last else {
                return
            }

            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            resolvedPoints.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard samples.count >= 2,
              let startDate = samples.first?.occurredAt,
              let endDate = samples.last?.occurredAt,
              endDate > startDate else {
            return []
        }

        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 8
        let drawableWidth = max(size.width - (horizontalPadding * 2), 1)
        let drawableHeight = max(size.height - (verticalPadding * 2), 1)
        let range = max(valueDomain.upperBound - valueDomain.lowerBound, 1)
        let duration = endDate.timeIntervalSince(startDate)

        return samples.map { sample in
            let xRatio = sample.occurredAt.timeIntervalSince(startDate) / duration
            let yRatio = (sample.value - valueDomain.lowerBound) / range
            return CGPoint(
                x: horizontalPadding + (drawableWidth * CGFloat(xRatio)),
                y: verticalPadding + (drawableHeight * CGFloat(1 - yRatio))
            )
        }
    }
}

#Preview(as: .systemSmall) {
    HomesteadSensorGraphWidget()
} timeline: {
    HomesteadSensorGraphEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "6H Trend",
        systemImage: "thermometer.medium",
        samples: [
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-6 * 60 * 60), value: 68),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-5 * 60 * 60), value: 69.5),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-4 * 60 * 60), value: 69),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-3 * 60 * 60), value: 71),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-2 * 60 * 60), value: 73),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-60 * 60), value: 71.4),
            HAWidgetHistorySample(occurredAt: .now, value: 72)
        ],
        valueDomain: 67...74,
        summaryText: "Low 68°F • High 73°F",
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .systemMedium) {
    HomesteadSensorGraphWidget()
} timeline: {
    HomesteadSensorGraphEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "6H Trend",
        systemImage: "thermometer.medium",
        samples: [
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-6 * 60 * 60), value: 68),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-5 * 60 * 60), value: 69.5),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-4 * 60 * 60), value: 69),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-3 * 60 * 60), value: 71),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-2 * 60 * 60), value: 73),
            HAWidgetHistorySample(occurredAt: .now.addingTimeInterval(-60 * 60), value: 71.4),
            HAWidgetHistorySample(occurredAt: .now, value: 72)
        ],
        valueDomain: 67...74,
        summaryText: "Low 68°F • High 73°F",
        isAvailable: true,
        isConfigured: true
    )
}
