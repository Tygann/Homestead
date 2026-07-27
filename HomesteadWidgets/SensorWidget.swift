import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadSensorChartWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: HomesteadWidgetKind.sensor.rawValue,
            intent: HomesteadSensorChartWidgetConfigurationIntent.self,
            provider: HomesteadSensorChartTimelineProvider()
        ) { entry in
            HomesteadSensorChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(SharedFeatureCatalog.widgetDescriptor(for: .sensor)!.displayName)
        .description(SharedFeatureCatalog.widgetDescriptor(for: .sensor)!.description)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct HomesteadSensorChartWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Sensor"
    static var description = IntentDescription("Choose a Home Assistant sensor.")

    @Parameter(title: "Sensor")
    var sensor: HomesteadSensorEntity?

    @Parameter(title: "Display Name")
    var customDisplayName: String?

    @Parameter(title: "Display")
    var display: HomesteadSensorWidgetDisplay?

    @Parameter(title: "Scale", default: .automatic)
    var gaugeScale: HomesteadGaugeScale

    @Parameter(title: "Minimum")
    var gaugeMinimum: Double?

    @Parameter(title: "Maximum")
    var gaugeMaximum: Double?

    @Parameter(title: "Zones", default: .automatic)
    var zoneCount: HomesteadGaugeZoneCount

    @Parameter(title: "Zone 1 Color", default: .blue)
    var zone1Color: HomesteadGaugeZoneColor

    @Parameter(title: "Zone 2 Begins At")
    var zone2BeginsAt: Double?

    @Parameter(title: "Zone 2 Color", default: .green)
    var zone2Color: HomesteadGaugeZoneColor

    @Parameter(title: "Zone 3 Begins At")
    var zone3BeginsAt: Double?

    @Parameter(title: "Zone 3 Color", default: .orange)
    var zone3Color: HomesteadGaugeZoneColor

    @Parameter(title: "Zone 4 Begins At")
    var zone4BeginsAt: Double?

    @Parameter(title: "Zone 4 Color", default: .red)
    var zone4Color: HomesteadGaugeZoneColor

    @Parameter(title: "Zone 5 Begins At")
    var zone5BeginsAt: Double?

    @Parameter(title: "Zone 5 Color", default: .purple)
    var zone5Color: HomesteadGaugeZoneColor

    static var parameterSummary: some ParameterSummary {
        When(
            \HomesteadSensorChartWidgetConfigurationIntent.$display,
            .oneOf,
            [HomesteadSensorWidgetDisplay.circularGauge, .segmentedGauge, .barGauge]
        ) {
            When(\.$gaugeScale, .equalTo, HomesteadGaugeScale.custom) {
                When(\.$zoneCount, .equalTo, HomesteadGaugeZoneCount.automatic) {
                    Summary {
                        \.$sensor
                        \.$customDisplayName
                        \.$display
                        \.$gaugeScale
                        \.$gaugeMinimum
                        \.$gaugeMaximum
                        \.$zoneCount
                    }
                } otherwise: {
                    Summary {
                        \.$sensor
                        \.$customDisplayName
                        \.$display
                        \.$gaugeScale
                        \.$gaugeMinimum
                        \.$gaugeMaximum
                        \.$zoneCount
                        \.$zone1Color
                        \.$zone2BeginsAt
                        \.$zone2Color
                        \.$zone3BeginsAt
                        \.$zone3Color
                        \.$zone4BeginsAt
                        \.$zone4Color
                        \.$zone5BeginsAt
                        \.$zone5Color
                    }
                }
            } otherwise: {
                When(\.$zoneCount, .equalTo, HomesteadGaugeZoneCount.automatic) {
                    Summary {
                        \.$sensor
                        \.$customDisplayName
                        \.$display
                        \.$gaugeScale
                        \.$zoneCount
                    }
                } otherwise: {
                    Summary {
                        \.$sensor
                        \.$customDisplayName
                        \.$display
                        \.$gaugeScale
                        \.$zoneCount
                        \.$zone1Color
                        \.$zone2BeginsAt
                        \.$zone2Color
                        \.$zone3BeginsAt
                        \.$zone3Color
                        \.$zone4BeginsAt
                        \.$zone4Color
                        \.$zone5BeginsAt
                        \.$zone5Color
                    }
                }
            }
        } otherwise: {
            Summary {
                \.$sensor
                \.$customDisplayName
                \.$display
            }
        }
    }

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
    var historyChartInterpolationStyle: HomesteadChartInterpolationStyle? = nil
    var chartAccentColor: WidgetGaugeColor? = nil

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
            icon: snapshot.resolvedIcon,
            historyChartInterpolationStyle: snapshot.historyChartInterpolationStyle,
            chartAccentColor: snapshot.chartAccentColor
        )
    }
}

