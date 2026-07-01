# Homestead Architecture

Homestead is a native SwiftUI frontend for Home Assistant. Home Assistant remains the system of record for integrations, devices, entities, automations, scenes, scripts, and service execution.

## Home Assistant API Shape

Homestead should follow Home Assistant's intended API shape instead of reverse-engineering frontend URLs or adding workaround transports. The main app data/control plane is Home Assistant's WebSocket API. `HAWebSocketClient` owns the persistent socket, authentication, typed outbound messages, inbound result routing, initial `get_states` snapshots, `state_changed` subscriptions, registry requests, and `call_service` requests.

Use HTTP only for Home Assistant features that are documented as HTTP surfaces, such as authentication/token exchange, camera snapshots, media downloads, or signed media paths. Use native-app/mobile-app registration only for companion-app capabilities that require it, such as official mobile app webhooks, app/device identity, notifications, app-provided sensors, or camera stream handoff.

When adding a Home Assistant feature, first identify the official API family for that feature and keep the integration in the matching layer. Prefer small typed clients and DTOs in `Core/HomeAssistant`, with SwiftUI consuming app-facing models or `HomeAssistantService` intents.

## WebSocket-first API

`HomeAssistantService` owns connection status, reconnect behavior, and UI-facing Home Assistant actions. When the socket drops unexpectedly, it retries with a small backoff sequence, fetches a fresh state snapshot, and resubscribes to `state_changed` events. App foreground/background transitions and network reachability updates feed this lifecycle so stale cached state remains visible while Homestead reconnects.

Live `state_changed` events are batched before they touch SwiftUI-observed state. A large Home Assistant instance can produce frequent background updates, and batching keeps those updates from interrupting scrolling and gestures as often.

## DTOs vs domain models

Raw Home Assistant payloads live in `Core/HomeAssistant`. DTOs such as `HAEntityDTO`, `HAEventDTO`, and `HAWebSocketIncomingMessage` mirror transport concerns, including dynamic JSON attributes.

SwiftUI views should not read those DTOs directly. `EntityMapper` converts raw DTOs into app-facing models such as `HomeEntity`, `LightEntity`, `ClimateEntity`, `CoverEntity`, and `SensorEntity`.

## State store

`HAStateStore` is the single source of truth for entity state. It stores the latest raw entity snapshot internally, exposes mapped domain entities to the app, applies initial snapshots, and handles `state_changed` event updates.

Stable entity catalog data, such as sorted entities and grouped entity IDs, is kept separate from live per-entity state. Dashboard cards and entity rows should prefer `HAEntityState` boxes so one entity update does not invalidate broad lists or grids.

Views should not decode Home Assistant JSON or hold independent entity caches.

## Service layer

SwiftUI views call `HomeAssistantService`, not `HAWebSocketClient`. The service exposes intent-level methods such as `toggleLight(entityID:)`, `turnOnLight(entityID:)`, `turnOffLight(entityID:)`, and `callService(domain:service:entityID:)`.

This keeps transport details out of cards and leaves room for optimistic updates, error presentation, and reconnect handling later.

## Credentials And Native App Registration

`HAConnectionSettings` stores the Home Assistant base URL plus Homestead-owned internal URL, external URL, and home-network metadata in `UserDefaults`; the base URL is also mirrored to shared widget defaults. Homestead supports the official Home Assistant native app OAuth2/IndieAuth flow as its only login path. `HomeAssistantService` builds the documented `/auth/authorize` URL with `https://connect.homesteadcontrol.com` as the OAuth client ID and `homestead://auth` as the native callback. The client ID website is served by the `homestead-api` Worker and whitelists that callback with Home Assistant's documented `rel="redirect_uri"` link. Authorization opens through `ASWebAuthenticationSession`; Homestead then exchanges the returned authorization code at `/auth/token` and stores the returned refresh token plus short-lived access-token metadata in Keychain through `KeychainHAOAuthTokenStore`.

Before WebSocket connect, reconnect, camera snapshot HTTP requests, mobile-app registration, or other documented HTTP calls, `HomeAssistantService` asks `HAOAuthManager` for a valid current access token. If the access token is expired or close to expiry, or if a WebSocket auth attempt is rejected, the manager refreshes through `/auth/token` using the stored refresh token and updates Keychain. `HomeAssistantService` resolves the active internal/external route from saved settings and iOS network state, then gives `HAWebSocketClient`, `HAHTTPClient`, and `HAMobileAppClient` an `HAConnectionConfiguration` whose active base URL may differ from the signed-in server identity. Cache scope, OAuth refresh, and mobile-app registration identity remain anchored to the signed-in server. SwiftUI never handles raw OAuth DTOs, tokens, or URL switching decisions.

`HAMobileAppClient` owns the official `/api/mobile_app/registrations` HTTP registration call and mobile-app webhook interactions such as `stream_camera`. After OAuth sign-in succeeds and Homestead has a valid access token, `HomeAssistantService` automatically creates a mobile-app registration when there is no saved registration for the current Home Assistant server. `HAMobileAppRegistrationStore` persists the returned registration metadata, especially `webhook_id`, in Keychain. These mobile-app paths are only for official companion-app capabilities; entity state and service control remain WebSocket-first.

## Adding cards

Dashboard persistence uses a versioned, source-first configuration model. A sourced item pairs a `DashboardSourceReference` (currently entity or summary) with a typed `DashboardPresentationConfiguration` (Chip or a card configuration that owns its valid layout/options). `DashboardPresentationCatalog` is the shared compatibility and recommendation source for both Items-first and Cards-first add flows. Unsupported layouts and incompatible decoded source/presentation pairs are removed before they become active state.

Dashboard schema changes are currently allowed to reset saved dashboard definitions because Homestead is pre-release. An unsupported or corrupt dashboard section resets independently; it must not discard connection, appearance, safety, or other iCloud-synced preferences. The current dashboard selection remains device-local.

New cards should:

1. Route from an `entityID`.
2. Read typed state from a per-entity `HAEntityState` when possible.
3. Send user actions through `HomeAssistantService`.
4. Use reusable design system primitives such as `CardContainer`, `CardIconView`, spacing, and radius constants.
5. Keep view-local logic small and move mapping or formatting that belongs to the domain into `EntityMapper` or domain models.

Avoid expensive material stacks, large shadows, and unnecessary implicit animations in scrolling dashboard cards. Prefer grouped system colors for frequently repeated card surfaces.
