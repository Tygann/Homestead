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
| OAuth sign-in and token refresh | HTTP auth | Mapped | Native app OAuth flow with Keychain-backed refresh tokens. |
| WebSocket connect/auth/reconnect | WebSocket | Mapped | `HAWebSocketClient` owns transport and request routing. |
| Internal/external URL routing | Native app setup guidance plus iOS network state | Mapped | Settings stores Homestead-owned internal URL, external URL, and home network metadata. `HomeAssistantService` resolves the active route for WebSocket, documented HTTP clients, and mobile-app registration while keeping OAuth refresh, cache scope, and registration identity anchored to the signed-in server. |
| Entity state snapshot | WebSocket `get_states` | Mapped | Stored in `HAStateStore` and mapped through `EntityMapper`. |
| Live state updates | WebSocket `subscribe_events` for `state_changed` | Mapped | Batched before touching SwiftUI-observed state. |
| Service calls | WebSocket `call_service` | Mapped | Domain-specific helpers live on `HomeAssistantService`. |
| Service catalog | WebSocket `get_services` | Mapped | Used to hide unsupported optional controls where practical. |
| Server config snapshot | WebSocket `get_config` | Mapped | Used by Settings > Account > Server for HA version/status/location/unit and official URL values returned by Home Assistant. |
| Current user | WebSocket `auth/current_user` | Mapped | Used for account display and matching person entity imagery. |
| Entity registry display | WebSocket registry command | Mapped | Used for Browse, Settings management, summaries, and filtering. Registry update events trigger a debounced metadata refresh. |
| Device registry | WebSocket registry command | Mapped | Used for device grouping and Settings management. Registry update events trigger a debounced metadata refresh. |
| Area registry | WebSocket registry command | Mapped | Used for Areas and area context, including HA-selected climate reading entities. Registry update events trigger a debounced metadata refresh. |
| Floor registry | WebSocket registry command | Mapped | Used for Areas and floor-first summary grouping. Registry update events trigger a debounced metadata refresh. |
| Dashboard summary membership | Entity state plus entity/device/area registry metadata | Mapped, frontend-derived | Home Assistant does not expose summary-category membership directly through REST or WebSocket. Homestead mirrors the current HA frontend filter strategies for Climate, Lights, Security, Media, and Maintenance using registry visibility/category metadata, device classes, selected area climate readings, and charging-device context. |
| Camera capabilities | WebSocket `camera/capabilities` | Mapped | Used to reason about live camera modes. |
| Camera snapshots | Documented HTTP camera proxy | Mapped | Authenticated snapshot loading. |
| Logbook | REST logbook API | Mapped | Read-only Settings > Logbook uses the documented start timestamp, `end_time`, and `entity` request shape, then applies domain/search presentation locally. The Security summary requests a 24-hour window and locally retains Security summary entities plus every `person.*` entity, matching HA's frontend strategy. |
| History/charts/timelines | REST history API | Mapped | Numeric sensor detail charts/dashboard chart cards plus detail-surface timelines for binary sensors, locks, switches, automations, covers, people, and device trackers use `/api/history/period/<timestamp>` with `filter_entity_id`, `end_time`, `minimal_response`, and `no_attributes`, then map into app-facing chart/timeline models outside `HAStateStore`. |
| Sensor gauges | Entity state attributes | Mapped | Numeric `sensor.*` values are mapped into app-facing gauge presentation when Home Assistant supplies usable min/max-style metadata or Homestead can safely infer bounded ranges from device class/unit. SwiftUI consumes the gauge model, not raw DTO attributes. |
| Weather | `.weather` entity state attributes | Mapped | Dashboard cards and native detail surfaces map condition, temperature, humidity, wind, forecast availability from state attributes, and attribution into app-facing presentation models. Read-only v1; no weather service calls are used. |
| Updates | `.update` entities plus WebSocket `call_service` | Mapped | Settings > Updates maps update entity attributes for versions, release notes, skipped/in-progress/unavailable state, registry context, grouping/filtering/search, and gates `update.install`, `update.skip`, and `update.clear_skipped` through the service catalog. |
| Supervisor apps/add-ons | Home Assistant Core WebSocket `supervisor/api` bridge to Supervisor `/addons`; Core `/api/hassio/addons/<slug>/icon` and `/logo` image proxy | Mapped, Supervisor-only | Settings > Apps asks Home Assistant Core to proxy the installed Supervisor apps/add-ons request to Supervisor, maps DTOs into app-facing rows with version, update availability, artwork availability, and Running/Stopped/Unknown status, and shows an unavailable state on non-Supervisor installs. Add-on artwork is loaded only when Supervisor reports `icon` or `logo` availability. Direct native-client HTTP calls to `http://supervisor` are not possible because Supervisor requires Core's/add-ons' `SUPERVISOR_TOKEN`; no install/uninstall/start/stop/configuration actions are exposed. |
| People/presence | `person.*`, `device_tracker.*`, registries, entity pictures | Mapped | Settings > People maps existing state and registry metadata into app-facing presence records, relates people to source trackers where Home Assistant exposes `source`, uses authenticated cached image requests for entity pictures, and reuses documented REST history for person/tracker recent activity. True user/admin management remains out of scope. |
| Mobile app registration | Native app HTTP registration | Mapped | Registration metadata persisted for companion-app features. |
| Mobile app camera stream handoff | Native app webhook | Mapped | Uses saved registration webhook metadata. |
| Native notification permission/status | iOS UserNotifications | Mapped | Settings > Notifications shows device permission status separately from Home Assistant mobile-app registration. |
| Native iOS permissions | iOS UserNotifications, AVFoundation, CoreLocation, iOS Settings | Mapped | Settings > Permissions shows Notifications, Local Network, Location, and Camera. Camera/location use public authorization APIs. Local Network is represented as iOS-managed because there is no direct read-only status API. |
| Mobile app WebSocket notifications | Native app WebSocket push notification channel | Mapped | Registers `push_websocket_channel`, subscribes with `mobile_app/push_notification_channel`, accepts documented root-level events and nested payload variants, presents local iOS notifications, and confirms HA delivery when requested. Delivery requires an active Home Assistant WebSocket connection; Homestead does not currently register an APNs token or operate a `push_url` forwarding service. |
| Home Screen widgets | Widget/App Intents plus HA WebSocket/OAuth/history | Mapped | The gallery is organized by experience: Control covers light/switch/fan toggles, cover open/close/stop, and lock-only lock actions; Status covers sensor/person state; Graph covers numeric sensor history; Action covers scene/script runs. Widgets use shared credentials, compact app-group snapshots, WebSocket state refresh, documented REST history for graphs, and official WebSocket service calls where actions are available. |