struct HomesteadSensorChartEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let display: HomesteadSensorWidgetDisplay
    let samples: [HomesteadChartSample]
    let valueDomain: ClosedRange<Double>
    let summaryText: String
    let isAlerting: Bool
    let isAvailable: Bool
    let isConfigured: Bool
    var icon: ResolvedIcon? = nil
    var gauge: WidgetGaugePresentation? = nil
    var chartUnitText: String? = nil
    var chartInterpolationStyle: HomesteadChartInterpolationStyle = .linear
    var chartAccentColor: WidgetGaugeColor? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var gaugeIcon: ResolvedIcon {
        guard let gauge else {
            return resolvedIcon
        }
        return gaugeDisplayIcon(base: resolvedIcon, value: gauge.value, status: gauge.status.visualStatus)
    }

    var shouldShowChart: Bool {
        display == .chart
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

    var chartPresentation: HomesteadWidgetChartPresentation {
        HomesteadWidgetChartPresentation(
            title: displayName,
            valueText: valueText,
            unitText: chartUnitText,
            icon: resolvedIcon,
            isAvailable: isAvailable,
            samples: samples,
            valueDomain: valueDomain,
            interpolationStyle: chartInterpolationStyle,
            rangeTitle: "6H",
            changeSummaryText: nil,
            emptyLabel: subtitle == "Needs connection" ? "Chart unavailable" : "No recent chart"
        )
    }
}

