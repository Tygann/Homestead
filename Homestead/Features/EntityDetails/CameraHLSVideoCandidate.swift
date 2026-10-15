import AVFoundation

@MainActor
final class CameraHLSVideoCandidate {
    private(set) var player: AVPlayer?

    // MARK: - Public API

    func prepare(url: URL, timeout: Duration = .seconds(30)) async throws -> Bool {
        let item = AVPlayerItem(url: url)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
        item.add(output)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        self.player = player
        var hasVideo = false
        defer {
            item.remove(output)
            if !hasVideo { stop() }
        }
        player.play()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            if item.status == .failed { return false }
            // Playing alone can mean audio-only. Require a decoded video buffer before selection.
            let time = output.itemTime(forHostTime: CACurrentMediaTime())
            if output.hasNewPixelBuffer(forItemTime: time),
               output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) != nil {
                hasVideo = true
                return true
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        return false
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}
