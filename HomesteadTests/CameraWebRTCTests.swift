import Foundation
import Testing
@testable import Homestead

struct CameraWebRTCTests {
    @Test func hevcAccessUnitsPreserveMixedAnnexBPrefixesAndBecomeLengthPrefixed() throws {
        let data = Data([0, 0, 0, 1, 0x40, 1, 0x12, 0, 0, 1, 0x42, 1, 0x34])
        let units = try #require(HEVCFramePayload.nalUnits(in: data))
        #expect(units == [Data([0x40, 1, 0x12]), Data([0x42, 1, 0x34])])
        #expect(HEVCFramePayload.lengthPrefixed(units) == Data([0, 0, 0, 3, 0x40, 1, 0x12, 0, 0, 0, 3, 0x42, 1, 0x34]))
    }

    @Test func malformedHEVCAccessUnitsAreRejected() {
        for bytes: [UInt8] in [[], [0, 0, 1], [0, 0, 1, 0x40], [0x40, 1], [0, 0, 1, 0x40, 1, 0, 0, 1]] {
            #expect(HEVCFramePayload.nalUnits(in: Data(bytes)) == nil)
        }
        #expect(HEVCFramePayload.lengthPrefixed([]) == nil)
        #expect(HEVCFramePayload.lengthPrefixed([Data([0x40])]) == nil)
    }

    @Test func hevcAnnexBPaddingDoesNotEnterParameterSets() {
        let padded = Data([0, 0, 0, 0, 0, 1, 0x40, 1, 0x12, 0, 0, 0, 0, 1, 0x42, 1, 0x34, 0, 0])
        #expect(HEVCFramePayload.nalUnits(in: padded) == [Data([0x40, 1, 0x12]), Data([0x42, 1, 0x34])])
    }

    @Test func cameraAudioDeviceCannotInitializeOrStartRecording() {
        let device = CameraPlaybackAudioDevice()
        #expect(!device.initializeRecording())
        #expect(!device.startRecording())
        #expect(!device.isRecordingInitialized)
        #expect(!device.isRecording)
        #expect(device.stopRecording())
        #expect(device.terminateDevice())
        #expect(!device.isInitialized)
    }

    @Test func capabilitiesRecognizeOfficialWebRTCAndRetainHLSFallback() throws {
        let capabilities = try JSONDecoder().decode(HACameraCapabilities.self,
            from: Data(#"{"frontend_stream_types":["web_rtc","hls"]}"#.utf8))
        #expect(capabilities.supportsWebRTCStream)
        #expect(capabilities.supportsHLSStream)
        let webRTCOnly = HACameraCapabilities(frontendStreamTypes: [.webRTC])
        #expect(webRTCOnly.supportsWebRTCStream && !webRTCOnly.supportsHLSStream)
        let unknown = try JSONDecoder().decode(HACameraCapabilities.self,
            from: Data(#"{"frontend_stream_types":["future_transport"]}"#.utf8))
        #expect(!unknown.supportsWebRTCStream && !unknown.supportsHLSStream)
    }

    @Test func hlsStreamRequestUsesCoreWebSocketShape() throws {
        let request = HAWebSocketRequest.cameraCommand(id: 5, type: "camera/stream", entityID: "camera.test", fields: [:])
        let encoded = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(request)).objectValue!
        #expect(encoded["type"] == .string("camera/stream"))
        #expect(encoded["entity_id"] == .string("camera.test"))
        #expect(encoded["webhook_id"] == nil)
    }

    @Test func signalingUsesAsyncOfferSubscriptionAndCandidateSession() throws {
        let offer = HAWebSocketRequest.cameraCommand(id: 7, type: "camera/webrtc/offer", entityID: "camera.test", fields: ["offer": .string("v=0\r\n")])
        let encodedOffer = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(offer)).objectValue!
        #expect(encodedOffer["id"] == .number(7))
        #expect(encodedOffer["type"] == .string("camera/webrtc/offer"))
        #expect(encodedOffer["entity_id"] == .string("camera.test"))
        #expect(encodedOffer["offer"] == .string("v=0\r\n"))
        let candidate: JSONValue = .object(["candidate": .string("candidate:test"), "sdpMid": .string("0"), "sdpMLineIndex": .number(0)])
        let request = HAWebSocketRequest.cameraCommand(id: 8, type: "camera/webrtc/candidate", entityID: "camera.test", fields: ["session_id": .string("session-1"), "candidate": candidate])
        let encoded = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(request)).objectValue!
        #expect(encoded["session_id"] == .string("session-1"))
        #expect(encoded["candidate"] == candidate)
        let cleanup = HAWebSocketRequest.unsubscribeEvents(id: 9, subscription: 7)
        let encodedCleanup = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(cleanup)).objectValue!
        #expect(encodedCleanup["subscription"] == .number(7))
    }

