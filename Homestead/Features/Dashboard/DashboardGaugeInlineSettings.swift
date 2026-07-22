import SwiftUI

struct DashboardGaugeInlineSettings: View {
    @State private var expandedZoneIndexes: Set<Int> = []

    let presentation: GaugePresentation
    @Binding var configurationOverride: GaugeZoneConfiguration?

    var body: some View {
        Section {
            valueField("Minimum", keyPath: \.lowerBound)
            valueField("Maximum", keyPath: \.upperBound)
        } header: {
            Text("Gauge Settings")
        } footer: {
            Text(scaleFooter)
        }

        Section {
            ForEach(configuration.colors.indices, id: \.self) { index in
                DisclosureGroup(isExpanded: expansionBinding(for: index)) {
                    LabeledContent("Name") {
                        TextField("Name", text: nameBinding(for: index))
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                    }

                    ColorPicker("Color", selection: colorBinding(for: index), supportsOpacity: false)

                    if index > 0 {
                        LabeledContent("Begins At") {
                            TextField("Value", value: boundaryBinding(for: index), format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                                .font(.body.monospacedDigit())
                                .frame(maxWidth: 110)
                        }
                    }

                    if configuration.colors.count > 1 {
                        Button("Remove Zone", role: .destructive) {
                            removeZone(at: index)
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.medium) {
                        Circle()
                            .fill(configuration.colors[index].color)
                            .frame(width: 10, height: 10)

                        Text(configuration.name(forZoneAt: index))
                            .lineLimit(1)

                        Spacer()

                        Text(zoneRangeText(index))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Button {
                updateConfiguration { $0.addZone() }
            } label: {
                Label("Add Zone", systemImage: "plus.circle.fill")
            }
            .disabled(!configuration.isValid || configuration.colors.count >= GaugeZoneConfiguration.maximumZoneCount)
        } header: {
            Text("Zones")
        } footer: {
            Text(configuration.isValid ? zoneFooter : validationMessage)
                .foregroundStyle(configuration.isValid ? Color.secondary : Color.red)
        }

        if configurationOverride != nil {
            Section {
                Button("Restore Automatic Setup") {
                    expandedZoneIndexes.removeAll()
                    configurationOverride = nil
                }
            }
        }
    }

    private var configuration: GaugeZoneConfiguration {
        configurationOverride ?? .defaults(for: presentation)
    }

    private func valueField(
        _ title: String,
        keyPath: WritableKeyPath<GaugeZoneConfiguration, Double>
    ) -> some View {
        LabeledContent(title) {
            TextField("Value", value: valueBinding(keyPath), format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 110)
        }
    }

    private func valueBinding(
        _ keyPath: WritableKeyPath<GaugeZoneConfiguration, Double>
    ) -> Binding<Double> {
        Binding(
            get: { configuration[keyPath: keyPath] },
            set: { newValue in
                updateConfiguration { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func nameBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { configuration.names[index] },
            set: { newValue in
                updateConfiguration { $0.names[index] = newValue }
            }
        )
    }

    private func colorBinding(for index: Int) -> Binding<Color> {
        Binding(
            get: { configuration.colors[index].color },
            set: { newValue in
                updateConfiguration { $0.colors[index] = GaugeZoneColor(color: newValue) }
            }
        )
    }

    private func boundaryBinding(for zoneIndex: Int) -> Binding<Double> {
        Binding(
            get: { configuration.boundaries[zoneIndex - 1] },
            set: { newValue in
                updateConfiguration { $0.boundaries[zoneIndex - 1] = newValue }
            }
        )
    }

    private func expansionBinding(for index: Int) -> Binding<Bool> {
        Binding(
            get: { expandedZoneIndexes.contains(index) },
            set: { isExpanded in
                if isExpanded {
                    expandedZoneIndexes.insert(index)
                } else {
                    expandedZoneIndexes.remove(index)
                }
            }
        )
    }

    private func updateConfiguration(_ update: (inout GaugeZoneConfiguration) -> Void) {
        var updatedConfiguration = configuration
        update(&updatedConfiguration)
        configurationOverride = updatedConfiguration
    }

    private func removeZone(at index: Int) {
        withAnimation(.snappy) {
            updateConfiguration { $0.removeZone(at: index) }
            expandedZoneIndexes.removeAll()
        }
    }

    private var scaleFooter: String {
        let source: String = switch presentation.rangeSource {
        case .homeAssistant: "Home Assistant"
        case .deviceClass, .percentageUnit: "the sensor type"
        case .valueSuggested: "the current value"
        case .userConfigured: "your saved setup"
        }
        return "The initial scale came from \(source). Editing a value customizes only this card."
    }

    private var zoneFooter: String {
        configuration.colors.count == 1
            ? "Add a zone to split the scale at a new threshold."
            : "Expand a zone to edit its name, color, and threshold."
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
        presentation.unitText.map { " \($0)" } ?? ""
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
