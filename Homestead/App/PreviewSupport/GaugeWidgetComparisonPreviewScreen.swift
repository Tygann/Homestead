#if DEBUG
import SwiftUI

struct GaugeWidgetComparisonPreviewScreen: View {
    private let widgetIcon = ResolvedIcon.sfSymbol("battery.100percent", provenance: .homesteadSemanticMapping)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    comparisonRow
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Gauge Preview")
        }
    }

    private var comparisonRow: some View {
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
                    .frame(width: 180)
                }

                previewColumn("Widget") {
                    WidgetGaugeInstrumentView(
                        gauge: .previewLowBattery,
                        tint: .blue,
                        title: "Front Door Battery",
                        icon: widgetIcon
                    )
                        .padding(16)
                        .frame(width: 180, height: 180)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
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
#endif
