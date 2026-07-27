# ADR 3: Homestead Plus StoreKit Entitlements

## Status

Accepted

## Context

Homestead needs sustainable monetization without making access to a user's own Home Assistant data, safety controls, or ordinary reliability dependent on payment. Purchases apply only to Apple-platform app capabilities and do not need a Homestead account or cross-platform entitlement service.

## Decision

Homestead uses StoreKit 2 with monthly and annual auto-renewable subscriptions plus one non-consumable lifetime purchase. Every verified product grants one app-facing `hasPlus` capability.

Core daily control, one server, one dashboard, wallpaper, standard notifications, and standard single-item widgets remain free. Plus gates creation of additional dashboards, adding additional servers, Homestead iCloud synchronization, Sensor Boards, and advanced Sensor widget presentations.

Entitlement loss never deletes configuration. Existing dashboards and servers remain usable, iCloud retains its enabled intent while pausing reads and writes, and premium widgets retain configuration while showing a Plus-required deep link. The main app verifies StoreKit transactions and publishes a short-lived app-group cache for extensions.

## Consequences

- App Store Connect owns production pricing, localization, trials, Family Sharing, and offer codes.
- Homestead does not require RevenueCat, a custom account, or a receipt server for v1.
- Hosted features with recurring marginal cost require a future entitlement and server-validation decision.
- Family Sharing is intended for every Plus product and cannot be disabled after it is enabled in App Store Connect.
