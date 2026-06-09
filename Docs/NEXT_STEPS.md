# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Device-test the polished in-app mini dashboard accessory tile in real dense dashboards, then use that design language only where it helps future medium/large multi-entity widget work.

Recommended reasoning level: High.

## Completed Chunk

- Added a read-only Settings > Logbook page backed by Home Assistant's documented REST logbook endpoint.
- Added typed logbook request/DTO support, an authenticated HTTP client path, app-facing `HAActivityRow` models, grouped/searchable presentation helpers, and focused regression tests for URL shape, decoding, mapping, filtering, and service auth handoff.
- Kept domain filtering and search local to Homestead; server requests use only the documented logbook start timestamp, `end_time`, and `entity` parameters.
- Added native iOS notification permission/status models and a `NativeNotificationService` separate from Home Assistant mobile-app registration state.
- Replaced the Settings > Notifications placeholder with a real setup/status page that shows iOS permission state, Home Assistant account/mobile-app readiness, delivery readiness, recovery actions, an iOS Settings handoff, and advanced details behind disclosure.
- Added Home Assistant's official mobile-app WebSocket notification delivery: registration advertises `push_websocket_channel`, the connected socket subscribes to `mobile_app/push_notification_channel`, received events present local iOS notifications, and Homestead confirms delivery when HA provides a confirmation ID.
- Hardened Home Assistant WebSocket notification decoding so both the documented root-level event payload and nested `event.data` payload variants can present local notifications and send HA confirmations.
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
- Added a focused non-numeric history/timeline slice for `binary_sensor.*` detail surfaces using Home Assistant's documented REST history endpoint and the existing authenticated HTTP/service handoff.
- Added app-facing timeline entry/series models for binary sensor on/off and availability changes, device-class-aware labels/SF Symbols, duplicate-state collapsing, and fixed 1H/6H/24H ranges while keeping raw HA history DTOs out of SwiftUI.
- Added a native Recent Activity panel to the existing binary sensor detail surface; dashboard timeline cards remain out of scope.
- Added focused tests for timeline mapping/filtering and service auth handoff.
- Extended the native detail-surface timeline pattern to `lock.*` entities using the same documented REST history endpoint and authenticated HTTP/service handoff.
- Added lock state timeline mapping for locked, unlocked, locking, unlocking, jammed, unknown, and unavailable states, plus a shared Recent Activity panel reused by binary sensor and lock detail surfaces.
- Kept lock timelines out of dashboard cards and kept raw Home Assistant history DTOs out of SwiftUI.
- Added focused tests for lock timeline mapping/filtering and service auth handoff.
- Extended the detail-surface timeline pattern in one combined pass to `switch.*`, `automation.*`, `cover.*`, `person.*`, and `device_tracker.*` where existing model/presentation support fit.
- Added domain-aware app-facing timeline mapping for switch on/off, automation enabled/disabled, cover open/closed/opening/closing, person/device-tracker home/away/zone, unknown, and unavailable states.
- Reused the documented REST history endpoint, authenticated HTTP/service handoff, and shared Recent Activity panel; raw Home Assistant history DTOs stay out of SwiftUI and dashboard timeline cards remain out of scope.
- Added focused tests for discrete-domain timeline mapping/filtering and service auth handoff.
- Polished the shared Recent Activity panel for detail surfaces by making range/refresh controls and summary overflow adapt better in narrow contexts, tightening timeline row text behavior, and adding debug-only small light/dark preview coverage for binary sensor, lock, switch, automation, cover, person, and device tracker timelines.
- Kept the polish in the shared app-facing timeline panel; no dashboard timeline cards, new Home Assistant API surface, or raw history DTO usage was added.
- Added a focused trust-and-recovery pass for service-call and reconnect feedback.
- `HomeAssistantService` now formats service-call failures with clearer recovery copy, starts reconnect recovery for transport-style failures as before, and app chrome lets failure feedback briefly surface over reconnect progress while keeping success feedback behind connection-health warnings.
- Reconnecting bottom chrome is now tappable for an immediate retry via the existing `refreshOrReconnect(settings:)` path.
- Added a native Settings > Permissions page covering Notifications, Local Network, Location, and Camera through app-owned permission models and public iOS APIs; Local Network is shown as iOS-managed because iOS does not expose a direct read-only permission status API.
- Added required Camera, Location When In Use, and Local Network usage descriptions to the app plist.
- Moved entity history/timelines out of the active workstream after multiple completed timeline passes; revisit only for concrete visual bugs, detail-surface polish, or a clearly useful state-only domain.
- Added a non-blocking notification setup prompt after Home Assistant sign-in and mobile-app registration, requesting iOS notification permission in app and persisting Not Now/asked state so Settings remains the recovery surface without making users discover it first.
- Added a Home Screen switch widget alongside the existing light widget.
- Reused the existing shared OAuth/app-group pattern, compact app-facing widget snapshots, widget-side WebSocket `get_states` refresh, optimistic widget state, and official WebSocket `call_service` for `switch.turn_on` / `switch.turn_off`.
- Kept raw Home Assistant state parsing inside the widget action client and added focused snapshot regression coverage.
- Added read-only Home Screen sensor and person/presence widgets using compact app-facing app-group snapshots plus widget-side WebSocket `get_states` refresh.
- Added a configurable Home Screen scene/script action widget using shared OAuth credentials and official WebSocket `call_service` for `scene.turn_on` / `script.turn_on`.
- Extended widget snapshot persistence to sensors, people, scenes, and scripts while keeping raw Home Assistant state parsing inside the widget action client.
- Added a Home Screen numeric sensor graph widget with Small and Medium families, numeric-only App Intent suggestions, compact sensor snapshot metadata, and a widget-side documented REST history fetch over the shared OAuth credential path.
- Added Home Screen cover, fan, and lock widgets using compact app-facing app-group snapshots, widget-side WebSocket `get_states` refresh, and official WebSocket `call_service` actions.
- Cover widgets send `cover.open_cover`, `cover.close_cover`, or `cover.stop_cover` based on current state; fan widgets use `fan.turn_on` / `fan.turn_off` with optimistic widget state; lock widgets expose status and `lock.lock` only, avoiding one-tap unlock from widgets.
- Extended widget snapshot persistence to covers, fans, and locks while keeping raw Home Assistant state parsing inside the widget action client.
- Refactored the public Home Screen widget gallery to the modern experience-first shape: `Homestead Control` for lights/switches/fans/covers/locks, `Homestead Status` for sensors/people, `Homestead Sensor Graph` for numeric history, and `Homestead Action` for scenes/scripts.
- Kept the underlying domain-specific widget code compileable, but the widget bundle now registers the smaller Control/Status/Graph/Action surface so users pick a widget experience first and the entity second.
- Polished add-widget gallery snapshots to use curated sample entries when unconfigured and tightened small widget bodies by hiding generic domain/trend labels so names, state, and meaningful status have more room.
- Removed first-entity default selection/fallback from the public Control, Status, Graph, and Action widgets so unconfigured add-widget previews stay sample-based and newly added widgets require explicit entity selection.
- Tightened Status widget supporting text to show only alert/recovery-style messages and made Action widgets communicate command behavior through a play-badged icon rather than adding Run/Script labels to the small face.
- Aligned Control and Status compact second-line text sizing and replaced the Action overlay badge with a single play-circle command glyph.
- Added searchable App Intent entity queries for the public Control, Status, Graph, and Action widgets.
- Enriched compact app-group widget snapshots with optional area/device context from existing registry metadata so the system picker can group by room/device/type and search across name, entity ID, domain, room, device, and value/status without exposing Home Assistant DTOs to widget views.
- Public widget pickers now return sectioned App Intent collections grouped by room/device/type where the system honors sections, and entity display representations include SF Symbol images for picker rows.
- Curated Control and Action add-widget/gallery placeholders are visual-only and no longer carry fake entity IDs, avoiding accidental sample service-call attempts before a real entity is selected.
- Widget picker rows now shorten entity names by removing the current room/device prefix where possible and keep raw Home Assistant domains/entity IDs searchable but hidden from the default row UI.
- Unconfigured Home Screen widget faces now use consistent short setup copy (`Choose Control/Status/Sensor/Action` and `Open Homestead`) and avoid placeholder data markers like `--`.
- WidgetKit still owns the configuration picker layout; if iOS flattens sections in a context, Homestead still orders rows by the same room/device/type groups and keeps search matching context-rich metadata.
- Public widget picker rows now omit routine domain subtitles entirely so grouped room/device lists feel closer to Apple Home's compact accessory chooser.
- Polished the in-app mini dashboard card into an Apple Home-inspired glance tile with a readable two-line entity name and compact icon, using tile/icon styling and accessibility for state.
- Reused app-facing dashboard presentation state for active, inactive, and unavailable styling; mini tiles now keep quick-action icon behavior and detail-opening card behavior inside the existing dashboard card architecture.
- Parameterized shared card icon/container styling so dashboard cards can use entity-specific accent colors without adding any Home Assistant API surface.

