import SwiftUI

struct SelectDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmationRequest: ActionConfirmationRequest?

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: EntityDetailPresentationModel {
        EntityDetailPresentationModel(entityBox: entityBox)
    }

    private var options: [String] {
        entityBox.selectEntity?.options ?? []
    }

    private var optionPresentation: EntityOptionSelectionPresentation {
        EntityOptionSelectionPresentation(
            options: options,
            selectedValue: entityBox.pendingCommand?.expectedState ?? entity.state
        )
    }

    private var serviceDomain: String {
        HomeAssistantService.selectServiceDomain(for: entity.entityID)
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    var body: some View {
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header

            if dynamicTypeSize.isAccessibilitySize && !options.isEmpty {
                optionPanel
            }

            EntityActivityHistoryPreview(entityBox: entityBox, tint: presentation.accentColor)
            contextDetails
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize || options.isEmpty {
                EntityDetailHeroCard(
                    icon: presentation.icon,
                    title: "Select",
                    subtitle: EntityDetailHeroSubtitle.updated(
                        entity,
                        summary: optionPresentation.selectedDisplayValue
                    ),
                    status: nil,
                    iconColor: entity.isAvailable ? .accentColor : .secondary,
                    statusColor: entity.isAvailable ? .accentColor : .red,
                    iconBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
                    statusBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12),
                    statePresentation: detailState
                ) {
                    EmptyView()
                }
            } else {
                EntityDetailHeroCard(
                    icon: presentation.icon,
                    title: "Select",
                    subtitle: EntityDetailHeroSubtitle.updated(entity),
                    status: nil,
                    iconColor: entity.isAvailable ? .accentColor : .secondary,
                    statusColor: entity.isAvailable ? .accentColor : .red,
                    iconBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground),
                    statusBackground: entity.isAvailable ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.12),
                    statePresentation: detailState,
                    accessory: {
                        optionMenu(style: .heroAccessory)
                    },
                    content: {
                        EmptyView()
                    }
                )
            }
        }
    }

    private var optionPanel: some View {
        EntityControlPanel(title: "Controls", systemImage: "filemenu.and.selection") {
            optionMenu(style: .controlRow)
        }
    }

    private func optionMenu(style: EntityOptionMenuStyle) -> some View {
        EntityOptionMenu(
            presentation: optionPresentation,
            style: style,
            isDisabled: isControlDisabled
        ) { option in
            confirmOrPerform(domain: serviceDomain, service: "select_option") {
                Task {
                    await homeAssistantService.selectOption(
                        entityID: entity.entityID,
                        option: option
                    )
                }
            }
        }
    }

    private var isControlDisabled: Bool {
        detailState.blocksControlInteraction
            || !homeAssistantService.serviceActionAvailable(
                domain: serviceDomain,
                service: "select_option"
            )
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "Service", value: "\(serviceDomain).select_option")
            ]
        )
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Select unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        return "Current option"
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
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "select.house_mode") {
        SelectDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
