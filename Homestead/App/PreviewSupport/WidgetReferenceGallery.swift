#if DEBUG
import SwiftUI
import WidgetKit

struct WidgetReferenceGallery: View {
    private let dashboardWidth: CGFloat = 180
    private let widgetSide: CGFloat = 169
    private let widgetCornerRadius: CGFloat = 36
    private let widgetPadding: CGFloat = 16
    private let gauge = WidgetGaugePresentation.previewLowBattery
    private let segmentedGauge = WidgetGaugePresentation(
        value: 56,
        lowerBound: 0,
        upperBound: 100,
        valueText: "56",
        unitText: "%",
        status: .nominal,
        statusDisplayText: "Comfortable",
        sections: [
            WidgetGaugeSection(lowerBound: 0, upperBound: 20, color: .red),
            WidgetGaugeSection(lowerBound: 20, upperBound: 30, color: .orange),
            WidgetGaugeSection(lowerBound: 30, upperBound: 60, color: .green),
            WidgetGaugeSection(lowerBound: 60, upperBound: 70, color: .orange),
            WidgetGaugeSection(lowerBound: 70, upperBound: 100, color: .red)
        ],
        accessibilityLabel: "Living Room Humidity gauge",
        accessibilityValue: "56%, comfortable"
    )
    private let sensorBoardTemperatureGauge = WidgetGaugePresentation(
        value: 76.6,
        lowerBound: 70,
        upperBound: 86,
        valueText: "76.6°F",
        unitText: "°F",
        status: .nominal,
        statusDisplayText: "Comfortable",
        sections: [
            WidgetGaugeSection(lowerBound: 70, upperBound: 72, color: .red),
            WidgetGaugeSection(lowerBound: 72, upperBound: 84, color: .green),
            WidgetGaugeSection(lowerBound: 84, upperBound: 86, color: .red)
        ],
        accessibilityLabel: "Temperature gauge",
        accessibilityValue: "76.6°F, comfortable"
    )
    private let baseIcon = IconResolver.resolveEntity(
        EntityIconResolutionInput(domain: "sensor", deviceClass: "battery", state: "18")
    )

    private var gaugeIcon: ResolvedIcon {
        gaugeDisplayIcon(base: baseIcon, value: gauge.value, status: gauge.status.visualStatus)
    }

    private var segmentedGaugeIcon: ResolvedIcon {
        IconResolver.resolveEntity(
            EntityIconResolutionInput(domain: "sensor", deviceClass: "humidity", state: "56")
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    plusLockPreviews
                    largeSensorBoardPreview
                    sensorBoardPreview
                    mediumSensorPreview
                    coreWidgetPreviews
                    configurationStatePreviews
                    accessoryWidgetPreviews
                    chartComparisonRow
                    circularComparisonRow
                    segmentedComparisonRow
                    barComparisonRow
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Widgets")
        }
    }

    // MARK: - Widget Families

    private var plusLockPreviews: some View {
        referenceSection("Homestead+ Locked") {
            HStack(alignment: .top, spacing: 12) {
                systemWidget("Advanced Sensor") {
                    HomesteadPlusWidgetLockView(previewFamily: .systemSmall)
                }
                systemWidget("Sensor Board") {
                    HomesteadPlusWidgetLockView(previewFamily: .systemSmall)
                }
            }
        }
    }