## Next Chunk

- Start the next pass by device-testing dense dashboards with a mix of mini, compact, square, and camera/history cards.
- Recommended next scope: visual tuning only if mini tiles show text clipping, tap-target confusion, or weak active/inactive/unavailable contrast on device.
- If the mini tile holds up, consider a separate medium/large multi-entity Accessories widget built from the same tile language.
- Keep Small Home Screen widgets focused on one configured entity; use medium/large families for any future multi-entity grid.
- Treat App Intent boolean toggles as optional product controls only when they have a clear user-facing purpose, such as auto-filled recommendations or hiding labels in a dense multi-entity widget.
- Keep widget snapshots compact and app-facing; do not expose Home Assistant transport DTOs directly to widget views.
- Keep service calls official through WebSocket `call_service`; do not add REST, webhook, or private frontend endpoints for widget actions.
- Keep lock widgets conservative unless a future design adds explicit confirmation; current widget scope intentionally does not expose one-tap unlock.
- Leave timeline work parked unless a concrete bug or visual polish issue appears during normal feature work.

## Acceptance Notes

- Settings should keep the top-level account card and the large Account header unless a later design decision explicitly replaces them.
- The profile card is the only root entry for Account setup; Server belongs inside Account as its own navigation destination, not as a duplicate root Settings row.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Use official Home Assistant API surfaces only. Do not add private frontend endpoints for server/admin details.
- Do not use private frontend endpoints for repairs, users, system health, or admin details.
- Keep URL switching in connection lifecycle code, not directly in SwiftUI views.
- Settings > Account > Server has saved internal/external URL, home network metadata, active route/status, and WebSocket `get_config` display. Automatic route selection is implemented in `HomeAssistantService`.
- Settings > Permissions has native iOS status rows for Notifications, Local Network, Location, and Camera. Keep future native permission work in app-owned platform services rather than Home Assistant API code.
- User-facing service-call and reconnect recovery feedback belongs in `HomeAssistantService` and app chrome, not scattered card/detail views.
- Numeric sensor history already has documented REST history plumbing, authenticated service handoff, app-facing chart models, fixed detail ranges, and lightweight dashboard chart cards; binary sensors, locks, switches, automations, covers, people, and device trackers now have app-facing detail timeline models and a shared Recent Activity panel. Reuse those shapes where they fit.

