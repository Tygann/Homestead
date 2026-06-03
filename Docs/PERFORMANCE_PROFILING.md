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

