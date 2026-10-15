import Testing
@testable import Homestead

struct MediaPlayerCapabilityTests {
    @Test(arguments: [
        ("playing", 1, true), ("paused", 1, false),
        ("playing", 16_384, false), ("paused", 16_384, true),
        ("idle", 16_384, true), ("off", 0, false),
        ("playing", 16_385, true), ("paused", 16_385, true)
    ])
    func playbackFollowsAdvertisedActionForCurrentState(state: String, features: Int, expected: Bool) throws {
        let media = try #require(EntityMapper.mediaPlayerEntity(from: HAEntityDTO(
            entityID: "media_player.test", state: state,
            attributes: ["supported_features": .number(Double(features))]
        )))
        #expect(media.supportedFeatures == features)
        #expect(media.supportsPlayPause == expected)
    }

    @Test func attributesAloneDoNotAdvertiseControls() throws {
        let media = try #require(EntityMapper.mediaPlayerEntity(from: HAEntityDTO(
            entityID: "media_player.test", state: "playing",
            attributes: ["volume_level": .number(0.4), "source_list": .array([.string("Music")])]
        )))
        #expect(!media.supportsPlayPause)
        #expect(!media.supportsVolumeControl)
        #expect(!media.supportsSourceSelection)
    }

    @Test func volumeAndSourceNeedFeatureAndUsableAttributes() throws {
        for features in [0, 4, 2_048, 2_052] {
            let media = try #require(EntityMapper.mediaPlayerEntity(from: HAEntityDTO(
                entityID: "media_player.test", state: "idle",
                attributes: ["supported_features": .number(Double(features)),
                    "volume_level": .number(0.4), "source_list": .array([.string("Music")])]
            )))
            #expect(media.supportsVolumeControl == (features & 4 != 0))
            #expect(media.supportsSourceSelection == (features & 2_048 != 0))
        }
        let media = try #require(EntityMapper.mediaPlayerEntity(from: HAEntityDTO(
            entityID: "media_player.test", state: "idle",
            attributes: ["supported_features": .number(2_052)]
        )))
        #expect(!media.supportsVolumeControl)
        #expect(!media.supportsSourceSelection)
    }
}
