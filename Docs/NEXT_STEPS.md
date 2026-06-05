# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Updates management groundwork using Home Assistant update entities.

Recommended reasoning level: High.

## Completed Chunk

- Added a read-only Settings > Logbook page backed by Home Assistant's documented REST logbook endpoint.
- Added typed logbook request/DTO support, an authenticated HTTP client path, app-facing `HAActivityRow` models, grouped/searchable presentation helpers, and focused regression tests for URL shape, decoding, mapping, filtering, and service auth handoff.
- Kept domain filtering and search local to Homestead; server requests use only the documented logbook start timestamp, `end_time`, and `entity` parameters.
- Added native iOS notification permission/status models and a `NativeNotificationService` separate from Home Assistant mobile-app registration state.
- Replaced the Settings > Notifications placeholder with a real setup/status page that shows iOS permission state, Home Assistant account/mobile-app readiness, delivery readiness, recovery actions, an iOS Settings handoff, and advanced details behind disclosure.
- Added Home Assistant's official mobile-app WebSocket notification delivery: registration advertises `push_websocket_channel`, the connected socket subscribes to `mobile_app/push_notification_channel`, received events present local iOS notifications, and Homestead confirms delivery when HA provides a confirmation ID.
- Kept cloud/APNs forwarding out of scope because Home Assistant's cloud path requires a separate push forwarding server and `push_url`.

## Next Chunk

- Add a Home Assistant Updates management page based on `.update` entities.
- Keep v1 focused on read-only update visibility and typed presentation helpers for installed/latest version, title, release summary, skipped state, and availability where present.
- Add service actions only after confirming available services and safety UX for install/skip/clear flows.
- Do not use private frontend endpoints for repairs, users, system health, or admin details while working on Updates.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.
- Settings > Account > Server already has the first foundation for saved internal/external URL, home network metadata, active route/status, and WebSocket `get_config` display. Automatic URL switching is still not implemented.

## After Updates

- Move to Weather and History/Charts in roadmap order unless priorities change.
