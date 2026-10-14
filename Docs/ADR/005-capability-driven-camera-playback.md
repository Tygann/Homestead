# ADR 5: Capability-Driven Camera Playback

## Status

Accepted

## Context

Home Assistant advertises `hls` and `web_rtc` through `camera/capabilities`. Some camera integrations offer only WebRTC; HLS-only playback excludes those cameras and can differ substantially from HA frontend startup behavior. The existing AVPlayer path remains useful for HLS compatibility.

## Decision

Prefer advertised WebRTC for entity-detail live viewing and retain advertised HLS as fallback. Use HA's authenticated native WebSocket connection for client configuration, asynchronous offer subscriptions, and ICE candidates. HLS URLs come from the core `camera/stream` WebSocket command and do not require Mobile App registration. Do not bypass HA to connect directly to Frigate, UniFi, or a configured go2rtc API.

Use a native receive-only WebRTC engine with a Metal video renderer inside the SwiftUI camera surface. Pin the community distribution of upstream WebRTC to an exact package version and retain its checksum-verified artifact. HA access tokens never enter the media engine; it receives SDP, ICE candidates, and HA-provided client configuration (which may contain ephemeral TURN credentials). Transceivers are receive-only and no local capture tracks are created. An injected playback-only `RTCAudioDevice` pulls decoded PCM into an output-only AVAudioEngine graph. It never creates an input node or delivers recorded samples, and rejects recording initialization/start. Muted previews defer output startup until the user enables listening. The default SDK voice-processing audio device enables microphone input even for receive-only peers and caused a physical-device TCC termination; adding microphone permission text is not a substitute for this receive-only boundary.

The distribution has no Apple HEVC decoder, so a receive-only VideoToolbox adapter extends its existing decoder factory on hardware supporting HEVC. It converts WebRTC's Annex B access units into Core Media samples, rebuilds decoding sessions when parameter sets change, and preserves frame timestamps/rotation. G6's HLS manifest advertised `hvc1.1.2.L150`; the upstream factory rejected its WebRTC video, making this adapter necessary for that hardware comparison.

One owned engine moves between detail/fullscreen and survives adaptive geometry changes. The native renderer receiving a nonempty decoded-frame size establishes readiness; the last good still remains visible beforehand. A 12-second WebRTC startup bound or explicit failure selects HLS when supported; otherwise the snapshot remains. Refresh, dismissal, backgrounding, failure, and connection loss clean up the peer and offer subscription; obsolete acknowledgements also unsubscribe. Replacement attempts wait for prior offer/cleanup completion within the startup bound. Foregrounding starts a new session.

## Consequences

Camera playback and chrome remain native. The WebRTC framework adds binary size and requires deliberate dependency/security updates. HLS retains AVPlayer. WebRTC codec support and ICE reachability depend on the camera, server configuration, platform, and network; local success does not establish remote or physical-device performance. Automatic selection avoids a protocol picker in normal use.

This is receive-only playback, not two-way audio, recording, or continuous dashboard live previews. Validate both Frigate and UniFi cameras plus HLS fallback, fullscreen, folding, cancellation, and local/remote connections.

## Sources

- [HA camera API changes](https://developers.home-assistant.io/blog/2024/11/26/camera-deprecations/)
- [HA camera entity](https://developers.home-assistant.io/docs/core/entity/camera/)
- [Official frontend camera API](https://github.com/home-assistant/frontend/blob/dev/src/data/camera.ts)
- [Official asynchronous signaling implementation](https://github.com/home-assistant/core/blob/dev/homeassistant/components/camera/webrtc.py)
- [Pinned native WebRTC distribution](https://github.com/stasel/WebRTC)
- [HA stream / LL-HLS](https://www.home-assistant.io/integrations/stream/)

- [Apple HEVC format descriptions](https://developer.apple.com/documentation/coremedia/cmvideoformatdescriptioncreatefromhevcparametersets(allocator:parametersetcount:parametersetpointers:parametersetsizes:nalunitheaderlength:extensions:formatdescriptionout:))
