import SwiftUI

struct AlarmControlPanelDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings

    @State private var code = ""
    @State private var confirmationRequest: ActionConfirmationRequest?

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: "Alarm", presentationStyle: presentationStyle) {
            header
            accessPanel
            if !availableArmActions.isEmpty {
                armPanel
            }
            contextDetails
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: statusSummary,
            badge: entity.isAvailable ? entity.state.displayStateText : "Unavailable",
            iconColor: iconColor,
            badgeColor: entity.isAvailable ? iconColor : .red,
            iconBackground: iconBackground,
            badgeBackground: badgeBackground
        )
    }

    private var accessPanel: some View {
        EntityControlPanel(title: "Access", systemImage: "key.fill") {
            SecureField("Code", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .font(.headline)
                .padding(.horizontal, AppSpacing.medium)
                .frame(height: 44)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
        }
    }

    private var armPanel: some View {
        EntityControlPanel(title: "Security Mode", systemImage: "shield.fill") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.small) {
                ForEach(availableArmActions) { action in
                    EntityDetailPillButton(
                        title: action.title,
                        systemImage: action.systemImage,
                        isSelected: entity.state == action.expectedState,
                        isDisabled: isActionDisabled(action),
                        tint: action.isDisarm ? .red : .accentColor
                    ) {
                        confirm(action)
                    }
                }
            }
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
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var availableArmActions: [AlarmServiceAction] {
        AlarmServiceAction.allCases.filter { action in
            homeAssistantService.serviceActionAvailable(domain: "alarm_control_panel", service: action.service)
        }
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Alarm unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return alarmSummary
    }

    private var alarmSummary: String {
        switch entity.state {
        case "disarmed":
            "Disarmed"
        case "armed_home", "armed_away", "armed_night", "armed_vacation", "armed_custom_bypass":
            "Armed"
        case "arming":
            "Arming"
        case "pending":
            "Pending"
        case "triggered":
            "Triggered"
        default:
            entity.state.displayStateText
        }
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        if entity.state == "triggered" { return .red }
        if entity.state == "disarmed" { return .secondary }
        return .accentColor
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return iconColor.opacity(0.12)
    }

    private var badgeBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return iconColor.opacity(0.12)
    }

    private func isActionDisabled(_ action: AlarmServiceAction) -> Bool {
        entityBox.pendingCommand != nil || !entity.isAvailable || entity.state == action.expectedState
    }

    private func confirm(_ action: AlarmServiceAction) {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: "alarm_control_panel",
            service: action.service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            Task { await perform(action) }
            return
        }

        confirmationRequest = ActionConfirmationRequest(
            presentation: presentation,
            perform: {
                Task { await perform(action) }
            }
        )
    }

    private func perform(_ action: AlarmServiceAction) async {
        await homeAssistantService.setAlarmControlPanelMode(
            entityID: entity.entityID,
            service: action.service,
            code: code
        )
    }
}

private enum AlarmServiceAction: String, CaseIterable, Identifiable {
    case disarm
    case armHome
    case armAway
    case armNight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disarm:
            "Disarm"
        case .armHome:
            "Home"
        case .armAway:
            "Away"
        case .armNight:
            "Night"
        }
    }

    var systemImage: String {
        switch self {
        case .disarm:
            "shield.slash"
        case .armHome:
            "house.fill"
        case .armAway:
            "figure.walk"
        case .armNight:
            "moon.fill"
        }
    }

    var service: String {
        switch self {
        case .disarm:
            "alarm_disarm"
        case .armHome:
            "alarm_arm_home"
        case .armAway:
            "alarm_arm_away"
        case .armNight:
            "alarm_arm_night"
        }
    }

    var expectedState: String {
        switch self {
        case .disarm:
            "disarmed"
        case .armHome:
            "armed_home"
        case .armAway:
            "armed_away"
        case .armNight:
            "armed_night"
        }
    }

    var isDisarm: Bool {
        self == .disarm
    }

}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "alarm_control_panel.home") {
        AlarmControlPanelDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
