# Home Assistant API Capability Inventory

This is Homestead's working map of Home Assistant API surfaces. It is not a promise to implement every capability. Use it to decide where a feature belongs, whether Homestead already has a safe backend path, and whether API research is needed before adding code.

Official references:

- WebSocket API: https://developers.home-assistant.io/docs/api/websocket/
- REST API: https://developers.home-assistant.io/docs/api/rest/
- Supervisor API: https://developers.home-assistant.io/docs/api/supervisor/endpoints/
- Native app integration: https://developers.home-assistant.io/docs/api/native-app-integration/setup/
- Push notifications: https://developers.home-assistant.io/docs/api/native-app-integration/notifications/

## Mapping Policy

- Prefer small, feature-owned typed clients and DTOs over broad unused models.
- Keep Home Assistant transport DTOs in `Core/HomeAssistant`; expose app-facing models through `HomeAssistantService`, `HAStateStore`, domain models, or feature-specific presentation helpers.
- Do not add private frontend endpoints or guessed URLs for integrations, helpers, repairs, blueprints, users, or system health without an explicit project decision.
- Add strong typed models when a feature needs them; otherwise keep the capability documented as researched or unknown.
- If the official API path is unclear, mark the feature as "API research needed" before implementation.

## Current Coverage

| Capability | API family | Homestead status | Notes |
| --- | --- | --- | --- |
| OAuth sign-in, token refresh, and revocation | HTTP auth | Mapped | Native OAuth credentials are Keychain-scoped by Homestead server profile. Removing a server calls Home Assistant `/auth/revoke`; failed revocation requires Retry or an explicit device-only removal. |
| Multiple saved servers | App-owned profiles plus Home Assistant auth/WebSocket APIs | Mapped | One profile is active per device and owns the foreground WebSocket. Switching advances the service generation, cancels old work, clears runtime state, restores only the target cache/dashboard, and reconnects with target credentials. |
| WebSocket connect/auth/reconnect | WebSocket | Mapped | `HAWebSocketClient` owns transport and request routing. |
| Discovery and internal/external URL routing | Bonjour `_home-assistant._tcp`, WebSocket `get_config`, platform network state, and optional current Wi-Fi SSID via `NEHotspotNetwork` | Mapped | Setup browses only after the user selects Find Home Assistant, parses advertised server identity and route metadata, and keeps manual entry as fallback. `HomeAssistantService` prefers the Local Address only on saved Wi-Fi names when a Remote Address exists; otherwise it uses the Remote Address/current sign-in address first. OAuth, cache, and registration identity remain anchored to the sign-in address. Reading the current Wi-Fi name requires Location permission and the Wi-Fi Information entitlement. |
| Entity state snapshot | WebSocket `get_states` | Mapped | Stored in `HAStateStore` and mapped through `EntityMapper`. |
| Live state updates | WebSocket `subscribe_events` for `state_changed` | Mapped | Batched before touching SwiftUI-observed state. |
| Service calls | WebSocket `call_service` | Mapped | Domain-specific helpers live on `HomeAssistantService`. |
| Service catalog | WebSocket `get_services` | Mapped | Feeds typed native controls and the generic entity-action fallback. Common boolean, numeric, select, and text field selectors map into a native action sheet; specialized controls remain preferred. |
| Server configuration | WebSocket `get_config` and admin-only `config/core/update`, plus read-only Supervisor bridge info when available | Mapped | Settings > Account reads the Home Assistant instance name, Core version, and official internal/external URL values. Its Name editor updates Home Assistant's actual `location_name`, then refreshes `get_config`; optional Supervisor/OS versions remain read-only through Core's `supervisor/api` bridge. |
| Current user | WebSocket `auth/current_user` | Mapped | Used for account display and matching person entity imagery. |
| Entity registry display and organization | WebSocket `config/entity_registry/list_for_display` plus read-only `config/entity_registry/list` organization metadata | Mapped | The compact documented display feed remains the enabled-entity UI source. Homestead separately maps full-registry area, label, and scoped category assignments for Settings grouping/filtering without changing entity visibility. Registry update events trigger a debounced metadata refresh. |
| Device registry | WebSocket registry command | Mapped | Used for device grouping, area context, label filtering, and Settings management. Registry update events trigger a debounced metadata refresh. |
| Labels and scoped categories | WebSocket `config/label_registry/list` and `config/category_registry/list` with `automation`, `scene`, `script`, and `helper` scopes | Mapped, read-only | Labels are reusable multi-value filters. Categories are single-value, table-specific groupings, and category headers render HA-provided icons through Homestead's native-first MDI/SF resolver. Unsupported/older servers degrade to empty organization metadata; creation, assignment, bulk editing, and deletion remain in Home Assistant. |
| Area registry | WebSocket registry command | Mapped | Used for Areas and area context, including HA-selected climate reading entities. Registry update events trigger a debounced metadata refresh. |
| Floor registry | WebSocket registry command | Mapped | Used for Areas and floor-first summary grouping. Registry update events trigger a debounced metadata refresh. |
| Dashboard summary membership | Entity state plus entity/device/area registry metadata | Mapped, frontend-derived | Home Assistant does not expose summary-category membership directly through REST or WebSocket. Homestead mirrors the current HA frontend filter strategies for Climate, Lights, Security, Media, and Maintenance using registry visibility/category metadata, device classes, selected area climate readings, and charging-device context. |
| Camera capabilities | WebSocket `camera/capabilities` | Mapped | Used to reason about live camera modes. |
| Camera snapshots | Documented HTTP camera proxy | Mapped | Authenticated snapshot loading. |
| Logbook | REST logbook API | Mapped | Read-only Settings > Logbook uses the documented start timestamp, `end_time`, and `entity` request shape, then applies domain/search presentation locally. The Security summary requests a 24-hour window, retains Security summary entities plus every `person.*` entity, maps returned state/context fields into HA-style activity narratives, trigger attribution, People-backed user attribution, and historical state-aware icons, and does not apply an additional local row cap. |
| History/charts/timelines | REST history API and WebSocket `trace/list` | Mapped | Numeric sensor detail charts/dashboard chart cards plus detail-surface timelines for binary sensors, locks, switches, covers, people, and device trackers use `/api/history/period/<timestamp>` with `filter_entity_id`, `end_time`, `minimal_response`, and `no_attributes`. Automations use Home Assistant's execution traces so activity reflects real runs rather than enable/disable state changes. All data is mapped into app-facing models outside `HAStateStore`. |
| Sensor gauges | Entity state attributes plus per-card/per-widget configuration | Mapped | Numeric measurements map into app-facing gauge presentation. Explicit HA range hints and safe device-class/unit defaults win; otherwise Homestead suggests neutral value-derived bounds. Generic measurements do not receive invented health semantics, while total and total-increasing sensors remain chart/statistics oriented. Every Sensor Gauge card independently persists editable min/max and an ordered one-to-five-zone configuration with user-defined names and RGBA color bands, rendered consistently by circular, segmented, and bar styles. Existing status-based card configurations migrate to their equivalent standard colors. Every Sensor widget instance independently supports an Automatic or Custom scale; Automatic follows the resolved Home Assistant range, while Custom conditionally reveals optional endpoint overrides. App Intent parameter summaries also reveal the required `Zone N Begins At` values and a compact per-zone color palette. |
| Weather | `.weather` entity state attributes plus WebSocket `weather/subscribe_forecast` | Mapped | Dashboard cards and native detail surfaces map current condition, temperature, humidity, wind, and attribution into app-facing models. Weather detail subscribes only while presented to each server-advertised daily, twice-daily, or hourly forecast type, retains the most recent forecast during refresh failures, and removes subscriptions on dismissal or connection changes. |
| Updates | `.update` entities plus WebSocket `call_service` | Mapped | Settings > Updates maps update entity attributes for versions, release notes, skipped/in-progress/unavailable state, registry context, grouping/filtering/search, and gates `update.install`, `update.skip`, and `update.clear_skipped` through the service catalog. |
| Supervisor apps/add-ons | Home Assistant Core WebSocket `supervisor/api` bridge to Supervisor `/addons`; Core `/api/hassio/addons/<slug>/icon` and `/logo` image proxy | Mapped, Supervisor-only | Settings > Apps asks Home Assistant Core to proxy the installed Supervisor apps/add-ons request to Supervisor, maps DTOs into app-facing rows with version, update availability, artwork availability, and Running/Stopped/Unknown status, and shows an unavailable state on non-Supervisor installs. Add-on artwork is loaded only when Supervisor reports `icon` or `logo` availability. Direct native-client HTTP calls to `http://supervisor` are not possible because Supervisor requires Core's/add-ons' `SUPERVISOR_TOKEN`; no install/uninstall/start/stop/configuration actions are exposed. |
| Integration platform overview | WebSocket entity registry display `platform` metadata, state/device registry context, and local Brands HTTP API | Mapped, read-only | Settings > Devices & Services > Integrations groups enabled entity-registry entries by the documented registry `platform` value, then follows Home Assistant's integration-to-device-to-entity hierarchy: integration details list alphabetized associated devices, device details list their entities, and entity-only platforms retain a direct entity section. It also shows entity/device/unavailable/config/diagnostic/hidden counts and loads cached light/dark integration icons through `/api/brands/integration/<domain>/<image>`. Servers before Home Assistant 2026.3 or integrations without artwork use a native fallback icon. This is not full Home Assistant config-entry management. |
| Helpers browser and value control | Entity state, registry metadata, and WebSocket `call_service` | Mapped | Settings > Devices & Services > Helpers recognizes `input_boolean`, `input_button`, `input_datetime`, `input_number`, `input_select`, `input_text`, `counter`, `timer`, and `schedule` entities. Select, number, text, and date/time helpers reuse typed native detail families and call their official helper-domain services. Helper definition creation/editing remains out of scope. |
| Automation and script details and organization | State entities, full entity organization metadata, area/label/category registries, WebSocket `automation/config`, `script/config`, and `trace/list` | Mapped, read-only | Settings > Automations & Scenes supports independently persisted Name, Area, Category, and Recently Used organization; label and availability filtering; scoped categories for each table; searchable area/category/label metadata; enabled-state presentation for automations; relative last-triggered/activated/run detail; native read-only automation When / And If / Then Do and script Sequence summaries, including nested conditions and branches; and automation execution-trace activity. Advanced editing and full trace inspection remain in Home Assistant. |
| People/presence | `person.*`, `device_tracker.*`, registries, entity pictures | Mapped | Settings > People and native entity details consume the same app-facing presence records, relate people to source trackers where Home Assistant exposes `source`, use authenticated cached image requests for entity pictures, and reuse documented REST history for person/tracker recent activity. Device Tracker presentation accepts legacy `gps_accuracy` and current `location_accuracy` plus `source_type`/`tracking_type` state metadata without exposing raw DTOs to SwiftUI. True user/admin management remains out of scope. |
| Mobile app registration | Native app HTTP registration | Mapped | Registration metadata persisted for companion-app features. |
| Mobile app camera stream handoff | Native app webhook | Mapped | Uses saved registration webhook metadata. |
| Native notification permission/status | iOS UserNotifications, APNs remote registration | Mapped | Settings > Notifications shows device permission status separately from Home Assistant mobile-app registration, requests permission natively, registers for APNs remote notifications when allowed, and reports non-sensitive background delivery state. |
| Native iOS permissions | AVFoundation, CoreLocation, iOS Settings | Mapped | Settings > Privacy & Permissions shows Local Network, Location, and Camera. Camera/location use public authorization APIs. Local Network is represented as iOS-managed because there is no direct read-only status API. Notification permission status lives in Settings > Notifications. |
| Mobile app WebSocket notifications | Native app WebSocket push notification channel | Implemented but not advertised | The client can subscribe with `mobile_app/push_notification_channel`, decode documented root-level events and nested payload variants, present local iOS notifications, and confirm HA delivery when requested. Homestead does not currently advertise `push_websocket_channel` in mobile-app registration so Home Assistant prefers the remote APNs `push_url` path. |
| Mobile app cloud push relay | Home Assistant native-app `push_url`, Cloudflare Workers, APNs | Mapped | The deployed `homestead-api` Worker stores app-registered relay-token to APNs-token mappings in `HOMESTEAD_PUSH_TOKENS`, relays Home Assistant `push_token` payloads to sandbox or production APNs using Worker secrets, and is registered with Home Assistant through `push_url = https://api.homesteadcontrol.com/mobile-app/push` plus Homestead's stable per-install relay token. |
| Home Screen widgets | Widget/App Intents plus HA WebSocket/OAuth/history | Mapped | The gallery is organized by experience: Control covers light/switch/fan toggles, cover open/close/stop, and lock-only lock actions; Status covers sensor/person state; Sensor covers readings, numeric charts, and capability-validated gauges; Sensor Board provides three independently configured Automatic/Gauge/Reading/Chart slots and dynamically switches each App Intent slot between a general Sensor picker and numeric-only Chart Sensor picker; Action covers scene/script/button runs. Widgets use shared credentials, compact app-group snapshots, WebSocket state refresh, documented REST history, and official WebSocket service calls. |
| Homestead iCloud sync | Apple iCloud key-value storage | Mapped | Payload v2 remains backward-compatible while carrying optional server-profile metadata and per-profile dashboard bundles. Credentials, active-profile selection, current dashboard selection, and generated/device data remain device-local. |

