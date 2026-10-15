import SwiftUI
import AVKit
import Combine
#if DEBUG
import os
#endif
#if canImport(UIKit)
import UIKit
#endif

struct CameraDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.scenePhase) private var scenePhase
    @State private var webRTC = CameraWebRTCPlayback()
    @State private var usesWebRTC = false
    @State private var fallbackGeneration = 0
    @State private var restartOnForeground = false
    @State private var cameraIsActive = true
    @State private var snapshotPhase: SnapshotPhase = .idle
    @State private var capabilitiesPhase: CameraCapabilitiesPhase = .idle
    @State private var livePhase: CameraLivePhase = .idle
    @State private var player: AVPlayer?
    @State private var refreshGeneration = 0
    @State private var loadAttemptID = UUID()
    @State private var playbackReadiness = CameraPlaybackReadiness()
    #if DEBUG
    @State private var loadStartedAt: Date?
    #endif
    @State private var isShowingFullScreenPreview = false

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
        EntityDetailScaffold(title: entity.displayName, presentationStyle: presentationStyle) {
            header
            cameraViewPanel
            EntityActivityHistoryPreview(entityBox: entityBox, tint: presentation.accentColor)
            contextDetails
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    refreshCamera()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(detailState.blocksControlInteraction || snapshotPhase.isLoading)
            }
        }
        .fullScreenCover(isPresented: $isShowingFullScreenPreview) {
            CameraFullScreenPreview(
                title: presentation.title,
                player: player,
                webRTC: webRTC,
                usesWebRTC: usesWebRTC,
                playbackReadiness: $playbackReadiness,
                isCurrentPlayer: { self.player === $0 },
                playbackStarted: { recordStartupStage("Playback playing") },
                playbackFailed: handlePlaybackFailure,
                snapshotPhase: snapshotPhase,
                livePhase: livePhase,
                aspectRatio: cameraPreviewAspectRatio
            ) {
                refreshCamera()
            }
        }
        .task(id: "\(entity.entityID)-\(refreshGeneration)-\(fallbackGeneration)-\(homeAssistantService.connectionStatus == .connected)") {
            guard cameraIsActive else { return }
            guard homeAssistantService.connectionStatus == .connected else {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
                    CameraStartupConsole.write("Waiting for Home Assistant connection")
                }
                #endif
                webRTC.stop()
                player?.pause()
                livePhase = .loading
                if case .loaded = snapshotPhase { return }
                if let cached = await CameraSnapshotStore.shared.snapshot(for: entity.entityID) {
                    guard !Task.isCancelled else { return }
                    snapshotPhase = .loaded(cached.data)
                }
                return
            }
            await loadCameraData()
        }
        .onDisappear {
            if !isShowingFullScreenPreview {
                cameraIsActive = false
                webRTC.stop()
                player?.pause()
            }
        }
        .onAppear {
            if !cameraIsActive, scenePhase == .active {
                cameraIsActive = true
                refreshCamera()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                recordStartupStage("Camera suspended")
                cameraIsActive = false
                refreshGeneration += 1
                webRTC.stop()
                player?.pause()
                restartOnForeground = true
            } else if phase == .active, restartOnForeground {
                recordStartupStage("Camera foreground restart")
                restartOnForeground = false
                cameraIsActive = true
                refreshCamera()
            }
        }
    }

    private var header: some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: presentation.icon,
            category: "Camera",
            summary: nil,
            status: nil,
            iconColor: iconColor,
            iconBackground: iconBackground
        )
    }

    private var cameraViewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                Label(cameraPanelTitle, systemImage: cameraPanelSystemImage)
                    .font(.headline)

                Spacer(minLength: AppSpacing.medium)

                Button {
                    isShowingFullScreenPreview = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!canShowFullScreenPreview)
                .accessibilityLabel("Show camera fullscreen")

                cameraPreviewBadge
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.medium)

            cameraViewContent
                .overlay(alignment: .bottomTrailing) {
                    if usesWebRTC, webRTC.hasStarted, webRTC.hasAudio {
                        CameraWebRTCAudioButton(playback: webRTC)
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.45), in: Circle())
                            .padding(AppSpacing.small)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(cameraPreviewAspectRatio, contentMode: .fit)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipped()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    @ViewBuilder
    private var cameraPreviewBadge: some View {
        if let text = cameraPreviewBadgeText {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(cameraPreviewBadgeColor)
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.xSmall)
                .background(cameraPreviewBadgeColor.opacity(0.14), in: Capsule())
        }
    }

    @ViewBuilder
    private var cameraViewContent: some View {
        if !entity.isAvailable {
            unavailableCameraContent(title: "Camera unavailable", systemImage: "video.slash")
        } else {
            switch livePhase {
            case .idle, .loading:
                preparingCameraContent
            case .live:
                if usesWebRTC {
                    ZStack {
                        CameraWebRTCVideo(videoView: webRTC.videoView, isVisible: !isShowingFullScreenPreview)
                            .opacity(webRTC.hasStarted ? 1 : 0.001)
                        .allowsHitTesting(webRTC.hasStarted)
                        if !webRTC.hasStarted { preparingCameraContent }
                    }
                } else if let player {
                    CameraLiveVideoPreview(
                        player: player,
                        readiness: $playbackReadiness,
                        placeholder: preparingCameraContent,
                        isCurrentPlayer: { self.player === player },
                        playbackStarted: { recordStartupStage("Playback playing") },
                        playbackFailed: { handlePlaybackFailure(player) }
                    )
                } else {
                    snapshotContent
                }
            case .snapshotOnly, .failed:
                snapshotContent
            }
        }
    }

    @ViewBuilder
    private var preparingCameraContent: some View {
        if case .loaded = snapshotPhase {
            snapshotContent
                .overlay(alignment: .topTrailing) {
                    ProgressView()
                        .padding(AppSpacing.medium)
                        .background(Color.black.opacity(0.4), in: Circle())
                        .padding(AppSpacing.small)
                }
        } else {
            VStack(spacing: AppSpacing.medium) {
                ProgressView()
                    .controlSize(.large)

                Text("Preparing camera")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var snapshotContent: some View {
        switch snapshotPhase {
        case .idle, .loading:
            ProgressView()
                .controlSize(.large)
        case .loaded(let data):
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            } else {
                unavailableSnapshotContent
            }
            #else
            unavailableSnapshotContent
            #endif
        case .failed:
            unavailableSnapshotContent
        }
    }

    private var unavailableSnapshotContent: some View {
        unavailableCameraContent(title: "Snapshot unavailable", systemImage: "camera.fill")
    }

    private func unavailableCameraContent(title: String, systemImage: String) -> some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "camera.fill",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "Live", value: liveCapabilityText),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Camera unavailable" }
        return "Available"
    }

    private var iconColor: Color {
        entity.isAvailable ? presentation.accentColor : .secondary
    }

    private var statusColor: Color {
        entity.isAvailable ? presentation.accentColor : .red
    }

    private var iconBackground: Color {
        entity.isAvailable ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var statusBackground: Color {
        entity.isAvailable ? presentation.accentColor.opacity(0.12) : Color.red.opacity(0.12)
    }

    private var liveCapabilityText: String {
        switch capabilitiesPhase {
        case .idle, .loading:
            "Checking"
        case .loaded(let capabilities):
            switch livePhase {
            case .live:
                usesWebRTC ? "Live WebRTC" : "Live HLS"
            case .failed:
                "Snapshot fallback (\(capabilities.displayText))"
            case .snapshotOnly:
                capabilities.supportsLiveStream ? "Snapshot fallback (\(capabilities.displayText))" : capabilities.displayText
            case .idle, .loading:
                capabilities.displayText
            }
        case .failed:
            "Snapshot fallback"
        }
    }

    private var cameraPanelTitle: String {
        "Camera Preview"
    }

    private var cameraPanelSystemImage: String {
        switch livePhase {
        case .live, .loading:
            "video.fill"
        case .idle, .snapshotOnly, .failed:
            "camera.viewfinder"
        }
    }

    private var cameraPreviewBadgeText: String? {
        switch livePhase {
        case .live:
            hasStartedPlayback ? "Live" : "Preparing"
        case .snapshotOnly:
            "Snapshot"
        case .failed:
            "Fallback"
        case .loading:
            "Loading"
        case .idle:
            nil
        }
    }

    private var cameraPreviewBadgeColor: Color {
        switch livePhase {
        case .live:
            hasStartedPlayback ? .green : .secondary
        case .failed:
            .orange
        default:
            .secondary
        }
    }

    private var canShowFullScreenPreview: Bool {
        guard entity.isAvailable else { return false }

        switch livePhase {
        case .live:
            return usesWebRTC || player != nil
        case .snapshotOnly, .failed:
            if case .loaded = snapshotPhase {
                return true
            }
            return false
        case .idle, .loading:
            return false
        }
    }

    private var cameraPreviewAspectRatio: CGFloat {
        #if canImport(UIKit)
        if case .loaded(let data) = snapshotPhase,
           let image = UIImage(data: data),
           image.size.height > 0 {
            return image.size.width / image.size.height
        }
        #endif

        return 16.0 / 9.0
    }

    private var shouldAttemptWebRTC: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--camera-force-hls") { return false }
        #endif
        return fallbackGeneration == 0
    }

    private var hasStartedPlayback: Bool {
        usesWebRTC ? webRTC.hasStarted : playbackReadiness.hasStarted
    }

    private func refreshCamera() {
        fallbackGeneration = 0
        refreshGeneration += 1
    }

    private func handlePlaybackFailure(_ failedPlayer: AVPlayer) {
        guard player === failedPlayer else { return }
        failedPlayer.pause()
        livePhase = .failed
        recordStartupStage("Playback failed")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--camera-startup-console"),
           let error = failedPlayer.currentItem?.error as NSError? {
            CameraStartupConsole.write("HLS error domain: \(error.domain), code: \(error.code)")
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                CameraStartupConsole.write("HLS underlying domain: \(underlying.domain), code: \(underlying.code)")
            }
        }
        #endif
    }

    private func recordStartupStage(_ stage: String) {
        #if DEBUG
        guard let loadStartedAt else { return }
        let milliseconds = Date().timeIntervalSince(loadStartedAt) * 1000
        if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
            CameraStartupConsole.write("\(stage): \(Int(milliseconds.rounded())) ms")
        }
        Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup")
            .info("\(stage, privacy: .public): \(milliseconds, format: .fixed(precision: 0)) ms")
        #endif
    }

    private func loadCameraData() async {
        guard !Task.isCancelled else { return }
        #if DEBUG
        loadStartedAt = .now
        recordStartupStage("Camera load started")
        #endif
        loadAttemptID = UUID()
        webRTC.stop()
        usesWebRTC = false
        player?.pause()
        player = nil
        playbackReadiness.reset()
        livePhase = .idle
        let cachedSnapshot = await CameraSnapshotStore.shared.snapshot(for: entity.entityID)
        guard !Task.isCancelled else { return }
        if let cachedSnapshot {
            snapshotPhase = .loaded(cachedSnapshot.data)
        } else {
            snapshotPhase = .idle
        }

        guard entity.isAvailable else {
            capabilitiesPhase = .failed
            livePhase = .failed
            snapshotPhase = .failed
            return
        }

        async let snapshotLoad: Void = loadSnapshot()
        let capabilities = await loadCapabilities()
        guard !Task.isCancelled else { return }
        recordStartupStage("Capabilities resolved")
        let loadedLiveStream = await loadLiveStreamIfPossible(capabilities: capabilities)
        await snapshotLoad

        if loadedLiveStream {
            return
        }
    }

    private func loadSnapshot() async {
        guard !Task.isCancelled else { return }
        guard entity.isAvailable else {
            snapshotPhase = .failed
            return
        }

        let hasCachedSnapshot: Bool
        if case .loaded = snapshotPhase {
            hasCachedSnapshot = true
        } else {
            hasCachedSnapshot = false
            snapshotPhase = .loading
        }

        do {
            let snapshot = try await homeAssistantService.fetchCameraSnapshot(entityID: entity.entityID)
            try Task.checkCancellation()
            recordStartupStage("Snapshot received")
            await CameraSnapshotStore.shared.store(snapshot, for: entity.entityID)
            try Task.checkCancellation()
            snapshotPhase = .loaded(snapshot)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            if !hasCachedSnapshot {
                snapshotPhase = .failed
            }
        }
    }

    @discardableResult
    private func loadCapabilities() async -> HACameraCapabilities? {
        guard !Task.isCancelled else { return nil }
        guard entity.isAvailable else {
            capabilitiesPhase = .failed
            return nil
        }

        capabilitiesPhase = .loading
        do {
            let capabilities = try await homeAssistantService.fetchCameraCapabilities(entityID: entity.entityID)
            try Task.checkCancellation()
            capabilitiesPhase = .loaded(capabilities)
            return capabilities
        } catch is CancellationError {
            return nil
        } catch {
            guard !Task.isCancelled else { return nil }
            recordStartupStage("Capabilities unavailable")
            capabilitiesPhase = .failed
            return nil
        }
    }

    /// HLS decodes silently offscreen until it has a video frame. Only the winner is exposed.
    private func raceLiveTransports(hlsPreparation: CameraHLSPreparation) async -> Bool {
        let candidate = CameraHLSVideoCandidate()
        let attemptID = loadAttemptID
        let generation = refreshGeneration
        usesWebRTC = true
        livePhase = .live
        // A previously unmuted native session must not compete with speculative HLS audio.
        webRTC.isPlaybackSelected = false
        recordStartupStage("WebRTC attempt")
        let winner = await CameraPlaybackRace.firstVideo {
            guard !Task.isCancelled, loadAttemptID == attemptID else { return false }
            let started = await webRTC.start(service: homeAssistantService, entityID: entity.entityID) {
                guard cameraIsActive, usesWebRTC, loadAttemptID == attemptID, refreshGeneration == generation else { return }
                fallbackGeneration += 1
            }
            if !started, !Task.isCancelled { hlsPreparation.startFallback() }
            return started
        } hls: {
            do {
                let url = try await hlsPreparation.scheduledValue()
                try Task.checkCancellation()
                recordStartupStage("HLS speculative playback started")
                return try await candidate.prepare(url: url)
            } catch {
                candidate.stop()
                return false
            }
        }
        guard !Task.isCancelled, cameraIsActive, loadAttemptID == attemptID, refreshGeneration == generation else {
            candidate.stop()
            if loadAttemptID == attemptID { webRTC.stop() }
            return false
        }
        switch winner {
        case .webRTC:
            candidate.stop()
            webRTC.isPlaybackSelected = true
            recordStartupStage("WebRTC first frame")
            return true
        case .hls:
            // Tear down native audio ownership before enabling the winning player's audio.
            webRTC.stop()
            usesWebRTC = false
            player = candidate.player
            player?.isMuted = false
            livePhase = .live
            recordStartupStage("HLS first video selected")
            return true
        case nil:
            candidate.stop()
            webRTC.stop()
            usesWebRTC = false
            livePhase = .failed
            return false
        }
    }

    private func loadLiveStreamIfPossible(capabilities: HACameraCapabilities?) async -> Bool {
        guard !Task.isCancelled, cameraIsActive else { return false }
        let hlsPreparation: CameraHLSPreparation?
        if capabilities?.supportsWebRTCStream == true, shouldAttemptWebRTC,
           capabilities?.supportsHLSStream == true {
            hlsPreparation = CameraHLSPreparation {
                try Task.checkCancellation()
                recordStartupStage("HLS preparation started")
                let url = try await homeAssistantService.cameraHLSStreamURL(entityID: entity.entityID)
                try Task.checkCancellation()
                recordStartupStage("HLS preparation ready")
                return url
            }
        } else {
            hlsPreparation = nil
        }
        defer { hlsPreparation?.cancel() }
        if let hlsPreparation {
            return await raceLiveTransports(hlsPreparation: hlsPreparation)
        }
        if capabilities?.supportsWebRTCStream == true, shouldAttemptWebRTC {
            webRTC.isPlaybackSelected = true
            recordStartupStage("WebRTC attempt")
            usesWebRTC = true
            livePhase = .live
            let generation = refreshGeneration
            let started = await withTaskCancellationHandler {
                await webRTC.start(service: homeAssistantService, entityID: entity.entityID, onFailure: {
                    guard cameraIsActive, usesWebRTC, refreshGeneration == generation else { return }
                    recordStartupStage("WebRTC fallback")
                    fallbackGeneration += 1
                })
            } onCancel: {
                Task { @MainActor in hlsPreparation?.cancel() }
            }
            if started {
                recordStartupStage("WebRTC first frame")
                return true
            }
            guard !Task.isCancelled, cameraIsActive else { return false }
            recordStartupStage("WebRTC fallback")
            usesWebRTC = false
        }
        guard capabilities?.supportsHLSStream == true else {
            livePhase = .snapshotOnly
            return false
        }

        livePhase = .loading
        do {
            let url: URL
            if let hlsPreparation {
                url = try await hlsPreparation.value()
            } else {
                url = try await homeAssistantService.cameraHLSStreamURL(entityID: entity.entityID)
            }
            try Task.checkCancellation()
            guard cameraIsActive else { return false }
            recordStartupStage("Stream handoff received")
            let player = AVPlayer(url: url)
            self.player = player
            livePhase = .live
            player.play()
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard !Task.isCancelled, cameraIsActive else { return false }
            livePhase = .failed
            return false
        }
    }
}

