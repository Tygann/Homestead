import SwiftUI
import AVKit
#if canImport(UIKit)
import UIKit
#endif

struct CameraDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var snapshotPhase: SnapshotPhase = .idle
    @State private var capabilitiesPhase: CameraCapabilitiesPhase = .idle
    @State private var livePhase: CameraLivePhase = .idle
    @State private var player: AVPlayer?
    @State private var isShowingFullScreenPreview = false

    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                header
                cameraViewPanel
                contextDetails
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadCameraData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!entity.isAvailable || snapshotPhase.isLoading)
            }
        }
        .dashboardDetailPresentation(title: "Camera", style: presentationStyle)
        .fullScreenCover(isPresented: $isShowingFullScreenPreview) {
            CameraFullScreenPreview(
                title: presentation.title,
                player: player,
                snapshotPhase: snapshotPhase,
                livePhase: livePhase,
                aspectRatio: cameraPreviewAspectRatio
            ) {
                Task { await loadCameraData() }
            }
        }
        .task(id: entity.entityID) {
            await loadCameraData()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var header: some View {
        DashboardEntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: statusSummary,
            badge: presentation.subtitle,
            iconColor: iconColor,
            badgeColor: statusColor,
            iconBackground: iconBackground,
            badgeBackground: statusBackground
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
                VStack(spacing: AppSpacing.medium) {
                    ProgressView()
                        .controlSize(.large)

                    Text("Preparing camera")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            case .live:
                if let player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity)
                        .onAppear {
                            player.play()
                        }
                } else {
                    snapshotContent
                }
            case .snapshotOnly, .failed:
                snapshotContent
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
        DashboardEntityMetadataDisclosure(
            title: "Home Assistant",
            systemImage: "camera.fill",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                DashboardEntityDetailRow(title: "Live", value: liveCapabilityText),
                DashboardEntityDetailRow(title: "State", value: entity.state.displayStateText)
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
                "Live HLS"
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
            "Live"
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
            .green
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
            return player != nil
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

    private func loadCameraData() async {
        player?.pause()
        player = nil
        livePhase = .idle
        snapshotPhase = .idle

        guard entity.isAvailable else {
            capabilitiesPhase = .failed
            livePhase = .failed
            snapshotPhase = .failed
            return
        }

        let capabilities = await loadCapabilities()

        if await loadLiveStreamIfPossible(capabilities: capabilities) {
            return
        }

        await loadSnapshot()
    }

    private func loadSnapshot() async {
        guard entity.isAvailable else {
            snapshotPhase = .failed
            return
        }

        snapshotPhase = .loading
        do {
            snapshotPhase = .loaded(try await homeAssistantService.fetchCameraSnapshot(entityID: entity.entityID))
        } catch {
            snapshotPhase = .failed
        }
    }

    @discardableResult
    private func loadCapabilities() async -> HACameraCapabilities? {
        guard entity.isAvailable else {
            capabilitiesPhase = .failed
            return nil
        }

        capabilitiesPhase = .loading
        do {
            let capabilities = try await homeAssistantService.fetchCameraCapabilities(entityID: entity.entityID)
            capabilitiesPhase = .loaded(capabilities)
            return capabilities
        } catch {
            capabilitiesPhase = .failed
            return nil
        }
    }

    private func loadLiveStreamIfPossible(capabilities: HACameraCapabilities?) async -> Bool {
        guard capabilities?.supportsHLSStream == true else {
            livePhase = .snapshotOnly
            return false
        }

        livePhase = .loading
        do {
            let handoff = try await homeAssistantService.prepareCameraStreamHandoff(entityID: entity.entityID)
            guard let hlsPath = handoff.hlsPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !hlsPath.isEmpty else {
                livePhase = .snapshotOnly
                return false
            }

            let url = try homeAssistantService.cameraStreamURL(pathOrURL: hlsPath, entityID: entity.entityID)
            let player = AVPlayer(url: url)
            self.player = player
            livePhase = .live
            player.play()
            return true
        } catch {
            livePhase = .failed
            return false
        }
    }
}

private struct CameraFullScreenPreview: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let player: AVPlayer?
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
            if let player {
                VideoPlayer(player: player)
            } else {
                snapshotContent
            }
        case .snapshotOnly, .failed, .idle, .loading:
            snapshotContent
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
            "Live"
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
            .green
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
