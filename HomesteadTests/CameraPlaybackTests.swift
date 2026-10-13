import AVFoundation
import Testing
@testable import Homestead

struct CameraPlaybackTests {
    @Test func liveStartsOnlyWhenPlayerIsPlayingAndDoesNotResetForPauseOrRebuffering() {
        var readiness = CameraPlaybackReadiness()
        let waitingStarts = readiness.observe(.waitingToPlayAtSpecifiedRate)
        #expect(!waitingStarts)
        #expect(!readiness.hasStarted)
        let firstPlay = readiness.observe(.playing)
        #expect(firstPlay)
        let pauseStarts = readiness.observe(.paused)
        let rebufferStarts = readiness.observe(.waitingToPlayAtSpecifiedRate)
        let resumedPlay = readiness.observe(.playing)
        #expect(!pauseStarts && !rebufferStarts && !resumedPlay)
        #expect(readiness.hasStarted)
        readiness.reset()
        #expect(!readiness.hasStarted)
        let nextPlayerStarts = readiness.observe(.playing)
        #expect(nextPlayerStarts)
    }
}