private struct CameraLiveVideoPreview<Placeholder: View>: View {
    let player: AVPlayer
    @Binding var readiness: CameraPlaybackReadiness
    let placeholder: Placeholder
    let isCurrentPlayer: () -> Bool
    let playbackStarted: () -> Void
    let playbackFailed: () -> Void

    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .opacity(readiness.hasStarted ? 1 : 0)
                .allowsHitTesting(readiness.hasStarted)

            if !readiness.hasStarted {
                placeholder
            }
        }
        .onAppear { player.play() }
        .onReceive(player.publisher(for: \.timeControlStatus).receive(on: RunLoop.main)) { status in
            guard isCurrentPlayer(), readiness.observe(status) else { return }
            playbackStarted()
        }
        .onReceive(player.publisher(for: \.currentItem)
            .compactMap { $0 }
            .map { $0.publisher(for: \.status) }
            .switchToLatest()
            .receive(on: RunLoop.main)
        ) { status in
            guard isCurrentPlayer(), status == .failed else { return }
            playbackFailed()
        }
    }
}

private struct CameraFullScreenPreview: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let player: AVPlayer?
    let webRTC: CameraWebRTCPlayback
    let usesWebRTC: Bool
    @Binding var playbackReadiness: CameraPlaybackReadiness
    let isCurrentPlayer: (AVPlayer) -> Bool
    let playbackStarted: () -> Void
    let playbackFailed: (AVPlayer) -> Void
    let snapshotPhase: SnapshotPhase
    let livePhase: CameraLivePhase
    let aspectRatio: CGFloat
    let refresh: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            previewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(aspectRatio, contentMode: .fit)
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                if usesWebRTC, webRTC.hasStarted, webRTC.hasAudio {
                    CameraWebRTCAudioButton(playback: webRTC)
                        .foregroundStyle(.white)
                }

                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline.weight(.semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Refresh camera")

                Button("Done") {
                    dismiss()
                }
                .font(.headline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.18))
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .background(Color.black.opacity(0.72))
        }
        .onAppear {
            player?.play()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch livePhase {
        case .live:
            if usesWebRTC {
                ZStack {
                    CameraWebRTCVideo(videoView: webRTC.videoView)
                        .opacity(webRTC.hasStarted ? 1 : 0.001)
                        .allowsHitTesting(webRTC.hasStarted)
                    if !webRTC.hasStarted { preparingContent }
                }
            } else if let player {
                CameraLiveVideoPreview(
                    player: player,
                    readiness: $playbackReadiness,
                    placeholder: preparingContent,
                    isCurrentPlayer: { isCurrentPlayer(player) },
                    playbackStarted: playbackStarted,
                    playbackFailed: { playbackFailed(player) }
                )
            } else {
                snapshotContent
            }
        case .snapshotOnly, .failed, .idle, .loading:
            snapshotContent
        }
    }

    @ViewBuilder
    private var preparingContent: some View {
        if case .loaded = snapshotPhase {
            snapshotContent.overlay { ProgressView().tint(.white) }
        } else {
            ProgressView().tint(.white)
        }
    }

    @ViewBuilder
    private var snapshotContent: some View {
        switch snapshotPhase {
        case .loaded(let data):
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                unavailableContent
            }
            #else
            unavailableContent
            #endif
        case .idle, .loading, .failed:
            unavailableContent
        }
    }

    private var unavailableContent: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40, weight: .semibold))

            Text("Camera preview unavailable")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
    }

    private var statusText: String {
        switch livePhase {
        case .live:
            (usesWebRTC ? webRTC.hasStarted : playbackReadiness.hasStarted) ? "Live" : "Preparing"
        case .snapshotOnly:
            "Snapshot"
        case .failed:
            "Snapshot fallback"
        case .loading:
            "Loading"
        case .idle:
            "Preview"
        }
    }

    private var statusColor: Color {
        switch livePhase {
        case .live:
            (usesWebRTC ? webRTC.hasStarted : playbackReadiness.hasStarted) ? .green : .secondary
        case .failed:
            .orange
        default:
            .secondary
        }
    }
}

private enum SnapshotPhase: Equatable {
    case idle
    case loading
    case loaded(Data)
    case failed

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}

private enum CameraCapabilitiesPhase: Equatable {
    case idle
    case loading
    case loaded(HACameraCapabilities)
    case failed
}

private enum CameraLivePhase: Equatable {
    case idle
    case loading
    case live
    case snapshotOnly
    case failed
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "camera.driveway") {
        CameraDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
