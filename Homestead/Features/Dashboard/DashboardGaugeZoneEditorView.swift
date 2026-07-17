import SwiftUI

struct DashboardGaugeZoneEditorContext: Identifiable {
    let id: UUID
    let presentation: GaugePresentation
    let kind: DashboardPresentationKind
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
                        style: previewStyle,
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
                    ForEach(configuration.colors.indices, id: \.self) { index in
                        NavigationLink {
                            DashboardGaugeZoneDetailView(
                                configuration: $configuration,
                                zoneIndex: index,
                                unitText: context.presentation.unitText
                            )
                        } label: {
                            HStack(spacing: AppSpacing.medium) {
                                Circle()
                                    .fill(configuration.colors[index].color)
                                    .frame(width: 10, height: 10)

                                Text(configuration.name(forZoneAt: index))

                                Spacer()

                                Text(zoneRangeText(index))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
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
                    .disabled(!configuration.isValid || configuration.colors.count >= GaugeZoneConfiguration.maximumZoneCount)
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

    private var previewStyle: GaugePresentationStyle {
        switch context.kind {
        case .segmentedGauge: .segmentedInstrument
        case .barGauge: .row
        default: .instrument
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
        configuration.colors.count == 1
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

}

private struct DashboardGaugeZoneDetailView: View {
    @Binding var configuration: GaugeZoneConfiguration

    let zoneIndex: Int
    let unitText: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("Name", text: nameBinding)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 220)
                }
                ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
            } header: {
                Text("Appearance")
            }

            if zoneIndex > 0 {
                Section {
                    LabeledContent("Begins At") {
                        TextField("Value", value: $configuration.boundaries[zoneIndex - 1], format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                            .font(.body.monospacedDigit())
                            .frame(maxWidth: 110)
                    }
                } header: {
                    Text("Range")
                } footer: {
                    Text("This zone begins at \(formatted(configuration.boundaries[zoneIndex - 1]))\(unitSuffix).")
                }
            }
        }
        .navigationTitle(configuration.name(forZoneAt: zoneIndex))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var unitSuffix: String {
        unitText.map { " \($0)" } ?? ""
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { configuration.colors[zoneIndex].color },
            set: { configuration.colors[zoneIndex] = GaugeZoneColor(color: $0) }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { configuration.names[zoneIndex] },
            set: { configuration.names[zoneIndex] = $0 }
        )
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
