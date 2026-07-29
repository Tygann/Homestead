# Homestead Product Inventory And Roadmap

This document is product memory for Homestead. It helps future maintainers and coding agents understand what Homestead already supports, what is likely worth building next, and which tempting paths should be treated carefully.

Homestead is a polished native SwiftUI frontend for Home Assistant on iPhone and iPad, with basic Apple silicon Mac support through Designed for iPad. Home Assistant remains the source of truth for integrations, devices, entities, automations, scenes, scripts, users, service execution, and system behavior. Homestead should focus on native daily control, Home Assistant-familiar management views, and official companion-app capabilities.

For the technical map of official Home Assistant API families, current Homestead coverage, and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

For the current tactical handoff, read `Docs/NEXT_STEPS.md`.

## Status Labels

- `Existing`: implemented and part of the current app.
- `Near-term`: intended soon, usually next after the active chunk unless priorities change.
- `Later`: valuable but not immediate.
- `API research needed`: do not implement until the official Home Assistant API path is confirmed.
- `Deferred`: intentionally not a focus right now.

## Existing Features

- Native SwiftUI app shell with Home, Areas, and Browse tabs, including a local primary-tab preference for choosing whether Home or Areas appears first while Browse remains separate.
- Native iPhone and iPad destinations with adaptive dashboard/area grids, plus basic Apple silicon Mac availability through the shared Designed for iPad experience; Mac Catalyst and a desktop-specific redesign remain deferred.
- Multiple saved Home Assistant servers with one active foreground WebSocket, profile-scoped OAuth/mobile-app credentials, cached state, dashboards, routes, and Account-centered server management. Account's Server row opens direct selection/add/removal, while selecting another server performs the full app-wide context switch and returns to Account.
- WebSocket-first state sync, registry loading, service discovery, service calls, reconnect handling, automatic internal/external URL route selection with optional saved Wi-Fi names for local routing, and cached startup state.
- Home dashboard with configurable saved dashboards, device-local enabled-page visibility and current-page selection, native horizontal paging in saved-dashboard order, an explicit opt-in starter setup, deterministic high-value suggested controls, direct empty-state and toolbar add actions, a source/presentation/layout configuration model, Items-first and Cards-first add flows, catalog-driven quick-add recommendations, independently repeatable entity presentations, in-place compatible entity replacement for existing cards and entity chips, entity cards, tappable entity chips with contextual editing, Apple Home-inspired mini accessory tiles, Home Assistant frontend-aligned single-instance summary chips/views with floor grouping and area navigation, an adaptive Security activity log including person presence changes, section headers, card layouts, card feature visibility, display names, searchable SF Symbols icon overrides with entity-aware recommendations, direct card/header drag editing, chip reordering, and edit mode.
- Local-only Homestead appearance personalization with System/Light/Dark mode selection, Start Page selection for Home/Areas, and one optimized wallpaper per configured Home Assistant server behind Home and Areas.
- Native dashboard and area detail flows for common domains, including lights, switches, fans, locks, covers, climate, media players, cameras, vacuums, alarm panels, buttons, selects, numbers, text, date/time values, sensors, people, device trackers, scenes, scripts, and automations. Home Assistant `input_select`, `input_number`, `input_text`, and `input_datetime` helpers join those same capability-based detail families while preserving their real service domains.
- Areas browsing backed by Home Assistant area and floor registries, with area summaries and domain-grouped area detail pages.
- Browse tab for searchable entity discovery and daily entity control, with dashboard membership editing.
- Settings sheet opened from account/avatar buttons on daily-use tabs.
- Settings hub with Home Assistant, Customize, and App sections; native management overviews for Devices & Services and Automations & Scenes; registry-driven Area, Label, and scoped Category organization across management browsers; recent automation/scene/script activity sorting; and no production placeholder rows for unsupported categories.
- Profile-card Account destination with a simplified user header, an active Home Assistant instance-name row that opens server selection, an editable Home Assistant Name row, internal/external URL and active-connection rows, dedicated Internal URL and External URL editing screens, trusted Wi-Fi network management under Internal URL, read-only Home Assistant environment rows, one consolidated Support & Diagnostics destination, and sign-out.
- Native Settings > Updates page backed by Home Assistant `.update` entities, with grouped/filterable/searchable presentation, on-demand full Markdown release notes plus summary/web fallbacks, relative status timing, capability-aware inline backup, version/status/context details, and official `update.install`, `update.skip`, and `update.clear_skipped` service actions.
- Native Settings > Apps page backed by Home Assistant Core's Supervisor WebSocket bridge to `/addons` and `/addons/<slug>/info`, showing installed Supervisor apps/add-ons, version, update availability, artwork, description, and exposed metadata where Supervisor is available. Apps and Updates retain separate discovery lists but open one App Store-inspired software detail that conditionally adds update actions and What’s New.
- Read-only Settings > Logbook page backed by Home Assistant's documented REST logbook API, with date range, entity/domain filtering, search, and app-facing activity row models.
- Native Settings > People page backed by `person.*` and `device_tracker.*` state plus registry metadata, with a compact Family-style people list, authenticated cached person imagery, related source tracker context, useful last-changed/update details, and recent activity timelines.
- Native entity history backed by Home Assistant's documented REST history API, including numeric `sensor.*` chart-first details with 6H/24H/7D/30D ranges, range statistics, and touch selection; dashboard Chart cards with independently persisted 1H/6H/24H/7D ranges, current-value-first edge-to-edge trends, stabilized visual bounds, recorded-history retention, and accessible audio-graph metadata; plus detail-surface timelines for binary sensors, locks, switches, covers, people, and device trackers with fixed ranges. Automation detail uses Home Assistant execution traces and configuration to present real Triggered activity plus native read-only When / And If / Then Do summaries.
- Capability-resolved native gauge presentation for numeric measurement sensors, including circular, bar, and segmented styles. Every gauge style renders the same configured zones; circular uses a continuous track while segmented and bar styles make boundaries explicit. Overall ranges prefer usable Home Assistant metadata and safe device-class defaults; otherwise Homestead offers neutral value-derived bounds without inventing health semantics. Each Sensor Gauge card independently supports min/max editing plus editable per-zone names, native color selection, Begin At editing, and Add/Delete Zone controls. Sensor widgets independently support an Automatic or Custom scale, Automatic or one-to-five zones, conditional Begin At/color fields, and optional custom endpoints. Total-style sensors remain chart/statistics oriented.
- Native dashboard card and detail surface for `.weather` entities, backed by typed current-condition mapping and shared consumer-aware daily, twice-daily, and hourly forecast subscriptions where Home Assistant advertises support. Dashboard Weather cards use contrast-protected condition-responsive surfaces, retain the last successful forecast through refresh failures, and adapt from Square current conditions to Wide hourly and Large hourly-plus-daily forecasts without requiring the detail view to be opened first.
- Official Home Assistant mobile-app registration groundwork, including persisted registration metadata and camera stream webhook handoff support.
- Home Assistant notifications through official mobile-app registration, including native iOS permission status, post-registration permission setup prompt, APNs remote-notification registration, stable relay-token persistence, and the deployed Cloudflare Worker `push_url` relay.
- Settings > Privacy & Permissions page for native iOS capabilities, including Local Network, Location, and Camera, with state-aware inline request or Settings actions, automatic foreground refresh, and system-managed Local Network presentation where iOS does not expose equivalent direct status or request APIs. Notification permission and Home Assistant delivery setup live in Settings > Notifications.
- User-facing service-call and reconnect recovery feedback through `HomeAssistantService` and app chrome, including tappable reconnecting state and clearer action-failure copy.
- Authenticated camera snapshot support.
- Experience-first Home Screen widgets: Control for lights, switches, covers, fans, and lock-only lock actions; Status for sensors and people; Sensor for readings, charts, and deeply configurable gauges; Action for scenes/scripts/buttons; a medium Sensor Board with three independently configured Automatic, Gauge, Reading, or six-hour Chart slots; and a large Sensor Board with nine interchangeable slots in a 3×3 grid. Every explicit Gauge slot supports the same custom scale, range, zone boundaries, and exact zone colors as the Sensor widget. Sensor Board is the single curated multi-sensor widget. Widgets use server-scoped entity identities, per-server compact app-group snapshots, shared semantic presentation, profile-scoped OAuth/WebSocket refresh, batched documented REST history, and official WebSocket service calls.
- Cloud-first setup bootstrap and opt-in automatic iCloud key-value sync for small Homestead-owned preferences. Server profile metadata and per-server dashboard bundles sync without credentials; the active server and current dashboard selection remain device-local.
- User-initiated local Home Assistant discovery through the advertised `_home-assistant._tcp` Bonjour service, with manual sign-in address entry as fallback.
- App-facing model mapping through `EntityMapper`, with SwiftUI avoiding direct Home Assistant DTO use.
- StoreKit-backed Homestead+ with monthly, annual trial, and lifetime choices. Core daily control, one server, one dashboard, wallpaper, and standard single-item widgets remain free; Homestead+ unlocks creation of additional dashboards, additional servers, iCloud sync, Sensor Boards, and advanced Sensor widget presentations. Entitlement changes preserve all user configuration.

