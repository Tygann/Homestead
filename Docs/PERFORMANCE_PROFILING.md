# Performance Profiling

Use this runbook when Homestead feels sluggish and the cause is not obvious from code review. Prefer a physical iPhone with live Home Assistant data; simulator results can miss render, GPU, and network behavior.

## Dashboard Rendering Example

In June 2026, dashboard scrolling/navigation lag was traced to repeated card compositing work:

- `CardContainer` applied drop shadows to every repeated card in scrolling grids.
- Camera preview cards added another shadow plus a material footer overlay.
- Instruments showed render/GPU-bound hitches with high offscreen-pass counts, while SwiftUI update work was usually only a few milliseconds.
- Replacing repeated shadows/materials with lightweight strokes and flat overlays removed the exported hitch rows in the follow-up trace.

## Setup

1. Connect the iPhone to the Mac. USB is preferable for repeatable traces; wireless can work but is easier to interrupt.
2. Build and run Homestead on the phone from Xcode.
3. Leave the app on the screen where the issue starts, then record from Terminal.

Find the device identifier:

```sh
xcrun xctrace list devices
```

If needed, confirm device connection state:

```sh
xcrun devicectl list devices
```

## Animation Hitches Trace

Use this first when the app feels janky during scrolling, transitions, or gestures:

```sh
mkdir -p Build/Traces
rm -rf Build/Traces/homestead-animation-hitches.trace
xcrun xctrace record \
  --template 'Animation Hitches' \
  --device DEVICE_IDENTIFIER \
  --all-processes \
  --time-limit 90s \
  --output Build/Traces/homestead-animation-hitches.trace \
  --no-prompt
```

While recording, reproduce the same path consistently. For dashboard issues, use a path like:

- Scroll Dashboard, especially with camera cards visible.
- Open and close a few card details.
- Open summary chips.
- Visit Areas and Devices, then return to Dashboard.

Export the useful tables:

```sh
xcrun xctrace export \
  --input Build/Traces/homestead-animation-hitches.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches"]' \
  --output Build/Traces/hitches.xml

xcrun xctrace export \
  --input Build/Traces/homestead-animation-hitches.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches-renders"]' \
  --output Build/Traces/hitches-renders.xml

xcrun xctrace export \
  --input Build/Traces/homestead-animation-hitches.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches-updates"]' \
  --output Build/Traces/hitches-updates.xml

xcrun xctrace export \
  --input Build/Traces/homestead-animation-hitches.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches-gpu"]' \
  --output Build/Traces/hitches-gpu.xml
```

Read the tables with:

```sh
sed -n '1,160p' Build/Traces/hitches.xml
sed -n '1,160p' Build/Traces/hitches-renders.xml
sed -n '1,160p' Build/Traces/hitches-updates.xml
sed -n '1,160p' Build/Traces/hitches-gpu.xml
```

Useful interpretation:

- High offscreen-pass counts usually point at shadows, materials, masks, clipping, blur, or layered translucent surfaces in repeated views.
- Long `hitches-updates` rows point more toward SwiftUI body work, observation breadth, sorting/grouping, or expensive derived presentation.
- Long GPU rows point toward compositing, image rendering, camera previews, gradients, and overdraw.

## Optional Signposts

Use signposts when you need to correlate user navigation or expensive presentation builders with Instruments. Keep them temporary unless there is a durable diagnostic reason to leave them in.

```swift
#if DEBUG
import OSLog

enum PerformanceSignpost {
    private static let log = OSLog(subsystem: "com.tyler.Homestead", category: "Performance")

    static func event(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }

    static func measure<T>(_ name: StaticString, _ message: String = "", _ work: () -> T) -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id, "%{public}s", message)
        let result = work()
        os_signpost(.end, log: log, name: name, signpostID: id, "%{public}s", message)
        return result
    }
}
#endif
```

Animation Hitches may not always expose custom signposts in exported tables. If signpost correlation matters, also try a Time Profiler or System Trace run targeting Homestead.

## Before And After

For performance fixes, capture a before trace and an after trace using the same device and navigation path. A fix is much more trustworthy when both are true:

- The user can feel the improvement on the device.
- The relevant exported trace rows shrink or disappear.


## Camera Startup And Duo Resizing

