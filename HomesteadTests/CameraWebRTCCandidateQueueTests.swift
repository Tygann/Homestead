import Foundation
import Testing
@testable import Homestead

@MainActor
struct CameraWebRTCCandidateQueueTests {
    @Test(arguments: [true, false])
    func candidatesWaitForBothAnswerAndSession(sessionFirst: Bool) async {
        var sent: [JSONValue] = []
        let queue = CameraWebRTCCandidateQueue(send: { _, candidate in sent.append(candidate) }, failed: { Issue.record("Unexpected failure") })
        queue.append(.string("candidate"))
        if sessionFirst { queue.setSession("session") } else { queue.didApplyAnswer() }
        for _ in 0..<10 { await Task.yield() }
        #expect(sent.isEmpty)
        if sessionFirst { queue.didApplyAnswer() } else { queue.setSession("session") }
        let deadline = Date().addingTimeInterval(2)
        while sent.isEmpty, Date() < deadline { await Task.yield() }
        #expect(sent == [.string("candidate")])
        queue.stop()
    }

    @Test func candidateSendsOverlapWithinBoundAndDrainAfterAcknowledgement() async {
        let sender = SuspendedCandidateSender()
        let queue = CameraWebRTCCandidateQueue(send: sender.send, failed: { Issue.record("Unexpected failure") })
        for i in 0..<6 { queue.append(.number(Double(i))) }
        queue.setSession("session")
        queue.didApplyAnswer()
        let deadline = Date().addingTimeInterval(2)
        while sender.calls.count < 4, Date() < deadline { await Task.yield() }
        #expect(sender.calls.count == 4)
        for _ in 0..<10 { await Task.yield() }
        #expect(sender.calls.count == 4)
        sender.finish(0)
        while sender.calls.count < 5, Date() < deadline { await Task.yield() }
        #expect(sender.calls.count == 5)
        queue.stop()
        sender.finishAll()
    }

    @Test func stoppedDeliveryCannotAcknowledgeOrFailReplacement() async {
        let sender = SuspendedCandidateSender()
        var failures = 0
        var acknowledgements = 0
        let queue = CameraWebRTCCandidateQueue(send: sender.send, failed: { failures += 1 }, acknowledged: { acknowledgements += 1 })
        queue.setSession("old")
        queue.didApplyAnswer()
        queue.append(.string("old"))
        let deadline = Date().addingTimeInterval(2)
        while sender.calls.isEmpty, Date() < deadline { await Task.yield() }
        queue.stop()
        queue.append(.string("new"))
        queue.setSession("new")
        sender.finish(0, failing: true)
        for _ in 0..<10 { await Task.yield() }
        #expect(failures == 0 && acknowledgements == 0)
        #expect(sender.calls.count == 1)
        queue.didApplyAnswer()
        while sender.calls.count < 2, Date() < deadline { await Task.yield() }
        #expect(sender.calls.map(\.0) == ["old", "new"])
        sender.finish(1)
        while acknowledgements == 0, Date() < deadline { await Task.yield() }
        #expect(acknowledgements == 1 && failures == 0)
        queue.stop()
        sender.finishAll()
    }

    @Test func stopBeforeScheduledSendDoesNotTransmitOldCandidates() async {
        var sent = 0
        let queue = CameraWebRTCCandidateQueue(send: { _, _ in sent += 1 }, failed: { Issue.record("Unexpected failure") })
        queue.setSession("old")
        queue.didApplyAnswer()
        queue.append(.string("old"))
        queue.stop()
        for _ in 0..<20 { await Task.yield() }
        #expect(sent == 0)
    }

    @Test func sendFailureStopsPendingCandidates() async {
        let sender = SuspendedCandidateSender()
        var failures = 0
        let queue = CameraWebRTCCandidateQueue(send: sender.send, failed: { failures += 1 })
        queue.setSession("session")
        queue.didApplyAnswer()
        for i in 0..<6 { queue.append(.number(Double(i))) }
        let deadline = Date().addingTimeInterval(2)
        while sender.calls.count < 4, Date() < deadline { await Task.yield() }
        sender.finish(0, failing: true)
        while failures == 0, Date() < deadline { await Task.yield() }
        #expect(failures == 1)
        #expect(sender.calls.count == 4)
        sender.finishAll()
        queue.stop()
    }

    @Test func candidateSummaryDoesNotExposeSDPFields() {
        #expect(CameraICECandidateSummary.describe("candidate:secret 1 udp 123 192.0.2.1 54321 typ srflx raddr 10.0.0.1 rport 99 ufrag secret") == "srflx/udp/ipv4/documentation")
        #expect(CameraICECandidateSummary.describe("candidate:secret 1 TCP 123 2001:db8::1 54321 typ relay") == "relay/tcp/ipv6/documentation/unknown")
        #expect(CameraICECandidateSummary.describe("candidate:secret 1 password 123 secret 54321 typ credential") == "unknown/unknown/name/unknown")
        #expect(CameraICECandidateSummary.describe("") == "unknown/unknown/unknown")
    }
}

@MainActor private final class SuspendedCandidateSender {
    private(set) var calls: [(String, JSONValue)] = []
    private var continuations: [Int: CheckedContinuation<Void, Error>] = [:]
    func send(session: String, candidate: JSONValue) async throws {
        let index = calls.count
        calls.append((session, candidate))
        try await withCheckedThrowingContinuation { continuations[index] = $0 }
    }
    func finish(_ index: Int, failing: Bool = false) {
        let continuation = continuations.removeValue(forKey: index)
        if failing { continuation?.resume(throwing: CancellationError()) } else { continuation?.resume() }
    }
    func finishAll() {
        let pending = continuations.values
        continuations.removeAll()
        for continuation in pending { continuation.resume() }
    }
}
