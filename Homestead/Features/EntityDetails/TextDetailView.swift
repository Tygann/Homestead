import SwiftUI

struct TextDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings

    @FocusState private var isFieldFocused: Bool
    @State private var draftValue = ""
    @State private var confirmationRequest: ActionConfirmationRequest?

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity { entityBox.homeEntity }
    private var textEntity: TextEntity? { entityBox.textEntity }
    private var presentation: DashboardEntityPresentation { DashboardEntityPresentation(entityBox: entityBox) }
    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }
    private var serviceDomain: String { HomeAssistantService.textServiceDomain(for: entity.entityID) }
    private var validationMessage: String? { textEntity?.validationMessage(for: draftValue) }

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            hero
            editorPanel
            contextDetails
        }
        .onAppear(perform: syncDraft)
        .onChange(of: entity.state) { _, _ in
            guard !isFieldFocused else { return }
            syncDraft()
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var hero: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: "Text",
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: entity.isAvailable ? .accentColor : .secondary,
            statusColor: entity.isAvailable ? .accentColor : .red,
            iconBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            statusBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12),
            statePresentation: detailState
        ) {
            Text(heroValue)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(entity.isAvailable ? Color.primary : Color.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editorPanel: some View {
        EntityControlPanel(title: "Value", systemImage: "text.cursor") {
            Group {
                if textEntity?.mode == .password {
                    SecureField("Value", text: $draftValue)
                } else {
                    TextField("Value", text: $draftValue, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .textFieldStyle(.plain)
            .padding(.horizontal, AppSpacing.medium)
            .frame(minHeight: 48)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .focused($isFieldFocused)
            .submitLabel(.done)
            .onSubmit(save)
            .disabled(isControlDisabled)
            .accessibilityLabel("Value")

            HStack(alignment: .firstTextBaseline) {
                if let validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                } else {
                    Text(lengthGuidance)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(draftValue.count)/\(textEntity?.maximumLength ?? 255)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.caption)

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
                EntityMetadataRow(title: "Service", value: "\(serviceDomain).set_value")
            ]
        )
    }

    private var heroValue: String {
        guard textEntity?.mode == .password else { return entity.state.displayStateText }
        return entity.state.isEmpty ? "No value" : String(repeating: "•", count: min(max(entity.state.count, 4), 12))
    }

    private var lengthGuidance: String {
        let minimum = textEntity?.minimumLength ?? 0
        return minimum > 0 ? "At least \(minimum) characters" : "Edit and save the current value"
    }

    private var isControlDisabled: Bool {
        detailState.blocksControlInteraction
            || !homeAssistantService.serviceActionAvailable(domain: serviceDomain, service: "set_value")
    }

    private var isSaveDisabled: Bool {
        isControlDisabled || validationMessage != nil || draftValue == textEntity?.value
    }

    private func syncDraft() {
        draftValue = textEntity?.value ?? entity.state
    }

    private func save() {
        guard !isSaveDisabled else { return }
        isFieldFocused = false
        confirmOrPerform {
            Task { await homeAssistantService.setTextValue(entityID: entity.entityID, value: draftValue) }
        }
    }

    private func confirmOrPerform(perform: @escaping () -> Void) {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: serviceDomain,
            service: "set_value",
            settings: actionConfirmationSettings.snapshot
        ) else {
            perform()
            return
        }
        confirmationRequest = ActionConfirmationRequest(presentation: presentation, perform: perform)
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "input_text.guest_message") {
        TextDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
