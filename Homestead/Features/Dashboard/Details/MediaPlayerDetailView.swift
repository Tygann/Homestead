import SwiftUI

struct MediaPlayerDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var volumePercentage = 50.0
    @State private var isEditingVolume = false

    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        DashboardEntityDetailScaffold(title: "Media Player", presentationStyle: presentationStyle) {
            header
            nowPlayingPanel
            playbackControls
            if let mediaPlayer = entityBox.mediaPlayerEntity {
                if mediaPlayer.volumeLevel != nil,
                   homeAssistantService.serviceActionAvailable(domain: "media_player", service: "volume_set") {
                    volumeControls(mediaPlayer)
                }

                if !mediaPlayer.sourceList.isEmpty,
                   homeAssistantService.serviceActionAvailable(domain: "media_player", service: "select_source") {
                    sourceControls(mediaPlayer)
                }
            }
            contextDetails
        }
        .onAppear {
            syncVolume()
        }
        .onChange(of: entityBox.mediaPlayerEntity?.volumeLevel) { _, _ in
            guard !isEditingVolume else { return }
            syncVolume()
        }
    }

    private var header: some View {
        DashboardEntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: mediaHeaderSubtitle,
            badge: mediaHeaderBadge,
            iconColor: iconColor,
            badgeColor: statusColor,
            iconBackground: iconBackground,
            badgeBackground: statusBackground
        )
    }

    @ViewBuilder
    private var nowPlayingPanel: some View {
        if let mediaPlayer = entityBox.mediaPlayerEntity,
           let nowPlayingText = mediaPlayer.nowPlayingText {
            DashboardControlPanel(title: "Now Playing", systemImage: "music.note") {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(nowPlayingText)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if let source = mediaPlayer.source, !source.isEmpty {
                        Text(source)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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

            DashboardDetailLevelSlider(
                value: $volumePercentage,
                range: 0...100,
                step: 1,
                isDisabled: !mediaPlayer.isAvailable || entityBox.pendingCommand != nil,
                accessibilityLabel: "Volume",
                accessibilityValue: "\(Int(volumePercentage)) percent",
                onEditingChanged: { editing in
                    isEditingVolume = editing
                },
                onCommit: { value in
                    setVolume(value, mediaPlayer: mediaPlayer)
                }
            )
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
                    DashboardDetailPillButton(
                        title: source,
                        isSelected: source == mediaPlayer.source,
                        isDisabled: !mediaPlayer.isAvailable || entityBox.pendingCommand != nil || source == mediaPlayer.source
                    ) {
                        Task {
                            await homeAssistantService.selectMediaSource(
                                entityID: mediaPlayer.entityID,
                                source: source
                            )
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var playbackControls: some View {
        DashboardControlPanel(title: "Playback", systemImage: playPauseSystemImage) {
            DashboardDetailActionButton(
                title: playPauseTitle,
                systemImage: playPauseSystemImage,
                style: entity.state == "playing" ? .secondary : .primary,
                isDisabled: entityBox.pendingCommand != nil || !entity.isAvailable || !homeAssistantService.serviceActionAvailable(domain: "media_player", service: "media_play_pause")
            ) {
                Task {
                    await homeAssistantService.playPauseMedia(entityID: entity.entityID)
                }
            }
        }
    }

    private var contextDetails: some View {
        DashboardEntityMetadataDisclosure(
            title: "Home Assistant",
            systemImage: "play.tv.fill",
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
        if entityBox.pendingCommand != nil { return "Waiting for Home Assistant confirmation" }
        if let source = entityBox.mediaPlayerEntity?.source, !source.isEmpty {
            return source
        }
        return presentation.isActive ? "Currently playing" : "Ready for playback"
    }

    private var mediaHeaderSubtitle: String {
        guard let mediaPlayer = entityBox.mediaPlayerEntity else { return statusSummary }
        if let source = mediaPlayer.source, !source.isEmpty {
            return "\(mediaPlayer.displayState) • \(source)"
        }

        return statusSummary
    }

    private var mediaHeaderBadge: String {
        entityBox.mediaPlayerEntity?.displayState ?? presentation.subtitle
    }

    private func setVolume(_ updatedVolume: Double, mediaPlayer: MediaPlayerEntity) {
        volumePercentage = updatedVolume

        Task {
            await homeAssistantService.setMediaVolume(
                entityID: mediaPlayer.entityID,
                volumePercentage: updatedVolume
            )
        }
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
        if entityBox.pendingCommand != nil {
            return "Updating..."
        }

        return switch entity.state {
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
