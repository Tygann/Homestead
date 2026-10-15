@preconcurrency import WebRTC

/// Match the official native HA client's route-aware iOS ICE setup.
@MainActor
enum CameraWebRTCConfiguration {
    // MARK: - Initialization
    private static let registerFieldTrials: Void = {
        // The pinned SDK exposes field trials through this global API only.
        // Register before constructing either configuration or the shared factory.
        RTCInitFieldTrialDictionary([kRTCFieldTrialUseNWPathMonitor: kRTCFieldTrialEnabledValue])
    }()

    static func registerBeforeCreatingFactory() {
        _ = registerFieldTrials
    }

    // MARK: - Public API
    static func make(_ config: [String: JSONValue]) -> RTCConfiguration {
        registerBeforeCreatingFactory()
        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        configuration.bundlePolicy = .maxBundle
        configuration.continualGatheringPolicy = .gatherContinually
        // Avoid cellular host TCP listeners and link-local interface pairs. HA-provided
        // TURN servers, including TURN over TCP/TLS, remain available to the engine.
        configuration.tcpCandidatePolicy = .disabled
        configuration.disableLinkLocalNetworks = true
        configuration.iceCandidatePoolSize = 1
        configuration.iceTransportPolicy = config["iceTransportPolicy"]?.stringValue == "relay" ? .relay : .all
        configuration.iceServers = (config["iceServers"]?.arrayValue ?? []).compactMap { server in
            guard let object = server.objectValue else { return nil }
            let urls = object["urls"]?.arrayValue?.compactMap(\.stringValue)
                ?? object["urls"]?.stringValue.map { [$0] } ?? []
            guard !urls.isEmpty else { return nil }
            return RTCIceServer(urlStrings: urls, username: object["username"]?.stringValue,
                credential: object["credential"]?.stringValue)
        }
        return configuration
    }
}
