import SwiftUI

struct MediaPlayerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var volumePercentage = 50.0
    @State private var isEditingVolume = false

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
                    playbackControls
                    if let mediaPlayer = entityBox.mediaPlayerEntity {
                        if mediaPlayer.volumeLevel != nil {
                            volumeControls(mediaPlayer)
                        }

                        if !mediaPlayer.sourceList.isEmpty {
                            sourceControls(mediaPlayer)
                        }
                    }
                    contextDetails
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Media Player")
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
        .onAppear {
            syncVolume()
        }
        .onChange(of: entityBox.mediaPlayerEntity?.volumeLevel) { _, _ in
            guard !isEditingVolume else { return }
            syncVolume()
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 64, height: 64)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(presentation.subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(statusBackground, in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(entityBox.mediaPlayerEntity?.nowPlayingText ?? statusSummary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func volumeControls(_ mediaPlayer: MediaPlayerEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Label("Volume", systemImage: "speaker.wave.2.fill")
                    .font(.headline)

                Spacer()

                Text("\(Int(volumePercentage))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(mediaPlayer.isPlaying ? Color.accentColor : Color.secondary)
            }

            Slider(
                value: $volumePercentage,
                in: 0...100,
                step: 1,
                onEditingChanged: { editing in
                    isEditingVolume = editing
                    guard !editing else { return }

                    Task {
                        await homeAssistantService.setMediaVolume(
                            entityID: mediaPlayer.entityID,
                            volumePercentage: volumePercentage
                        )
                    }
                }
            )
            .disabled(!mediaPlayer.isAvailable || entityBox.pendingCommand != nil)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int(volumePercentage)) percent")
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func sourceControls(_ mediaPlayer: MediaPlayerEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Source", systemImage: "airplayaudio")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: AppSpacing.small)], spacing: AppSpacing.small) {
                ForEach(mediaPlayer.sourceList, id: \.self) { source in
                    Button {
                        Task {
                            await homeAssistantService.selectMediaSource(
                                entityID: mediaPlayer.entityID,
                                source: source
                            )
                        }
                    } label: {
                        Text(source)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(source == mediaPlayer.source ? Color.white : Color.primary)
                    .background(source == mediaPlayer.source ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
                    .disabled(!mediaPlayer.isAvailable || entityBox.pendingCommand != nil || source == mediaPlayer.source)
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var playbackControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Button {
                Task {
                    await homeAssistantService.playPauseMedia(entityID: entity.entityID)
                }
            } label: {
                Label(playPauseTitle, systemImage: playPauseSystemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!entity.isAvailable)

        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var contextDetails: some View {
        DashboardEntityContextPanel(
            title: "Home Assistant",
            systemImage: "play.tv",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                sourceDetailRow,
                volumeDetailRow,
                DashboardEntityDetailRow(title: "State", value: entity.state.displayStateText)
            ].compactMap { $0 }
        )
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Media player unavailable" }
        if let source = entityBox.mediaPlayerEntity?.source, !source.isEmpty {
            return source
        }
        return presentation.isActive ? "Currently playing" : "Ready for playback"
    }

    private var sourceDetailRow: DashboardEntityDetailRow? {
        guard let source = entityBox.mediaPlayerEntity?.source, !source.isEmpty else {
            return nil
        }

        return DashboardEntityDetailRow(title: "Source", value: source)
    }

    private var volumeDetailRow: DashboardEntityDetailRow? {
        guard let volumePercentage = entityBox.mediaPlayerEntity?.volumePercentage else {
            return nil
        }

        return DashboardEntityDetailRow(title: "Volume", value: "\(volumePercentage)%")
    }

    private var playPauseTitle: String {
        switch entity.state {
        case "playing":
            "Pause"
        case "paused":
            "Play"
        default:
            "Play/Pause"
        }
    }

    private var playPauseSystemImage: String {
        entity.state == "playing" ? "pause.fill" : "play.fill"
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        return presentation.isActive ? presentation.accentColor : .secondary
    }

    private var statusColor: Color {
        guard entity.isAvailable else { return .red }
        return presentation.isActive ? presentation.accentColor : .primary
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var statusBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func syncVolume() {
        if let volumePercentage = entityBox.mediaPlayerEntity?.volumePercentage {
            self.volumePercentage = Double(volumePercentage)
        }
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "media_player.living_room") {
        MediaPlayerDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
