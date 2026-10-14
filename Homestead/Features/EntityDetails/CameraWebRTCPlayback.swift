import SwiftUI
@preconcurrency import WebRTC
import Observation
#if DEBUG
import os
#endif

@MainActor
protocol CameraWebRTCSignaling: AnyObject {
    func cameraWebRTCConfiguration(entityID: String) async throws -> JSONValue
    func subscribeCameraWebRTC(entityID: String, offer: String, handler: @escaping @Sendable (CameraWebRTCSignal) async -> Void) async throws -> Int
    func sendCameraWebRTCCandidate(entityID: String, sessionID: String, candidate: JSONValue) async throws
    func closeCameraWebRTC(subscriptionID: Int) async
}

extension HomeAssistantService: CameraWebRTCSignaling {}

/// One native receive-only engine survives layout and presentation changes.
/// Authentication and signaling remain in HAWebSocketClient.
@MainActor @Observable
final class CameraWebRTCPlayback: NSObject {
    // MARK: - Properties
    @ObservationIgnored private let startupTimeout: Duration
    var isMuted = true {
        didSet {
            audioTrack?.isEnabled = !isMuted
            if peer != nil { Self.audioDevice.setListening(!isMuted) }
        }
    }
    @ObservationIgnored private var audioTrack: RTCAudioTrack?
    private(set) var hasAudio = false
    private(set) var hasStarted = false
    private(set) var videoView: RTCMTLVideoView?
    @ObservationIgnored private var peer: RTCPeerConnection?
    @ObservationIgnored private var videoTrack: RTCVideoTrack?
    @ObservationIgnored private var dataChannel: RTCDataChannel?
    @ObservationIgnored private var hasRemoteDescription = false
    @ObservationIgnored private var remoteCandidates: [RTCIceCandidate] = []
    @ObservationIgnored private var service: (any CameraWebRTCSignaling)?
    @ObservationIgnored private var entityID = ""
    @ObservationIgnored private var generation: UUID?
    @ObservationIgnored private var subscriptionID: Int?
    @ObservationIgnored private var sessionID: String?
    @ObservationIgnored private var candidates: [JSONValue] = []
    @ObservationIgnored private var completion: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var cleanupTask: Task<Void, Never>?
    @ObservationIgnored private var setupTask: Task<Void, Never>?
    @ObservationIgnored private var offerTask: Task<Void, Never>?
    @ObservationIgnored private var candidateTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var configuration: JSONValue?
    @ObservationIgnored var failedAfterStart: (() -> Void)?

    // MARK: - Lifecycle
    init(startupTimeout: Duration = .seconds(12)) {
        self.startupTimeout = startupTimeout
        super.init()
    }