    @Test(arguments: [
        #"{"type":"session","session_id":"test-session"}"#,
        #"{"type":"answer","answer":"v=0\r\n"}"#,
        #"{"type":"candidate","candidate":{"candidate":"candidate:test"}}"#,
        #"{"type":"error","code":"failed","message":"Test failure"}"#
    ])
    func asynchronousEventsDecodeWithoutStateEventShape(event: String) throws {
        let envelope = "{\"id\":7,\"type\":\"event\",\"event\":\(event)}"
        let message = try JSONDecoder().decode(HAWebSocketIncomingMessage.self, from: Data(envelope.utf8))
        #expect(message.id == 7)
        #expect(message.cameraSignal != nil)
        #expect(message.event == nil)
    }

    @MainActor @Test func canceledOfferUnsubscribesLateAcknowledgement() async {
        let signaling = DelayedOfferSignaling()
        let playback = CameraWebRTCPlayback()
        let start = Task { await playback.start(service: signaling, entityID: "camera.test") }
        let deadline = Date().addingTimeInterval(5)
        while !signaling.requested, Date() < deadline { await Task.yield() }
        #expect(signaling.requested)
        start.cancel()
        let started = await start.value
        #expect(!started)
        signaling.finish()
        while signaling.closed.isEmpty, Date() < deadline { await Task.yield() }
        #expect(signaling.closed == [41])
        #expect(playback.videoView == nil)
    }

    @MainActor @Test func connectionLossDuringOfferClosesItsLateAcknowledgement() async {
        let signaling = DelayedOfferSignaling()
        let playback = CameraWebRTCPlayback()
        let start = Task { await playback.start(service: signaling, entityID: "camera.test") }
        let deadline = Date().addingTimeInterval(5)
        while signaling.handlers.isEmpty, Date() < deadline { await Task.yield() }
        guard let handler = signaling.handlers.first else { Issue.record("Offer was not submitted"); start.cancel(); return }
        await handler(.connectionClosed)
        let started = await start.value
        #expect(!started)
        #expect(playback.videoView == nil)
        signaling.finish()
        while signaling.closed.isEmpty, Date() < deadline { await Task.yield() }
        #expect(signaling.closed == [41])
    }

    @MainActor @Test func oldCameraSignalCannotStopAReplacementCamera() async {
        let signaling = DelayedOfferSignaling()
        let playback = CameraWebRTCPlayback()
        let first = Task { await playback.start(service: signaling, entityID: "camera.first") }
        let deadline = Date().addingTimeInterval(5)
        while signaling.handlers.isEmpty, Date() < deadline { await Task.yield() }
        guard let oldHandler = signaling.handlers.first else { Issue.record("Offer was not submitted"); first.cancel(); return }
        playback.stop()
        #expect(await first.value == false)
        let replacement = Task { await playback.start(service: signaling, entityID: "camera.second") }
        signaling.finish()
        while signaling.handlers.count < 2, Date() < deadline { await Task.yield() }
        guard signaling.handlers.count == 2 else { Issue.record("Replacement offer was not submitted"); replacement.cancel(); return }
        await oldHandler(.connectionClosed)
        #expect(playback.videoView != nil)
        #expect(signaling.closed == [41])
        await signaling.handlers[1](.connectionClosed)
        #expect(await replacement.value == false)
        signaling.finish(subscriptionID: 42)
        while signaling.closed.count < 2, Date() < deadline { await Task.yield() }
        #expect(signaling.closed == [41, 42])
    }

