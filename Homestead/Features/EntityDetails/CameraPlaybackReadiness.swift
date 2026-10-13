import AVFoundation

nonisolated struct CameraPlaybackReadiness: Equatable {
    private(set) var hasStarted = false

    mutating func observe(_ status: AVPlayer.TimeControlStatus) -> Bool {
        guard !hasStarted, status == .playing else { return false }
        hasStarted = true
        return true
    }

    mutating func reset() {
        hasStarted = false
    }
}
