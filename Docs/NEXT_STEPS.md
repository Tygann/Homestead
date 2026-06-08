# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Expand entity history into native, glanceable timelines beyond numeric sensor charts.

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
- Tuned direct drag to use a transient visual preview order so cards and section headers reflow while dragging, with the lifted item drawn as a floating preview over a stable opacity-hidden grid placeholder; persisted order commits only on drop, cards/headers show a quiet non-interactive corner grip badge in edit mode, edit-mode card/header context menus are disabled so long-press only starts movement, and the visible three-dot edit overlay was removed.
- Added a visible-grid move helper that persists flat dashboard order without storing grid coordinates, preserves chip slots, and avoids moving hidden/unavailable configured items.
- Add-card now reports the new card ID back to the dashboard so appended cards can scroll into view and briefly highlight after being added.
- Added a deliberate edit-mode affordance for dashboard cards and section headers: a single tapped ellipsis menu reuses the existing customization actions while the card/header body remains the direct drag target, avoiding long-press/context-menu conflicts.
- Hid the account/settings avatar from the dashboard toolbar while edit mode is active so edit mode keeps focus on dashboard organization.
- Made active card drag previews render over an opaque card-shaped base so translucent active fills do not reveal dashboard cards underneath while dragging.
- Added direct edit-mode chip drag reordering inside the horizontal chip row, with movement clamped left/right, a floating chip preview, and a single chip ellipsis affordance for customization actions.
- Removed the legacy chip reorder sheet path now that chips reorder directly in edit mode.
- Added focused persistence coverage for visible chip dragging so chip order changes preserve card/header slots.
- Tuned edit-mode dragging to require a brief press-and-hold lift before cards, section headers, or chips start moving, preserving normal dashboard scrolling while in edit mode.
- Replaced the SwiftUI sequenced edit-mode drag gestures with a UIKit long-press recognizer surface after device testing showed the SwiftUI recognizer could still prevent ScrollView scrolling from card/chip touches; it does not delay touches before recognition, but owns the touch stream once the hold succeeds so lifted cards/chips can move.
- Kept the active card/chip drag recognizer mounted after lift while disabling inactive item recognizers, avoiding stranded drag state if SwiftUI re-renders mid-gesture.
- Measure edit-mode drag translation in window coordinates so preview movement stays stable while the dashboard grid or chip row reflows beneath the lifted item.
- Lowered the chip ellipsis affordance slightly so it remains visible within the clipped horizontal chip row.
- Polished edit-mode card/header/chip drag feel with an explicit lift/drop phase, a lightweight lifted shadow/scale, opaque lifted header/card/chip previews, reduced-motion handling, impact haptics on lift, and delayed cleanup so the floating preview settles into its placeholder before disappearing.
- Added practical edge auto-scroll to the UIKit long-press drag surface for vertical dashboard grid dragging and horizontal chip-row dragging, including scroll-offset-aware translations so previews stay stable while content scrolls under the finger.
- Tuned dense-dashboard edit-mode dragging so final drops preserve edge auto-scroll offset, edge scrolling ramps in more gently near the viewport boundary, and floating previews linger long enough for dense grid/chip reflow to settle.
- Polished Add to Dashboard card organization for larger homes by adding card-type result counts, group result counts, and a lightweight expand/collapse-groups control in the card picker.
- Fixed the add-card exclusion path so already-added unavailable cards stay hidden when the user toggles unavailable entities into the picker.

## Next Chunk

- Start a focused history/timeline pass for non-numeric state entities using Home Assistant's documented REST history API and the existing authenticated HTTP/service handoff.
- Prefer entity detail surfaces first, not dashboard cards, so the UX can prove itself without adding more dashboard complexity.
- Likely first targets are discrete state domains with useful recent-change stories, such as `binary_sensor`, `switch`, `lock`, `cover`, `automation`, `person`, or `device_tracker`; pick a narrow first slice based on existing model/presentation support and API fit.
- Keep raw Home Assistant history DTOs out of SwiftUI. Map history responses into app-facing timeline presentation models outside `HAStateStore`.
- Do not add private frontend endpoints. If a target domain needs data beyond documented history/state/service APIs, mark it as API research instead of implementing.
- Dashboard organization is no longer the active workstream; revisit it only for concrete bugs or new-card friction discovered during feature work.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Do not use private frontend endpoints for repairs, users, system health, or admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.
- Settings > Account > Server has saved internal/external URL, home network metadata, active route/status, and WebSocket `get_config` display. Automatic route selection is implemented in `HomeAssistantService`.
- Numeric sensor history already has documented REST history plumbing, authenticated service handoff, app-facing chart models, fixed detail ranges, and lightweight dashboard chart cards; reuse that shape where it fits.

## Recent Verification Notes

- Generic iOS Simulator build passed after adding opaque active-card drag previews and direct horizontal chip dragging.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` for visible chip/grid reorder persistence.
- Generic iOS Simulator build passed after adding press-and-hold dashboard dragging and adjusting chip ellipsis placement.
- Generic iOS Simulator build passed after replacing edit-mode SwiftUI sequenced drag gestures with the UIKit long-press drag surface and tuning it to own touches after lift.
- Generic iOS Simulator build passed after keeping active drag recognizers mounted through card/chip lift, movement, and finger-up.
- Generic iOS Simulator build passed after switching edit-mode drag translation to window coordinates.
- Generic iOS Simulator build passed after polishing edit-mode lift/drop animation and adding grid/chip edge auto-scroll.
- Generic iOS Simulator build passed after dense-dashboard edit-mode drag tuning.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` after dense-dashboard edit-mode drag tuning.
- Generic iOS Simulator build passed after Add to Dashboard card grouping/count polish.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` after Add to Dashboard card grouping/count polish.
