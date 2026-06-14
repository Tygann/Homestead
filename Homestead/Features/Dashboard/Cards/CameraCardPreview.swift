import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CameraCardPreview: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshotPhase: CameraCardSnapshotPhase = .idle

    let entityID: String
    let isAvailable: Bool
    let title: String
    let accessibilityTitle: String
    let fallbackSystemImage: String
    let refreshGeneration: Int
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                snapshotContent(width: proxy.size.width)
                    .frame(width: proxy.size.width, height: height)
                    .background(Color(.tertiarySystemGroupedBackground))

                LinearGradient(
                    colors: [.clear, .black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: height)

                if shouldShowTextOverlay {
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.42)

                        Text(title)
//                            .font(.headline)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, AppSpacing.small)
                    }
                    .frame(width: proxy.size.width, height: footerHeight)
                } else {
                    EmptyView()
                        .frame(width: proxy.size.width, alignment: .bottomLeading)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .task(id: refreshTaskID) {
            await refreshSnapshotsWhileVisible()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(snapshotSubtitle)
    }

    @ViewBuilder
    private func snapshotContent(width: CGFloat) -> some View {
        switch snapshotPhase {
        case .idle, .loading:
            cameraPlaceholder(status: placeholderStatus)
                .frame(width: width, height: height)
        case .loaded(let data):
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                cameraPlaceholder(status: .failed)
                    .frame(width: width, height: height)
            }
            #else
            cameraPlaceholder(status: .failed)
                .frame(width: width, height: height)
            #endif
        case .failed:
            cameraPlaceholder(status: placeholderStatus)
                .frame(width: width, height: height)
        }
    }

    private var snapshotSubtitle: String {
        guard isAvailable else {
            return "Unavailable"
        }

        switch snapshotPhase {
        case .idle, .loading:
            return "Loading preview"
        case .loaded:
            return ""
        case .failed:
            return "Preview unavailable"
        }
    }

    private var shouldShowTextOverlay: Bool {
        !title.isEmpty
    }

    private var footerHeight: CGFloat {
        min(max(42, height * 0.2), 56)
    }

    private var placeholderStatus: CameraCardPlaceholderStatus {
        guard isAvailable else {
            return .unavailable
        }

        switch snapshotPhase {
        case .idle, .loading:
            return .loading
        case .loaded:
            return .failed
        case .failed:
            return .failed
        }
    }

    private func cameraPlaceholder(status: CameraCardPlaceholderStatus) -> some View {
        ZStack {
            Color(.tertiarySystemGroupedBackground)

            if status == .loading {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: status.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var refreshTaskID: String {
        "\(entityID)-\(isAvailable)-\(scenePhase == .active)-\(refreshGeneration)"
    }

    @MainActor
    private func refreshSnapshotsWhileVisible() async {
        guard isAvailable else {
            snapshotPhase = .failed
            return
        }

        guard scenePhase == .active else {
            return
        }

        await loadSnapshot(useCache: refreshGeneration == 0)

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
            } catch {
                return
            }

            await loadSnapshot(useCache: false)
        }
    }

    @MainActor
    private func loadSnapshot(useCache: Bool) async {
        if useCache,
           let cachedSnapshot = await CameraCardSnapshotCache.shared.snapshot(for: entityID) {
            snapshotPhase = .loaded(cachedSnapshot)
            return
        }

        let shouldShowLoadingState = !snapshotPhase.hasLoadedSnapshot
        if shouldShowLoadingState {
            snapshotPhase = .loading
        }

        do {
            let snapshot = try await homeAssistantService.fetchCameraSnapshot(entityID: entityID)
            await CameraCardSnapshotCache.shared.store(snapshot, for: entityID)
            guard !Task.isCancelled else { return }
            snapshotPhase = .loaded(snapshot)
        } catch {
            guard !Task.isCancelled else { return }
            if shouldShowLoadingState {
                snapshotPhase = .failed
            }
        }
    }

    private var refreshIntervalNanoseconds: UInt64 {
        CameraCardSnapshotCache.baseRefreshIntervalNanoseconds + refreshJitterNanoseconds
    }

    private var refreshJitterNanoseconds: UInt64 {
        UInt64(entityID.hashValue.magnitude % 8) * 1_000_000_000
    }
}

private enum CameraCardSnapshotPhase: Equatable {
    case idle
    case loading
    case loaded(Data)
    case failed

    var hasLoadedSnapshot: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }
}

private enum CameraCardPlaceholderStatus {
    case loading
    case unavailable
    case failed

    var title: String {
        switch self {
        case .loading:
            return "Loading preview"
        case .unavailable:
            return "Unavailable"
        case .failed:
            return "Preview unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .loading:
            return "progress.indicator"
        case .unavailable, .failed:
            return "photo.badge.exclamationmark"
        }
    }
}

private actor CameraCardSnapshotCache {
    static let shared = CameraCardSnapshotCache()
    nonisolated static let baseRefreshIntervalNanoseconds: UInt64 = 45_000_000_000

    private struct Entry {
        let data: Data
        let date: Date
    }

    private var entriesByEntityID: [String: Entry] = [:]
    private let timeToLive: TimeInterval = 45

    func snapshot(for entityID: String, now: Date = Date()) -> Data? {
        guard let entry = entriesByEntityID[entityID] else {
            return nil
        }

        guard now.timeIntervalSince(entry.date) <= timeToLive else {
            entriesByEntityID[entityID] = nil
            return nil
        }

        return entry.data
    }

    func store(_ data: Data, for entityID: String, now: Date = Date()) {
        entriesByEntityID[entityID] = Entry(data: data, date: now)
    }
}
