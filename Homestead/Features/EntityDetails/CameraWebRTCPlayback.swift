import SwiftUI
@preconcurrency import WebRTC
import Observation
@preconcurrency import Network
#if DEBUG
import os

/// Pipe captures must receive each stage immediately rather than at stdout's buffer threshold.
nonisolated enum CameraStartupConsole {
    private static let sink = CameraStartupLogSink()
    static func write(_ message: String) {
        try? FileHandle.standardOutput.write(contentsOf: Data("[CameraStartup] \(message)\n".utf8))
        sink.append(message)
    }
}

/// A bounded local capture survives loss of the wireless development connection.
private nonisolated final class CameraStartupLogSink: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    func append(_ message: String) {
        lock.withLock {
            lines.append("\(Date().timeIntervalSince1970) \(message)")
            if lines.count > 512 { lines.removeFirst(lines.count - 512) }
            guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
            try? Data((lines.joined(separator: "\n") + "\n").utf8)
                .write(to: directory.appendingPathComponent("CameraStartup.log"), options: .atomic)
        }
    }
}
#endif

@MainActor
protocol CameraWebRTCSignaling: AnyObject {
    #if DEBUG
    var cameraDiagnosticNetworkPath: NWPath? { get }
    #endif
    func cameraWebRTCConfiguration(entityID: String) async throws -> JSONValue
    func subscribeCameraWebRTC(entityID: String, offer: String, handler: @escaping @Sendable (CameraWebRTCSignal) async -> Void) async throws -> Int
    func sendCameraWebRTCCandidate(entityID: String, sessionID: String, candidate: JSONValue) async throws
    func closeCameraWebRTC(subscriptionID: Int) async
}

#if DEBUG
extension CameraWebRTCSignaling {
    var cameraDiagnosticNetworkPath: NWPath? { nil }
}
#endif

extension HomeAssistantService: CameraWebRTCSignaling {}

/// One native receive-only engine survives layout and presentation changes.
/// Authentication and signaling remain in HAWebSocketClient.
@MainActor @Observable
final class CameraWebRTCPlayback: NSObject {
    // MARK: - Properties
    @ObservationIgnored private let startupTimeout: Duration
    var isMuted = true { didSet { updateListening() } }
    /// Speculative decoding must not acquire audible output before transport selection.
    var isPlaybackSelected = true { didSet { updateListening() } }
    var isListeningAllowed: Bool { !isMuted && isPlaybackSelected }