Debug builds log camera startup stages under subsystem `com.tyler.Homestead`, category `CameraStartup`, without URLs or credentials. Compare `Capabilities resolved`, `Snapshot received`, `Stream handoff received`, and `Playback playing` to separate capability/handoff latency from AVPlayer startup. Snapshot loading runs concurrently and does not gate stream installation. `Playback playing` records the shared detail/fullscreen HLS player's first playing status. WebRTC logs offer/answer/session, ICE connection, and `WebRTC first frame` (the native renderer receiving a nonempty decoded-frame size). These are startup milestones, not a GPU presentation timestamp; verify visible video as well. Timeout counters report only received video packets and decoded frame counts, never SDP, ICE addresses, or TURN credentials.

For a signed-in app profile on the Duo simulator, inspect stages with:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun simctl spawn <duo-udid> log show --info --last 5m --predicate 'subsystem == "com.tyler.Homestead" AND category == "CameraStartup"' --style compact
```

Camera playback now uses core WebSocket APIs and does not require Mobile App registration. Test with a signed-in normal profile or isolated `--live-preview`. Debug-only `--camera-startup-console` also prints sanitized stages to stdout for `devicectl --console` capture. Debug-only `--camera-force-hls` bypasses the WebRTC attempt to verify the advertised HLS path; relaunch without that argument afterward. Test opening/closing camera detail during preparation, refresh replacement, fullscreen, background/foreground, and fold/unfold/rotation while playing. Keep dashboard still refresh and live playback separate.

Use `--preview-screen home --preview-card-state resize` for credential-free Security scroll checks. Its long Devices and Activity fixtures support independent checkpoints across tab switches and compact/split transitions. A bookmark retains its original offset when an interim lazy-stack estimate clamps the viewport, and user scrolling takes precedence over restoration.

The October 13 physical iPhone 15 Pro profiling attempt disconnected after 2.12 seconds; targeted attachments could not locate Homestead despite CoreDevice listing its process. These attempts do not establish physical camera startup latency, steady-state hitch rates, or physical Duo readiness. A separate registered Duo simulator run measured capabilities at 267 ms, handoff at 353 ms, snapshot receipt at 17,111 ms, and playback at 17,144 ms. Both media arrivals were delayed after the quick handoff; this supports investigating source delivery/playback startup without claiming a proven server-side cause. Actual live frames survived fold/unfold, rotation, partial opening, and fullscreen without another handoff. Re-run a valid trace before making performance claims.


For physical startup capture, build/install Debug, unlock the phone, then launch with:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun devicectl device process launch --device <iphone-udid> --terminate-existing --console --environment-variables '{"OS_ACTIVITY_MODE":"disable"}' com.tyler.Homestead -- --camera-startup-console
```

Open the camera manually and compare the printed stage timings with visible playback. This does not record a hitch trace. WebRTC uses an injected playback-only audio device; muted previews do not start its output engine. Verify listening, routing, and interruption recovery separately on hardware. The default SDK voice-processing unit enabled microphone input even for receive-only playback and caused an iOS privacy termination; it must not be reintroduced. A simulator RemoteIO initialization abort and received packets with zero decoded video frames were observed during development, so simulator failures do not alone establish camera/server latency or device decoding behavior.

The October 14 native HEVC pass used G6 as the stable physical-device reference: decoded-frame timings were 1,970 ms initially and 1,665/2,046 ms on refresh, with user-confirmed visible motion and listening. The earlier HLS comparison reached playing at 19,304 ms. These startup timings are not a CPU, energy, or hitch profile. Front Porch failed in both Homestead and HA during that check. The simulator does not advertise HEVC when VideoToolbox reports no hardware support, so its G6 checks cover HLS fallback/layout; use hardware for HEVC decoding/audio.

### Short Remaining Hardware Check

Complete automated signaling/audio-policy checks, simulator refresh/dismiss/background/fullscreen checks, and leak inspection first. Keep G6 as the reference and bundle hardware testing into one session of about three minutes:

1. With Homestead open, turn Wi-Fi off and open G6 over cellular. Confirm moving video and note any unusually long preparation. Compare with HA on the same network only if it fails.
2. Connect Bluetooth headphones and unmute. Confirm audio in the headphones; disconnect them and confirm Homestead mutes instead of continuing on the speaker. Reconnect and explicitly unmute to resume listening.
3. Briefly background or lock the phone, then return to G6. Confirm video restarts. If a real call/audio interruption occurs, confirm audio stays suspended during it and only resumes when iOS permits; a nonresumable interruption requires explicit unmute.

Restore Wi-Fi and leave the app available normally afterward. Capture sanitized startup logs during this same session if the phone is connected. Do not repeat the already-verified initial local playback, refresh, or fullscreen checks unless a failure requires it. Bluetooth/cellular results and a valid physical Instruments trace cannot be inferred from simulator success or synthetic audio notifications.

