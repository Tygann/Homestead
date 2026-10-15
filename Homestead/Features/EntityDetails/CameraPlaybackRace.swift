import Foundation

/// The first transport with video owns playback; a failed contender cannot cancel a viable one.
@MainActor
enum CameraPlaybackRace {
    enum Winner: Sendable { case webRTC, hls }

    static func firstVideo(
        native: @escaping @MainActor @Sendable () async -> Bool,
        hls: @escaping @MainActor @Sendable () async -> Bool
    ) async -> Winner? {
        await withTaskGroup(of: Winner?.self) { group in
            group.addTask { await native() ? .webRTC : nil }
            group.addTask { await hls() ? .hls : nil }
            for await result in group {
                if let result, !Task.isCancelled {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }
}