    private func updateListening() {
        audioTrack?.isEnabled = isListeningAllowed
        if peer != nil, let generation {
            Self.audioDevice.setListening(isListeningAllowed, owner: generation)
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
    @ObservationIgnored private var candidateQueue: CameraWebRTCCandidateQueue?
    @ObservationIgnored private var completion: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var cleanupTask: Task<Void, Never>?
    @ObservationIgnored private var setupTask: Task<Void, Never>?
    @ObservationIgnored private var offerTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    #if DEBUG
    @ObservationIgnored private var candidateDiagnostics = CameraICECandidateDiagnostics()
    @ObservationIgnored private var diagnosticsTask: Task<Void, Never>?
    #endif
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
        #if DEBUG
        candidateDiagnostics = CameraICECandidateDiagnostics()
        recordNetworkPath()
        #endif
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
        let audioOwner = generation
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
        #if DEBUG
        if generation != nil { record(candidateDiagnostics.summary) }
        #endif
        generation = nil
        setupTask?.cancel()
        offerTask?.cancel()
        candidateQueue?.stop()
        timeoutTask?.cancel()
        #if DEBUG
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        #endif
        setupTask = nil
        offerTask = nil
        candidateQueue = nil
        timeoutTask = nil
        completion?.resume(returning: false)
        completion = nil
        subscriptionID = nil
        sessionID = nil
        configuration = nil
        if let videoView { videoTrack?.remove(videoView) }
        videoTrack = nil
        audioTrack = nil
        hasAudio = false
        dataChannel?.close()
        dataChannel = nil
        peer?.close()
        peer = nil
        if let audioOwner { Self.audioDevice.release(owner: audioOwner) }
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
        CameraWebRTCConfiguration.registerBeforeCreatingFactory()
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
        let rtcConfiguration = CameraWebRTCConfiguration.make(config)
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peer = Self.factory.peerConnection(with: rtcConfiguration, constraints: constraints, delegate: self) else {
            fail()
            return
        }
        self.peer = peer
        #if DEBUG
        diagnosticsTask = Task { [weak self, weak peer] in
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            guard let self, let peer, self.peer === peer, !self.hasStarted else { return }
            self.recordMediaCounters()
        }
        #endif
        if let service, let id = generation {
            let entityID = entityID
            candidateQueue = CameraWebRTCCandidateQueue(send: { sessionID, candidate in
                try await service.sendCameraWebRTCCandidate(entityID: entityID, sessionID: sessionID, candidate: candidate)
            }, failed: { [weak self] in
                guard self?.generation == id else { return }
                self?.record("WebRTC candidate send failed")
                self?.fail()
            }, acknowledged: { [weak self] in
                guard self?.generation == id else { return }
                #if DEBUG
                self?.candidateDiagnostics.didAcknowledge()
                #endif
            })
        }
        let schemes = rtcConfiguration.iceServers.flatMap(\.urlStrings).map { $0.split(separator: ":").first.map(String.init)?.lowercased() ?? "" }
        record("WebRTC ICE services: STUN \(schemes.filter { ["stun", "stuns"].contains($0) }.count), TURN \(schemes.filter { ["turn", "turns"].contains($0) }.count)")
        record("WebRTC route-aware ICE: path monitor, continual gathering, pool 1, host TCP disabled, link-local excluded")
        record("WebRTC ICE policy: \(rtcConfiguration.iceTransportPolicy == .relay ? "relay" : "all"), servers: \(rtcConfiguration.iceServers.count)")
        RTCSetMinDebugLogLevel(.none)
        if let id = generation {
            Self.audioDevice.acquire(owner: id, listening: isListeningAllowed) { [weak self] in
                Task { @MainActor [weak self] in
                    guard self?.generation == id else { return }
                    self?.isMuted = true
                }
            }
        }
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
        // The installed description includes candidates already gathered by the pool.
        submitOffer(peer.localDescription?.sdp ?? offer.sdp)
    }

    private func submitOffer(_ offer: String) {
        guard offerTask == nil, let service, let id = generation else { return }
        record("WebRTC offer created")
        #if DEBUG
        candidateDiagnostics.appendSDP(offer, direction: .local)
        #endif
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
            candidateQueue?.setSession(sessionID)
        case "answer":
            guard let answer = signal.answer else { fail(); return }
            record("WebRTC answer received")
            #if DEBUG
            candidateDiagnostics.appendSDP(answer, direction: .remote)
            #endif
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
                    self.record("WebRTC answer applied; candidate delivery enabled")
                    self.hasRemoteDescription = true
                    self.candidateQueue?.didApplyAnswer()
                    let pending = self.remoteCandidates
                    self.remoteCandidates.removeAll()
                    for candidate in pending { self.addRemoteCandidate(candidate) }
                }
            }
        case "candidate":
            guard let object = signal.candidate?.objectValue, let sdp = object["candidate"]?.stringValue else { return }
            #if DEBUG
            candidateDiagnostics.append(sdp, direction: .remote)
            #endif
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
                if error != nil {
                    self.record("WebRTC remote candidate rejected")
                    self.fail()
                }
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

