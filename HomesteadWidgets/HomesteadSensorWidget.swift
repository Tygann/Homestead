import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadSensorWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadSensorWidget",
            intent: HomesteadSensorWidgetConfigurationIntent.self,
            provider: HomesteadSensorTimelineProvider()
        ) { entry in
            HomesteadSensorWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Sensor")
        .description("Show a Home Assistant sensor on your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadSensorWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Sensor"
    static var description = IntentDescription("Choose a Home Assistant sensor.")

    @Parameter(title: "Sensor")
    var sensor: HomesteadSensorEntity?

    @Parameter(title: "Display")
    var displayStyle: HomesteadSensorWidgetDisplayStyle?
}

enum HomesteadSensorWidgetDisplayStyle: String, AppEnum {
    case reading
    case gauge

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [HomesteadSensorWidgetDisplayStyle: DisplayRepresentation] = [
        .reading: "Reading",
        .gauge: "Gauge"
    ]
}

struct HomesteadSensorEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sensor")
    static var defaultQuery = HomesteadSensorEntityQuery()

    let id: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let unit: String?
    let isNumeric: Bool
    let isAlerting: Bool
    let isAvailable: Bool
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadSensorEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadSensorEntity.ID]) async throws -> [HomesteadSensorEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadSensorEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadSensorEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadSensorEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots.map { snapshot in
            HomesteadSensorEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                valueText: snapshot.valueText,
                subtitle: snapshot.subtitle,
                systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
                unit: snapshot.unit,
                isNumeric: snapshot.isNumeric == true,
                isAlerting: snapshot.isAlerting,
                isAvailable: snapshot.isAvailable,
                icon: snapshot.resolvedIcon
            )
        }
    }
}

struct HomesteadSensorEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let isAlerting: Bool
    let isAvailable: Bool
    let isConfigured: Bool
    let displayStyle: HomesteadSensorWidgetDisplayStyle
    var icon: ResolvedIcon? = nil
    var gauge: WidgetGaugePresentation? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var shouldShowGauge: Bool {
        displayStyle == .gauge && gauge != nil
    }
}

struct HomesteadSensorTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSensorEntry {
        HomesteadSensorEntry(
            date: Date(),
            entityID: "sensor.living_room_temperature",
            displayName: "Living Room",
            valueText: "72°F",
            subtitle: "Temperature",
            systemImage: "thermometer.medium",
            isAlerting: false,
            isAvailable: true,
            isConfigured: true,
            displayStyle: .gauge,
            gauge: .previewTemperature
        )
    }

    func snapshot(
        for configuration: HomesteadSensorWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadSensorEntry {
        await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadSensorWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSensorEntry> {
        Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    private func entry(for configuration: HomesteadSensorWidgetConfigurationIntent) async -> HomesteadSensorEntry {
        let displayStyle = configuration.displayStyle ?? .reading
        let configuredSensor = configuration.sensor
        let latestConfiguredSnapshot = configuredSensor.flatMap { sensor in
            HomesteadWidgetSharedStore.sensorSnapshot(entityID: sensor.id)
        }
        let fallbackSnapshot = HomesteadWidgetSharedStore.sensorSnapshots.first
        let selectedSnapshot = latestConfiguredSnapshot ?? (configuredSensor == nil ? fallbackSnapshot : nil)
        let selectedSensor = selectedSnapshot.map(Self.entity) ?? configuredSensor

        guard let selectedSensor else {
            return HomesteadSensorEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose a Sensor",
                valueText: "--",
                subtitle: "Open Homestead first",
                systemImage: "gauge.medium",
                isAlerting: false,
                isAvailable: false,
                isConfigured: false,
                displayStyle: displayStyle
            )
        }

        let cachedGauge = selectedSnapshot?.gauge
        do {
            let state = try await HAWidgetActionClient().fetchSensorState(entityID: selectedSensor.id)
            let liveGauge = state.numericValue.flatMap { value in
                cachedGauge?.updating(value: value, valueText: state.valueText)
            } ?? cachedGauge

            return HomesteadSensorEntry(
                date: Date(),
                entityID: state.entityID,
                displayName: state.displayName,
                valueText: state.valueText,
                subtitle: state.subtitle,
                systemImage: state.systemImage,
                isAlerting: state.isAlerting,
                isAvailable: state.isAvailable,
                isConfigured: true,
                displayStyle: displayStyle,
                icon: state.icon,
                gauge: liveGauge
            )
        } catch {
            return HomesteadSensorEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: selectedSensor.displayName,
                valueText: selectedSensor.valueText,
                subtitle: "Needs connection",
                systemImage: selectedSensor.systemImage,
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                displayStyle: displayStyle,
                icon: selectedSensor.icon,
                gauge: cachedGauge
            )
        }
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadSensorEntity {
        HomesteadSensorEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            subtitle: snapshot.subtitle,
            systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
            unit: snapshot.unit,
            isNumeric: snapshot.isNumeric == true,
            isAlerting: snapshot.isAlerting,
            isAvailable: snapshot.isAvailable,
            icon: snapshot.resolvedIcon
        )
    }
}

