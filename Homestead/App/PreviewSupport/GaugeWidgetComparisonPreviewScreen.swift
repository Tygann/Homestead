#if DEBUG
import SwiftUI

struct GaugeWidgetComparisonPreviewScreen: View {
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
            WidgetGaugeSection(lowerBound: 0, upperBound: 20, status: .critical),
            WidgetGaugeSection(lowerBound: 20, upperBound: 30, status: .warning),
            WidgetGaugeSection(lowerBound: 30, upperBound: 60, status: .nominal),
            WidgetGaugeSection(lowerBound: 60, upperBound: 70, status: .warning),
            WidgetGaugeSection(lowerBound: 70, upperBound: 100, status: .critical)
        ],
        accessibilityLabel: "Living Room Humidity gauge",
        accessibilityValue: "56%, comfortable"
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
                    circularComparisonRow
                    segmentedComparisonRow
                    barComparisonRow
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Gauge Preview")
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
                        presentationKind: .gauge,
                        presentationStyle: .gauge(.circular),
                        isPreview: true
                    )
                    .frame(width: dashboardWidth)
                }

                previewColumn("Widget") {
                    WidgetGaugeInstrumentView(
                        gauge: gauge,
                        tint: widgetGaugeStatusColor(for: gauge.status),
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
                        presentationKind: .gauge,
                        presentationStyle: .gauge(.bar),
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
                        presentationKind: .gauge,
                        presentationStyle: .gauge(.segmented),
                        isPreview: true
                    )
                    .frame(width: dashboardWidth)
                }

                previewColumn("Widget") {
                    WidgetGaugeInstrumentView(
                        gauge: segmentedGauge,
                        tint: widgetGaugeStatusColor(for: segmentedGauge.status),
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
                        .foregroundStyle(widgetGaugeStatusColor(for: gauge.status))
                }
                .frame(width: GaugeVisualMetrics.compactHeaderIconSize, height: GaugeVisualMetrics.compactHeaderIconSize)

                VStack(alignment: .leading, spacing: GaugeVisualMetrics.compactHeaderTextSpacing) {
                    Text(title)
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
        .foregroundStyle(widgetGaugeStatusColor(for: gauge.status))
        .lineLimit(1)
        .minimumScaleFactor(0.58)
        .monospacedDigit()
    }
}

#Preview("Gauge Widget Comparison") {
    GaugeWidgetComparisonPreviewScreen()
        .withPreviewEnvironment()
        .preferredColorScheme(.dark)
}
#endif
