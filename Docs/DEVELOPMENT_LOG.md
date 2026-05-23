# Development Log

This is a short project memory log for future maintainers and coding agents. It should capture durable decisions and checkpoints, not every edit.

## 2026-05-22

### Dashboard Header Items

- Replaced separate dashboard entity and size storage with one ordered dashboard item list.
- Added user-created header items as full-width dashboard row breakers for lightweight grouping.
- Added an edit-mode reorder sheet backed by the ordered item list.
- Kept entity cards backed by Home Assistant state while header items remain local-only dashboard organization.
- Added regression tests for item persistence, header rename/removal, stale entity reconciliation, and addable entity filtering.

### Home Assistant Pending Confirmation Hardening

- Pending commands now clear only when a confirmed Home Assistant state satisfies the expected state and attributes.
- Stale snapshots can update confirmed state without dismissing pending UI feedback prematurely.
- Recoverable WebSocket request failures during service calls or refreshes now trigger reconnect handling.
- Kept broad entity projections fresh when live per-entity state changes.
- Added regression tests for stale snapshot handling, attribute confirmation, and cached projection updates.

### In-Place Dashboard Editing

- Replaced the separate dashboard edit sheet with an in-place edit mode on the dashboard.
- Cards now show lightweight corner controls for remove and size changes only while editing.
- Added a reusable entity browser list so Devices and the add-card sheet share grouping and search behavior.
- Live Home Assistant previews now keep dashboard card selection and sizing in preview-specific persistent defaults.

## 2026-05-21

### Added Project Memory Docs

- Added a root `README.md` with project purpose, structure, development commands, and credential guidance.
- Added `AGENTS.md` as durable coding-agent context.
- Added this development log.

### Dashboard Performance Pass

- Batched Home Assistant `state_changed` events before applying them to SwiftUI-observed state.
- Added per-entity observable state boxes so cards and rows can observe one entity instead of broad store dictionaries.
- Split stable entity catalog/grouping from live entity values.
- Moved Devices rows to per-entity observation.
- Replaced expensive dashboard material layers and heavy shadows with cheaper grouped iOS surfaces.
- Removed card-level active-state animation that could fire while scrolling.
- Verified with `xcodebuild` build and `HomesteadTests`.

Reason: live Home Assistant data with many entities made dashboard scrolling and light detail presentation laggy. The largest visible improvement came from reducing material/shadow compositing in dashboard cards.

### Live Home Assistant Previews

- Added a debug-only live Home Assistant preview path.
- Preferred credential source is local Keychain data entered through the app.
- Environment variables are available as a fallback:
  - `HOMESTEAD_PREVIEW_HA_BASE_URL`
  - `HOMESTEAD_PREVIEW_HA_TOKEN`
- Preview credential setup is documented in `Docs/PREVIEW_CREDENTIALS.md`.

### Dashboard Customization And Light Controls

- Added dashboard favorites configuration with editable ordering.
- Added light cards with tap-to-toggle behavior.
- Added a light detail sheet for brightness and power controls.
- Added optimistic updates for light state and brightness after successful service calls.

### Home Assistant Real-Time State Refactor

- Changed initial WebSocket sync to subscribe to `state_changed` before applying the `get_states` snapshot, buffering live events during the snapshot fetch.
- Removed optimistic writes from confirmed entity state; service calls now set pending UI command state and wait for Home Assistant state confirmation.
- Added monotonic state application, stable `HAEntityState` identity across snapshots, entity removal for `new_state: null`, WebSocket request timeouts, ping heartbeat, and foreground resume refresh.
- Added regression tests for stale update prevention, stable boxes, removal events, and pending command clearing.

### Home Assistant Foundation

- Established WebSocket-first architecture.
- Added `HAWebSocketClient`, `HomeAssistantService`, DTOs, domain models, `EntityMapper`, and `HAStateStore`.
- Kept SwiftUI views behind domain models instead of raw Home Assistant JSON.

## Maintenance Rules

- Add entries for major feature, architecture, performance, credential, or workflow decisions.
- Keep entries concise and dated.
- Do not include secrets, personal tokens, private network details, or long command output.
- Prefer links to docs and source files over repeating large explanations.
