# Live Home Assistant Previews

Homestead includes a debug-only `Live Home Assistant` Xcode preview. It is intentionally opt-in so Home Assistant credentials are not stored in source code.

## Preferred local setup

For deterministic Xcode previews only, create disposable Home Assistant long-lived access tokens, then copy `PreviewCredentials.example.json` to `PreviewCredentials.json` at the repo root and fill in:

```json
{
  "servers": [
    {
      "name": "My Home",
      "baseURL": "https://homeassistant.example.com",
      "accessToken": "your-preview-only-token"
    },
    {
      "name": "Friend's Home",
      "baseURL": "https://friends-home-assistant.example.com",
      "accessToken": "your-friends-preview-only-token"
    }
  ]
}
```

`PreviewCredentials.json` is ignored by git and copied into Debug builds only. It is not used by normal app sign-in; the app uses Home Assistant OAuth through Settings.

Do not commit this file or reuse a personal token you care about elsewhere. Revoke the preview token when you are done with live preview work.

## Live Preview Behavior

The live preview reads every server in the bundled `PreviewCredentials.json` copied by the Debug build phase. Open the avatar, then Settings > Servers to switch the Canvas between them. The previously active preview server remains selected across preview reloads. The original single-server JSON shape remains supported for compatibility.

If `PreviewCredentials.json` is missing, the live preview falls back to the saved base URL and OAuth credential from local app storage. Xcode Preview may not reliably share the simulator app's Keychain/container, so the local JSON file is the recommended live preview path.

## Notes

The default `Sample Data` preview never connects to Home Assistant. Use it for UI work when you do not need real entities.

The `Live Home Assistant` preview stores dashboard definitions and selection in Homestead's App Group container, with profile-specific keys for each preview server. This keeps live preview layout edits persistent when Xcode replaces the ordinary Canvas app container without mixing them into the simulator app's normal on-device dashboard layout. Existing layouts from the earlier preview-specific `UserDefaults` suite migrate automatically.

For recovery after replacing or erasing the simulator/runtime, stop editing the dashboard and export its current App Group state from the simulator used by Canvas:

```sh
Scripts/export_live_preview_dashboard.sh <simulator-udid>
```

The optional simulator argument defaults to `booted`. The script writes `PreviewDashboardLayout.json` at the repo root. That file is ignored by git, contains only dashboard configuration and selection keys, and is copied into Debug builds. When App Group storage has no layout for a server, the live preview restores the matching layout from this bundled backup. It never overwrites a layout already present in App Group storage.

## Debug Simulator Launch

Debug builds can use the same isolated live-preview environment outside Xcode's canvas. Launch with `--live-preview` to bypass onboarding without writing the preview token into the simulator Keychain or changing the normal OAuth startup path:

```sh
xcrun simctl launch booted com.tyler.Homestead --live-preview
```

For focused card inspection, optionally replace the preview-specific dashboard with one live entity and select its card size:

```sh
xcrun simctl launch booted com.tyler.Homestead \
  --live-preview \
  --preview-entity sensor.example_battery \
  --preview-presentation chart \
  --preview-size square \
  --preview-appearance dark
```

Supported sizes are `mini`, `compact`, `row`, `square`, `wide`, and `large`. Optional presentation values are `control`, `status`, `circularGauge`, `segmentedGauge`, `barGauge`, `chart`, `camera`, `weather`, `media`, and `action`; the presentation must support the selected size. Preview appearance accepts `system`, `light`, or `dark`. These arguments are compiled only in Debug builds. Live-preview services do not register Homestead as a Home Assistant Mobile App device.

For UI-only simulator checks that should bypass onboarding without connecting to Home Assistant, launch a Debug-only sample screen:

```sh
xcrun simctl launch booted com.tyler.Homestead --preview-screen appearance
```

Available sample screens are:

| Value | Purpose |
| --- | --- |
| `appearance` | Appearance settings with deterministic sample dependencies. |
| `dashboard-card-editor` | Unified contextual card editor with a live Gauge preview and exact dashboard-item context. |
| `dashboard-cards` | Chart, Weather, Media, and Action cards across Compact, Square, Wide, and Large layouts. |
| `entity-detail-card` | Entity-first detail opened from a Chart card, including History focus and the contextual Card menu. |
| `entity-details` | The entity-detail family/state reference gallery, including Presence. |
| `gauge-widget` | Mixed Sensor Board plus dashboard and widget gauge comparison; add `--preview-card-state unavailable` for unavailable/no-history Sensor Board content. |

For focused dashboard-card gallery inspection, add `--preview-size square`, `wide`, or `large`. Use `--preview-card-state transient` for deterministic Chart loading/empty plus Weather loading and retained-data refresh-failure states, or `--preview-card-state unavailable` for unavailable Chart and Weather cards, including a Chart with retained recorded history.

Entity-detail verification can launch a specific deterministic matrix cell:

```sh
xcrun simctl launch booted com.tyler.Homestead \
  --preview-screen entity-details \
  --preview-detail-family information \
  --preview-detail-state loading
```

Family values are `metric`, `positional`, `environmental`, `information`, `presence`, `editableNumber`, `editableText`, and `editableTemporal`. State values are `live`, `loading`, `empty`, `pending`, `unavailable`, `stale`, `failed`, `minimum`, `maximum`, and `longContent`.

These routes are intended for Codex desktop and in-app browser simulator verification loops. They use sample dependencies instead of the normal app startup path. Prefer them for deterministic layout and state review; use `--live-preview` only when the change must be verified against real Home Assistant data, authenticated media, or server-specific capabilities.