## Recent Verification Notes

- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-Notifications` after hardening Home Assistant WebSocket notification payload decoding and clarifying connected-session notification scope.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-Notifications` after hardening Home Assistant WebSocket notification payload decoding.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPlaceholderPolish` after aligning unconfigured widget setup faces.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPlaceholderPolish` after aligning unconfigured widget setup faces. The test compile emitted existing Swift 6-mode warnings around main actor-isolated snapshot `Equatable` conformances in macro-expanded expectations.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerSubtitle` after removing routine domain subtitles from public widget picker rows.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerSubtitle` after removing routine domain subtitles from public widget picker rows.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerNames` after shortening grouped widget picker row titles and hiding entity IDs from default subtitles.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerNames` after shortening grouped widget picker row titles and hiding entity IDs from default subtitles. The test compile emitted existing Swift 6-mode warnings around main actor-isolated snapshot `Equatable` conformances in macro-expanded expectations.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerSections` after returning sectioned/icon App Intent picker collections and non-actionable sample placeholders.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerSections` after returning sectioned/icon App Intent picker collections and non-actionable sample placeholders. The test compile emitted existing Swift 6-mode warnings around main actor-isolated snapshot `Equatable` conformances in macro-expanded expectations.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerSearch` after adding searchable context-rich widget entity pickers.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPickerSearch` after adding searchable context-rich widget entity pickers.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetVisualAlign` after aligning compact widget typography and simplifying the Action icon.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetVisualAlign` after aligning compact widget typography and simplifying the Action icon.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetFacePolish` after tightening Status supporting text and Action command icon treatment.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetFacePolish` after tightening Status supporting text and Action command icon treatment.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPreviewDefaults` after removing automatic first-entity defaults from unified widget intents.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetPreviewDefaults` after removing automatic first-entity defaults from unified widget intents.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetGalleryPolish` after polishing experience-first widget gallery previews and compact widget labels.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetGalleryPolish` after polishing experience-first widget gallery previews and compact widget labels.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetUnified` after refactoring widgets into the experience-first Control/Status/Graph/Action gallery.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetUnified` after refactoring widgets into the experience-first Control/Status/Graph/Action gallery.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetCoverFanLock` after adding cover, fan, and lock widgets.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetCoverFanLock` after adding cover, fan, and lock widgets.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetGraph` after adding the numeric sensor graph widget.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetGraph` after adding the numeric sensor graph widget.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetStatusActions` after adding sensor, presence, and scene/script action widgets.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetStatusActions` after adding sensor, presence, and scene/script action widgets.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetSwitch` after adding the switch widget.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-WidgetSwitch` after adding the switch widget.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-TrustRecovery` after the trust-and-recovery permissions pass.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-TrustRecovery` after the trust-and-recovery permissions pass.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-NotificationOnboarding` after the notification setup prompt pass.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-NotificationOnboarding` after the notification setup prompt pass.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-TimelinePolish` after the Recent Activity UX polish pass.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-TimelinePolish` after the Recent Activity UX polish pass.
- Generic iOS Simulator build passed with `-derivedDataPath /tmp/HomesteadDerivedData-TimelinePass` after adding switch, automation, cover, person, and device-tracker Recent Activity timelines.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` with `-derivedDataPath /tmp/HomesteadDerivedData-TimelinePass` after adding switch, automation, cover, person, and device-tracker Recent Activity timelines.
- Generic iOS Simulator build passed after adding lock detail Recent Activity timelines.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` after adding lock timeline mapping and service handoff.
- Generic iOS Simulator build passed after adding binary sensor Recent Activity timelines.
- Focused `HomesteadTests` passed on `platform=iOS Simulator,name=iPhone 17,OS=26.5` after adding binary sensor timeline mapping and service handoff.
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