struct HomesteadSensorChartTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSensorChartEntry {
        HomesteadSensorChartEntry(
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
        for configuration: HomesteadSensorChartWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadSensorChartEntry {
        if context.isPreview, configuration.sensor == nil {
            return placeholder(in: context)
        }

        return await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadSensorChartWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSensorChartEntry> {
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

    private func entry(for configuration: HomesteadSensorChartWidgetConfigurationIntent) async -> HomesteadSensorChartEntry {
        let gaugeConfiguration = configuration.gaugeWidgetConfiguration
        let display = gaugeConfiguration.display
        if !HomesteadWidgetPlusPolicy.allowsSensorDisplay(
            display,
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        ) {
            return HomesteadSensorChartEntry(
                date: Date(),
                entityID: nil,
                displayName: "Homestead+",
                valueText: "",
                subtitle: "",
                systemImage: "lock.fill",
                display: display,
                samples: [],
                valueDomain: 0...1,
                summaryText: "",
                isAlerting: false,
                isAvailable: false,
                isConfigured: true
            )
        }
        let configuredSensor = configuration.sensor
        let latestConfiguredSnapshot = configuredSensor.flatMap { sensor in
            HomesteadWidgetSharedStore.sensorSnapshot(entityID: sensor.id)
        }
        let selectedSensor = latestConfiguredSnapshot.map(Self.entity) ?? configuredSensor

        guard let selectedSensor else {
            return HomesteadSensorChartEntry(
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
            gaugeConfiguration.resolvedGauge($0)
        }
        let displayName = Self.resolvedDisplayName(
            configuration.customDisplayName,
            fallback: selectedSensor.displayName
        )

        if display == .chart {
            return await chartEntry(for: selectedSensor, displayName: displayName, cachedGauge: cachedGauge)
        }

        return await stateEntry(
            for: selectedSensor,
            displayName: displayName,
            display: display,
            cachedGauge: cachedGauge
        )
    }

    private func chartEntry(
        for selectedSensor: HomesteadSensorEntity,
        displayName: String,
        cachedGauge: WidgetGaugePresentation?
    ) async -> HomesteadSensorChartEntry {
        guard selectedSensor.isNumeric else {
            return HomesteadSensorChartEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: displayName,
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
            return HomesteadSensorChartEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: displayName,
                valueText: series.latestValueText ?? selectedSensor.valueText,
                subtitle: "6H Chart",
                systemImage: selectedSensor.systemImage,
                display: .chart,
                samples: series.samples.map { .init(occurredAt: $0.occurredAt, value: $0.value) },
                valueDomain: HomesteadChartDomain.stabilized(
                    values: series.samples.map(\.value),
                    unit: series.unit
                ),
                summaryText: series.summaryText,
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                icon: selectedSensor.resolvedIcon,
                gauge: cachedGauge,
                chartUnitText: series.unit,
                chartInterpolationStyle: selectedSensor.historyChartInterpolationStyle ?? .linear,
                chartAccentColor: selectedSensor.chartAccentColor
            )
        } catch {
            return HomesteadSensorChartEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: displayName,
                valueText: selectedSensor.valueText,
                subtitle: "Needs connection",
                systemImage: selectedSensor.systemImage,
                display: .chart,
                samples: [],
                valueDomain: 0...1,
                summaryText: "Needs connection",
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                icon: selectedSensor.resolvedIcon,
                gauge: cachedGauge,
                chartUnitText: selectedSensor.unit,
                chartInterpolationStyle: selectedSensor.historyChartInterpolationStyle ?? .linear,
                chartAccentColor: selectedSensor.chartAccentColor
            )
        }
    }

    private func stateEntry(
        for selectedSensor: HomesteadSensorEntity,
        displayName: String,
        display: HomesteadSensorWidgetDisplay,
        cachedGauge: WidgetGaugePresentation?
    ) async -> HomesteadSensorChartEntry {
        do {
            let state = try await HAWidgetActionClient().fetchSensorState(entityID: selectedSensor.id)
            let liveGauge = state.numericValue.flatMap { value in
                cachedGauge?.updating(value: value, valueText: state.valueText)
            } ?? cachedGauge

            return HomesteadSensorChartEntry(
                date: Date(),
                entityID: state.entityID,
                displayName: displayName,
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
            return HomesteadSensorChartEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: displayName,
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
            icon: snapshot.resolvedIcon,
            historyChartInterpolationStyle: snapshot.historyChartInterpolationStyle,
            chartAccentColor: snapshot.chartAccentColor
        )
    }

    private static func resolvedDisplayName(_ customDisplayName: String?, fallback: String) -> String {
        let trimmedName = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? fallback : trimmedName
    }

    private static func placeholderSamples() -> [HomesteadChartSample] {
        let now = Date()
        return [
            HomesteadChartSample(occurredAt: now.addingTimeInterval(-6 * 60 * 60), value: 68),
            HomesteadChartSample(occurredAt: now.addingTimeInterval(-5 * 60 * 60), value: 69.5),
            HomesteadChartSample(occurredAt: now.addingTimeInterval(-4 * 60 * 60), value: 69),
            HomesteadChartSample(occurredAt: now.addingTimeInterval(-3 * 60 * 60), value: 71),
            HomesteadChartSample(occurredAt: now.addingTimeInterval(-2 * 60 * 60), value: 73),
            HomesteadChartSample(occurredAt: now.addingTimeInterval(-60 * 60), value: 71.4),
            HomesteadChartSample(occurredAt: now, value: 72)
        ]
    }
}

struct HomesteadSensorChartWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadSensorChartEntry

    var body: some View {
        if requiresPlus {
            HomesteadPlusWidgetLockView()
        } else {
            deepLinkedContent {
                familyContent
            }
        }
    }

    private var requiresPlus: Bool {
        !HomesteadWidgetPlusPolicy.allowsSensorDisplay(
            entry.display,
            hasPlus: HomesteadWidgetPlusAccess.isGranted()
        )
    }

    @ViewBuilder
    private var familyContent: some View {
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
    private func deepLinkedContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let entityID = entry.entityID {
            content()
                .widgetURL(HomesteadWidgetDeepLink.entityURL(entityID: entityID))
        } else {
            content()
        }
    }

    @ViewBuilder
    private var systemSmall: some View {
        if entry.isConfigured, entry.shouldShowChart {
            chartFace(density: .small)
        } else {
            systemSmallInsetContent
                .padding(16)
        }
    }

    @ViewBuilder
    private var systemMedium: some View {
        if entry.isConfigured, entry.shouldShowChart {
            chartFace(density: .medium)
        } else {
            systemMediumInsetContent
                .padding(16)
        }
    }

    @ViewBuilder
    private var systemSmallInsetContent: some View {
        if !entry.isConfigured {
            unconfigured
        } else if entry.shouldShowCircularGauge, let gauge = entry.gauge {
            HomesteadSensorCircularGaugeWidgetView(entry: entry, gauge: gauge)
        } else if entry.shouldShowSegmentedGauge, let gauge = entry.gauge {
            HomesteadSensorCircularGaugeWidgetView(entry: entry, gauge: gauge, style: .segmented)
        } else if entry.shouldShowBarGauge, let gauge = entry.gauge {
            HomesteadSensorBarGaugeWidgetView(entry: entry, gauge: gauge, isMedium: false)
        } else {
            sensorReading
        }
    }

    @ViewBuilder
    private var systemMediumInsetContent: some View {
        if !entry.isConfigured {
            unconfigured
        } else if entry.shouldShowBarGauge, let gauge = entry.gauge {
            HomesteadSensorBarGaugeWidgetView(entry: entry, gauge: gauge, isMedium: true)
        } else if entry.shouldShowSegmentedGauge, let gauge = entry.gauge {
            mediumCircularGauge(gauge, style: .segmented)
        } else if entry.shouldShowCircularGauge, let gauge = entry.gauge {
            mediumCircularGauge(gauge)
        } else {
            mediumReading
        }
    }

    private func chartFace(density: HomesteadWidgetChartDensity) -> some View {
        HomesteadWidgetChartFace(
            presentation: entry.chartPresentation,
            accentColor: chartAccentColor,
            density: density
        )
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
            tint: widgetGaugeColor(for: gauge.currentColor),
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

    private var sensorValueColor: Color {
        if entry.isAlerting {
            return .red
        }

        return entry.isAvailable ? .blue : .secondary
    }

    private var chartAccentColor: Color {
        guard entry.isAvailable else { return .secondary }
        guard let chartAccentColor = entry.chartAccentColor else { return sensorValueColor }
        return widgetGaugeColor(for: chartAccentColor)
    }

}

private struct HomesteadSensorCircularGaugeWidgetView: View {
    let entry: HomesteadSensorChartEntry
    let gauge: WidgetGaugePresentation
    var style: WidgetGaugeInstrumentStyle = .standard

    var body: some View {
        WidgetGaugeInstrumentView(
            gauge: gauge,
            tint: entry.isAvailable ? widgetGaugeColor(for: gauge.currentColor) : .secondary,
            title: entry.displayName,
            icon: entry.gaugeIcon,
            style: style
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct HomesteadSensorBarGaugeWidgetView: View {
    let entry: HomesteadSensorChartEntry
    let gauge: WidgetGaugePresentation
    let isMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 10 : 8) {
            HStack(alignment: .top, spacing: GaugeVisualMetrics.compactHeaderSpacing) {
                HomesteadWidgetIconBadge(
                    content: .resolved(entry.gaugeIcon),
                    color: widgetGaugeColor(for: gauge.currentColor),
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
        .foregroundStyle(widgetGaugeColor(for: gauge.currentColor))
        .lineLimit(1)
        .minimumScaleFactor(0.58)
        .monospacedDigit()
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
            WidgetGaugeSection(lowerBound: 0, upperBound: 40, color: .orange),
            WidgetGaugeSection(lowerBound: 40, upperBound: 60, color: .blue),
            WidgetGaugeSection(lowerBound: 60, upperBound: 80, color: .green),
            WidgetGaugeSection(lowerBound: 80, upperBound: 100, color: .orange),
            WidgetGaugeSection(lowerBound: 100, upperBound: 120, color: .orange)
        ],
        accessibilityLabel: "Living Room gauge",
        accessibilityValue: "72°F"
    )
}

#Preview(as: .systemSmall) {
    HomesteadSensorChartWidget()
} timeline: {
    HomesteadSensorChartEntry(
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
    HomesteadSensorChartWidget()
} timeline: {
    HomesteadSensorChartEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "6H Chart",
        systemImage: "thermometer.medium",
        display: .chart,
        samples: [
            HomesteadChartSample(occurredAt: .now.addingTimeInterval(-6 * 60 * 60), value: 68),
            HomesteadChartSample(occurredAt: .now.addingTimeInterval(-5 * 60 * 60), value: 69.5),
            HomesteadChartSample(occurredAt: .now.addingTimeInterval(-4 * 60 * 60), value: 69),
            HomesteadChartSample(occurredAt: .now.addingTimeInterval(-3 * 60 * 60), value: 71),
            HomesteadChartSample(occurredAt: .now.addingTimeInterval(-2 * 60 * 60), value: 73),
            HomesteadChartSample(occurredAt: .now.addingTimeInterval(-60 * 60), value: 71.4),
            HomesteadChartSample(occurredAt: .now, value: 72)
        ],
        valueDomain: 67...74,
        summaryText: "Low 68°F • High 73°F",
        isAlerting: false,
        isAvailable: true,
        isConfigured: true,
        chartUnitText: "°F",
        chartInterpolationStyle: .smooth
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadSensorChartWidget()
} timeline: {
    HomesteadSensorChartEntry(
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