    private var coreWidgetPreviews: some View {
        referenceSection("Core Widgets") {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    systemWidget("Control") {
                        smallReferenceFace(
                            title: "Bed Lamp",
                            value: showsUnavailableBoard ? "Unavailable" : "On • 50%",
                            icon: "lightbulb.fill",
                            color: showsUnavailableBoard ? .secondary : .yellow
                        )
                    }
                    systemWidget("Status") {
                        smallReferenceFace(
                            title: "Living Room",
                            value: showsUnavailableBoard ? "—" : "72°F",
                            supportingText: showsUnavailableBoard ? "Unavailable" : nil,
                            icon: "thermometer.medium",
                            color: showsUnavailableBoard ? .secondary : .blue
                        )
                    }
                    systemWidget("Sensor") {
                        HomesteadWidgetChartFace(
                            presentation: sensorChartPresentation,
                            accentColor: showsUnavailableBoard ? .secondary : .orange,
                            density: .small
                        )
                    }
                    systemWidget("Action") {
                        smallReferenceFace(
                            title: "Movie Time",
                            icon: "play.circle.fill",
                            color: .purple,
                            titleLineLimit: 3
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var mediumSensorPreview: some View {
        referenceSection("Medium Sensor") {
            HomesteadWidgetChartFace(
                presentation: sensorChartPresentation,
                accentColor: showsUnavailableBoard ? .secondary : .orange,
                density: .medium
            )
            .frame(width: 360, height: 169)
            .background(
                .fill.tertiary,
                in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous))
        }
    }

    private var configurationStatePreviews: some View {
        referenceSection("Configuration States") {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    systemWidget("Control") {
                        smallReferenceFace(
                            title: "Choose Control",
                            value: "Open Homestead",
                            icon: "switch.2",
                            color: .secondary
                        )
                    }
                    systemWidget("Status") {
                        smallReferenceFace(
                            title: "Choose Status",
                            value: "Open Homestead",
                            icon: "gauge.medium",
                            color: .secondary
                        )
                    }
                    systemWidget("Sensor") {
                        smallReferenceFace(
                            title: "Choose Sensor",
                            value: "Open Homestead",
                            icon: "thermometer.medium",
                            color: .secondary
                        )
                    }
                    systemWidget("Action") {
                        smallReferenceFace(
                            title: "Choose Action",
                            supportingText: "Open Homestead",
                            icon: "sparkles",
                            color: .secondary
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var accessoryWidgetPreviews: some View {
        referenceSection("Accessories") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    accessoryRectangular {
                        rectangularReferenceFace(
                            title: "Bed Lamp",
                            value: showsUnavailableBoard ? "Unavailable" : "On • 50%",
                            icon: "lightbulb.fill",
                            color: showsUnavailableBoard ? .secondary : .yellow
                        )
                    }
                    accessoryRectangular {
                        rectangularReferenceFace(
                            title: "Living Room",
                            value: showsUnavailableBoard ? "—" : "72°F",
                            icon: "thermometer.medium",
                            color: showsUnavailableBoard ? .secondary : .blue
                        )
                    }
                }

                HStack(spacing: 12) {
                    accessoryRectangular {
                        rectangularReferenceFace(
                            title: "Hallway",
                            value: showsUnavailableBoard ? "—" : "72°F",
                            icon: "thermometer.medium",
                            color: showsUnavailableBoard ? .secondary : .orange
                        )
                    }
                    accessoryRectangular {
                        rectangularReferenceFace(
                            title: "Movie Time",
                            value: nil,
                            icon: "play.circle.fill",
                            color: .purple
                        )
                    }
                }

                HStack(spacing: 18) {
                    accessoryCircular {
                        iconBadge("lightbulb.fill", color: showsUnavailableBoard ? .secondary : .yellow)
                    }
                    accessoryCircular {
                        iconBadge("thermometer.medium", color: showsUnavailableBoard ? .secondary : .blue)
                    }
                    accessoryCircular {
                        iconBadge("thermometer.medium", color: showsUnavailableBoard ? .secondary : .orange)
                    }
                    accessoryCircular {
                        iconBadge("play.circle.fill", color: .purple)
                    }
                }
            }
        }
    }

    private func referenceSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            content()
        }
    }

    private func systemWidget<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        previewColumn(title) {
            content()
                .padding(16)
                .frame(width: widgetSide, height: widgetSide)
                .background(
                    .fill.tertiary,
                    in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
                )
                .clipShape(RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous))
        }
    }

