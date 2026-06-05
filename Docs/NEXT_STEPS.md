# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Richer Settings > Account > Server page and connection routing groundwork.

Recommended reasoning level: High.

## Next Chunk

- Add typed WebSocket `get_config` support only for fields the dedicated `Settings > Account > Server` page needs, such as Home Assistant version and URL/config metadata that is officially returned.
- Preserve existing sign-in, retry, mobile-app registration recovery, and sign-out behavior while keeping account/session details separate from server/connection details.
- Start modeling Homestead-owned internal URL, external URL, selected home network, active route/status, and recovery affordances without changing connection routing until the lifecycle code is ready.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.

## After This Chunk

- Move to Notifications, Logbook, Updates, Weather, and History/Charts in roadmap order unless priorities change.
