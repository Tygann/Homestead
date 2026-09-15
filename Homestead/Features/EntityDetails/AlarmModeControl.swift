import SwiftUI

/// Shared by the dashboard and detail screen; codes live only in the presented prompt.
struct AlarmModeControl: View {
    @Environment(HomeAssistantService.self) private var service
    @Environment(ActionConfirmationSettings.self) private var confirmationSettings
    @Environment(\.homesteadWallpaperSurfaceActive) private var wallpaperActive
    @State private var codeAction: AlarmServiceAction?
    @State private var confirmationRequest: ActionConfirmationRequest?

    let entityBox: HAEntityState
    var expanded = false
    var isInteractionEnabled = true

    // MARK: - Body

    var body: some View {
        Group {
            if expanded {
                VStack(spacing: AppSpacing.small) {
                    ForEach(Array(actionRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: AppSpacing.small) {
                            ForEach(row) { action in
                                actionButton(action)
                            }
                        }
                    }
                }
            } else {
                Menu {
                    ForEach(actions) { action in
                        Button { select(action) } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                        .disabled(isDisabled(action))
                    }
                } label: {
                    HStack(spacing: AppSpacing.small) {
                        Text(selectedModeTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 0)
                        if entityBox.pendingCommand != nil {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, AppSpacing.medium)
                    .frame(height: 44)
                    .background(
                        HomesteadSurfaceStyle.controlBackground(isWallpaperActive: wallpaperActive, isActive: false),
                        in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                    )
                }
                .disabled(blocksInteraction || actions.isEmpty)
                .tint(.primary)
                .accessibilityLabel("Alarm mode")
                .accessibilityValue(selectedModeTitle)
            }
        }
        .actionConfirmationDialog(request: $confirmationRequest)
        .sheet(item: $codeAction) { action in
            AlarmCodePrompt(entityBox: entityBox, action: action) { code in
                perform(action, code: code)
            }
        }
        .onChange(of: entityBox.entityID) { _, _ in
            codeAction = nil
            confirmationRequest = nil
        }
    }

    // MARK: - Actions

    private var actions: [AlarmServiceAction] {
        (entityBox.alarmEntity?.actions ?? []).filter {
            service.serviceActionAvailable(domain: "alarm_control_panel", service: $0.service)
        }
    }

    private var blocksInteraction: Bool {
        !isInteractionEnabled || EntityDetailStatePresentation.resolve(entityBox: entityBox, service: service).blocksControlInteraction
    }

    private var selectedModeTitle: String {
        AlarmEntity.modeTitle(for: effectiveState)
    }

    private var effectiveState: String {
        entityBox.pendingCommand?.expectedState ?? entityBox.homeEntity.state
    }

    private var actionRows: [[AlarmServiceAction]] {
        stride(from: 0, to: actions.count, by: 2).map { startIndex in
            Array(actions[startIndex..<min(startIndex + 2, actions.count)])
        }
    }

    private func actionButton(_ action: AlarmServiceAction) -> some View {
        let isSelected = effectiveState == action.expectedState
        return EntityDetailPillButton(
            title: action.title(isSelected: isSelected),
            systemImage: action.systemImage,
            isSelected: isSelected,
            isDisabled: blocksInteraction,
            tint: action == .disarm ? Color.secondary : Color.accentColor
        ) { select(action) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func isDisabled(_ action: AlarmServiceAction) -> Bool {
        blocksInteraction || entityBox.homeEntity.state == action.expectedState
    }

    private func select(_ action: AlarmServiceAction) {
        guard !isDisabled(action), actions.contains(action) else { return }
        if entityBox.alarmEntity?.requiresCode(for: action) == true {
            codeAction = action
        } else if let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox, domain: "alarm_control_panel", service: action.service,
            settings: confirmationSettings.snapshot
        ) {
            confirmationRequest = ActionConfirmationRequest(presentation: presentation) {
                perform(action, code: nil)
            }
        } else {
            perform(action, code: nil)
        }
    }

    private func perform(_ action: AlarmServiceAction, code: String?) {
        guard !isDisabled(action), actions.contains(action) else { return }
        Task {
            await service.setAlarmControlPanelMode(entityID: entityBox.entityID, service: action.service, code: code)
        }
    }
}

private struct AlarmCodePrompt: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var service
    @State private var code = ""
    @FocusState private var codeFocused: Bool
    let entityBox: HAEntityState
    let action: AlarmServiceAction
    let submit: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Code", text: $code)
                        .keyboardType(entityBox.alarmEntity?.codeFormat == "number" ? .numberPad : .default)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($codeFocused)
                } header: {
                    Text(entityBox.homeEntity.displayName)
                } footer: {
                    Text("Leave blank to use a code saved in Home Assistant.")
                }
            }
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { code = ""; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action.title) {
                        let submittedCode = code
                        code = ""
                        submit(submittedCode)
                        dismiss()
                    }
                    .disabled(EntityDetailStatePresentation.resolve(entityBox: entityBox, service: service).blocksControlInteraction)
                }
            }
            .onAppear { codeFocused = true }
            .onDisappear { code = "" }
        }
        .presentationDetents([.medium])
    }
}