    func start(service: any CameraWebRTCSignaling, entityID: String, onFailure: (() -> Void)? = nil) async -> Bool {
        stop()
        let previousCleanup = cleanupTask
        failedAfterStart = onFailure
        let id = UUID()
        generation = id
        self.service = service
        self.entityID = entityID
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                completion = continuation
                let timeout = startupTimeout
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    guard self?.generation == id else { return }
                    self?.record("WebRTC startup timeout")
                    self?.recordMediaCounters()
                    self?.fail()
                }
                setupTask = Task { [weak self] in
                    do {
                        // Finish the previous HA session before opening another for this camera.
                        await previousCleanup?.value
                        guard self?.generation == id, !Task.isCancelled else { return }
                        let config = try await service.cameraWebRTCConfiguration(entityID: entityID)
                        guard let self, self.generation == id, !Task.isCancelled else { return }
                        self.record("WebRTC configuration received")
                        self.configuration = config
                        try await self.makeEngine()
                    } catch {
                        guard self?.generation == id else { return }
                        self?.fail()
                    }
                }
                if Task.isCancelled { stop() }
            }
        } onCancel: { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.generation == id else { return }
                self?.stop()
            }
        }
    }

    func stop() {
        let pendingOffer = offerTask
        let activeSubscription = subscriptionID
        let previousCleanup = cleanupTask
        let service = service
        if pendingOffer != nil || activeSubscription != nil {
            // Retain the barrier across repeated stop calls, including before an offer is acknowledged.
            cleanupTask = Task {
                await previousCleanup?.value
                await pendingOffer?.value
                if let activeSubscription, let service {
                    await service.closeCameraWebRTC(subscriptionID: activeSubscription)
                }
            }
        }
        generation = nil
        setupTask?.cancel()
        offerTask?.cancel()
        candidateTask?.cancel()
        timeoutTask?.cancel()
        setupTask = nil
        offerTask = nil
        candidateTask = nil
        timeoutTask = nil
        completion?.resume(returning: false)
        completion = nil
        subscriptionID = nil
        sessionID = nil
        candidates.removeAll()
        configuration = nil
        if let videoView { videoTrack?.remove(videoView) }
        videoTrack = nil
        audioTrack = nil
        hasAudio = false
        dataChannel?.close()
        dataChannel = nil
        peer?.close()
        peer = nil
        Self.audioDevice.setListening(false)
        remoteCandidates.removeAll()
        hasRemoteDescription = false
        videoView?.delegate = nil
        videoView?.removeFromSuperview()
        videoView = nil
        hasStarted = false
        failedAfterStart = nil
    }

    // MARK: - Signaling
    private static let audioDevice = CameraPlaybackAudioDevice()
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        RTCSetMinDebugLogLevel(.none)
        let factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: CameraVideoDecoderFactory(), audioDevice: audioDevice)
        RTCSetMinDebugLogLevel(.none)
        return factory
    }()

    private func makeEngine() async throws {
        guard let configuration, let config = configuration.objectValue?["configuration"]?.objectValue else {
            fail()
            return
        }
        let rtcConfiguration = RTCConfiguration()
        rtcConfiguration.sdpSemantics = .unifiedPlan
        rtcConfiguration.bundlePolicy = .maxBundle
        rtcConfiguration.iceTransportPolicy = config["iceTransportPolicy"]?.stringValue == "relay" ? .relay : .all
        rtcConfiguration.iceServers = (config["iceServers"]?.arrayValue ?? []).compactMap { server in
            guard let object = server.objectValue else { return nil }
            let urls = object["urls"]?.arrayValue?.compactMap(\.stringValue)
                ?? object["urls"]?.stringValue.map { [$0] } ?? []
            guard !urls.isEmpty else { return nil }
            return RTCIceServer(urlStrings: urls, username: object["username"]?.stringValue,
                credential: object["credential"]?.stringValue)
        }
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peer = Self.factory.peerConnection(with: rtcConfiguration, constraints: constraints, delegate: self) else {
            fail()
            return
        }
        self.peer = peer
        RTCSetMinDebugLogLevel(.none)
        Self.audioDevice.setListening(!isMuted)
        let renderer = RTCMTLVideoView(frame: .zero)
        renderer.videoContentMode = .scaleAspectFit
        renderer.delegate = self
        videoView = renderer
        if let label = configuration.objectValue?["dataChannel"]?.stringValue {
            dataChannel = peer.dataChannel(forLabel: label, configuration: RTCDataChannelConfiguration())
        }
        let audio = RTCRtpTransceiverInit()
        audio.direction = .recvOnly
        _ = peer.addTransceiver(of: .audio, init: audio)
        let video = RTCRtpTransceiverInit()
        video.direction = .recvOnly
        _ = peer.addTransceiver(of: .video, init: video)
        let offer = try await peer.offer(for: constraints)
        guard self.peer === peer, !Task.isCancelled else { return }
        try await peer.setLocalDescription(offer)
        guard self.peer === peer, !Task.isCancelled else { return }
        submitOffer(offer.sdp)
    }

    private func submitOffer(_ offer: String) {
        guard offerTask == nil, let service, let id = generation else { return }
        record("WebRTC offer created")
        let entityID = entityID
        offerTask = Task { [weak self] in
            do {
                let subscription = try await service.subscribeCameraWebRTC(entityID: entityID, offer: offer) { [weak self] signal in
                    await MainActor.run { [weak self] in
                        guard self?.generation == id else { return }
                        self?.receive(signal)
                    }
                }
                guard let self, self.generation == id, !Task.isCancelled else {
                    await service.closeCameraWebRTC(subscriptionID: subscription)
                    return
                }
                self.subscriptionID = subscription
            } catch {
                guard self?.generation == id else { return }
                self?.fail()
            }
        }
    }

    private func receive(_ signal: CameraWebRTCSignal) {
        guard let peer else { return }
        switch signal.type {
        case "session":
            record("WebRTC session received")
            sessionID = signal.sessionID
            flushCandidates()
        case "answer":
            guard let answer = signal.answer else { fail(); return }
            record("WebRTC answer received")
            peer.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: answer)) { [weak self, weak peer] error in
                Task { @MainActor [weak self, weak peer] in
                    guard let self, let peer, self.peer === peer else { return }
                    guard error == nil else { self.fail(); return }
                    var receivesVideo = false
                    for transceiver in peer.transceivers where transceiver.mediaType == .video {
                        var direction: RTCRtpTransceiverDirection = .inactive
                        if !transceiver.isStopped, transceiver.currentDirection(&direction),
                           direction == .recvOnly || direction == .sendRecv {
                            receivesVideo = true
                            if let track = transceiver.receiver.track as? RTCVideoTrack {
                                self.attachVideo(track)
                            }
                        }
                    }
                    guard receivesVideo else {
                        self.record("WebRTC answer has no receiving video")
                        self.fail()
                        return
                    }
                    self.hasRemoteDescription = true
                    let pending = self.remoteCandidates
                    self.remoteCandidates.removeAll()
                    for candidate in pending { self.addRemoteCandidate(candidate) }
                }
            }
        case "candidate":
            guard let object = signal.candidate?.objectValue, let sdp = object["candidate"]?.stringValue else { return }
            let candidate = RTCIceCandidate(sdp: sdp,
                sdpMLineIndex: Int32(exactly: object["sdpMLineIndex"]?.doubleValue ?? 0) ?? 0,
                sdpMid: object["sdpMid"]?.stringValue ?? "0")
            if hasRemoteDescription { addRemoteCandidate(candidate) } else { remoteCandidates.append(candidate) }
        case "error":
            record("WebRTC signaling failed")
            fail()
        default: break
        }
    }

    private func addRemoteCandidate(_ candidate: RTCIceCandidate) {
        guard let peer else { return }
        peer.add(candidate) { [weak self, weak peer] error in
            Task { @MainActor [weak self, weak peer] in
                guard let self, let peer, self.peer === peer else { return }
                if error != nil { self.fail() }
            }
        }
    }

    private func attachVideo(_ track: RTCVideoTrack) {
        guard let videoView, videoTrack?.trackId != track.trackId else { return }
        videoTrack?.remove(videoView)
        videoTrack = track
        track.add(videoView)
        record("WebRTC media track received")
    }

    private func flushCandidates() {
        guard candidateTask == nil, let sessionID, let service, let id = generation else { return }
        let entityID = entityID
        candidateTask = Task { [weak self] in
            while let self, self.generation == id, !Task.isCancelled, !self.candidates.isEmpty {
                let candidate = self.candidates.removeFirst()
                do {
                    try await service.sendCameraWebRTCCandidate(entityID: entityID, sessionID: sessionID, candidate: candidate)
                } catch {
                    guard self.generation == id else { return }
                    self.fail()
                    return
                }
            }
            guard self?.generation == id else { return }
            self?.candidateTask = nil
        }
    }

    private func recordMediaCounters() {
        #if DEBUG
        peer?.statistics { report in
            for statistic in report.statistics.values where statistic.type == "inbound-rtp" {
                guard statistic.values["kind"] as? String == "video" else { continue }
                let packets = statistic.values["packetsReceived"] as? NSNumber ?? 0
                let frames = statistic.values["framesDecoded"] as? NSNumber ?? 0
                if let codecID = statistic.values["codecId"] as? String,
                   let codec = report.statistics[codecID]?.values["mimeType"] as? String,
                   ["video/H264", "video/H265", "video/VP8", "video/VP9", "video/AV1"].contains(codec) {
                    Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup")
                        .info("WebRTC timeout video codec: \(codec, privacy: .public)")
                    if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
                        print("[CameraStartup] WebRTC timeout codec: \(codec)")
                    }
                }
                Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup")
                    .info("WebRTC timeout video packets: \(packets.intValue, privacy: .public), decoded frames: \(frames.intValue, privacy: .public)")
                if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
                    print("[CameraStartup] WebRTC timeout packets: \(packets.intValue), decoded frames: \(frames.intValue)")
                }
            }
        }
        #endif
    }

    private func record(_ stage: String) {
        #if DEBUG
        Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup").info("\(stage, privacy: .public)")
        if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
            print("[CameraStartup] \(stage)")
        }
        #endif
    }

    private func fail() {
        let notify = hasStarted ? failedAfterStart : nil
        stop()
        notify?()
    }

}

