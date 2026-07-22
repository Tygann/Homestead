import SwiftUI

struct ActionEntityDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?
    @State private var scriptOverviewPhase: ScriptOverviewPhase = .loading

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: EntityDetailPresentationModel {
        EntityDetailPresentationModel(entityBox: entityBox)
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            header
            actionPanel
            scriptOverviewPanel
            stateDetails
        }
        .task(id: entity.entityID) {
            guard entity.domain == .script else { return }
            await refreshScriptOverview()
        }
        .actionConfirmationDialog(request: $confirmationRequest)
    }

    private var header: some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: presentation.icon,
            category: entityCategory,
            summary: nil,
            status: entity.state == "on"
                ? EntityDetailStatusPresentation(text: "Running", tone: .positive)
                : nil,
            iconColor: iconColor,
            iconBackground: badgeBackground
        )
    }

    private var actionPanel: some View {
        EntityControlPanel(title: "Action", systemImage: actionSystemImage) {
            EntityDetailActionButton(
                title: actionTitle,
                systemImage: actionSystemImage,
                isDisabled: detailState.blocksControlInteraction || !isActionServiceAvailable
            ) {
                Task { await performAction() }
            }
        }
    }

    private var stateDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "bolt.horizontal",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "Service", value: actionServiceName)
            ]
        )
    }

    @ViewBuilder
    private var scriptOverviewPanel: some View {
        if entity.domain == .script {
            switch scriptOverviewPhase {
            case .loading:
                EntityControlPanel(title: "Script Logic", systemImage: "list.bullet.rectangle") {
                    ProgressView("Loading script logic")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .loaded(let overview):
                AutomationLogicOverviewView(overview: overview, kind: .script)
            case .unavailable:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    private var navigationTitle: String {
        entity.displayName
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "\(entityCategory) unavailable" }
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }

        switch entity.domain {
        case .scene:
            return "Ready to activate"
        case .script:
            return entity.state == "on" ? "Currently running" : "Ready to run"
        default:
            return presentation.subtitle
        }
    }

    private var entityCategory: String {
        EntityCapabilityRegistry.profile(for: entity.domain).categoryTitle
    }

    private var actionTitle: String {
        if entityBox.pendingCommand != nil {
            return "Updating..."
        }

        return switch entity.domain {
        case .scene:
            "Activate Scene"
        case .script:
            entity.state == "on" ? "Run Again" : "Run Script"
        default:
            "Run"
        }
    }

    private var actionSystemImage: String {
        switch entity.domain {
        case .scene:
            "sparkles"
        case .script:
            "play.fill"
        default:
            "bolt.fill"
        }
    }

    private var actionServiceName: String {
        switch entity.domain {
        case .scene:
            "scene.turn_on"
        case .script:
            "script.turn_on"
        default:
            "\(entity.domain.rawValue).turn_on"
        }
    }

    private var isActionServiceAvailable: Bool {
        switch entity.domain {
        case .scene:
            return homeAssistantService.serviceActionAvailable(domain: "scene", service: "turn_on")
        case .script:
            return homeAssistantService.serviceActionAvailable(domain: "script", service: "turn_on")
        default:
            return false
        }
    }

    private var iconColor: Color {
        guard presentation.isAvailable else { return .secondary }
        return presentation.accentColor
    }

    private var badgeBackground: Color {
        guard presentation.isAvailable else { return Color.red.opacity(0.12) }
        return iconColor.opacity(0.12)
    }

    private func performAction() async {
        switch entity.domain {
        case .scene:
            await confirmOrPerform(domain: "scene", service: "turn_on") {
                await homeAssistantService.activateScene(entityID: entity.entityID)
            }
        case .script:
            await confirmOrPerform(domain: "script", service: "turn_on") {
                await homeAssistantService.runScript(entityID: entity.entityID)
            }
        default:
            break
        }
    }

    @MainActor
    private func refreshScriptOverview() async {
        scriptOverviewPhase = .loading
        do {
            scriptOverviewPhase = .loaded(try await homeAssistantService.fetchScriptOverview(entityID: entity.entityID))
        } catch {
            scriptOverviewPhase = .unavailable
        }
    }

    private func confirmOrPerform(
        domain: String,
        service: String,
        perform: @escaping () async -> Void
    ) async {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: domain,
            service: service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            await perform()
            return
        }

        confirmationRequest = ActionConfirmationRequest(
            presentation: presentation,
            perform: {
                Task { await perform() }
            }
        )
    }

    private enum ScriptOverviewPhase: Equatable {
        case loading
        case loaded(HAAutomationOverview)
        case unavailable
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "scene.movie_night") {
        ActionEntityDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
