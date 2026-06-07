# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Post-Weather roadmap work after completing native `.weather` dashboard/detail support.

Recommended reasoning level: High.

## Completed Chunk

- Added a read-only Settings > Logbook page backed by Home Assistant's documented REST logbook endpoint.
- Added typed logbook request/DTO support, an authenticated HTTP client path, app-facing `HAActivityRow` models, grouped/searchable presentation helpers, and focused regression tests for URL shape, decoding, mapping, filtering, and service auth handoff.
- Kept domain filtering and search local to Homestead; server requests use only the documented logbook start timestamp, `end_time`, and `entity` parameters.
- Added native iOS notification permission/status models and a `NativeNotificationService` separate from Home Assistant mobile-app registration state.
- Replaced the Settings > Notifications placeholder with a real setup/status page that shows iOS permission state, Home Assistant account/mobile-app readiness, delivery readiness, recovery actions, an iOS Settings handoff, and advanced details behind disclosure.
- Added Home Assistant's official mobile-app WebSocket notification delivery: registration advertises `push_websocket_channel`, the connected socket subscribes to `mobile_app/push_notification_channel`, received events present local iOS notifications, and Homestead confirms delivery when HA provides a confirmation ID.
- Kept cloud/APNs forwarding out of scope because Home Assistant's cloud path requires a separate push forwarding server and `push_url`.
- Added a native Settings > Updates page backed by Home Assistant `.update` entities.
- Added typed update mapping and presentation helpers for installed/latest version, title/name, release summary/notes URL, skipped state, in-progress/unavailable state, entity/device/area/floor context, grouping, filtering, and search.
- Added official Home Assistant update service actions for install, skip, and clear skipped update through WebSocket `call_service`, gated by `HomeAssistantService.serviceActionAvailable(...)` and confirmation UX for install backup choices.
- Kept private frontend repairs, system health, admin, and update-metadata endpoints out of scope.
- Added a focused History/Charts pass for numeric `sensor.*` entities using Home Assistant's documented REST history endpoint only.
- Added typed history request/response models, authenticated HTTP/service handoff, app-facing chart series/range helpers, and a native Swift Charts history panel in the existing sensor detail surface with fixed 1H/6H/24H ranges.
- Kept raw Home Assistant history DTOs out of SwiftUI and kept chart aggregation/formatting outside `HAStateStore`.
- Added a focused native Weather pass for `.weather` entities.
- Added typed app-facing weather state and presentation helpers for condition, temperature, humidity, wind, forecast availability, and attribution, mapped from Home Assistant entity state attributes.
- Added `HAStateStore` / `HAEntityState` weather accessors so SwiftUI dashboard cards and detail views do not read raw Home Assistant DTOs.
- Added a native read-only Weather detail surface and richer dashboard card presentation while keeping weather service calls out of scope.
- Added focused mapping, state-store, and dashboard presentation tests for weather behavior.

## Next Chunk

- Consider automatic internal/external URL route selection now that Settings > Account > Server has saved URL and home-network metadata foundations.
- Or expand History/Charts into dashboard cards or richer entity history if performance and UX are clear.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Do not use private frontend endpoints for repairs, users, system health, or admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.
- Settings > Account > Server already has the first foundation for saved internal/external URL, home network metadata, active route/status, and WebSocket `get_config` display. Automatic URL switching is still not implemented.

## Recent Verification Notes

- Generic iOS Simulator build passed after the Weather implementation.
- Focused Weather tests passed for mapping, state-store access, dashboard presentation, and wide/large card content.
- A full `HomesteadTests` run on the named iPhone 17 simulator compiled and started, but Xcode reported repeated locked physical-device `notification_proxy` errors and ended the tail of the suite as signal-trap failures. The focused Weather subset passed afterward with a unique result bundle path.