    private func recordMediaCounters() {
        #if DEBUG
        record(candidateDiagnostics.summary)
        recordNetworkPath()
        let attempt = String(generation?.uuidString.prefix(8) ?? "stopped")
        peer?.statistics { report in
            let pairs = report.statistics.values.filter { $0.type == "candidate-pair" }
            let succeeded = pairs.filter { $0.values["state"] as? String == "succeeded" }.count
            let requests = pairs.reduce(0) { $0 + (($1.values["requestsSent"] as? NSNumber)?.intValue ?? 0) }
            let responses = pairs.reduce(0) { $0 + (($1.values["responsesReceived"] as? NSNumber)?.intValue ?? 0) }
            let received = pairs.reduce(0) { $0 + (($1.values["requestsReceived"] as? NSNumber)?.intValue ?? 0) }
            let sent = pairs.reduce(0) { $0 + (($1.values["responsesSent"] as? NSNumber)?.intValue ?? 0) }
            let summary = "[\(attempt)] WebRTC ICE pairs: \(pairs.count), succeeded: \(succeeded), requests: \(requests), responses: \(responses), inbound requests: \(received), outbound responses: \(sent)"
            Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup").info("\(summary, privacy: .public)")
            if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") { CameraStartupConsole.write(summary) }
            let selectedIDs = Set(report.statistics.values.filter { $0.type == "transport" }
                .compactMap { $0.values["selectedCandidatePairId"] as? String })
            for pair in pairs where selectedIDs.contains(pair.id) ||
                (selectedIDs.isEmpty && (pair.values["nominated"] as? NSNumber)?.boolValue == true && pair.values["state"] as? String == "succeeded") {
                func category(_ key: String) -> String {
                    guard let id = pair.values[key] as? String, let candidate = report.statistics[id] else { return "unknown" }
                    return CameraICECandidateSummary.describe(type: candidate.values["candidateType"] as? String,
                        transport: candidate.values["protocol"] as? String, address: candidate.values["address"] as? String ?? candidate.values["ip"] as? String,
                        tcpType: candidate.values["tcpType"] as? String)
                }
                let role = selectedIDs.isEmpty ? "nominated" : "selected"
                let selected = "[\(attempt)] WebRTC \(role) pair local \(category("localCandidateId")), remote \(category("remoteCandidateId"))"
                Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup").info("\(selected, privacy: .public)")
                if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") { CameraStartupConsole.write(selected) }
            }
            for statistic in report.statistics.values where statistic.type == "inbound-rtp" {
                guard statistic.values["kind"] as? String == "video" else { continue }
                let packets = statistic.values["packetsReceived"] as? NSNumber ?? 0
                let frames = statistic.values["framesDecoded"] as? NSNumber ?? 0
                if let codecID = statistic.values["codecId"] as? String,
                   let codec = report.statistics[codecID]?.values["mimeType"] as? String,
                   ["video/H264", "video/H265", "video/VP8", "video/VP9", "video/AV1"].contains(codec) {
                    Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup")
                        .info("WebRTC video codec: \(codec, privacy: .public)")
                    if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
                        CameraStartupConsole.write("[\(attempt)] WebRTC codec: \(codec)")
                    }
                }
                Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup")
                    .info("WebRTC video packets: \(packets.intValue, privacy: .public), decoded frames: \(frames.intValue, privacy: .public)")
                if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
                    CameraStartupConsole.write("[\(attempt)] WebRTC packets: \(packets.intValue), decoded frames: \(frames.intValue)")
                }
            }
        }
        #endif
    }

    #if DEBUG
    private func recordNetworkPath() {
        guard let path = service?.cameraDiagnosticNetworkPath else { record("WebRTC default network: unknown"); return }
        let interfaces: [(NWInterface.InterfaceType, String)] = [(.wifi, "wifi"), (.cellular, "cellular"), (.wiredEthernet, "wired"), (.other, "other")]
        let active = interfaces.filter { path.usesInterfaceType($0.0) }.map(\.1).joined(separator: "+")
        record("WebRTC default network: \(path.status == .satisfied ? "available" : "unavailable"), \(active.isEmpty ? "unknown" : active), IPv4 \(path.supportsIPv4), IPv6 \(path.supportsIPv6)")
    }
    #endif

    private func record(_ stage: String) {
        #if DEBUG
        let stage = "[\(generation?.uuidString.prefix(8) ?? "stopped")] \(stage)"
        Logger(subsystem: "com.tyler.Homestead", category: "CameraStartup").info("\(stage, privacy: .public)")
        if ProcessInfo.processInfo.arguments.contains("--camera-startup-console") {
            CameraStartupConsole.write("\(stage)")
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
            self.audioTrack?.isEnabled = self.isListeningAllowed
            if let track = stream.videoTracks.first { self.attachVideo(track) }
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            self.record("WebRTC ICE state: \(newState.rawValue)")
            if newState == .failed { self.recordMediaCounters(); self.fail() }
            if newState == .connected || newState == .completed { self.record("WebRTC ICE connected") }
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            self.record("WebRTC gathering state: \(newState.rawValue)")
            #if DEBUG
            if newState == .complete { self.record(self.candidateDiagnostics.summary) }
            #endif
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task { @MainActor [weak self] in
            guard let self, self.peer === peerConnection else { return }
            #if DEBUG
            self.candidateDiagnostics.append(candidate.sdp, direction: .local)
            #endif
            self.candidateQueue?.append(.object(["candidate": .string(candidate.sdp),
                "sdpMLineIndex": .number(Double(candidate.sdpMLineIndex)),
                "sdpMid": candidate.sdpMid.map(JSONValue.string) ?? .null]))
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
                track.isEnabled = self.isListeningAllowed
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
                track.isEnabled = self.isListeningAllowed
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
            self.recordMediaCounters()
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
