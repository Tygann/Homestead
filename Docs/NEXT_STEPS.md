# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Post-history/dashboard roadmap work after adding numeric sensor dashboard chart cards.

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
- Added automatic internal/external URL route selection in the connection lifecycle using the saved Settings > Account > Server internal URL, external URL, and home-network metadata.
- Kept route selection in `HomeAssistantService` instead of SwiftUI; Settings now displays the active route and still sends retry/register actions through the service.
- Preserved OAuth/token refresh behavior, state-cache scope, mobile-app registration identity, WebSocket-first startup, documented HTTP calls, and service calls by separating active route URL from signed-in server identity in `HAConnectionConfiguration`.
- Added fallback handling for transport-style route failures and focused tests for route selection, route fallback, WebSocket connection, logbook HTTP handoff, and mobile-app registration handoff.
- Expanded History/Charts into dashboard card support for numeric `sensor.*` entities using the existing documented REST history client/service flow.
- Added dashboard history eligibility/request helpers, a `HomeAssistantService.fetchDashboardHistory(...)` handoff that keeps URL routing in the service layer, and app-facing chart-card presentation mapping.
- Square, Wide, and Large numeric sensor dashboard cards now render a lightweight 6H Swift Charts trend while compact sizes keep the existing fast value-card presentation; newly generated numeric sensor cards prefer a Square card.
- Added focused tests for card eligibility, default dashboard history request shape, service handoff, chart presentation mapping, and generated dashboard card sizing.
- Started the dashboard organization/add-card flow pass as card types grow.
- Added app-facing add-card candidate presentation helpers that group by Home Assistant registry device when available, fall back to domain groups, filter by Homestead card style, search locally, hide already-added cards, and preserve unavailable filtering.
- Replaced the Cards tab in Add to Dashboard with card-type filter chips, collapsible candidate groups, clean entity rows, plus-button quick add, and row-tap card-size previews with feature visibility selection.
- Preserved the existing generated-size behavior for camera and numeric sensor chart cards while moving size/feature choice into a visual preview picker instead of cramped rows.
- Added focused tests for add-card grouping, type filters, search, availability handling, configured-card exclusion, generated card size hints, and size-choice summaries.
- Replaced the card/header reorder sheet path with direct edit-mode drag reordering in the dashboard grid while keeping chips in their existing chip reorder sheet.
- Tuned direct drag to move only the lifted card during drag and commit the reorder on drop; removed the visible three-dot edit overlay from cards/headers.
- Added a visible-grid move helper that persists flat dashboard order without storing grid coordinates, preserves chip slots, and avoids moving hidden/unavailable configured items.
- Add-card now reports the new card ID back to the dashboard so appended cards can scroll into view and briefly highlight after being added.

## Next Chunk

- Continue dashboard organization and edit-flow polish as card types grow, likely focusing on simulator/device validation of drop-target feel, chip-row editing ergonomics, section/header affordances, or larger dashboard management affordances.
- As dashboard/add/edit views are touched, review nearby copy and controls for development-facing labels, explanations, or layout mechanics, and prefer user-facing choices, previews, and direct manipulation where the behavior is already visually clear.
- Or expand richer entity history beyond numeric sensor detail/dashboard charts if performance and UX are clear.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Do not use private frontend endpoints for repairs, users, system health, or admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.
- Settings > Account > Server has saved internal/external URL, home network metadata, active route/status, and WebSocket `get_config` display. Automatic route selection is implemented in `HomeAssistantService`.

## Recent Verification Notes

- Generic iOS Simulator build passed after direct dashboard grid editing.
- `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` after direct dashboard grid editing.
