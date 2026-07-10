import SwiftUI

struct DashboardGaugeZoneEditorContext: Identifiable {
    let id: UUID
    let presentation: GaugePresentation
    let configuration: GaugeZoneConfiguration
}

struct DashboardGaugeZoneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration: GaugeZoneConfiguration

    let context: DashboardGaugeZoneEditorContext
    let onSave: (GaugeZoneConfiguration) -> Void
    let onReset: () -> Void

    init(
        context: DashboardGaugeZoneEditorContext,
        onSave: @escaping (GaugeZoneConfiguration) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.context = context
        self.onSave = onSave
        self.onReset = onReset
        _configuration = State(initialValue: context.configuration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GaugePresentationView(
                        presentation: context.presentation.applying(zoneConfiguration: configuration),
                        style: .segmentedInstrument,
                        tint: .accentColor
                    )
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Range") {
                    valueField("Minimum", value: $configuration.lowerBound)
                    valueField("Maximum", value: $configuration.upperBound)
                }

                Section {
                    ForEach(configuration.boundaries.indices, id: \.self) { index in
                        HStack(spacing: AppSpacing.medium) {
                            Circle()
                                .fill(statusColor(configuration.statuses[index]))
                                .frame(width: 10, height: 10)

                            Text(boundaryTitle(index))

                            Spacer()

                            TextField("Value", value: $configuration.boundaries[index], format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(maxWidth: 100)
                        }
                    }
                } header: {
                    Text("Zone Boundaries")
                } footer: {
                    Text(configuration.isValid
                         ? "Each boundary is the upper value of its colored zone."
                         : "Values must increase from the minimum to the maximum.")
                        .foregroundStyle(configuration.isValid ? Color.secondary : Color.red)
                }

                Section {
                    Button("Use Recommended Zones", role: .destructive) {
                        onReset()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Gauge Zones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) {
                        onSave(configuration)
                        dismiss()
                    }
                    .disabled(!configuration.isValid)
                }
            }
        }
    }

    private func valueField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Value", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .frame(maxWidth: 100)
        }
    }

    private func boundaryTitle(_ index: Int) -> String {
        switch configuration.statuses[index] {
        case .critical: index == 0 ? "Low Critical" : "High Critical"
        case .warning: index < configuration.boundaries.count / 2 ? "Low Warning" : "High Warning"
        case .nominal: "Comfortable"
        case .low: "Low"
        case .high: "High"
        }
    }

    private func statusColor(_ status: GaugePresentationStatus) -> Color {
        gaugeVisualStatusColor(for: status.visualStatus)
    }
}