## Near-Term API Targets

| Feature | API family | Status | Intended Homestead surface |
| --- | --- | --- | --- |
| Expanded widgets | WidgetKit/App Intents plus OAuth/WebSocket/history/service calls | In progress | Home Screen Control, Status, Sensor, Sensor Board, Gauge Grid, and Action widgets exist; Control Center controls and widget polish/device testing remain follow-up scope. |

## Next Feature-Sized Mapping Queue

These are the next API slices to map when the matching feature is implemented. Do not add the code for all of them at once.

### Server And Connection Routing

- Typed WebSocket `get_config` support exists for the inline Account server details, and the admin-only `config/core/update` command updates Home Assistant's actual `location_name`.
- Home Assistant instance name, Core version, and internal/external URL metadata are displayed only if returned by the official config shape. Supervisor and OS versions are fetched opportunistically through Core's documented `supervisor/api` bridge and gracefully show unavailable on non-Supervisor installs.
- Connection settings store a sign-in identity plus Homestead-owned local and remote route candidates. Optional saved Wi-Fi names gate Local Address preference when a Remote Address exists. The legacy single home-network field migrates to that list.
- Automatic internal/external URL switching now lives in `HomeAssistantService` connection lifecycle code. SwiftUI displays the active route but does not choose URLs.
- Route fallback tries the next saved URL for transport-style failures while preserving OAuth/token refresh behavior and cache/mobile-app server identity.

