import SwiftUI

struct TemporalDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings

    @State private var draftValue = Date()
    @State private var isEditingValue = false
    @State private var confirmationRequest: ActionConfirmationRequest?

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity { entityBox.homeEntity }
    private var temporal: TemporalEntity? { entityBox.temporalEntity }
    private var presentation: EntityDetailPresentationModel { EntityDetailPresentationModel(entityBox: entityBox) }
    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            hero
            editorPanel
            EntityActivityHistoryPreview(entityBox: entityBox, tint: presentation.accentColor)
            contextDetails
        }
        .onAppear(perform: syncDraft)
        .onChange(of: entity.state) { _, _ in
            guard !isEditingValue else { return }
            syncDraft()
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var hero: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: categoryTitle,
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: entity.isAvailable ? .accentColor : .secondary,
            statusColor: entity.isAvailable ? .accentColor : .red,
            iconBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            statusBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12),
            statePresentation: detailState
        ) {
            Text(formatted(draftValue))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(entity.isAvailable ? Color.primary : Color.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
    }

    private var editorPanel: some View {
        EntityControlPanel(title: "Controls", systemImage: temporalSystemImage) {
            DatePicker(
                categoryTitle,
                selection: draftValueBinding,
                displayedComponents: displayedComponents
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(isControlDisabled)

            EntityDetailActionButton(
                title: "Save",
                systemImage: "checkmark",
                isDisabled: isSaveDisabled,
                action: save
            )
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "Service", value: temporal?.serviceName ?? "Unavailable")
            ]
        )
    }

    private var displayedComponents: DatePickerComponents {
        switch temporal?.kind {
        case .date: .date
        case .time: .hourAndMinute
        case .dateTime, .none: [.date, .hourAndMinute]
        }
    }

    private var categoryTitle: String {
        switch temporal?.kind {
        case .date: "Date"
        case .time: "Time"
        case .dateTime, .none: "Date & Time"
        }
    }

    private var temporalSystemImage: String {
        switch temporal?.kind {
        case .date: "calendar"
        case .time: "clock"
        case .dateTime, .none: "calendar.badge.clock"
        }
    }

    private var isControlDisabled: Bool {
        guard let temporal else { return true }
        return detailState.blocksControlInteraction
            || !homeAssistantService.serviceActionAvailable(domain: temporal.serviceDomain, service: temporal.service)
    }

    private var isSaveDisabled: Bool {
        isControlDisabled || !isEditingValue
    }

    private var draftValueBinding: Binding<Date> {
        Binding(
            get: { draftValue },
            set: { value in
                draftValue = value
                isEditingValue = true
            }
        )
    }

    private func syncDraft() {
        draftValue = temporal?.value ?? Date()
        isEditingValue = false
    }

    private func save() {
        guard !isSaveDisabled, let temporal else { return }
        let value = draftValue
        confirmOrPerform(domain: temporal.serviceDomain, service: temporal.service) {
            Task { await homeAssistantService.setTemporalValue(entityID: entity.entityID, date: value) }
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
        confirmationRequest = ActionConfirmationRequest(presentation: presentation, perform: perform)
    }

    private func formatted(_ value: Date) -> String {
        switch temporal?.kind {
        case .date:
            value.formatted(date: .abbreviated, time: .omitted)
        case .time:
            value.formatted(date: .omitted, time: .shortened)
        case .dateTime, .none:
            value.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "input_datetime.quiet_hours_start") {
        TemporalDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
