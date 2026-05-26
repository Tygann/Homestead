import SwiftUI

struct ToggleEntityDetailView: View {
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
                    actionButton
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
                    .foregroundStyle(presentation.isActive ? presentation.accentColor : Color.secondary)
                    .frame(width: 64, height: 64)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(presentation.subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(presentation.isAvailable ? presentation.headlineColor : Color.red)
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

    private var actionButton: some View {
        Button {
            Task { await performPrimaryAction() }
        } label: {
            Label(actionTitle, systemImage: actionSystemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(entityBox.pendingCommand != nil || !entity.isAvailable)
    }

    private var stateDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Current State", systemImage: "waveform.path.ecg")
                .font(.headline)

            HStack {
                Text(entity.state.replacingOccurrences(of: "_", with: " ").capitalized)
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
        case .switch:
            "Switch"
        case .fan:
            "Fan"
        case .lock:
            "Lock"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            "Entity"
        }
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "\(navigationTitle) unavailable" }

        if entityBox.pendingCommand != nil {
            return "Waiting for Home Assistant confirmation"
        }

        switch entity.domain {
        case .lock:
            return entity.state == "locked" ? "Secured" : "Needs attention"
        case .switch, .fan:
            return presentation.isActive ? "Currently active" : "Currently idle"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            return presentation.subtitle
        }
    }

    private var actionTitle: String {
        if entityBox.pendingCommand != nil {
            return "Updating..."
        }

        switch entity.domain {
        case .lock:
            return entity.state == "locked" ? "Unlock" : "Lock"
        case .switch, .fan:
            return presentation.isActive ? "Turn Off" : "Turn On"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            return "Update"
        }
    }

    private var actionSystemImage: String {
        switch entity.domain {
        case .lock:
            return entity.state == "locked" ? "lock.open" : "lock"
        case .fan:
            return "fan"
        case .switch:
            return "power"
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            return "checkmark"
        }
    }

    private var iconBackground: Color {
        presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var badgeBackground: Color {
        guard presentation.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func performPrimaryAction() async {
        switch entity.domain {
        case .switch:
            await homeAssistantService.toggleSwitch(entityID: entity.entityID)
        case .fan:
            await homeAssistantService.toggleFan(entityID: entity.entityID)
        case .lock:
            await homeAssistantService.toggleLock(entityID: entity.entityID)
        case .light, .climate, .cover, .sensor, .binarySensor, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            break
        }
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "switch.coffee_maker") {
        ToggleEntityDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
