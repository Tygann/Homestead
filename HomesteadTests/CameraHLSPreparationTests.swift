import Foundation
import Testing
@testable import Homestead

@MainActor
struct CameraHLSPreparationTests {
    private let url = URL(string: "https://example.invalid/stream.m3u8")!

    @Test func nativeWinnerDoesNotWaitForCancellationInsensitiveURLRequest() async throws {
        var request: CheckedContinuation<URL, Never>?
        let preparation = CameraHLSPreparation(gracePeriod: .zero) {
            await withCheckedContinuation { request = $0 }
        }
        let race = Task {
            await CameraPlaybackRace.firstVideo {
                for _ in 0..<1000 where request == nil { await Task.yield() }
                return request != nil
            } hls: {
                do { _ = try await preparation.scheduledValue(); return true }
                catch { return false }
            }
        }
        var completed = false
        let observer = Task { _ = await race.value; completed = true }
        for _ in 0..<1000 where !completed { await Task.yield() }
        // Always resume the intentionally uncooperative request so a failing test cannot hang.
        let completedBeforeURL = completed
        request?.resume(returning: url)
        await observer.value
        #expect(completedBeforeURL)
        #expect(await race.value == .webRTC)
        preparation.cancel()
    }

    @Test func nativeFailureAcceleratesScheduledPlayback() async throws {
        var calls = 0
        let preparation = CameraHLSPreparation(gracePeriod: .seconds(60)) {
            calls += 1
            return url
        }
        defer { preparation.cancel() }
        let waiter = Task { try await preparation.scheduledValue() }
        await Task.yield()
        #expect(calls == 0)
        preparation.startFallback()
        #expect(try await waiter.value == url)
        #expect(calls == 1)
    }

    @Test func cancellationStopsScheduledWaitWithoutStartingRequest() async {
        var calls = 0
        let preparation = CameraHLSPreparation(gracePeriod: .seconds(60)) {
            calls += 1
            return url
        }
        let waiter = Task { try await preparation.scheduledValue() }
        await Task.yield()
        preparation.cancel()
        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(calls == 0)
    }

    @Test func fastNativeSuccessSkipsHLS() async throws {
        var calls = 0
        let preparation = CameraHLSPreparation(gracePeriod: .seconds(60)) {
            calls += 1
            return url
        }
        preparation.cancel()
        await Task.yield()
        #expect(calls == 0)
        await #expect(throws: CancellationError.self) { try await preparation.value() }
    }

    @Test func earlyFallbackStartsImmediatelyAndReusesRequest() async throws {
        var calls = 0
        let preparation = CameraHLSPreparation(gracePeriod: .seconds(60)) {
            calls += 1
            return url
        }
        defer { preparation.cancel() }
        #expect(try await preparation.value() == url)
        #expect(try await preparation.value() == url)
        #expect(calls == 1)
    }

    @Test func stalledNativeWarmsProducerBeforeFallback() async throws {
        var calls = 0
        let preparation = CameraHLSPreparation(gracePeriod: .zero) {
            calls += 1
            return url
        }
        defer { preparation.cancel() }
        for _ in 0..<100 where calls == 0 { await Task.yield() }
        #expect(calls == 1)
        #expect(try await preparation.value() == url)
        #expect(calls == 1)
    }

    @Test func cancelledFallbackRejectsLateURLAndCancelsRequest() async throws {
        var continuation: CheckedContinuation<URL, Never>?
        var requestWasCancelled = false
        let preparation = CameraHLSPreparation(gracePeriod: .seconds(60)) {
            let result = await withCheckedContinuation { continuation = $0 }
            requestWasCancelled = Task.isCancelled
            return result
        }
        let fallback = Task { try await preparation.value() }
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        try #require(continuation != nil)
        fallback.cancel()
        // The cancellation handler marshals cleanup back to the main actor.
        for _ in 0..<10 { await Task.yield() }
        continuation?.resume(returning: url)
        await #expect(throws: CancellationError.self) { try await fallback.value }
        #expect(requestWasCancelled)
    }
}
