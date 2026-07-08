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
        .configurationDisplayName("Homestead Sensor")
        .description("Show a Home Assistant sensor reading, trend, or gauge.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadSensorGraphWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Sensor"
    static var description = IntentDescription("Choose a Home Assistant sensor.")

    @Parameter(title: "Sensor")
    var sensor: HomesteadSensorEntity?

    @Parameter(title: "Display")
    var display: HomesteadSensorWidgetDisplay?
}

enum HomesteadSensorWidgetDisplay: String, AppEnum {
    case reading
    case trend
    case circularGauge
    case barGauge

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [HomesteadSensorWidgetDisplay: DisplayRepresentation] = [
        .reading: "Reading",
        .trend: "Trend",
        .circularGauge: "Gauge - Circular",
        .barGauge: "Gauge - Bar"
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
    let areaName: String?
    let deviceName: String?
    let isNumeric: Bool
    let isAlerting: Bool
    let isAvailable: Bool
    let hasGauge: Bool
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

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
            fallback: "Sensors"
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
                isNumeric ? "numeric sensor" : nil,
                hasGauge ? "gauge" : nil,
                areaName,
                deviceName,
                id
            ]
        )
    }
}

struct HomesteadSensorEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    typealias Result = IntentItemCollection<HomesteadSensorEntity>

    func entities(for identifiers: [HomesteadSensorEntity.ID]) async throws -> [HomesteadSensorEntity] {
        flatEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HomesteadSensorEntity> {
        collection(from: flatEntities().filter { $0.matches(string) })
    }

    func allEntities() async throws -> IntentItemCollection<HomesteadSensorEntity> {
        collection(from: flatEntities())
    }

    func suggestedEntities() async throws -> IntentItemCollection<HomesteadSensorEntity> {
        try await allEntities()
    }

    func defaultResult() async -> HomesteadSensorEntity? {
        nil
    }

    private func flatEntities() -> [HomesteadSensorEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots.map(Self.entity)
    }

    private func collection(from entities: [HomesteadSensorEntity]) -> IntentItemCollection<HomesteadSensorEntity> {
        HomesteadWidgetEntityPickerText.collection(
            from: entities,
            groupedBy: \.pickerGroupTitle,
            sortedBy: \.pickerDisplayName
        )
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadSensorEntity {
        HomesteadSensorEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            subtitle: snapshot.subtitle,
            systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
            unit: snapshot.unit,
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName,
            isNumeric: snapshot.isNumeric == true,
            isAlerting: snapshot.isAlerting,
            isAvailable: snapshot.isAvailable,
            hasGauge: snapshot.gauge != nil,
            icon: snapshot.resolvedIcon
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
    let display: HomesteadSensorWidgetDisplay
    let samples: [HAWidgetHistorySample]
    let valueDomain: ClosedRange<Double>
    let summaryText: String
    let isAlerting: Bool
    let isAvailable: Bool
    let isConfigured: Bool
    var icon: ResolvedIcon? = nil
    var gauge: WidgetGaugePresentation? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var shouldShowTrend: Bool {
        display == .trend
    }

    var shouldShowCircularGauge: Bool {
        display == .circularGauge && gauge != nil
    }

    var shouldShowBarGauge: Bool {
        display == .barGauge && gauge != nil
    }
}

struct HomesteadSensorGraphTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSensorGraphEntry {
        HomesteadSensorGraphEntry(
            date: Date(),
            entityID: "sensor.living_room_temperature",
            displayName: "Living Room",
            valueText: "72°F",
            subtitle: "Temperature",
            systemImage: "thermometer.medium",
            display: .circularGauge,
            samples: Self.placeholderSamples(),
            valueDomain: 67...74,
            summaryText: "Low 68°F • High 73°F",
            isAlerting: false,
            isAvailable: true,
            isConfigured: true,
            gauge: .previewTemperature
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
        let display = configuration.display ?? .trend
        let configuredSensor = configuration.sensor
        let latestConfiguredSnapshot = configuredSensor.flatMap { sensor in
            HomesteadWidgetSharedStore.sensorSnapshot(entityID: sensor.id)
        }
        let selectedSensor = latestConfiguredSnapshot.map(Self.entity) ?? configuredSensor

        guard let selectedSensor else {
            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose Sensor",
                valueText: "Open Homestead",
                subtitle: "",
                systemImage: "gauge.medium",
                display: display,
                samples: [],
                valueDomain: 0...1,
                summaryText: "",
                isAlerting: false,
                isAvailable: false,
                isConfigured: false
            )
        }

        let cachedGauge = latestConfiguredSnapshot?.gauge

        if display == .trend {
            return await trendEntry(for: selectedSensor, cachedGauge: cachedGauge)
        }

        return await stateEntry(for: selectedSensor, display: display, cachedGauge: cachedGauge)
    }

    private func trendEntry(
        for selectedSensor: HomesteadSensorEntity,
        cachedGauge: WidgetGaugePresentation?
    ) async -> HomesteadSensorGraphEntry {
        guard selectedSensor.isNumeric else {
            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: selectedSensor.displayName,
                valueText: selectedSensor.valueText,
                subtitle: selectedSensor.subtitle,
                systemImage: selectedSensor.systemImage,
                display: .reading,
                samples: [],
                valueDomain: 0...1,
                summaryText: "",
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                icon: selectedSensor.resolvedIcon,
                gauge: cachedGauge
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
                display: .trend,
                samples: series.samples,
                valueDomain: series.valueDomain,
                summaryText: series.summaryText,
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                icon: selectedSensor.resolvedIcon,
                gauge: cachedGauge
            )
        } catch {
            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: selectedSensor.displayName,
                valueText: selectedSensor.valueText,
                subtitle: "Needs connection",
                systemImage: selectedSensor.systemImage,
                display: .trend,
                samples: [],
                valueDomain: 0...1,
                summaryText: "Needs connection",
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                icon: selectedSensor.resolvedIcon,
                gauge: cachedGauge
            )
        }
    }

    private func stateEntry(
        for selectedSensor: HomesteadSensorEntity,
        display: HomesteadSensorWidgetDisplay,
        cachedGauge: WidgetGaugePresentation?
    ) async -> HomesteadSensorGraphEntry {
        do {
            let state = try await HAWidgetActionClient().fetchSensorState(entityID: selectedSensor.id)
            let liveGauge = state.numericValue.flatMap { value in
                cachedGauge?.updating(value: value, valueText: state.valueText)
            } ?? cachedGauge

            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: state.entityID,
                displayName: state.displayName,
                valueText: state.valueText,
                subtitle: state.subtitle,
                systemImage: state.systemImage,
                display: display,
                samples: [],
                valueDomain: 0...1,
                summaryText: "",
                isAlerting: state.isAlerting,
                isAvailable: state.isAvailable,
                isConfigured: true,
                icon: state.icon,
                gauge: liveGauge
            )
        } catch {
            return HomesteadSensorGraphEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: selectedSensor.displayName,
                valueText: selectedSensor.valueText,
                subtitle: "Needs connection",
                systemImage: selectedSensor.systemImage,
                display: display,
                samples: [],
                valueDomain: 0...1,
                summaryText: "",
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                icon: selectedSensor.resolvedIcon,
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
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName,
            isNumeric: snapshot.isNumeric == true,
            isAlerting: snapshot.isAlerting,
            isAvailable: snapshot.isAvailable,
            hasGauge: snapshot.gauge != nil,
            icon: snapshot.resolvedIcon
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
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
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
        } else if entry.shouldShowCircularGauge, let gauge = entry.gauge {
            HomesteadSensorCircularGaugeWidgetView(entry: entry, gauge: gauge)
        } else if entry.shouldShowBarGauge, let gauge = entry.gauge {
            HomesteadSensorBarGaugeWidgetView(entry: entry, gauge: gauge, isMedium: false)
        } else if entry.shouldShowTrend {
            trendSmall
        } else {
            sensorReading
        }
    }

    @ViewBuilder
    private var systemMedium: some View {
        if !entry.isConfigured {
            unconfigured
        } else if entry.shouldShowBarGauge, let gauge = entry.gauge {
            HomesteadSensorBarGaugeWidgetView(entry: entry, gauge: gauge, isMedium: true)
        } else if entry.shouldShowCircularGauge, let gauge = entry.gauge {
            mediumCircularGauge(gauge)
        } else if entry.shouldShowTrend {
            trendMedium
        } else {
            mediumReading
        }
    }

    private var trendSmall: some View {
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

    private var trendMedium: some View {
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

    private var sensorReading: some View {
        HomesteadWidgetSmallTile(
            title: entry.displayName,
            value: entry.valueText,
            supportingText: entry.subtitle,
            valueColor: sensorValueColor,
            valueFont: .title2.weight(.semibold)
        ) {
            sensorIcon(size: 44, pointSize: 22, cornerRadius: 14)
        }
    }

    private var mediumReading: some View {
        HStack(alignment: .center, spacing: 16) {
            sensorIcon(size: 52, pointSize: 25, cornerRadius: 16)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(entry.valueText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(sensorValueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func mediumCircularGauge(_ gauge: WidgetGaugePresentation) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                header

                Spacer(minLength: 0)

                Text(gauge.valueText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor(for: gauge.status))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .monospacedDigit()

                Text(gauge.statusDisplayText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(for: gauge.status))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 122, alignment: .leading)

            WidgetGaugeArcView(gauge: gauge)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gauge.accessibilityLabel)
        .accessibilityValue(gauge.accessibilityValue)
    }

    private var accessoryCircular: some View {
        sensorIcon(size: 44, pointSize: 22, cornerRadius: 14)
    }

    private var accessoryRectangular: some View {
        HomesteadWidgetRectangularTile(
            title: entry.displayName,
            value: entry.valueText
        ) {
            HomesteadIconView(icon: entry.resolvedIcon, pointSize: 16)
                .foregroundStyle(sensorValueColor)
        }
    }

    private var unconfigured: some View {
        HomesteadWidgetSmallTile(
            title: entry.displayName,
            value: entry.valueText,
            valueColor: .secondary
        ) {
            sensorIcon(size: 44, pointSize: 22, cornerRadius: 14)
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            sensorIcon(size: 24, pointSize: 13, cornerRadius: 7, background: AnyShapeStyle(.fill.tertiary))

            Text(entry.displayName)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private func sensorIcon(
        size: CGFloat,
        pointSize: CGFloat,
        cornerRadius: CGFloat,
        background: AnyShapeStyle = AnyShapeStyle(.thinMaterial)
    ) -> some View {
        HomesteadWidgetIconBadge(
            content: .resolved(entry.resolvedIcon),
            color: sensorValueColor,
            pointSize: pointSize,
            size: size,
            cornerRadius: cornerRadius,
            background: background
        )
    }

    private var graph: some View {
        HomesteadWidgetLineChart(
            samples: entry.samples,
            valueDomain: entry.valueDomain,
            accentColor: sensorValueColor
        )
    }

    private var sensorValueColor: Color {
        if entry.isAlerting {
            return .red
        }

        return entry.isAvailable ? .blue : .secondary
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

private struct HomesteadSensorCircularGaugeWidgetView: View {
    let entry: HomesteadSensorGraphEntry
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

private struct HomesteadSensorBarGaugeWidgetView: View {
    let entry: HomesteadSensorGraphEntry
    let gauge: WidgetGaugePresentation
    let isMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 10 : 8) {
            HStack(alignment: .top, spacing: 8) {
                HomesteadWidgetIconBadge(
                    content: .resolved(entry.resolvedIcon),
                    color: statusColor(for: gauge.status),
                    pointSize: isMedium ? 16 : 13,
                    size: isMedium ? 30 : 24,
                    cornerRadius: isMedium ? 9 : 7,
                    background: AnyShapeStyle(.fill.tertiary)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.headline)
                        .lineLimit(isMedium ? 1 : 2)
                        .minimumScaleFactor(0.78)

                    Text(gauge.statusDisplayText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusColor(for: gauge.status))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Text(gauge.valueText)
                .font(.system(size: isMedium ? 36 : 27, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor(for: gauge.status))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .monospacedDigit()

            WidgetGaugeBarView(gauge: gauge)
                .frame(height: isMedium ? 22 : 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gauge.accessibilityLabel)
        .accessibilityValue(gauge.accessibilityValue)
    }
}

private struct WidgetGaugeBarView: View {
    let gauge: WidgetGaugePresentation

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { proxy in
                let fillWidth = max(proxy.size.width * CGFloat(gauge.normalizedValue), 4)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.fill.quaternary)

                    ForEach(Array(gauge.sections.enumerated()), id: \.offset) { _, section in
                        let segment = visualSegment(for: section)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(statusColor(for: section.status).opacity(sectionBackgroundOpacity(for: section.status)))
                            .frame(width: max(proxy.size.width * CGFloat(segment.width), 0))
                            .offset(x: proxy.size.width * CGFloat(segment.start))
                    }

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(statusColor(for: gauge.status))
                        .frame(width: fillWidth)
                }
            }

            HStack {
                Text(rangeText(gauge.lowerBound))
                Spacer(minLength: 8)
                Text(rangeText(gauge.upperBound))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private func visualSegment(for section: WidgetGaugeSection) -> (start: Double, width: Double) {
        let start = normalized(section.lowerBound)
        let end = normalized(section.upperBound)
        return (start, max(end - start, 0))
    }

    private func normalized(_ value: Double) -> Double {
        guard gauge.upperBound > gauge.lowerBound else { return 0 }
        let normalizedValue = (value - gauge.lowerBound) / (gauge.upperBound - gauge.lowerBound)
        return min(max(normalizedValue, 0), 1)
    }

    private func sectionBackgroundOpacity(for status: WidgetGaugeStatus) -> Double {
        status == gauge.status ? 0.28 : 0.14
    }

    private func rangeText(_ value: Double) -> String {
        widgetGaugeRangeFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
    HomesteadSensorGraphWidget()
} timeline: {
    HomesteadSensorGraphEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "Temperature",
        systemImage: "thermometer.medium",
        display: .circularGauge,
        samples: [],
        valueDomain: 67...74,
        summaryText: "",
        isAlerting: false,
        isAvailable: true,
        isConfigured: true,
        gauge: .previewTemperature
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
        display: .trend,
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
        isAlerting: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadSensorGraphWidget()
} timeline: {
    HomesteadSensorGraphEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "Temperature",
        systemImage: "thermometer.medium",
        display: .reading,
        samples: [],
        valueDomain: 67...74,
        summaryText: "",
        isAlerting: false,
        isAvailable: true,
        isConfigured: true,
        gauge: .previewTemperature
    )
}