    private func accessoryRectangular<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .padding(.horizontal, 10)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func accessoryCircular<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: 62, height: 62)
            .background(.fill.quaternary, in: Circle())
    }

    private var sensorChartPresentation: HomesteadWidgetChartPresentation {
        let now = Date()
        let samples = showsUnavailableBoard ? [] : [70.8, 71.2, 71.1, 71.8, 72.0].enumerated().map {
            HomesteadChartSample(
                occurredAt: now.addingTimeInterval(Double($0.offset - 4) * 90 * 60),
                value: $0.element
            )
        }
        return HomesteadWidgetChartPresentation(
            title: "Hallway",
            valueText: showsUnavailableBoard ? "—" : "72°F",
            unitText: "°F",
            icon: .sfSymbol("thermometer.medium", provenance: .homesteadSemanticMapping),
            isAvailable: !showsUnavailableBoard,
            samples: samples,
            valueDomain: HomesteadChartDomain.stabilized(values: samples.map(\.value), unit: "°F"),
            interpolationStyle: .smooth,
            rangeTitle: "6H",
            changeSummaryText: nil,
            emptyLabel: showsUnavailableBoard ? "Chart unavailable" : "No recent chart"
        )
    }

    private func smallReferenceFace(
        title: String,
        value: String? = nil,
        supportingText: String? = nil,
        icon: String,
        color: Color,
        titleLineLimit: Int = 2
    ) -> some View {
        HomesteadWidgetSingleItemFace(
            family: .systemSmall,
            title: title,
            value: value,
            supportingText: supportingText,
            valueColor: color == .secondary ? .secondary : .primary,
            titleLineLimit: titleLineLimit
        ) {
            iconBadge(icon, color: color)
        }
    }

    private func rectangularReferenceFace(
        title: String,
        value: String?,
        icon: String,
        color: Color
    ) -> some View {
        HomesteadWidgetSingleItemFace(
            family: .accessoryRectangular,
            title: title,
            value: value
        ) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func iconBadge(_ systemName: String, color: Color) -> some View {
        HomesteadWidgetIconBadge(content: .symbol(systemName), color: color)
    }

    private var chartComparisonRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Chart")
                .font(.headline)

            HStack(alignment: .top, spacing: 18) {
                previewColumn("Dashboard") {
                    DashboardCardView(
                        entityID: "sensor.hallway_temperature",
                        size: .square,
                        presentationKind: .chart,
                        isPreview: true
                    )
                    .frame(width: dashboardWidth)
                }

                previewColumn("Widget") {
                    HomesteadWidgetChartFace(
                        presentation: chartPresentation,
                        accentColor: .orange,
                        density: .small
                    )
                    .frame(width: widgetSide, height: widgetSide)
                    .background(
                        .fill.tertiary,
                        in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous))
                }
            }
        }
    }

    private var sensorBoardPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sensor Board")
                .font(.headline)

            Text("Chart, Reading, Gauge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            WidgetSensorBoardFace(
                items: sensorBoardItems
            )
            .frame(width: 360, height: 169)
            .background(
                .fill.tertiary,
                in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
            )

            Text("Circular, Segmented, Bar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            WidgetSensorBoardFace(
                items: sensorBoardGaugeStyleItems
            )
            .frame(width: 360, height: 169)
            .background(
                .fill.tertiary,
                in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
            )

            Text("No History, Unavailable, Empty")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            WidgetSensorBoardFace(
                items: sensorBoardStatusItems
            )
            .frame(width: 360, height: 169)
            .background(
                .fill.tertiary,
                in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
            )
        }
    }

    private var largeSensorBoardPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Large Sensor Board")
                .font(.headline)

            WidgetSensorBoardFace(
                items: largeSensorBoardItems,
                layout: .large
            )
            .frame(width: 360, height: 360)
            .background(
                .fill.tertiary,
                in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
            )
        }
    }

    private var circularComparisonRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Circular")
                .font(.headline)

            HStack(alignment: .top, spacing: 18) {
                previewColumn("Dashboard") {
                    DashboardCardView(
                        entityID: "sensor.front_door_battery",
                        size: .square,
                        presentationKind: .circularGauge,
                        isPreview: true
                    )
                    .frame(width: dashboardWidth)
                }

                previewColumn("Widget") {
                    WidgetGaugeInstrumentView(
                        gauge: gauge,
                        tint: widgetGaugeColor(for: gauge.currentColor),
                        title: "Front Door Battery",
                        icon: gaugeIcon
                    )
                    .padding(widgetPadding)
                    .frame(width: widgetSide, height: widgetSide)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous))
                }
            }
        }
    }

    private var barComparisonRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bar")
                .font(.headline)

            HStack(alignment: .top, spacing: 18) {
                previewColumn("Dashboard") {
                    DashboardCardView(
                        entityID: "sensor.front_door_battery",
                        size: .square,
                        presentationKind: .barGauge,
                        isPreview: true
                    )
                    .frame(width: dashboardWidth)
                }

                previewColumn("Widget") {
                    WidgetGaugeBarComparisonFace(
                        title: "Front Door Battery",
                        gauge: gauge,
                        icon: gaugeIcon
                    )
                    .padding(widgetPadding)
                    .frame(width: widgetSide, height: widgetSide)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous))
                }
            }
        }
    }

    private var segmentedComparisonRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Segmented")
                .font(.headline)

            HStack(alignment: .top, spacing: 18) {
                previewColumn("Dashboard") {
                    DashboardCardView(
                        entityID: "sensor.living_room_humidity",
                        size: .square,
                        presentationKind: .segmentedGauge,
                        isPreview: true
                    )
                    .frame(width: dashboardWidth)
                }

                previewColumn("Widget") {
                    WidgetGaugeInstrumentView(
                        gauge: segmentedGauge,
                        tint: widgetGaugeColor(for: segmentedGauge.currentColor),
                        title: "Living Room Humidity",
                        icon: segmentedGaugeIcon,
                        style: .segmented
                    )
                    .padding(widgetPadding)
                    .frame(width: widgetSide, height: widgetSide)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous))
                }
            }
        }
    }

    private func previewColumn<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private var sensorBoardItems: [WidgetSensorBoardItem?] {
        [
            .chart(sensorBoardChartItem),
            .compact(WidgetSensorBoardCompactItem.sensor(
                from: previewSensor(
                    id: "sensor.living_room_temperature",
                    name: "Temperature",
                    valueText: "76.6°F",
                    icon: "thermometer.medium",
                    gauge: sensorBoardTemperatureGauge
                ),
                presentation: .reading
            )),
            .compact(WidgetSensorBoardCompactItem.sensor(
                from: previewSensor(
                    id: "sensor.alkalinity",
                    name: "Alkalinity",
                    valueText: "8.3 dKH",
                    icon: "testtube.2",
                    isAvailable: !showsUnavailableBoard,
                    gauge: WidgetGaugePresentation(
                        value: 8.3,
                        lowerBound: 7,
                        upperBound: 11,
                        valueText: "8.3 dKH",
                        unitText: "dKH",
                        status: .nominal,
                        statusDisplayText: "Available",
                        sections: [
                            .init(lowerBound: 7, upperBound: 8, color: .red),
                            .init(lowerBound: 8, upperBound: 10, color: .green),
                            .init(lowerBound: 10, upperBound: 11, color: .orange)
                        ],
                        accessibilityLabel: "Alkalinity gauge",
                        accessibilityValue: "8.3 dKH"
                    )
                )
            ))
        ]
    }

    private var sensorBoardStatusItems: [WidgetSensorBoardItem?] {
        [
            .chart(WidgetSensorBoardChartItem(
                id: "sensor.trident_error",
                displayName: "Trident Error",
                icon: .sfSymbol("exclamationmark.triangle.fill", provenance: .homesteadSemanticMapping),
                valueText: "14",
                unitText: nil,
                supportingText: WidgetStateText.noHistory,
                isAvailable: true,
                samples: [],
                valueDomain: 0...1,
                interpolationStyle: .linear,
                accentColor: .blue
            )),
            .compact(WidgetSensorBoardCompactItem.sensor(
                from: previewSensor(
                    id: "sensor.unavailable",
                    name: "Pool Sensor",
                    valueText: "—",
                    icon: "sensor",
                    isAvailable: false,
                    gauge: nil
                ),
                presentation: .reading
            )),
            nil
        ]
    }

    private var sensorBoardGaugeStyleItems: [WidgetSensorBoardItem?] {
        [
            sensorBoardGaugeItem(id: "sensor.circular", name: "Circular", style: .circular),
            sensorBoardGaugeItem(id: "sensor.segmented", name: "Segmented", style: .segmented),
            sensorBoardGaugeItem(id: "sensor.bar", name: "Bar", style: .bar)
        ]
    }

    private func sensorBoardGaugeItem(
        id: String,
        name: String,
        style: WidgetSensorBoardGaugeStyle
    ) -> WidgetSensorBoardItem {
        .compact(WidgetSensorBoardCompactItem.sensor(
            from: previewSensor(
                id: id,
                name: name,
                valueText: "76.6°F",
                icon: "thermometer.medium",
                gauge: sensorBoardTemperatureGauge
            ),
            presentation: .gauge,
            gaugeStyle: style
        ))
    }

    private var largeSensorBoardItems: [WidgetSensorBoardItem?] {
        sensorBoardItems + [
            .compact(WidgetSensorBoardCompactItem.sensor(
                from: previewSensor(
                    id: "sensor.pool_temperature",
                    name: "Pool",
                    valueText: "81.2°F",
                    icon: "thermometer.medium",
                    gauge: sensorBoardTemperatureGauge
                ),
                presentation: .reading
            )),
            .chart(sensorBoardChartItem),
            .compact(WidgetSensorBoardCompactItem.sensor(
                from: previewSensor(
                    id: "sensor.spa_temperature",
                    name: "Spa",
                    valueText: "101°F",
                    icon: "thermometer.high",
                    gauge: sensorBoardTemperatureGauge
                ),
                gaugeStyle: .circular
            )),
            .compact(WidgetSensorBoardCompactItem.sensor(
                from: previewSensor(
                    id: "sensor.pool_ph",
                    name: "Pool pH",
                    valueText: "7.5",
                    icon: "drop.degreesign",
                    gauge: nil
                ),
                presentation: .reading
            )),
            .chart(sensorBoardChartItem),
            .compact(WidgetSensorBoardCompactItem.sensor(
                from: previewSensor(
                    id: "sensor.water_temperature",
                    name: "Water",
                    valueText: "78.4°F",
                    icon: "water.waves.and.thermometer",
                    gauge: sensorBoardTemperatureGauge
                ),
                gaugeStyle: .bar
            ))
        ]
    }

    private var sensorBoardChartItem: WidgetSensorBoardChartItem {
        let now = Date()
        return WidgetSensorBoardChartItem(
            id: "sensor.salinity",
            displayName: "Salinity",
            icon: .sfSymbol("water.waves", provenance: .homesteadSemanticMapping),
            valueText: "33.8 ppt",
            unitText: "ppt",
            supportingText: showsUnavailableBoard ? "Needs connection" : "No recent chart",
            isAvailable: !showsUnavailableBoard,
            samples: showsUnavailableBoard ? [] : [33.2, 33.5, 33.4, 33.7, 33.5, 33.6, 33.8].enumerated().map { index, value in
                HomesteadChartSample(
                    occurredAt: now.addingTimeInterval(Double(index - 6) * 60 * 60),
                    value: value
                )
            },
            valueDomain: HomesteadChartDomain.stabilized(
                values: [33.2, 33.5, 33.4, 33.7, 33.5, 33.6, 33.8],
                unit: "ppt"
            ),
            interpolationStyle: .smooth,
            accentColor: .blue
        )
    }

    private var chartPresentation: HomesteadWidgetChartPresentation {
        let now = Date()
        let values = [-0.08, -0.03, 0.04, -0.01, 0.07, 0.02, 0.09, 0.0].map { 72 + ($0 * 5.76) }
        return HomesteadWidgetChartPresentation(
            title: "Hallway",
            valueText: "72°F",
            unitText: "°F",
            icon: .sfSymbol("thermometer.medium", provenance: .homesteadSemanticMapping),
            isAvailable: true,
            samples: values.enumerated().map { index, value in
                HomesteadChartSample(
                    occurredAt: now.addingTimeInterval((Double(index) / 7 * 6 - 6) * 60 * 60),
                    value: value
                )
            },
            valueDomain: HomesteadChartDomain.stabilized(values: values, unit: "°F"),
            interpolationStyle: .smooth,
            rangeTitle: "6H",
            changeSummaryText: nil,
            emptyLabel: "No recent chart"
        )
    }

    private func previewSensor(
        id: String,
        name: String,
        valueText: String,
        icon: String,
        isAvailable: Bool = true,
        gauge: WidgetGaugePresentation?
    ) -> WidgetSensorSnapshot {
        WidgetSensorSnapshot(
            entityID: id,
            displayName: name,
            valueText: valueText,
            subtitle: "Sensor",
            systemImage: icon,
            unit: gauge?.unitText,
            isNumeric: true,
            isAlerting: false,
            isAvailable: isAvailable,
            areaName: nil,
            deviceName: nil,
            gauge: gauge
        )
    }

    private var showsUnavailableBoard: Bool {
        RuntimeEnvironment.dashboardCardReferenceState == "unavailable"
    }
}