## Near-Term Priorities

- Configure and submit the matching Homestead+ products in App Store Connect, exercise the ordinary annual trial with all four TestFlight testers, validate sandbox renewal/expiration and offer-code redemption, then issue four complimentary lifetime codes after approval.
- Device-test the completed Chart, Weather, Media, and Action card families in dense live dashboards, including unavailable/pending states and real Media Player capability combinations, then capture the physical-device performance baseline.
- Physical-device-test the native medium and large Sensor Board configuration sheets plus real sensor names, ranges, icons, history, removed-server, and unavailable states; keep additional layouts curated rather than introducing a free-form widget canvas.
- Polish and device-test the expanded WidgetKit/App Intents surface, then consider Control Center controls for the safest common actions.
- Maintain existing entity history/timeline surfaces and polish them only when concrete visual issues or clearly useful state-only domains appear.
- Continue dashboard organization, filtering, and add-card polish only when user testing or new card types expose concrete friction.

## Later Candidates

- Per-dashboard or per-area wallpaper choices if one wallpaper per server proves too limiting.
- Control Center controls and App Intents for common Home Assistant actions.
- Live Activities for long-running or glanceable states such as appliances, climate, energy, and presence.
- True Home Assistant users/admin views if an official supported API path is confirmed for the signed-in user's permissions.
- Siri/Shortcuts once App Intents have stable action coverage.
- Domain-specific cards and details for calendars, todo lists, humidifiers, water heaters, valves, sirens, air-quality sensors, and image entities.

## Be Careful

- Do not add REST, mobile-app/webhook, or custom URL paths unless the Home Assistant feature is officially exposed that way.
- Do not use private Home Assistant frontend endpoints for integrations, helpers, repairs, blueprints, users, or system health unless the project explicitly accepts that risk.
- Keep the main tab bar focused on daily use. Prefer Settings for registry/admin/companion management surfaces.
- Keep Browse distinct from Settings: Browse is daily discovery/control; Settings is administration, diagnostics, and companion-app configuration.
- Keep newly synced dashboards from appearing automatically on every device; enabled Home pages remain a deliberate device-local choice, while locally created or duplicated dashboards become visible without changing the current page.
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
- Keep unsupported future sections out of production Settings unless they provide real status, recovery, or handoff value; do not use fake data or private API experiments.
