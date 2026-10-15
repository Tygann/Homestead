import Foundation
import Testing
@testable import Homestead

@MainActor
struct CameraPlaybackRaceTests {
    @Test func selectionGatesAudioWithoutChangingUserPreference() {
        let native = CameraWebRTCPlayback()
        native.isMuted = false
        native.isPlaybackSelected = false
        #expect(!native.isListeningAllowed)
        #expect(!native.isMuted)
        native.isPlaybackSelected = true
        #expect(native.isListeningAllowed)
        native.isMuted = true
        #expect(!native.isListeningAllowed)
    }

    @Test func nativeWinnerCancelsPendingHLS() async {
        var cancelled = false
        let winner = await CameraPlaybackRace.firstVideo { true } hls: {
            do { try await Task.sleep(for: .seconds(60)) } catch { cancelled = true }
            return false
        }
        #expect(winner == .webRTC)
        #expect(cancelled)
    }

    @Test func hlsWinnerCancelsPendingNative() async {
        var cancelled = false
        let winner = await CameraPlaybackRace.firstVideo {
            do { try await Task.sleep(for: .seconds(60)) } catch { cancelled = true }
            return false
        } hls: { true }
        #expect(winner == .hls)
        #expect(cancelled)
    }

    @Test func failedNativeDoesNotCancelHLS() async {
        let winner = await CameraPlaybackRace.firstVideo { false } hls: {
            await Task.yield()
            return !Task.isCancelled
        }
        #expect(winner == .hls)
    }

    @Test func failedHLSDoesNotCancelNative() async {
        let winner = await CameraPlaybackRace.firstVideo {
            await Task.yield()
            return !Task.isCancelled
        } hls: { false }
        #expect(winner == .webRTC)
    }

    @Test func bothFailuresLeaveNoWinner() async {
        #expect(await CameraPlaybackRace.firstVideo(native: { false }, hls: { false }) == nil)
    }

    @Test func simultaneousVideoChoosesOneWinner() async {
        let winner = await CameraPlaybackRace.firstVideo(native: { true }, hls: { true })
        #expect(winner == .webRTC || winner == .hls)
    }

    @Test func cancellationRejectsLateSuccess() async {
        var nativeStarted = false
        var hlsStarted = false
        let task = Task {
            await CameraPlaybackRace.firstVideo {
                nativeStarted = true
                do { try await Task.sleep(for: .seconds(60)) } catch { }
                return true
            } hls: {
                hlsStarted = true
                do { try await Task.sleep(for: .seconds(60)) } catch { }
                return true
            }
        }
        for _ in 0..<100 where !nativeStarted || !hlsStarted { await Task.yield() }
        task.cancel()
        #expect(await task.value == nil)
    }
}