private struct WidgetGaugeBarComparisonFace: View {
    let title: String
    let gauge: WidgetGaugePresentation
    let icon: ResolvedIcon

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: GaugeVisualMetrics.compactHeaderSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: GaugeVisualMetrics.compactHeaderIconCornerRadius, style: .continuous)
                        .fill(.fill.tertiary)

                    HomesteadIconView(icon: icon, pointSize: GaugeVisualMetrics.compactHeaderIconPointSize, weight: .semibold)
                        .foregroundStyle(widgetGaugeColor(for: gauge.currentColor))
                }
                .frame(width: GaugeVisualMetrics.compactHeaderIconSize, height: GaugeVisualMetrics.compactHeaderIconSize)

                VStack(alignment: .leading, spacing: GaugeVisualMetrics.compactHeaderTextSpacing) {
                    Text(title)
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
    }

    private var gaugeReadout: some View {
        let parts = gaugeValueParts(from: gauge.valueText, unitText: gauge.unitText)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.value)
                .font(.system(size: 27, weight: .bold, design: .rounded))

            if let unit = parts.unit {
                Text(unit)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .baselineOffset(2)
                    .padding(.leading, -1)
            }
        }
        .foregroundStyle(widgetGaugeColor(for: gauge.currentColor))
        .lineLimit(1)
        .minimumScaleFactor(0.58)
        .monospacedDigit()
    }
}

#Preview("Gauge Widget Comparison") {
    WidgetReferenceGallery()
        .withPreviewEnvironment()
        .preferredColorScheme(.dark)
}
#endif