struct HomesteadSensorWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadSensorEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        default:
            systemSmall
        }
    }

    @ViewBuilder
    private var systemSmall: some View {
        if entry.shouldShowGauge, let gauge = entry.gauge {
            HomesteadSensorGaugeWidgetView(entry: entry, gauge: gauge)
        } else {
            sensorReading
        }
    }

    private var sensorReading: some View {
        VStack(alignment: .leading, spacing: 10) {
            sensorIcon

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.valueText)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryCircular: some View {
        sensorIcon
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            HomesteadIconView(icon: entry.resolvedIcon, pointSize: 16)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.valueText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var sensorIcon: some View {
        HomesteadIconView(icon: entry.resolvedIcon, pointSize: 22)
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconColor: Color {
        if entry.isAlerting {
            return .red
        }

        return entry.isAvailable ? .blue : .secondary
    }
}

private struct HomesteadSensorGaugeWidgetView: View {
    let entry: HomesteadSensorEntry
    let gauge: WidgetGaugePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 4)

                Text(gauge.statusDisplayText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor(for: gauge.status))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)

            WidgetGaugeArcView(gauge: gauge)
                .frame(maxWidth: .infinity)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(gauge.valueText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor(for: gauge.status))
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                    .monospacedDigit()

                Spacer(minLength: 4)

                Text(entry.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gauge.accessibilityLabel)
        .accessibilityValue(gauge.accessibilityValue)
    }
}

private struct WidgetGaugeArcView: View {
    let gauge: WidgetGaugePresentation

    private let lineWidth: CGFloat = 11
    private let arcHeight: CGFloat = 58
    private let markerHeight: CGFloat = 11
    private let sectionGap: Double = 0.018
    private let horizontalScale: CGFloat = 1.18

