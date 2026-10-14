import Foundation
import Testing
@testable import Homestead

@MainActor
struct CameraHLSPreparationTests {
    private let url = URL(string: "https://example.invalid/stream.m3u8")!

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
