import SwiftUI
import os
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UIKit)
import UIKit
#endif

private let cameraPreviewLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Homestead",
    category: "CameraPreview"
)

struct CameraCardPreview: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshotPhase: CameraCardSnapshotPhase = .idle
    #if canImport(UIKit)
    @State private var snapshotImage: UIImage?
    #endif

    let entityID: String
    let isAvailable: Bool
    let title: String
    let accessibilityTitle: String
    let refreshGeneration: Int
    let height: CGFloat
    var loadsSnapshots = true

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

                if snapshotPhase.isStale {
                    Text("Last view")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.xSmall)
                        .background(Color.black.opacity(0.56), in: Capsule())
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topTrailing
                        )
                        .padding(AppSpacing.small)
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
        case .loaded:
            #if canImport(UIKit)
            if let snapshotImage {
                Image(uiImage: snapshotImage)
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
        case .loaded(let isStale):
            return isStale ? "Showing last view" : ""
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
        guard loadsSnapshots else {
            snapshotPhase = .idle
            return
        }
        guard isAvailable else {
            snapshotPhase = .failed
            return
        }

        guard scenePhase == .active else {
            return
        }

        await loadSnapshotWithRetry()

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
            } catch {
                return
            }

            await loadSnapshotWithRetry()
        }
    }

    @MainActor
    private func loadSnapshotWithRetry() async {
        if let cachedSnapshot = await CameraSnapshotStore.shared.snapshot(for: entityID) {
            _ = await presentSnapshot(
                cachedSnapshot.data,
                isStale: !cachedSnapshot.isFresh(
                    freshnessInterval: CameraSnapshotStore.freshnessInterval
                )
            )
        }

        for delay in retryDelays {
            guard !Task.isCancelled else { return }

            if delay > .zero {
                do {
                    try await Task.sleep(for: delay + retryJitter)
                } catch {
                    return
                }
            }

            if await loadSnapshot() {
                return
            }
        }
    }

    @MainActor
    private func loadSnapshot() async -> Bool {
        let shouldShowLoadingState = !snapshotPhase.hasLoadedSnapshot
        if shouldShowLoadingState {
            snapshotPhase = .loading
        }

        do {
            let snapshot = try await CameraSnapshotRequestGate.shared.perform {
                try await homeAssistantService.fetchCameraSnapshot(entityID: entityID)
            }
            await CameraSnapshotStore.shared.store(snapshot, for: entityID)
            return await presentSnapshot(snapshot, isStale: false)
        } catch {
            guard !Task.isCancelled else { return false }
            cameraPreviewLogger.debug(
                "Snapshot refresh failed for \(entityID, privacy: .private(mask: .hash)): \(String(describing: error), privacy: .private)"
            )
            if shouldShowLoadingState {
                snapshotPhase = .failed
            } else if case .loaded = snapshotPhase {
                snapshotPhase = .loaded(isStale: true)
            }
            return false
        }
    }

    @MainActor
    private func presentSnapshot(_ data: Data, isStale: Bool) async -> Bool {
        #if canImport(UIKit) && canImport(ImageIO)
        let image = await Task.detached(priority: .utility) { [data] in
            CameraSnapshotImageDecoder.image(from: data, maximumPixelSize: 1_280)
        }.value
        guard !Task.isCancelled else { return false }
        guard let image else {
            snapshotImage = nil
            snapshotPhase = .failed
            return false
        }

        snapshotImage = UIImage(cgImage: image)
        snapshotPhase = .loaded(isStale: isStale)
        return true
        #else
        _ = data
        _ = isStale
        snapshotPhase = .failed
        return false
        #endif
    }

    private var retryDelays: [Duration] {
        [.zero, .seconds(2), .seconds(6), .seconds(15)]
    }

    private var retryJitter: Duration {
        .milliseconds(Int64(entityID.hashValue.magnitude % 750))
    }

    private var refreshIntervalNanoseconds: UInt64 {
        45_000_000_000 + refreshJitterNanoseconds
    }

    private var refreshJitterNanoseconds: UInt64 {
        UInt64(entityID.hashValue.magnitude % 8) * 1_000_000_000
    }
}

private enum CameraCardSnapshotPhase: Equatable {
    case idle
    case loading
    case loaded(isStale: Bool)
    case failed

    var hasLoadedSnapshot: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }

    var isStale: Bool {
        if case .loaded(let isStale) = self {
            return isStale
        }
        return false
    }
}

#if canImport(UIKit) && canImport(ImageIO)
private enum CameraSnapshotImageDecoder {
    nonisolated static func image(from data: Data, maximumPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
#endif

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
