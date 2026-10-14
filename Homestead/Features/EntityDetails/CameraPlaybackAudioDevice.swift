import AVFoundation
@preconcurrency import WebRTC

/// A receive-only audio device. The SDK's default voice-processing unit enables
/// microphone input even when the peer only receives audio.
nonisolated final class CameraPlaybackAudioDevice: NSObject, RTCAudioDevice, @unchecked Sendable {
    // MARK: - Properties
    private let delegateLock = NSLock()
    private var storedDelegate: (any RTCAudioDeviceDelegate)?
    private var delegate: (any RTCAudioDeviceDelegate)? {
        get { delegateLock.withLock { storedDelegate } }
        set { delegateLock.withLock { storedDelegate = newValue } }
    }
    private var engine: AVAudioEngine?
    private var playback = CameraAudioPlaybackState()
    private var systemMuted: (@Sendable () -> Void)?
    private var observers: [NSObjectProtocol] = []
    private(set) var isInitialized = false
    private(set) var isPlayoutInitialized = false
    var isPlaying: Bool { playback.isPlaying }
    var isRecordingInitialized: Bool { false }
    var isRecording: Bool { false }
    var deviceInputSampleRate: Double { 48_000 }
    var inputIOBufferDuration: TimeInterval { 0.01 }
    var inputNumberOfChannels: Int { 1 }
    var inputLatency: TimeInterval { 0 }
    var deviceOutputSampleRate: Double { 48_000 }
    var outputIOBufferDuration: TimeInterval { 0.01 }
    var outputNumberOfChannels: Int { 1 }
    var outputLatency: TimeInterval { AVAudioSession.sharedInstance().outputLatency }

    // MARK: - Lifecycle
    func initialize(with delegate: any RTCAudioDeviceDelegate) -> Bool {
        self.delegate = delegate
        isInitialized = true
        let center = NotificationCenter.default
        observers = [AVAudioSession.routeChangeNotification, AVAudioSession.interruptionNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
                guard let self, let delegate = self.delegate else { return }
                let isInterruption = notification.name == AVAudioSession.interruptionNotification
                let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                    == AVAudioSession.InterruptionType.began.rawValue
                let options = AVAudioSession.InterruptionOptions(rawValue:
                    notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                let reason = AVAudioSession.RouteChangeReason(rawValue:
                    notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0)
                delegate.dispatchAsync { [weak self] in
                    guard let self else { return }
                    let wasListening = self.playback.isListening
                    if isInterruption {
                        self.playback.interruption(began: began, shouldResume: options.contains(.shouldResume))
                    } else {
                        // Our own session-category configuration must not trigger a restart loop.
                        guard let reason, reason != .categoryChange, reason != .unknown else { return }
                        self.playback.routeChanged(deviceRemoved: reason == .oldDeviceUnavailable)
                    }
                    self.stopEngine()
                    if wasListening, !self.playback.isListening { self.systemMuted?() }
                    if self.playback.shouldPlay { _ = self.startEngine() }
                }
            }
        }
        return true
    }

    func terminateDevice() -> Bool {
        stopEngine()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        delegate = nil
        isInitialized = false
        isPlayoutInitialized = false
        playback = CameraAudioPlaybackState()
        systemMuted = nil
        return true
    }

    // MARK: - Playback
    func acquire(owner: UUID, listening: Bool, systemMuted: @escaping @Sendable () -> Void) {
        guard let delegate else { return }
        delegate.dispatchAsync { [weak self] in
            guard let self else { return }
            self.playback.acquire(owner: owner, listening: listening)
            self.systemMuted = systemMuted
            self.updateOutput()
        }
    }

    func setListening(_ enabled: Bool, owner: UUID) {
        guard let delegate else { return }
        delegate.dispatchAsync { [weak self] in
            guard let self else { return }
            guard self.playback.setListening(enabled, owner: owner) else { return }
            self.updateOutput()
        }
    }

    func release(owner: UUID) {
        guard let delegate else { return }
        delegate.dispatchAsync { [weak self] in
            guard let self, self.playback.release(owner: owner) else { return }
            self.systemMuted = nil
            self.updateOutput()
        }
    }

    func initializePlayout() -> Bool {
        isPlayoutInitialized = true
        return true
    }

    func startPlayout() -> Bool {
        playback.isPlaying = true
        return !playback.shouldPlay || startEngine()
    }

    func stopPlayout() -> Bool {
        playback.isPlaying = false
        stopEngine()
        return true
    }

    func initializeRecording() -> Bool { false }
    func startRecording() -> Bool { false }
    func stopRecording() -> Bool { true }

    // MARK: - Private Helpers
    private func updateOutput() {
        if playback.shouldPlay { _ = startEngine() }
        else { stopEngine() }
    }

    private func startEngine() -> Bool {
        guard engine == nil, let delegate else { return engine != nil }
        var startingEngine: AVAudioEngine?
        var activatedSession = false
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setPreferredIOBufferDuration(outputIOBufferDuration)
            try session.setActive(true)
            activatedSession = true
            let engine = AVAudioEngine()
            startingEngine = engine
            let format = AVAudioFormat(standardFormatWithSampleRate: deviceOutputSampleRate, channels: 1)!
            let samples = CameraAudioSamples()
            let pull = delegate.getPlayoutData
            let source = AVAudioSourceNode(format: format) { _, timestamp, count, output in
                let buffers = UnsafeMutableAudioBufferListPointer(output)
                guard count <= CameraAudioSamples.capacity else {
                    for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
                    return noErr
                }
                var flags = AudioUnitRenderActionFlags()
                var pcm = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1,
                    mDataByteSize: count * 2, mData: samples.pointer))
                let status = pull(&flags, timestamp, 0, count, &pcm)
                for buffer in buffers {
                    guard let output = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for index in 0..<Int(count) { output[index] = status == noErr ? Float(samples.pointer[index]) / 32_768 : 0 }
                }
                return noErr
            }
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            delegate.notifyAudioOutputParametersChange()
            try engine.start()
            self.engine = engine
            return true
        } catch {
            startingEngine?.stop()
            if activatedSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            return false
        }
    }

    private func stopEngine() {
        guard let engine else { return }
        engine.stop()
        self.engine = nil
        delegate?.notifyAudioOutputInterrupted()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Mutations run on the SDK audio thread; stale owners cannot change current playback.
nonisolated struct CameraAudioPlaybackState {
    private(set) var owner: UUID?
    private(set) var isListening = false
    var isPlaying = false
    private(set) var isInterrupted = false
    var shouldPlay: Bool { owner != nil && isListening && isPlaying && !isInterrupted }

    mutating func acquire(owner: UUID, listening: Bool) {
        self.owner = owner
        isListening = listening
    }

    @discardableResult mutating func setListening(_ enabled: Bool, owner: UUID) -> Bool {
        guard self.owner == owner else { return false }
        isListening = enabled
        return true
    }

    @discardableResult mutating func release(owner: UUID) -> Bool {
        guard self.owner == owner else { return false }
        self.owner = nil
        isListening = false
        return true
    }

    mutating func interruption(began: Bool, shouldResume: Bool) {
        isInterrupted = began
        if !began, !shouldResume { isListening = false }
    }

    mutating func routeChanged(deviceRemoved: Bool) {
        if deviceRemoved { isListening = false }
    }
}

/// Storage is allocated before the realtime render callback and owned by it.
private nonisolated final class CameraAudioSamples: @unchecked Sendable {
    static let capacity: UInt32 = 4_096
    let pointer = UnsafeMutablePointer<Int16>.allocate(capacity: Int(capacity))
    init() { pointer.initialize(repeating: 0, count: Int(Self.capacity)) }
    deinit { pointer.deinitialize(count: Int(Self.capacity)); pointer.deallocate() }
}
