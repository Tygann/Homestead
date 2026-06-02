import SwiftUI
import AVKit
#if canImport(UIKit)
import UIKit
#endif

struct CameraDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var snapshotPhase: SnapshotPhase = .idle
    @State private var capabilitiesPhase: CameraCapabilitiesPhase = .idle
    @State private var livePhase: CameraLivePhase = .idle
    @State private var player: AVPlayer?

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
                    cameraViewPanel
                    statusCard
                    contextDetails
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Camera")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadCameraData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!entity.isAvailable || snapshotPhase.isLoading)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: entity.entityID) {
            await loadCameraData()
        }
        .onDisappear {
            player?.pause()
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

                Text(statusSummary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var cameraViewPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                Label(cameraPanelTitle, systemImage: cameraPanelSystemImage)
                    .font(.headline)

                Spacer(minLength: AppSpacing.medium)

                if case .live = livePhase {
                    Text("Live")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.xSmall)
                        .background(Color.green.opacity(0.14), in: Capsule())
                }
            }

            cameraViewContent
                .frame(maxWidth: .infinity)
                .frame(minHeight: 220)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
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
                        .frame(maxWidth: .infinity, minHeight: 220)
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
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 172)
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
        DashboardEntityContextPanel(
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
        switch livePhase {
        case .live:
            "Live View"
        case .loading:
            "Preparing Live View"
        case .idle:
            "Camera"
        case .snapshotOnly:
            "Snapshot Preview"
        case .failed:
            "Snapshot Fallback"
        }
    }

    private var cameraPanelSystemImage: String {
        switch livePhase {
        case .live, .loading:
            "video.fill"
        case .idle, .snapshotOnly, .failed:
            "camera.viewfinder"
        }
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
