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

The log contains only the most recent 128 opt-in Debug stage/counter/error-domain lines, with timestamps; no SDP, HA URLs, tokens, or entity payloads. Relaunch normally after verification. A USB data connection can preserve development connectivity during Wi-Fi changes, but the local capture avoids requiring one for the short behavior check.

The first cellular/background check reported about 25 seconds to live, then Snapshot on foreground return and about 11 seconds after manual reload; no microphone prompts/indicators appeared. The connection-dependent camera retry is covered by a hosted SwiftUI test and the successful physical retest below; transport-specific cold-start diagnosis remains pending. Instruments could not find the app's reported PID, so no valid physical profile was collected.

The standalone physical retest successfully recovered video on foreground without Reload: waiting for HA lasted about 0.6 seconds, followed by native WebRTC first-frame timing of 3,080 ms (about four seconds total by user observation). Cold cellular startup remained slow: WebRTC fallback at 12,339 ms, HLS handoff at 12,394 ms, and HLS playing at 25,234 ms. This proves the serial wait consumed most startup time; it does not explain why initial ICE failed while the later attempt connected. Bluetooth and a valid physical performance trace remain deferred.
