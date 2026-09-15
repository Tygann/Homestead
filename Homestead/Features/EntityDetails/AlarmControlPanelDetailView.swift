import SwiftUI

struct AlarmControlPanelDetailView: View {
    // MARK: - Properties

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: EntityDetailPresentationModel {
        EntityDetailPresentationModel(entityBox: entityBox)
    }

    // MARK: - Body

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header
            controls
            EntityActivityHistoryPreview(entityBox: entityBox, tint: presentation.accentColor)
            contextDetails
        }
    }

    // MARK: - Sections

    private var header: some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: presentation.icon,
            category: "Alarm",
            summary: nil,
            status: EntityDetailStatusPresentation(text: alarmSummary, tone: alarmStatusTone),
            iconColor: iconColor,
            iconBackground: iconBackground
        )
    }

    private var controls: some View {
        EntityControlPanel(title: "Controls", systemImage: "slider.horizontal.3") {
            AlarmModeControl(entityBox: entityBox, expanded: true)
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

    private var alarmSummary: String {
        switch entity.state {
        case "disarmed":
            "Disarmed"
        case "armed_home", "armed_away", "armed_night", "armed_vacation", "armed_custom_bypass":
            entity.state.displayStateText
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

    private var alarmStatusTone: EntityDetailStatusTone {
        switch entity.state {
        case "triggered": .critical
        case "arming", "pending", "disarming": .warning
        case "disarmed": .neutral
        default: .accent
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
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "alarm_control_panel.home") {
        AlarmControlPanelDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
