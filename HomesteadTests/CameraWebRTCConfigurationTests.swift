import Testing
@preconcurrency import WebRTC
@testable import Homestead

@MainActor
struct CameraWebRTCConfigurationTests {
    @Test func routeAwareGatheringPreservesHARelayPolicyAndTurnTransports() throws {
        let configuration = CameraWebRTCConfiguration.make([
            "iceTransportPolicy": .string("relay"),
            "iceServers": .array([
                .object(["urls": .array([.string("turn:relay.example:3478?transport=tcp"), .string("turns:relay.example:5349")]),
                         "username": .string("ephemeral-user"), "credential": .string("ephemeral-test-credential")]),
                .object(["urls": .string("stun:stun.example:3478")])
            ])
        ])
        #expect(configuration.iceTransportPolicy == .relay)
        let server = try #require(configuration.iceServers.first)
        #expect(server.urlStrings == ["turn:relay.example:3478?transport=tcp", "turns:relay.example:5349"])
        #expect(server.username == "ephemeral-user")
        #expect(server.credential == "ephemeral-test-credential")
        #expect(configuration.iceServers.count == 2)
        #expect(configuration.tcpCandidatePolicy == .disabled)
        #expect(configuration.disableLinkLocalNetworks)
        #expect(configuration.continualGatheringPolicy == .gatherContinually)
        #expect(configuration.iceCandidatePoolSize == 1)
        #expect(configuration.bundlePolicy == .maxBundle)
        #expect(!configuration.disableIPV6OnWiFi)
        #expect(configuration.maxIPv6Networks > 0)
    }

    @Test func missingServersDoNotIntroduceAnExternalRelay() {
        let configuration = CameraWebRTCConfiguration.make([:])
        #expect(configuration.iceTransportPolicy == .all)
        #expect(configuration.iceServers.isEmpty)
        #expect(configuration.sdpSemantics == .unifiedPlan)
    }
}
