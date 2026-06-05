# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Logbook groundwork using Home Assistant's documented logbook API.

Recommended reasoning level: High.

## Completed Chunk

- Added native iOS notification permission/status models and a `NativeNotificationService` separate from Home Assistant mobile-app registration state.
- Replaced the Settings > Notifications placeholder with a real setup/status page that shows iOS permission state, Home Assistant account/mobile-app readiness, recovery actions, and that push delivery is not enabled yet.
- Kept notification direction aligned with Home Assistant's official native-app notification path and did not add APNs token handling or full push delivery.

## Next Chunk

- Add a read-only Settings > Logbook page using Home Assistant's documented logbook API.
- Keep v1 focused on date range, entity/domain filtering, search presentation helpers, and app-facing activity row models.
- Do not use private frontend endpoints for repairs, users, system health, or admin details while working on Logbook.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.
- Settings > Account > Server already has the first foundation for saved internal/external URL, home network metadata, active route/status, and WebSocket `get_config` display. Automatic URL switching is still not implemented.

## After Logbook

- Move to Updates, Weather, and History/Charts in roadmap order unless priorities change.