The reliability follow-up passed 26 focused camera tests and live G6 HLS lifecycle checks on Duo/iOS 27.1. Post-dismissal memgraphs showed no retained camera playback controller, peer, renderer, decoder, or output engine; the singleton factory/audio device remain intentionally. Leak scanning grew from 44/1,408 bytes before camera use to 50/1,600 bytes afterward, all untyped 32-byte allocations. The six extra allocations cannot be attributed without allocation backtraces; no camera-engine leak was identified, and whole-app leak freedom is not established. Captures are local under `/tmp/homestead-camera-reliability-memory/`, not committed.

### Cellular Checks Without A Wireless Console

Changing Wi-Fi can drop the wireless CoreDevice console/Instruments connection. It does not undo an installed build. For cellular verification, launch the Debug app independently with the diagnostic flag, complete the check, restore Wi-Fi, then retrieve the bounded local stage log:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun devicectl device process launch --device <iphone-udid> --terminate-existing com.tyler.Homestead -- --camera-startup-console
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun devicectl device copy from --device <iphone-udid> --domain-type appDataContainer --domain-identifier com.tyler.Homestead --source Library/Caches/CameraStartup.log --destination /tmp/Homestead-CameraStartup.log
```

The log contains only the most recent 512 opt-in Debug stage/counter/error-domain lines, with timestamps; no SDP, HA URLs, tokens, or entity payloads. Relaunch normally after verification. A USB data connection can preserve development connectivity during Wi-Fi changes, but the local capture avoids requiring one for the short behavior check.

The first cellular/background check reported about 25 seconds to live, then Snapshot on foreground return and about 11 seconds after manual reload; no microphone prompts/indicators appeared. The connection-dependent camera retry is covered by a hosted SwiftUI test and the successful physical retest below; transport-specific cold-start diagnosis remains pending. Instruments could not find the app's reported PID, so no valid physical profile was collected.

The standalone physical retest successfully recovered video on foreground without Reload: waiting for HA lasted about 0.6 seconds, followed by native WebRTC first-frame timing of 3,080 ms (about four seconds total by user observation). Cold cellular startup remained slow: WebRTC fallback at 12,339 ms, HLS handoff at 12,394 ms, and HLS playing at 25,234 ms. This proves the serial wait consumed most startup time; it does not explain why initial ICE failed while the later attempt connected. Bluetooth and a valid physical performance trace remain deferred.


### Cold Cellular ICE Candidate Delivery (October 15)

Authenticated read-only inspection found G6 on HA Core 2026.10.1, registered through UniFi Protect with go2rtc loaded. Its client configuration advertises two STUN URLs and no TURN URL. This is configuration evidence, not proof that every cellular NAT path can reach the media endpoint.

The matching [Core signaling implementation](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/camera/webrtc.py) emits the session before invoking the provider. The [go2rtc provider](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/go2rtc/__init__.py) awaits source preparation before registering its session and ignores unknown-session candidates. Homestead now queues local candidates until both the session and successfully applied remote answer exist. At most four candidate requests run concurrently, avoiding one cellular round trip per candidate. Canceled queued sends and late completions cannot affect a replacement. This mitigates a real source-level race; the previous phone logs lack candidate evidence to establish it as their root cause.

Debug stages now include an eight-character local attempt tag, ICE/gathering enum values, STUN/TURN counts, local/remote candidate type and transport/address-family categories, candidate acknowledgements, and aggregate ICE pair counts/requests/responses. A six-second snapshot captures counters before timeout teardown, with another requested at failure. Pair statistics are SDK snapshots and may be empty. No raw candidate, SDP, IP, port, server URL, session ID, or credential is logged. ICE raw states are new=0, checking=1, connected=2, completed=3, failed=4, disconnected=5, closed=6; gathering is new=0, gathering=1, complete=2. The opt-in cache is bounded to 512 lines so the expanded diagnostics retain the cold attempt through the bundled refresh/recovery checks; retrieval commands above apply.

Bundle the remaining physical acceptance into one short session after installing this Debug revision and launching with `--camera-startup-console`:

1. Disable Wi-Fi **before launching/opening G6**. Avoid opening G6 in HA first, since that may warm its producer. Confirm moving video and note startup time. Keep the app alive long enough to record fallback if native startup fails; HLS preparation should still start around three seconds.
2. Refresh G6 once, then briefly background/lock and return without Reload. Confirm automatic recovery. Restore Wi-Fi and verify G6 again. Retrieve the cache log after restoring connectivity and compare the attempt tags, candidate categories, acknowledgements, ICE requests/responses, and first-frame versus HLS milestones.
3. Only if the cold cellular attempt still fails, compare G6 in HA over the same cellular connection and capture a fresh cold Homestead attempt separately. STUN-only configuration can still leave a reachability limitation; do not add arbitrary TURN services, direct go2rtc calls, shorter timeouts, or repeated retries without that evidence.

Continue using G6 as the stable reference. This check establishes cellular behavior only; Bluetooth and an Instruments performance trace remain deferred. The HLS preparation overlap and SDK-required camera usage declaration remain intact.


#### Physical Retest Result

The October 15 signed Debug retest preserved the waiting snapshot. The user observed roughly 17 seconds to initial live video and roughly three seconds after background/return without Reload. The retrieved cache log showed:

- Cold attempt: HLS preparation at 3,208 ms, ready at 3,281 ms; native timeout/fallback at 12,220 ms; HLS playing at 13,135 ms from camera-load start. The difference from the observed total is not explained by this log.
- Cold ICE counters: 55 candidate pairs, zero successful pairs, 122 requests/zero responses at the six-second snapshot and 242 requests/zero responses at timeout. Candidate acknowledgements are present in the retained tail, but the beginning of this attempt was overwritten. These counters establish unanswered connectivity checks, not the failing network hop or a definite NAT/TURN diagnosis.
- First foreground return: about 0.48 seconds waiting for HA; native first frame at 2,415 ms after camera-load start. A later foreground attempt waited about 0.38 seconds for HA and reached a frame at 2,721 ms. The user restored Wi-Fi before retrieval; the log does not label which network each attempt used.

The candidate timing mitigation did not resolve cold cellular ICE. Preserve the verified HLS overlap and automatic foreground recovery. Next investigate the cold media reachability path, with an HA comparison on the same cellular connection if needed. Do not infer that a relay is mandatory or shorten the native bound from these counters alone.

The 512-line cache was full: repeated remote candidate category lines displaced the initial cold configuration/session/answer stages. Complete later attempts each contained 129 host/TCP/IPv6 candidate events; category equality does not establish duplicate candidate payloads. Before the next phone check, aggregate candidate diagnostics by category and preserve startup milestones rather than continuing to expand the ring. The sanitized capture remains local at `/tmp/homestead-camera-ice-physical.log` and is not committed.


### Candidate Aggregation And Endpoint Trace

The next Debug revision replaces per-candidate/ack lines with one bounded summary at gathering completion, six seconds, first frame, and stop/failure. It records local/remote totals, embedded-SDP counts, acknowledgement count, allowlisted type/protocol/address family/scope/TCP role categories, and first/last arrival milliseconds from the native attempt. Distinct-payload counts use at most 512 process-random fingerprints per direction; `unique` means distinct candidate strings (including foundation/extensions), not distinct endpoints. Fingerprints are never logged or persisted. More than 512 distinct payloads produces a `512+` lower bound. A 10,000-event burst is covered by an aggregation/privacy regression test. The existing 512-line cache bound remains unchanged.

First-frame statistics now report the transport's selected pair, with a nominated/succeeded fallback labeled `nominated` when no transport selection is exposed. Only candidate categories leave SDK statistics. Pair totals include inbound requests and outbound responses as well as sent requests/received responses. Default-network snapshots use the existing HA NWPathMonitor and expose only availability, Wi-Fi/cellular/wired/other categories and IP-family support. This is the system default path, not proof of the interface used by a selected ICE socket; previews or a monitor not started can report unknown. No interface names, addresses, ports, server URLs, raw SDP, credentials, hashes, or session IDs are persisted.

Two short G6 sessions through **official HA WebSocket signaling**, using synthetic receive-only offers without local trickle candidates or ICE/media traffic, both returned 13 distinct candidate payloads: private IPv4 UDP/TCP, four private IPv6 UDP/TCP pairs, shared IPv4 UDP/TCP, and one server-reflexive IPv4 UDP candidate. All six TCP listener candidates used 18555. Answers arrived at 73/44 ms and last candidates at 128/90 ms. Both subscriptions were explicitly unsubscribed. These are signaling probes from the Mac, not a cold-media or cellular connection test. Only category/count/timing summaries were output; no raw endpoint or SDP capture was saved. One go2rtc config entry exists, but official entry metadata cannot prove managed versus external mode.

Version-scoped interpretation:

- [HA 2026.10.1 server configuration](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/go2rtc/server.py) sets managed go2rtc to TCP 18555 with random UDP ports. The observed listeners are consistent with this mode, not definitive proof of it. Do not apply generic advice to forward default go2rtc port 8555 to this setup.
- [HA's provider](https://github.com/home-assistant/core/blob/2026.10.1/homeassistant/components/go2rtc/__init__.py) forwards client ICE servers per offer, so its global empty ICE-server list does not disable the per-session STUN configuration. [Documented HA configuration](https://www.home-assistant.io/integrations/go2rtc/) exposes an external go2rtc URL and authenticated debug UI; raw candidate/filter configuration is not an HA YAML option. No debug UI or server setting was enabled.
- [go2rtc 1.9.14](https://github.com/AlexxIT/go2rtc/blob/v1.9.14/go.mod) uses Pion ICE 4.2.0. [Pion's passive TCP handling](https://github.com/pion/ice/blob/v4.2.0/agent.go) generates active candidates across matching local IPs. Native client candidates can therefore elicit additional server events absent from the candidate-free probe. The older phone log omitted TCP roles, so this is a source-backed explanation for possible expansion, not proof that every observed event came from it. Keep all supported candidates; do not deduplicate/filter based on category equality.

Remaining physical comparison: install the new signed Debug revision with the same opt-in log flag; disable Wi-Fi before opening G6 and keep it off through the entire Homestead cold/Refresh/background-return sequence. The user reports Tailscale installed with Connect on Demand and VPN status disconnected on later inspection; that does not establish the earlier attempt's route. Note VPN state before/after the check without changing it mid-comparison. Close Homestead's camera before opening G6 in HA on the same cellular connection if native still falls back. Record ordering and whether HA itself displays moving video quickly; opening either viewer can warm the producer, so this alone is not an equal-server-coldness experiment. Restore Wi-Fi only after the cellular sequence, then retrieve the log. Compare default-network snapshots, first/last candidate timing, TCP roles, selected/nominated pair categories, and both directions of ICE checks before proposing a transport/configuration change. This check is still needed; the Mac probe cannot identify a cellular failing hop, mandate TURN, or justify timeout changes.


### Network-Labeled Cellular Comparison Result

The next physical capture is complete and remains local at `/tmp/homestead-camera-aggregate-physical.log`. The bounded summaries preserved the complete starts and failure milestones. User observations: initial roughly 16 seconds, Refresh roughly 12 seconds, background/return roughly 12 seconds, then HA app G6 moving video almost instant (about half a second). Wi-Fi was restored after the comparison.

| Homestead attempt | Default path | HLS preparation | Native fallback | HLS playing | ICE requests sent |
| --- | --- | --- | --- | --- | --- |
| Initial | Cellular, IPv4/IPv6 available | 3,238 ms | 12,211 ms | 16,781 ms | 241 |
| Refresh | Cellular, IPv4/IPv6 available | 3,205 ms | 12,194 ms | 13,425 ms | 238 |
| Foreground return | Cellular, IPv4/IPv6 available | 3,219 ms | 12,239 ms | 13,073 ms | 242 |

Each full attempt recorded 17 distinct local candidate payloads, all 17 acknowledged, 144 distinct remote candidate payloads, 55 pairs, no successful pair, zero received ICE responses, zero inbound requests, and zero outbound responses. Local candidates completed within roughly 0.22–0.35 seconds; remote candidates arrived by roughly 0.51–1.87 seconds. Remote categories include 105 active TCP link-local IPv6 payloads and 20 active TCP private IPv6 payloads. These are distinct payloads, not a reason to discard a category; the source-backed passive-to-active candidate expansion remains relevant. No selected pair existed. One additional short foreground attempt was canceled before six seconds and is not counted as a completed failure.

This verifies HLS overlap, retained snapshots, complete diagnostic capture, and automatic foreground restart. It does **not** verify native cellular recovery: foreground also fell back in this controlled cellular sequence. Earlier successful foreground attempts lacked network labels; do not retroactively label them cellular. Default NWPath labels still do not prove the interface used by every ICE socket or establish VPN state.

HA was tested after Homestead had already started the producer, and its actual playback transport was not captured. Its nearly immediate video is a meaningful comparison but not proof that HA WebRTC traversed the same cellular path. Next trace official frontend/Companion transport selection and native SDK offer/gathering/ICE differences before proposing another physical experiment. No new timeout, candidate filtering, VPN, relay, router, or server configuration change follows from this capture alone.