### Notifications

- Native iOS notification permission/status models and Settings > Notifications setup UI exist separately from Home Assistant registration state.
- Homestead registers for APNs remote notifications after the user allows notification permission, stores a stable relay token in Keychain, sends APNs token metadata to `https://api.homesteadcontrol.com/mobile-app/register-push-token`, and includes `app_data.push_url` plus `app_data.push_token` in Home Assistant mobile-app registration.
- Homestead does not advertise `push_websocket_channel` for this first remote-push version, even though the client-side decoder/subscription code remains available.
- Use the official native-app push notification path; do not invent a separate Homestead notification automation path.

### History And Charts

- A small REST client for the documented history endpoint exists for numeric sensor charts and discrete state timelines.
- Current support covers sensor-style numeric entities plus binary sensor, lock, switch, automation, cover, person, and device tracker state timelines with fixed 1H/6H/24H ranges.
- Dashboard Chart cards support numeric sensors in chart-capable card sizes with independently persisted 1H/6H/24H/7D ranges through the same service/HTTP flow. Their chart-first detail supports 6H/24H/7D/30D selection, range statistics, and direct point inspection.
- One-year numeric history remains deferred until an official long-term statistics contract is mapped; it should not be implemented as an expensive raw-history request.
- Arbitrary entity history and dashboard timeline cards remain follow-up scope.
- Keep history-specific aggregation and formatting outside `HAStateStore`.

