import SwiftUI

struct ActionEntityDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        DashboardEntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            header
            actionPanel
            stateDetails
        }
    }

    private var header: some View {
        DashboardEntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: statusSummary,
            badge: presentation.subtitle,
            iconColor: iconColor,
            badgeColor: presentation.isAvailable ? iconColor : .red,
            badgeBackground: badgeBackground
        )
    }

    private var actionPanel: some View {
        DashboardControlPanel(title: "Action", systemImage: actionSystemImage) {
            DashboardDetailActionButton(
                title: actionTitle,
                systemImage: actionSystemImage,
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !isActionServiceAvailable
            ) {
                Task { await performAction() }
            }
        }
    }

    private var stateDetails: some View {
        DashboardEntityMetadataDisclosure(
            title: "Home Assistant",
            systemImage: "bolt.horizontal",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                DashboardEntityDetailRow(title: "Service", value: actionServiceName)
            ]
        )
    }

    private var navigationTitle: String {
        switch entity.domain {
        case .scene:
            "Scene"
        case .script:
            "Script"
        default:
            "Action"
        }
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "\(navigationTitle) unavailable" }
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
            await homeAssistantService.activateScene(entityID: entity.entityID)
        case .script:
            await homeAssistantService.runScript(entityID: entity.entityID)
        default:
            break
        }
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
