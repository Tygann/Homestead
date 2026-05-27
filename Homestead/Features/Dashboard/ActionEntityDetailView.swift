import SwiftUI

struct ActionEntityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    statusCard
                    runButton
                    stateDetails
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 64, height: 64)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(presentation.subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(presentation.isAvailable ? iconColor : Color.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(badgeBackground, in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(statusSummary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var runButton: some View {
        Button {
            Task { await performAction() }
        } label: {
            Label(actionTitle, systemImage: actionSystemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!entity.isAvailable)
    }

    private var stateDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Home Assistant Action", systemImage: "bolt.horizontal")
                .font(.headline)

            HStack {
                Text(actionServiceName)
                    .font(.body.weight(.medium))

                Spacer()

                Text(entity.entityID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var navigationTitle: String {
        switch entity.domain {
        case .scene:
            "Scene"
        case .script:
            "Script"
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .other:
            "Action"
        }
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "\(navigationTitle) unavailable" }

        switch entity.domain {
        case .scene:
            return "Ready to activate"
        case .script:
            return entity.state == "on" ? "Currently running" : "Ready to run"
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .other:
            return presentation.subtitle
        }
    }

    private var actionTitle: String {
        switch entity.domain {
        case .scene:
            "Activate Scene"
        case .script:
            entity.state == "on" ? "Run Again" : "Run Script"
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .other:
            "Run"
        }
    }

    private var actionSystemImage: String {
        switch entity.domain {
        case .scene:
            "sparkles"
        case .script:
            "play.fill"
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .other:
            "bolt.fill"
        }
    }

    private var actionServiceName: String {
        switch entity.domain {
        case .scene:
            "scene.turn_on"
        case .script:
            "script.turn_on"
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .other:
            "\(entity.domain.rawValue).turn_on"
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
        case .light, .climate, .cover, .sensor, .binarySensor, .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .other:
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