## Near-Term API Targets

| Feature | API family | Status | Intended Homestead surface |
| --- | --- | --- | --- |
| Expanded widgets | WidgetKit/App Intents plus OAuth/WebSocket/history/service calls | In progress | Home Screen Control, Status, Graph, and Action widgets exist; Control Center controls and widget polish/device testing remain follow-up scope. |

## Next Feature-Sized Mapping Queue

These are the next API slices to map when the matching feature is implemented. Do not add the code for all of them at once.

### Server And Connection Routing

- Typed WebSocket `get_config` support exists for the dedicated `Settings > Account > Server` page.
- Home Assistant version, location/time-unit basics, status/config source, and internal/external URL metadata are displayed only if returned by the official config shape.
- Connection settings now store Homestead-owned internal URL, external URL, and selected home network metadata.
- Automatic internal/external URL switching now lives in `HomeAssistantService` connection lifecycle code. SwiftUI displays the active route but does not choose URLs.
- Route fallback tries the next saved URL for transport-style failures while preserving OAuth/token refresh behavior and cache/mobile-app server identity.

### Notifications

- Build on existing mobile-app registration metadata.
- Native iOS notification permission/status models and Settings > Notifications setup UI exist separately from Home Assistant registration state.
- Homestead uses Home Assistant's official WebSocket push notification channel by setting `push_websocket_channel` during mobile-app registration, subscribing with the saved webhook ID, presenting local notifications, and confirming delivery when Home Assistant provides a confirmation ID.
- This is connected-session notification delivery. Homestead currently has no `aps-environment` entitlement, no `registerForRemoteNotifications` APNs token flow, and no Home Assistant `push_url` server registration, so automations cannot wake a suspended/closed app through APNs.
- Use the official native-app push notification path; do not invent a separate Homestead notification automation path.
- Cloud/APNs notification forwarding would require a separate Homestead-operated push service and should stay out of scope unless the project explicitly accepts that infrastructure.

### History And Charts

- A small REST client for the documented history endpoint exists for numeric sensor charts and discrete state timelines.
- Current support covers sensor-style numeric entities plus binary sensor, lock, switch, automation, cover, person, and device tracker state timelines with fixed 1H/6H/24H ranges.
- Dashboard chart cards support numeric sensors in chart-capable card sizes with a fixed dashboard range through the same service/HTTP flow.
- Arbitrary entity history and dashboard timeline cards remain follow-up scope.
- Keep history-specific aggregation and formatting outside `HAStateStore`.

### Widgets And App Intents

- Reuse OAuth and app-group credential patterns from the current Home Screen widgets.
- Keep the widget gallery organized by user intent rather than Home Assistant domain: Control, Status, Graph, and Action are the primary user-facing widget kinds.
- Add one safe action family at a time, starting with toggles/actions that map cleanly to WebSocket service calls. Light/switch/fan controls, cover open/close/stop, lock-only lock actions, and scene/script action widgets now use this pattern.
- Numeric sensor graph widgets use the documented REST history endpoint with the same OAuth/app-group credential path.
- Keep widget snapshots small and scoped to what WidgetKit needs to render quickly.

## Research Needed

| Feature | Why it needs research |
| --- | --- |
| Integrations management | Need an official supported API path before exposing native details or actions. |
| Helpers management | Need an official supported API path; entity-domain inference is not enough for full helper management. |
| Blueprints | Need an official supported API path for browsing/importing/managing blueprints. |
| Repairs/system health | Home Assistant has repairs concepts, but Homestead should confirm supported external-client APIs before implementing. |
| True HA users/admin views | Current user is mapped; listing/managing all users needs confirmed official API support and permission behavior. |
| Automation/scene/script editing | Entity control is supported; native editing requires official config/editor APIs or a deliberate decision to defer. |
| Energy dashboard data | Needs API research before charting or dashboard summary work. |
| Backups | Needs API research and careful permission/safety design. |
| Calendar and todo management | Entity display is recognized; CRUD and rich interactions need API research. |
| Floor plans, room scanning, and AR mapping | High product and platform cost; not a near-term API mapping target. |

## Entity Domain Mapping Notes

Homestead already recognizes many Home Assistant domains through `EntityDomain` and maps common presentation behavior through `EntityMapper` and dashboard presentation helpers. Strong domain models currently exist only where the UI needs richer native state or controls, such as lights, climate, covers, fans, media players, sensors, binary sensors, and select-style option entities.

`select.*` and `input_select.*` share Homestead's select-style presentation and dashboard Options feature, but service calls preserve Home Assistant's real service domain: `select.select_option` for `select.*` and `input_select.select_option` for `input_select.*`.

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
