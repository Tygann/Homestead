# Homestead Architecture

Homestead is a native SwiftUI frontend for Home Assistant. Home Assistant remains the system of record for integrations, devices, entities, automations, scenes, scripts, and service execution.

## WebSocket-first API

The initial API layer is Home Assistant's WebSocket API only. `HAWebSocketClient` owns the persistent socket, authentication, typed outbound messages, inbound result routing, initial `get_states` snapshots, `state_changed` subscriptions, and `call_service` requests.

`HomeAssistantService` owns connection status and reconnect behavior. When the socket drops unexpectedly, it retries with a small backoff sequence, fetches a fresh state snapshot, and resubscribes to `state_changed` events. TODO: add app lifecycle and network reachability awareness before shipping.

## DTOs vs domain models

Raw Home Assistant payloads live in `Core/HomeAssistant`. DTOs such as `HAEntityDTO`, `HAEventDTO`, and `HAWebSocketIncomingMessage` mirror transport concerns, including dynamic JSON attributes.

SwiftUI views should not read those DTOs directly. `EntityMapper` converts raw DTOs into app-facing models such as `HomeEntity`, `LightEntity`, `ClimateEntity`, `CoverEntity`, and `SensorEntity`.

## State store

`HAStateStore` is the single source of truth for entity state. It stores the latest raw entity snapshot internally, exposes mapped domain entities to the app, applies initial snapshots, and handles `state_changed` event updates.

Views observe `HAStateStore` and ask it for typed entities by `entityID`. They should not decode Home Assistant JSON or hold independent entity caches.

## Service layer

SwiftUI views call `HomeAssistantService`, not `HAWebSocketClient`. The service exposes intent-level methods such as `toggleLight(entityID:)`, `turnOnLight(entityID:)`, `turnOffLight(entityID:)`, and `callService(domain:service:entityID:)`.

This keeps transport details out of cards and leaves room for optimistic updates, error presentation, and reconnect handling later.

## Credentials

`HAConnectionSettings` stores the Home Assistant base URL in `UserDefaults` and the long-lived access token in Keychain through `HACredentialStore`. Tests and previews use `InMemoryHACredentialStore` so they do not read or write real credentials.

## Adding cards

New cards should:

1. Accept an `entityID`.
2. Read typed state from `HAStateStore`.
3. Send user actions through `HomeAssistantService`.
4. Use reusable design system primitives such as `CardContainer`, `CardIconView`, spacing, and radius constants.
5. Keep view-local logic small and move mapping or formatting that belongs to the domain into `EntityMapper` or domain models.