    @MainActor @Test func replacementWaitsForPendingOfferCleanupAcrossRepeatedStops() async {
        let signaling = DelayedOfferSignaling()
        let playback = CameraWebRTCPlayback()
        let first = Task { await playback.start(service: signaling, entityID: "camera.test") }
        let deadline = Date().addingTimeInterval(5)
        while !signaling.requested, Date() < deadline { await Task.yield() }
        #expect(signaling.requested)
        playback.stop()
        playback.stop()
        let firstStarted = await first.value
        #expect(!firstStarted)
        let replacement = Task { await playback.start(service: signaling, entityID: "camera.test") }
        for _ in 0..<20 { await Task.yield() }
        #expect(signaling.configurationRequests == 1)
        signaling.finish()
        while signaling.configurationRequests < 2, Date() < deadline { await Task.yield() }
        #expect(signaling.closed == [41])
        #expect(signaling.configurationRequests == 2)
        replacement.cancel()
        let replacementStarted = await replacement.value
        #expect(!replacementStarted)
        signaling.finish()
    }

    @MainActor @Test func stalledConfigurationHasBoundedStartupAndCannotInstallLateEngine() async {
        let signaling = DelayedCameraSignaling()
        let playback = CameraWebRTCPlayback(startupTimeout: .milliseconds(50))
        let start = Task { await playback.start(service: signaling, entityID: "camera.test") }
        while !signaling.requested { await Task.yield() }
        let started = await start.value
        #expect(!started)
        signaling.finish()
        await Task.yield()
        #expect(playback.videoView == nil)
    }

    @MainActor @Test func canceledConfigurationCannotInstallAPlaybackEngine() async {
        let signaling = DelayedCameraSignaling()
        let playback = CameraWebRTCPlayback()
        let start = Task { await playback.start(service: signaling, entityID: "camera.test") }
        while !signaling.requested { await Task.yield() }
        start.cancel()
        let started = await start.value
        #expect(!started)
        signaling.finish()
        await Task.yield()
        #expect(playback.videoView == nil)
        #expect(!playback.hasStarted)
    }
}

@MainActor private final class DelayedCameraSignaling: CameraWebRTCSignaling {
    var requested = false
    private var continuation: CheckedContinuation<JSONValue, Never>?
    func cameraWebRTCConfiguration(entityID: String) async throws -> JSONValue {
        await withCheckedContinuation {
            continuation = $0
            requested = true
        }
    }
    func finish() {
        continuation?.resume(returning: .object(["configuration": .object([:])]))
        continuation = nil
    }
    func subscribeCameraWebRTC(entityID: String, offer: String, handler: @escaping @Sendable (CameraWebRTCSignal) async -> Void) async throws -> Int { 1 }
    func sendCameraWebRTCCandidate(entityID: String, sessionID: String, candidate: JSONValue) async throws {}
    func closeCameraWebRTC(subscriptionID: Int) async {}
}

@MainActor private final class DelayedOfferSignaling: CameraWebRTCSignaling {
    var requested = false
    var closed: [Int] = []
    var configurationRequests = 0
    var handlers: [@Sendable (CameraWebRTCSignal) async -> Void] = []
    private var continuation: CheckedContinuation<Int, Never>?
    func cameraWebRTCConfiguration(entityID: String) async throws -> JSONValue {
        configurationRequests += 1
        return .object(["configuration": .object(["iceServers": .array([])])])
    }
    func subscribeCameraWebRTC(entityID: String, offer: String, handler: @escaping @Sendable (CameraWebRTCSignal) async -> Void) async throws -> Int {
        handlers.append(handler)
        return await withCheckedContinuation { continuation = $0; requested = true }
    }
    func finish(subscriptionID: Int = 41) { continuation?.resume(returning: subscriptionID); continuation = nil }
    func sendCameraWebRTCCandidate(entityID: String, sessionID: String, candidate: JSONValue) async throws {}
    func closeCameraWebRTC(subscriptionID: Int) async { closed.append(subscriptionID) }
}