### Widgets And App Intents

- Reuse OAuth and app-group credential patterns from the current Home Screen widgets.
- Keep the widget gallery organized by user intent rather than Home Assistant domain: Control, Status, Sensor, and Action are the primary user-facing widget kinds.
- Add one safe action family at a time, starting with toggles/actions that map cleanly to WebSocket service calls. Light/switch/fan controls, cover open/close/stop, lock-only lock actions, and scene/script/button action widgets now use this pattern.
- Numeric sensor chart widgets use the documented REST history endpoint with the same OAuth/app-group credential path.
- Keep widget snapshots small and scoped to what WidgetKit needs to render quickly.

## Research Needed

| Feature | Why it needs research |
| --- | --- |
| Integrations management | Read-only platform grouping is mapped; setup, reconfigure, delete, repair, reload, and full config-entry management still need an official supported external API path. |
| Helpers management | Read-only helper entity browsing is mapped; helper creation/editing still needs an official supported external API path. |
| Blueprints | Need an official supported API path for browsing/importing/managing blueprints. |
| Repairs/system health | Home Assistant has repairs concepts, but Homestead should confirm supported external-client APIs before implementing. |
| True HA users/admin views | Current user is mapped; listing/managing all users needs confirmed official API support and permission behavior. |
| Automation/scene/script editing | Entity control is supported; native editing requires official config/editor APIs or a deliberate decision to defer. |
| Energy dashboard data | Needs API research before charting or dashboard summary work. |
| Backups | Needs API research and careful permission/safety design. |
| Calendar and todo management | Entity display is recognized; CRUD and rich interactions need API research. |
| Floor plans, room scanning, and AR mapping | High product and platform cost; not a near-term API mapping target. |

