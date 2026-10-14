import Foundation
import Testing
@testable import Homestead

struct CameraAudioPlaybackTests {
    @Test func routeChangesAndExplicitUnmuteCannotOverrideAnActiveInterruption() {
        let owner = UUID()
        var state = listeningState(owner: owner)
        state.interruption(began: true, shouldResume: false)
        state.routeChanged(deviceRemoved: false)
        #expect(!state.shouldPlay)
        #expect(state.isListening)
        state.setListening(true, owner: owner)
        #expect(!state.shouldPlay)
    }

    @Test func resumableInterruptionRestoresRequestedListening() {
        var state = listeningState(owner: UUID())
        state.interruption(began: true, shouldResume: false)
        state.interruption(began: false, shouldResume: true)
        #expect(state.shouldPlay)
    }

    @Test func nonresumableInterruptionRequiresExplicitListening() {
        let owner = UUID()
        var state = listeningState(owner: owner)
        state.interruption(began: true, shouldResume: false)
        state.interruption(began: false, shouldResume: false)
        state.routeChanged(deviceRemoved: false)
        #expect(!state.isListening)
        #expect(!state.shouldPlay)
        state.setListening(true, owner: owner)
        #expect(state.shouldPlay)
    }

    @Test func removingHeadphonesDoesNotStartAudioOnTheSpeaker() {
        let owner = UUID()
        var state = listeningState(owner: owner)
        state.routeChanged(deviceRemoved: true)
        state.routeChanged(deviceRemoved: false)
        #expect(!state.shouldPlay)
        state.setListening(true, owner: owner)
        #expect(state.shouldPlay)
    }

    @Test func staleOwnerCannotMuteOrReleaseTheCurrentCamera() {
        let old = UUID(), current = UUID()
        var state = listeningState(owner: old)
        state.acquire(owner: current, listening: true)
        let staleRelease = state.release(owner: old)
        let staleMute = state.setListening(false, owner: old)
        #expect(!staleRelease)
        #expect(!staleMute)
        #expect(state.owner == current)
        #expect(state.shouldPlay)
        let released = state.release(owner: current)
        #expect(released)
        #expect(!state.shouldPlay)
    }

    @Test func switchingCamerasPreservesAnOngoingSystemInterruption() {
        var state = listeningState(owner: UUID())
        state.interruption(began: true, shouldResume: false)
        state.acquire(owner: UUID(), listening: true)
        #expect(!state.shouldPlay)
        state.interruption(began: false, shouldResume: true)
        #expect(state.shouldPlay)
    }

    @Test func receivingTrackMustBePlayingBeforeOutputStarts() {
        let owner = UUID()
        var state = CameraAudioPlaybackState()
        state.acquire(owner: owner, listening: true)
        #expect(!state.shouldPlay)
        state.isPlaying = true
        #expect(state.shouldPlay)
        state.isPlaying = false
        #expect(!state.shouldPlay)
    }

    private func listeningState(owner: UUID) -> CameraAudioPlaybackState {
        var state = CameraAudioPlaybackState()
        state.acquire(owner: owner, listening: true)
        state.isPlaying = true
        return state
    }
}