    var body: some View {
        GeometryReader { proxy in
            let maxArcWidth = max((arcHeight - lineWidth) * 2 * horizontalScale, 0)
            let arcWidth = min(max(proxy.size.width - lineWidth, 0), maxArcWidth)

            VStack(spacing: 1) {
                ZStack {
                    ForEach(Array(gauge.sections.enumerated()), id: \.offset) { index, section in
                        let segment = visualSegment(for: section, at: index)

                        WidgetGaugeArcShape(
                            start: segment.start,
                            end: segment.end,
                            inset: lineWidth / 2,
                            horizontalScale: horizontalScale
                        )
                        .stroke(
                            statusColor(for: section.status).opacity(sectionBackgroundOpacity(for: section.status)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }

                    if gauge.normalizedValue > 0 {
                        WidgetGaugeArcShape(
                            start: 0,
                            end: gauge.normalizedValue,
                            inset: lineWidth / 2,
                            horizontalScale: horizontalScale
                        )
                        .stroke(
                            statusColor(for: gauge.status),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .frame(width: arcWidth, height: arcHeight)

                ZStack {
                    Text(rangeText(gauge.lowerBound))
                        .position(x: lineWidth / 2, y: markerHeight / 2)

                    Text(rangeText(gauge.upperBound))
                        .position(x: arcWidth - lineWidth / 2, y: markerHeight / 2)
                }
                .frame(width: arcWidth, height: markerHeight)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: arcHeight + markerHeight + 1)
    }

    private func visualSegment(
        for section: WidgetGaugeSection,
        at index: Int
    ) -> (start: Double, end: Double) {
        let rawStart = normalized(section.lowerBound)
        let rawEnd = normalized(section.upperBound)
        let start = index == 0 ? rawStart : rawStart + (sectionGap / 2)
        let end = index == gauge.sections.indices.last ? rawEnd : rawEnd - (sectionGap / 2)

        return (min(max(start, 0), 1), min(max(end, start), 1))
    }

    private func normalized(_ value: Double) -> Double {
        guard gauge.upperBound > gauge.lowerBound else { return 0 }
        let normalizedValue = (value - gauge.lowerBound) / (gauge.upperBound - gauge.lowerBound)
        return min(max(normalizedValue, 0), 1)
    }

    private func sectionBackgroundOpacity(for status: WidgetGaugeStatus) -> Double {
        switch gauge.status {
        case .nominal:
            status == .nominal ? 0.18 : 0.10
        case .low, .high, .warning, .critical:
            status == gauge.status ? 0.28 : 0.16
        }
    }

    private func rangeText(_ value: Double) -> String {
        widgetGaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct WidgetGaugeArcShape: Shape {
    let start: Double
    let end: Double
    let inset: CGFloat
    let horizontalScale: CGFloat

    func path(in rect: CGRect) -> Path {
        let normalizedStart = min(max(start, 0), 1)
        let normalizedEnd = min(max(end, normalizedStart), 1)
        let radius = max((rect.height - inset) / 2, 0)
        let scaledRadius = radius * horizontalScale
        let center = CGPoint(x: rect.midX, y: rect.maxY - inset)
        let startAngle = Angle.degrees(180 + normalizedStart * 180)
        let endAngle = Angle.degrees(180 + normalizedEnd * 180)

        var path = Path()
        path.addArc(
            center: center,
            radius: scaledRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

private func statusColor(for status: WidgetGaugeStatus) -> Color {
    switch status {
    case .nominal:
        .green
    case .low:
        .blue
    case .high:
        .orange
    case .warning:
        .yellow
    case .critical:
        .red
    }
}

private let widgetGaugeRangeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 0
    return formatter
}()

private extension WidgetGaugePresentation {
    static let previewTemperature = WidgetGaugePresentation(
        value: 72,
        lowerBound: 0,
        upperBound: 120,
        valueText: "72°F",
        unitText: "°F",
        status: .nominal,
        statusDisplayText: "Comfortable",
        sections: [
            WidgetGaugeSection(lowerBound: 0, upperBound: 40, status: .warning),
            WidgetGaugeSection(lowerBound: 40, upperBound: 60, status: .low),
            WidgetGaugeSection(lowerBound: 60, upperBound: 80, status: .nominal),
            WidgetGaugeSection(lowerBound: 80, upperBound: 100, status: .high),
            WidgetGaugeSection(lowerBound: 100, upperBound: 120, status: .warning)
        ],
        accessibilityLabel: "Living Room gauge",
        accessibilityValue: "72°F"
    )
}

#Preview(as: .systemSmall) {
    HomesteadSensorWidget()
} timeline: {
    HomesteadSensorEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "Temperature",
        systemImage: "thermometer.medium",
        isAlerting: false,
        isAvailable: true,
        isConfigured: true,
        displayStyle: .gauge,
        gauge: .previewTemperature
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadSensorWidget()
} timeline: {
    HomesteadSensorEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "Temperature",
        systemImage: "thermometer.medium",
        isAlerting: false,
        isAvailable: true,
        isConfigured: true,
        displayStyle: .reading
    )
}
