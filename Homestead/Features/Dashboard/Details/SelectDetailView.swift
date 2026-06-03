import SwiftUI

struct SelectDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HAStateStore.self) private var stateStore

    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    private var options: [String] {
        stateStore.rawEntity(for: entity.entityID)?
            .attributes["options"]?
            .arrayValue?
            .compactMap(\.stringValue) ?? []
    }

    var body: some View {
        DashboardEntityDetailScaffold(title: "Select", presentationStyle: presentationStyle) {
            header

            if !options.isEmpty {
                optionPanel
            }

            currentPanel
            contextDetails
        }
    }

    private var header: some View {
        DashboardEntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: statusSummary,
            badge: entity.isAvailable ? entity.state.displayStateText : "Unavailable",
            iconColor: entity.isAvailable ? .accentColor : .secondary,
            badgeColor: entity.isAvailable ? .accentColor : .red,
            iconBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
            badgeBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12)
        )
    }

    private var optionPanel: some View {
        DashboardControlPanel(title: "Option", systemImage: "filemenu.and.selection") {
            DashboardDetailMenuRow(
                title: "Current",
                systemImage: "checkmark.circle",
                value: entity.state.displayStateText,
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "select", service: "select_option")
            ) {
                ForEach(options, id: \.self) { option in
                    Button {
                        Task { await homeAssistantService.selectOption(entityID: entity.entityID, option: option) }
                    } label: {
                        if option == entity.state {
                            Label(option.displayStateText, systemImage: "checkmark")
                        } else {
                            Text(option.displayStateText)
                        }
                    }
                    .disabled(option == entity.state)
                }
            }
        }
    }

    private var currentPanel: some View {
        DashboardEntityContextPanel(
            title: "Current Value",
            systemImage: "text.word.spacing",
            rows: [
                DashboardEntityDetailRow(title: "State", value: entity.state.displayStateText),
                DashboardEntityDetailRow(title: "Options", value: options.isEmpty ? "None" : "\(options.count)")
            ]
        )
    }

    private var contextDetails: some View {
        DashboardEntityMetadataDisclosure(
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                DashboardEntityDetailRow(title: "Service", value: "select.select_option")
            ]
        )
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Select unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return "Current option"
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "select.house_mode") {
        SelectDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
