import SwiftUI

struct NumberDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings

    @State private var draftValue: Double = 0
    @State private var isEditingValue = false
    @State private var confirmationRequest: ActionConfirmationRequest?

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: EntityDetailPresentationModel {
        EntityDetailPresentationModel(entityBox: entityBox)
    }

    private var number: NumberEntity? {
        entityBox.numberEntity
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }
    private var serviceDomain: String {
        HomeAssistantService.numberServiceDomain(for: entity.entityID)
    }
    private var features: EntityDetailFeatureSet {
        EntityDetailFeatureProvider.features(for: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header
            valuePanel
            if features.supports(.numericHistory) {
                EntityNumericHistoryPreview(
                    entityBox: entityBox,
                    displayName: entity.displayName,
                    unit: unit,
                    accentColor: .accentColor,
                    preferredRange: valueRange
                )
            }
            contextDetails
        }
        .onAppear {
            syncDraftValue()
        }
        .onChange(of: entity.state) { _, _ in
            guard !isEditingValue else { return }
            syncDraftValue()
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: "Number",
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: entity.isAvailable ? .accentColor : .secondary,
            statusColor: entity.isAvailable ? .accentColor : .red,
            iconBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            statusBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12),
            statePresentation: detailState
        ) {
            Text(formattedValue(draftValue))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(entity.isAvailable ? Color.accentColor : Color.secondary)
                .monospacedDigit()
        }
    }

    private var valuePanel: some View {
        EntityControlPanel(title: "Controls", systemImage: "slider.horizontal.3") {
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
                        setValue(value)
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
        detailState.blocksControlInteraction || !homeAssistantService.serviceActionAvailable(domain: serviceDomain, service: "set_value")
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Number unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return "Adjustable value"
    }

    private var valueRange: ClosedRange<Double> {
        number?.valueRange ?? 0...100
    }

    private var step: Double {
        number?.step ?? 1
    }

    private var unit: String? {
        number?.unit
    }

    private var numericStateValue: Double? {
        number?.value
    }

    private func syncDraftValue() {
        draftValue = min(max(numericStateValue ?? valueRange.lowerBound, valueRange.lowerBound), valueRange.upperBound)
    }

    private func adjustValue(by delta: Double) {
        let updatedValue = min(max(draftValue + delta, valueRange.lowerBound), valueRange.upperBound)
        draftValue = (updatedValue / step).rounded() * step
        setValue(draftValue)
    }

    private func setValue(_ value: Double) {
        confirmOrPerform(domain: serviceDomain, service: "set_value") {
            Task { await homeAssistantService.setNumberValue(entityID: entity.entityID, value: value) }
        }
    }

    private func confirmOrPerform(domain: String, service: String, perform: @escaping () -> Void) {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: domain,
            service: service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            perform()
            return
        }

        confirmationRequest = ActionConfirmationRequest(
            presentation: presentation,
            perform: perform
        )
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
