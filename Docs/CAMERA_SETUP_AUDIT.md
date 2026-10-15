# Camera Setup Audit — October 15, 2026

## Scope and outcome

Read-only authenticated audit of the configured Home Assistant instance and stable G6 reference, compared with official documentation and Core 2026.10.1 source. No server preferences, subscriptions, credentials, camera encoding settings, or router rules were changed. Media reads temporarily start the existing HA producer; no playback client or offer subscription is left open by the probe. The producer may remain warm until HA's normal idle timeout.

Homestead uses core camera capabilities, asynchronous WebRTC signaling, HA-provided ICE configuration, and the returned HLS HTTP media URL. No required API/setup mismatch was identified. Preserve the three-second producer preparation overlap, receive-only ownership, and SDK-required camera usage declaration in ADR 5.

## Live findings

| Check | Observation | Implication |
| --- | --- | --- |
| Core/integrations | 2026.10.1; stream, web_rtc, go2rtc, cloud loaded | Expected integrations available |
| Cloud | Signed out | Cloud relay cannot currently be supplied by this account session; subscription ownership is unknown |
| G6 ICE configuration | Policy all; two STUN URLs; no TURN | Direct connectivity only; no relay alternative for restrictive networks |
| G6 preload | Disabled | Supported default; continuous preload remains optional |
| HLS delivery | Successful HTTP/2 ALPN negotiation at configured origin | Recommended browser transport is available; this does not establish phone network performance |
| Media playlist | Blocking reload enabled, 1-second part target, 2-second part hold-back, partial segments present | LL-HLS is active; no need to enable it again |
| Segment output | Target duration 10 seconds | Observed output only; neither YAML segment duration nor camera keyframe interval was inspected |

Two sequential probes requested the core HLS URL, fetched its master, then the referenced media playlist. No signed URL, token, SDP, address, or Cloud account information was persisted in this document.

| Probe | Core URL response | Master response | Media response |
| --- | ---: | ---: | ---: |
| First observation | 41 ms | 11,169 ms | 95 ms |
| Repeat with warm producer | 37 ms | 133 ms | 59 ms |

These are Mac HTTP measurements, not a controlled cold-media experiment or phone playback timings. They demonstrate why URL readiness must not be treated as playable media. Core's camera helper adds the provider and starts the stream before returning the URL. The HLS master handler waits for two segment entries, with the last potentially incomplete. Our preparation already overlaps producer work; this audit does not justify removing it or adding a blocking manifest prefetch before AVPlayer.

## Next actions

1. Resolve relay availability: if the user already subscribes to Cloud, sign this instance in and verify WebRTC connections plus newly supplied TURN configuration. Otherwise retain the working HTTP fallback or explicitly provision a TURN service using HA's supported configuration. A subscription or externally reachable relay is a separate setup choice, not a prerequisite for Homestead's basic camera support.
2. Improve generic fallback startup through a bounded first-video race after the existing grace period, with one winner and explicit audio/cancellation ownership. This is an app design change inspired by official frontend behavior, not a prose documentation requirement; deliberately update ADR 5 if implemented.
3. Verify simulator behavior and focused lifecycle tests before a single bundled cellular phone comparison. No additional phone test is useful for the unchanged build from this audit.

Permanent preload can reduce startup but consumes ongoing server resources. Leave it disabled unless that tradeoff is chosen; it would also conceal the cold-start comparison. Do not change camera encoding/keyframes from the target-duration tag alone. Do not shorten native timeout or AVPlayer buffering without evidence.

## Official references

- [HA stream and LL-HLS configuration](https://www.home-assistant.io/integrations/stream/): LL-HLS defaults, HTTP/2 browser recommendation, configurable segment and part durations.
- [HA camera preload](https://www.home-assistant.io/integrations/camera/): startup benefit and continuous resource cost.
- [Cloud WebRTC relay](https://support.nabucasa.com/hc/en-us/articles/25619464018461-Improved-camera-streaming-with-WebRTC): signed-in Cloud relay, direct-only STUN limitations, fallback behavior.
- [Custom ICE configuration](https://www.home-assistant.io/integrations/web_rtc/): supported STUN/TURN configuration; YAML uses `url`, while client RTC configuration uses `urls`.
- [Core camera stream helper, 2026.10.1](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/camera/helper.py): producer start before endpoint return.
- [Core HLS handler, 2026.10.1](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/stream/hls.py): master segment readiness and media playlist output.
- [Core Cloud status, 2026.10.1](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/cloud/http_api.py): authenticated status and signed-out account shape.
