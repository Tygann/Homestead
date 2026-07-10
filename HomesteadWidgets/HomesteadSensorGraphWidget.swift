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

    @Parameter(title: "Gauge Minimum")
    var gaugeMinimum: Double?

    @Parameter(title: "Low Critical Upper Bound")
    var gaugeLowCriticalUpperBound: Double?

    @Parameter(title: "Low Warning Upper Bound")
    var gaugeLowWarningUpperBound: Double?

    @Parameter(title: "Comfortable Upper Bound")
    var gaugeComfortableUpperBound: Double?

    @Parameter(title: "High Warning Upper Bound")
    var gaugeHighWarningUpperBound: Double?

    @Parameter(title: "Gauge Maximum")
    var gaugeMaximum: Double?
}

enum HomesteadSensorWidgetDisplay: String, AppEnum {
    case reading
    case trend
    case circularGauge
    case segmentedGauge
    case barGauge

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [HomesteadSensorWidgetDisplay: DisplayRepresentation] = [
        .reading: "Reading",
        .trend: "Trend",
        .circularGauge: "Gauge - Circular",
        .segmentedGauge: "Gauge - Segmented",
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

    var gaugeIcon: ResolvedIcon {
        guard let gauge else {
            return resolvedIcon
        }
        return gaugeDisplayIcon(base: resolvedIcon, value: gauge.value, status: gauge.status.visualStatus)
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

    var shouldShowSegmentedGauge: Bool {
        display == .segmentedGauge && gauge != nil
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

        let cachedGauge = latestConfiguredSnapshot?.gauge.map {
            resolvedGauge($0, display: display, configuration: configuration)
        }

        if display == .trend {
            return await trendEntry(for: selectedSensor, cachedGauge: cachedGauge)
        }

        return await stateEntry(for: selectedSensor, display: display, cachedGauge: cachedGauge)
    }

    private func resolvedGauge(
        _ gauge: WidgetGaugePresentation,
        display: HomesteadSensorWidgetDisplay,
        configuration: HomesteadSensorGraphWidgetConfigurationIntent
    ) -> WidgetGaugePresentation {
        guard [.circularGauge, .segmentedGauge, .barGauge].contains(display) else { return gauge }
        let overrides = [
            configuration.gaugeMinimum,
            configuration.gaugeLowCriticalUpperBound,
            configuration.gaugeLowWarningUpperBound,
            configuration.gaugeComfortableUpperBound,
            configuration.gaugeHighWarningUpperBound,
            configuration.gaugeMaximum
        ]
        guard overrides.contains(where: { $0 != nil }) else { return gauge }

        let defaults = gauge.fiveZoneValues
        return gauge.applyingFiveZoneConfiguration(
            lowerBound: configuration.gaugeMinimum ?? defaults[0],
            boundaries: [
                configuration.gaugeLowCriticalUpperBound ?? defaults[1],
                configuration.gaugeLowWarningUpperBound ?? defaults[2],
                configuration.gaugeComfortableUpperBound ?? defaults[3],
                configuration.gaugeHighWarningUpperBound ?? defaults[4]
            ],
            upperBound: configuration.gaugeMaximum ?? defaults[5]
        )
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
        } else if entry.shouldShowSegmentedGauge, let gauge = entry.gauge {
            HomesteadSensorCircularGaugeWidgetView(entry: entry, gauge: gauge, style: .segmented)
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
        } else if entry.shouldShowSegmentedGauge, let gauge = entry.gauge {
            mediumCircularGauge(gauge, style: .segmented)
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

    private func mediumCircularGauge(
        _ gauge: WidgetGaugePresentation,
        style: WidgetGaugeInstrumentStyle = .standard
    ) -> some View {
        WidgetGaugeInstrumentView(
            gauge: gauge,
            tint: widgetGaugeStatusColor(for: gauge.status),
            title: entry.displayName,
            icon: entry.resolvedIcon,
            style: style
        )
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
    var style: WidgetGaugeInstrumentStyle = .standard

    var body: some View {
        WidgetGaugeInstrumentView(
            gauge: gauge,
            tint: entry.isAvailable ? widgetGaugeStatusColor(for: gauge.status) : .secondary,
            title: entry.displayName,
            icon: entry.gaugeIcon,
            style: style
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct HomesteadSensorBarGaugeWidgetView: View {
    let entry: HomesteadSensorGraphEntry
    let gauge: WidgetGaugePresentation
    let isMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 10 : 8) {
            HStack(alignment: .top, spacing: GaugeVisualMetrics.compactHeaderSpacing) {
                HomesteadWidgetIconBadge(
                    content: .resolved(entry.gaugeIcon),
                    color: widgetGaugeStatusColor(for: gauge.status),
                    pointSize: GaugeVisualMetrics.compactHeaderIconPointSize,
                    size: GaugeVisualMetrics.compactHeaderIconSize,
                    cornerRadius: GaugeVisualMetrics.compactHeaderIconCornerRadius,
                    background: AnyShapeStyle(.fill.tertiary)
                )

                VStack(alignment: .leading, spacing: GaugeVisualMetrics.compactHeaderTextSpacing) {
                    Text(entry.displayName)
                        .font(GaugeVisualMetrics.compactHeaderTitleFont)
                        .lineLimit(1)
                        .minimumScaleFactor(GaugeVisualMetrics.compactHeaderTitleMinimumScale)

                    Text(gauge.statusDisplayText)
                        .font(GaugeVisualMetrics.compactHeaderStatusFont)
                        .foregroundStyle(widgetGaugeStatusColor(for: gauge.status))
                        .lineLimit(1)
                        .minimumScaleFactor(GaugeVisualMetrics.compactHeaderStatusMinimumScale)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            gaugeReadout

            WidgetGaugeBarView(gauge: gauge)
                .frame(height: GaugeVisualMetrics.barTotalHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gauge.accessibilityLabel)
        .accessibilityValue(gauge.accessibilityValue)
    }

    private var gaugeReadout: some View {
        let fontSize: CGFloat = isMedium ? 36 : 27
        let parts = gaugeValueParts(from: gauge.valueText, unitText: gauge.unitText)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.value)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))

            if let unit = parts.unit {
                Text(unit)
                    .font(.system(size: fontSize * 0.52, weight: .bold, design: .rounded))
                    .baselineOffset(fontSize * 0.08)
                    .padding(.leading, -1)
            }
        }
        .foregroundStyle(widgetGaugeStatusColor(for: gauge.status))
        .lineLimit(1)
        .minimumScaleFactor(0.58)
        .monospacedDigit()
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
