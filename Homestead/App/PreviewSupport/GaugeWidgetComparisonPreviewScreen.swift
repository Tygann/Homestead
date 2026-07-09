#if DEBUG
import SwiftUI

struct GaugeWidgetComparisonPreviewScreen: View {
    private let dashboardWidth: CGFloat = 180
    private let widgetSide: CGFloat = 169
    private let widgetCornerRadius: CGFloat = 36
    private let widgetPadding: CGFloat = 16
    private let gauge = WidgetGaugePresentation.previewLowBattery
    private let widgetIcon = ResolvedIcon.sfSymbol("battery.25percent", provenance: .homesteadSemanticMapping)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    circularComparisonRow
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
                        icon: widgetIcon
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
                        icon: widgetIcon
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
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.fill.tertiary)

                    HomesteadIconView(icon: icon, pointSize: 13, weight: .semibold)
                        .foregroundStyle(widgetGaugeStatusColor(for: gauge.status))
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(gauge.statusDisplayText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(widgetGaugeStatusColor(for: gauge.status))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            gaugeReadout

            WidgetGaugeBarView(gauge: gauge)
                .frame(height: 18)
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
#endif