extension CameraWebRTCPlayback: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            self.audioTrack = stream.audioTracks.first
            self.hasAudio = self.audioTrack != nil
            self.audioTrack?.isEnabled = !self.isMuted
            if let track = stream.videoTracks.first { self.attachVideo(track) }
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            if newState == .failed { self.fail() }
            if newState == .connected || newState == .completed { self.record("WebRTC ICE connected") }
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            self.candidates.append(.object(["candidate": .string(candidate.sdp),
                "sdpMLineIndex": .number(Double(candidate.sdpMLineIndex)),
                "sdpMid": candidate.sdpMid.map(JSONValue.string) ?? .null]))
            self.flushCandidates()
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            if let track = rtpReceiver.track as? RTCVideoTrack { self.attachVideo(track) }
            if let track = rtpReceiver.track as? RTCAudioTrack {
                self.audioTrack = track
                self.hasAudio = true
                track.isEnabled = !self.isMuted
            }
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            if let track = transceiver.receiver.track as? RTCVideoTrack { self.attachVideo(track) }
            if let track = transceiver.receiver.track as? RTCAudioTrack {
                self.audioTrack = track
                self.hasAudio = true
                track.isEnabled = !self.isMuted
            }
        }
    }
}

extension CameraWebRTCPlayback: RTCVideoViewDelegate {
    nonisolated func videoView(_ videoView: any RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        Task { @MainActor [weak self] in
            guard let self, let view = videoView as? RTCMTLVideoView, self.videoView === view,
                  !self.hasStarted, size.width > 0, size.height > 0 else { return }
            self.hasStarted = true
            self.record("WebRTC video frame received")
            self.timeoutTask?.cancel()
            self.completion?.resume(returning: true)
            self.completion = nil
        }
    }
}

struct CameraWebRTCVideo: UIViewRepresentable {
    let videoView: RTCMTLVideoView?
    var isVisible = true

    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ container: UIView, context: Context) {
        guard isVisible, let view = videoView else { return }
        if view.superview !== container {
            view.removeFromSuperview()
            view.frame = container.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(view)
        }
    }
}

struct CameraWebRTCAudioButton: View {
    let playback: CameraWebRTCPlayback
    var body: some View {
        Button { playback.isMuted.toggle() } label: {
            Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playback.isMuted ? "Unmute camera" : "Mute camera")
    }
}
