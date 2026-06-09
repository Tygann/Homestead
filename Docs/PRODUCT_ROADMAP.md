# Homestead Product Inventory And Roadmap

This document is product memory for Homestead. It helps future maintainers and coding agents understand what Homestead already supports, what is likely worth building next, and which tempting paths should be treated carefully.

Homestead is a polished native iOS frontend for Home Assistant. Home Assistant remains the source of truth for integrations, devices, entities, automations, scenes, scripts, users, service execution, and system behavior. Homestead should focus on native daily control, Home Assistant-familiar management views, and official companion-app capabilities.

For the technical map of official Home Assistant API families, current Homestead coverage, and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

For the current tactical handoff, read `Docs/NEXT_STEPS.md`.

## Status Labels

- `Existing`: implemented and part of the current app.
- `Near-term`: intended soon, usually next after the active chunk unless priorities change.
- `Later`: valuable but not immediate.
- `API research needed`: do not implement until the official Home Assistant API path is confirmed.
- `Deferred`: intentionally not a focus right now.

## Existing Features

- Native SwiftUI iOS app shell with Home, Areas, and Browse tabs.
- Home Assistant OAuth sign-in with short-lived access-token refresh and Keychain-backed credentials.
- WebSocket-first state sync, registry loading, service discovery, service calls, reconnect handling, automatic internal/external URL route selection, and cached startup state.
- Home dashboard with configurable entity cards, summary chips, section headers, card sizes, card feature visibility, display names, icon overrides, direct card/header drag editing, chip reordering, and edit mode.
- Native dashboard and area detail flows for common domains, including lights, switches, fans, locks, covers, climate, media players, cameras, vacuums, alarm panels, buttons, selects, numbers, sensors, scenes, scripts, and automations.
- Areas browsing backed by Home Assistant area and floor registries, with area summaries and domain-grouped area detail pages.
- Browse tab for searchable entity discovery and daily entity control, with dashboard membership editing.
- Settings sheet opened from account/avatar buttons on daily-use tabs.
- Settings hub with Home Assistant and Homestead sections, native management overviews for Devices & Services and Automations & Scenes, registry/admin-oriented devices and entities, and placeholders for unsupported categories.
- Profile-card Account destination for Home Assistant identity/session details, diagnostics, sign-out, and a nested Server page for connection status, recovery actions, automatic route status, saved internal/external URL and home network metadata, and Home Assistant `get_config` details.
- Native Settings > Updates page backed by Home Assistant `.update` entities, with grouped/filterable/searchable presentation, release/version/status/context details, and official `update.install`, `update.skip`, and `update.clear_skipped` service actions.
- Read-only Settings > Logbook page backed by Home Assistant's documented REST logbook API, with date range, entity/domain filtering, search, and app-facing activity row models.
- Native entity history backed by Home Assistant's documented REST history API, including numeric `sensor.*` detail charts/dashboard chart cards and detail-surface timelines for binary sensors, locks, switches, automations, covers, people, and device trackers with fixed ranges.
- Native dashboard card and detail surface for `.weather` entities, backed by typed state-attribute mapping for condition, temperature, humidity, wind, forecast availability, and attribution.
- Official Home Assistant mobile-app registration groundwork, including persisted registration metadata and camera stream webhook handoff support.
- Notifications support through Home Assistant's official mobile-app WebSocket notification channel, including native iOS permission status, post-registration permission setup prompt, mobile-app registration readiness, local notification presentation, and Home Assistant delivery confirmation.
- Settings > Permissions page for native iOS capabilities, including Notifications, Local Network, Location, and Camera, backed by public platform APIs or app-owned status where iOS does not expose direct status.
- User-facing service-call and reconnect recovery feedback through `HomeAssistantService` and app chrome, including tappable reconnecting state and clearer action-failure copy.
- Authenticated camera snapshot support.
- Home Screen widgets for lights, switches, sensors, people, scenes, and scripts using shared OAuth credentials, app-group state, WebSocket state refresh, and official WebSocket service calls where actions are available.
- App-facing model mapping through `EntityMapper`, with SwiftUI avoiding direct Home Assistant DTO use.

## Near-Term Priorities

- Expand widget support to graph widgets for numeric sensors and additional safe controls such as locks, covers, and fans where service semantics and safety UX are clear.
- Maintain existing entity history/timeline surfaces and polish them only when concrete visual issues or clearly useful state-only domains appear.
- Continue dashboard organization, filtering, and add-card polish only when user testing or new card types expose concrete friction.

## Later Candidates

- Multiple dashboards with a dashboard switcher or management screen; avoid adding every dashboard as a main tab by default.
- Control Center controls and App Intents for common Home Assistant actions.
- Live Activities for long-running or glanceable states such as appliances, climate, energy, and presence.
- People and presence management based on `person.*`, `device_tracker.*`, and official user/person APIs where available.
- True Home Assistant users/admin views if an official supported API path is confirmed for the signed-in user's permissions.
- iCloud sync for Homestead-owned preferences such as dashboard layouts, display overrides, widget configuration, and server configuration metadata.
- Siri/Shortcuts once App Intents have stable action coverage.
- Cloud/APNs notification forwarding if Homestead later commits to operating a separate push forwarding service for Home Assistant's `push_url` path.
- Domain-specific cards and details for calendars, todo lists, humidifiers, water heaters, valves, sirens, air-quality sensors, and image entities.

## Be Careful

- Do not add REST, mobile-app/webhook, or custom URL paths unless the Home Assistant feature is officially exposed that way.
- Do not use private Home Assistant frontend endpoints for integrations, helpers, repairs, blueprints, users, or system health unless the project explicitly accepts that risk.
- Keep the main tab bar focused on daily use. Prefer Settings for registry/admin/companion management surfaces.
- Keep Browse distinct from Settings: Browse is daily discovery/control; Settings is administration, diagnostics, and companion-app configuration.
- Avoid making every user-created dashboard a top-level tab by default; this can quickly make navigation feel cluttered.
- Treat floor plans, 3D room scanning, and AR-style room mapping as high-cost exploratory features, not near-term core work.
- Avoid decorative UI that competes with fast smart-home control. Prefer native, legible, low-latency surfaces.
- When revisiting existing surfaces, look for development-facing labels, explanatory copy, or configuration mechanics that can be replaced with clearer user-facing choices, previews, and direct manipulation.
- Continue profiling before major visual/performance rewrites, especially in scrolling dashboard grids with live Home Assistant updates.

## API Confidence Notes

- Use `Docs/API_CAPABILITY_INVENTORY.md` as the source of truth for mapped, planned, and research-needed Home Assistant API surfaces.
- Prefer WebSocket for state, events, registries, service catalog, service calls, and other core Home Assistant data/control flows.
- Use documented HTTP APIs for auth/token exchange, camera snapshots, history, logbook, media, and other official HTTP surfaces.
- Use native-app/mobile-app registration only for companion-app capabilities such as app identity, notifications, webhooks, app-provided sensors, and camera stream handoff.
- Mark new feature ideas as "API research needed" before implementation when Home Assistant's official public path is unclear.
- Keep unsupported future sections as honest placeholders rather than fake data or private API experiments.
