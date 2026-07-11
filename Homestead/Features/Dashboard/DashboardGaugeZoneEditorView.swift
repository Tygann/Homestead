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

                Section {
                    valueField("Minimum", value: $configuration.lowerBound)
                    valueField("Maximum", value: $configuration.upperBound)
                } header: {
                    Text("Scale")
                } footer: {
                    Text(scaleFooter)
                }

                Section {
                    ForEach(configuration.statuses.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack(spacing: AppSpacing.medium) {
                                Circle()
                                    .fill(statusColor(configuration.statuses[index]))
                                    .frame(width: 10, height: 10)

                                Picker("Zone \(index + 1)", selection: $configuration.statuses[index]) {
                                    ForEach(GaugePresentationStatus.allCases, id: \.self) { status in
                                        Text(status.displayName).tag(status)
                                    }
                                }
                                .pickerStyle(.menu)

                                Spacer()

                                Text(zoneRangeText(index))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            if index > 0 {
                                LabeledContent("Starts At") {
                                    TextField("Value", value: $configuration.boundaries[index - 1], format: .number)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.numbersAndPunctuation)
                                        .frame(maxWidth: 110)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .onDelete(perform: deleteZones)

                    Button {
                        withAnimation(.snappy) {
                            configuration.addZone()
                        }
                    } label: {
                        Label("Add Zone", systemImage: "plus.circle.fill")
                    }
                    .disabled(!configuration.isValid || configuration.statuses.count >= GaugeZoneConfiguration.maximumZoneCount)
                } header: {
                    Text("Zones")
                } footer: {
                    Text(configuration.isValid
                         ? zoneFooter
                         : validationMessage)
                        .foregroundStyle(configuration.isValid ? Color.secondary : Color.red)
                }

                Section {
                    Button("Restore Automatic Setup") {
                        onReset()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Gauge Setup")
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
        LabeledContent(title) {
            TextField("Value", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 110)
        }
    }

    private var scaleFooter: String {
        let source: String = switch context.presentation.rangeSource {
        case .homeAssistant: "Home Assistant"
        case .deviceClass, .percentageUnit: "the sensor type"
        case .valueSuggested: "the current value"
        case .userConfigured: "your saved setup"
        }
        return "The initial scale came from \(source). You can override either endpoint for this card."
    }

    private var zoneFooter: String {
        configuration.statuses.count == 1
            ? "Add a zone to split the scale at a new threshold."
            : "Swipe a zone to remove it. Each threshold must stay inside the scale."
    }

    private var validationMessage: String {
        guard configuration.lowerBound < configuration.upperBound else {
            return "Maximum must be greater than minimum."
        }
        return "Thresholds must increase and remain inside the scale."
    }

    private func zoneRangeText(_ index: Int) -> String {
        guard let range = configuration.range(forZoneAt: index) else { return "Check values" }
        return "\(formatted(range.lowerBound))–\(formatted(range.upperBound))\(unitSuffix)"
    }

    private var unitSuffix: String {
        context.presentation.unitText.map { " \($0)" } ?? ""
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func deleteZones(at offsets: IndexSet) {
        withAnimation(.snappy) {
            for index in offsets.sorted(by: >) {
                configuration.removeZone(at: index)
            }
        }
    }

    private func statusColor(_ status: GaugePresentationStatus) -> Color {
        gaugeVisualStatusColor(for: status.visualStatus)
    }
}

private extension GaugePresentationStatus {
    var displayName: String {
        switch self {
        case .nominal: "Normal"
        case .low: "Low"
        case .high: "High"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}
