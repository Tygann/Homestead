import SwiftUI

struct NumberDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HAStateStore.self) private var stateStore

    @State private var draftValue: Double = 0
    @State private var isEditingValue = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    private var rawAttributes: [String: JSONValue] {
        stateStore.rawEntity(for: entity.entityID)?.attributes ?? [:]
    }

    var body: some View {
        EntityDetailScaffold(title: "Number", presentationStyle: presentationStyle) {
            header
            valuePanel
            contextDetails
        }
        .onAppear {
            syncDraftValue()
        }
        .onChange(of: entity.state) { _, _ in
            guard !isEditingValue else { return }
            syncDraftValue()
        }
    }

    private var header: some View {
        EntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: statusSummary,
            badge: formattedValue(draftValue),
            iconColor: entity.isAvailable ? .accentColor : .secondary,
            badgeColor: entity.isAvailable ? .accentColor : .red,
            iconBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            badgeBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12)
        )
    }

    private var valuePanel: some View {
        EntityControlPanel(title: "Value", systemImage: "slider.horizontal.3") {
            HStack(spacing: AppSpacing.medium) {
                EntityDetailIconButton(
                    systemImage: "minus",
                    accessibilityLabel: "Decrease value",
                    isDisabled: isControlDisabled || draftValue <= valueRange.lowerBound
                ) {
                    adjustValue(by: -step)
                }

                EntityDetailLevelSlider(
                    value: $draftValue,
                    range: valueRange,
                    step: step,
                    isDisabled: isControlDisabled,
                    accessibilityLabel: "Value",
                    accessibilityValue: formattedValue(draftValue),
                    onEditingChanged: { isEditingValue = $0 },
                    onCommit: { value in
                        Task { await homeAssistantService.setNumberValue(entityID: entity.entityID, value: value) }
                    }
                )

                EntityDetailIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Increase value",
                    isDisabled: isControlDisabled || draftValue >= valueRange.upperBound
                ) {
                    adjustValue(by: step)
                }
            }

            EntityMetadataRow(title: "Current", value: formattedValue(draftValue))
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "number",
            rows: contextRows
        )
    }

    private var contextRows: [EntityMetadataRow] {
        var rows = [
            EntityMetadataRow(title: "Entity ID", value: entity.entityID),
            EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
            EntityMetadataRow(title: "State", value: entity.state.displayStateText)
        ]

        if let unit {
            rows.append(EntityMetadataRow(title: "Unit", value: unit))
        }

        rows.append(EntityMetadataRow(title: "Range", value: "\(formattedNumber(valueRange.lowerBound))-\(formattedNumber(valueRange.upperBound))"))
        rows.append(EntityMetadataRow(title: "Step", value: formattedNumber(step)))
        return rows
    }

    private var isControlDisabled: Bool {
        entityBox.pendingCommand != nil || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "number", service: "set_value")
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Number unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return "Adjustable value"
    }

    private var valueRange: ClosedRange<Double> {
        let currentValue = numericStateValue ?? 0
        let minimum = rawAttributes["min"]?.doubleValue ?? min(0, currentValue)
        let maximum = rawAttributes["max"]?.doubleValue ?? max(100, currentValue)
        return minimum...max(minimum, maximum)
    }

    private var step: Double {
        max(rawAttributes["step"]?.doubleValue ?? 1, 0.01)
    }

    private var unit: String? {
        rawAttributes["unit_of_measurement"]?.stringValue
    }

    private var numericStateValue: Double? {
        Double(entity.state)
    }

    private func syncDraftValue() {
        draftValue = min(max(numericStateValue ?? valueRange.lowerBound, valueRange.lowerBound), valueRange.upperBound)
    }

    private func adjustValue(by delta: Double) {
        let updatedValue = min(max(draftValue + delta, valueRange.lowerBound), valueRange.upperBound)
        draftValue = (updatedValue / step).rounded() * step
        Task { await homeAssistantService.setNumberValue(entityID: entity.entityID, value: draftValue) }
    }

    private func formattedValue(_ value: Double) -> String {
        if let unit {
            "\(formattedNumber(value)) \(unit)"
        } else {
            formattedNumber(value)
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "number.target_humidity") {
        NumberDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
