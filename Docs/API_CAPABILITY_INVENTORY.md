# Home Assistant API Capability Inventory

This is Homestead's working map of Home Assistant API surfaces. It is not a promise to implement every capability. Use it to decide where a feature belongs, whether Homestead already has a safe backend path, and whether API research is needed before adding code.

Official references:

- WebSocket API: https://developers.home-assistant.io/docs/api/websocket/
- REST API: https://developers.home-assistant.io/docs/api/rest/
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
| Entity state snapshot | WebSocket `get_states` | Mapped | Stored in `HAStateStore` and mapped through `EntityMapper`. |
| Live state updates | WebSocket `subscribe_events` for `state_changed` | Mapped | Batched before touching SwiftUI-observed state. |
| Service calls | WebSocket `call_service` | Mapped | Domain-specific helpers live on `HomeAssistantService`. |
| Service catalog | WebSocket `get_services` | Mapped | Used to hide unsupported optional controls where practical. |
| Current user | WebSocket `auth/current_user` | Mapped | Used for account display and matching person entity imagery. |
| Entity registry display | WebSocket registry command | Mapped | Used for Browse, Settings management, summaries, and filtering. |
| Device registry | WebSocket registry command | Mapped | Used for device grouping and Settings management. |
| Area registry | WebSocket registry command | Mapped | Used for Areas and area context. |
| Floor registry | WebSocket registry command | Mapped | Used for Areas grouping where helpful. |
| Camera capabilities | WebSocket `camera/capabilities` | Mapped | Used to reason about live camera modes. |
| Camera snapshots | Documented HTTP camera proxy | Mapped | Authenticated snapshot loading. |
| Mobile app registration | Native app HTTP registration | Mapped | Registration metadata persisted for companion-app features. |
| Mobile app camera stream handoff | Native app webhook | Mapped | Uses saved registration webhook metadata. |
| Home Screen light widget | Widget/App Intents plus HA WebSocket/OAuth | Mapped | Basic light control with shared credentials. |

## Near-Term API Targets

| Feature | API family | Status | Intended Homestead surface |
| --- | --- | --- | --- |
| Server/config page | WebSocket `get_config`, auth summary, mobile-app registration | Planned | Settings > Server. |
| Internal/external URL routing | Native app setup guidance plus iOS network state | Planned | Settings > Server and connection lifecycle. |
| Notifications | Native app push notification channel | Planned | Settings > Notifications, app registration, APNs/WebSocket handling. |
| Logbook | REST logbook API | Planned | Settings > Logbook, read-only v1. |
| History/charts | REST history API | Planned | Dashboard chart cards and sensor detail history. |
| Weather card | Entity state attributes for `.weather` | Planned | Dashboard card and weather detail surface. |
| Updates page | `.update` entities and service calls where supported | Planned | Settings > Updates. |
| People/presence | `person.*`, `device_tracker.*`, registries, current user | Planned | Settings > People and presence cards/details. |
| Expanded widgets | WidgetKit/App Intents plus OAuth/WebSocket/service calls | Planned | Widgets and Control Center controls. |

## Next Feature-Sized Mapping Queue

These are the next API slices to map when the matching feature is implemented. Do not add the code for all of them at once.

### Server And Connection Routing

- Add typed support for WebSocket `get_config` only when building the richer Server page.
- Capture Home Assistant version, location/time-unit basics, and external URL metadata only if returned by the official config shape.
- Extend connection settings for Homestead-owned internal URL, external URL, and selected home network metadata.
- Keep URL switching in the connection lifecycle, not in SwiftUI views.

### Notifications

- Build on existing mobile-app registration metadata.
- Add notification permission/status models for iOS app state separately from Home Assistant registration state.
- Use the official native-app push notification path; do not invent a separate Homestead notification automation path.
- Treat APNs token handling, WebSocket push channel handling, and local notification presentation as separate implementation units.

### Logbook

- Add a small REST client for the documented logbook endpoint when building Settings > Logbook.
- Keep v1 read-only with date range, entity/domain filtering, and search presentation helpers.
- Map logbook events into app-facing activity rows instead of exposing raw REST DTOs to SwiftUI.

### History And Charts

- Add a small REST client for the documented history endpoint when building chart cards or sensor detail history.
- Start with sensor-style numeric entities and fixed time ranges before supporting arbitrary entity history.
- Keep chart-specific aggregation and formatting outside `HAStateStore`.

### Weather

- Add a typed weather model only for fields the card/detail UI needs, such as condition, temperature, humidity, wind, forecast availability, and attribution.
- Keep the existing generic `.weather` entity presentation as the fallback.
- Prefer read-only v1 unless official service semantics are needed later.

### Updates

- Use `.update` entities for v1 update visibility.
- Add typed update presentation helpers for installed/latest version, title, release summary, skipped state, and availability where present.
- Add service actions only after confirming available services and safety UX for install/skip/clear flows.

### People And Presence

- Start from `person.*` and `device_tracker.*` entities plus registry metadata.
- Keep true Home Assistant users/admin management separate until an official supported API path is confirmed.
- Avoid assuming every person entity maps to an app user or every user has a person entity.

### Widgets And App Intents

- Reuse OAuth and app-group credential patterns from the current light widget.
- Add one safe action family at a time, starting with toggles/actions that map cleanly to WebSocket service calls.
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

Homestead already recognizes many Home Assistant domains through `EntityDomain` and maps common presentation behavior through `EntityMapper` and dashboard presentation helpers. Strong domain models currently exist only where the UI needs richer native state or controls, such as lights, climate, covers, fans, media players, sensors, and binary sensors.

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
