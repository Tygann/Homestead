# Development Log

This is a short project memory log for future maintainers and coding agents. It should capture durable decisions and checkpoints, not every edit.

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

### Home Assistant Foundation

- Established WebSocket-first architecture.
- Added `HAWebSocketClient`, `HomeAssistantService`, DTOs, domain models, `EntityMapper`, and `HAStateStore`.
- Kept SwiftUI views behind domain models instead of raw Home Assistant JSON.

## Maintenance Rules

- Add entries for major feature, architecture, performance, credential, or workflow decisions.
- Keep entries concise and dated.
- Do not include secrets, personal tokens, private network details, or long command output.
- Prefer links to docs and source files over repeating large explanations.