## Entity Domain Mapping Notes

Homestead already recognizes many Home Assistant domains through `EntityDomain` and maps common presentation behavior through `EntityMapper` and dashboard presentation helpers. Strong domain models exist only where the UI needs richer native state or controls, including lights, climate, covers, fans, media players, sensors, binary sensors, selects, numbers, constrained text, and date/time values.

`select.*` and `input_select.*` share Homestead's select-style presentation and dashboard Options feature, but service calls preserve Home Assistant's real service domain: `select.select_option` for `select.*` and `input_select.select_option` for `input_select.*`.

The same alias rule applies to editable values: `number.*`/`input_number.*`, `text.*`/`input_text.*`, and native `date.*`, `time.*`, `datetime.*`/`input_datetime.*` share app-facing models and native editors. Service routing retains each entity's actual Home Assistant domain and payload key (`value`, `date`, `time`, or `datetime`).

When adding richer support for a domain:

- Start from official Home Assistant state attributes and service descriptions.
- Add a typed app model only for state the UI actually consumes.
- Add state-store accessors only when more than one feature needs that typed model.
- Add service helpers only for explicit user intents and known safe actions.
- Keep read-only domains read-only until service semantics and safety UX are clear.

## Implementation Checklist For New API Work

- Confirm the official API family and document it here.
- Add transport DTOs or request cases in `Core/HomeAssistant` only for the feature being built.
- Keep raw DTO use out of SwiftUI view bodies.
- Add focused tests for request encoding, response decoding, mapping, state-store helpers, and UI presentation helpers.
- Update `Docs/PRODUCT_ROADMAP.md` if the feature priority or product direction changes.
