# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Notifications groundwork through Home Assistant's official mobile-app notification path.

Recommended reasoning level: High.

## Next Chunk

- Add native notification permission/status models for iOS app state separately from Home Assistant mobile-app registration state.
- Add a Settings > Notifications destination that shows permission state, mobile-app registration readiness, and honest setup/recovery actions.
- Use Home Assistant's official native-app notification path only; do not invent a separate Homestead notification automation path.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.
- Settings > Account > Server already has the first foundation for saved internal/external URL, home network metadata, active route/status, and WebSocket `get_config` display. Automatic URL switching is still not implemented.

## After Notifications

- Move to Logbook, Updates, Weather, and History/Charts in roadmap order unless priorities change.
