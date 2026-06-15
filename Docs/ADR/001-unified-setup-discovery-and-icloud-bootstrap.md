# ADR 1: Unified Setup, Discovery, and iCloud Bootstrap

## Status

Accepted

## Context

URL-first onboarding made the sign-in address and optional connection routes unclear. Startup also allowed default dashboard seeding and iCloud uploads before a new device had downloaded existing preferences, which could replace a configured device's dashboard with defaults.

## Decision

Homestead performs a read-only iCloud bootstrap before authentication, cache loading, connection, dashboard seeding, or preference uploads. A clean device explicitly offers an iCloud restore, then completes OAuth with device-local credentials. Declining restore leaves the cloud payload intact.

When no restore is chosen, setup offers user-initiated Bonjour discovery for `_home-assistant._tcp.local.` and one manual Home Assistant address as fallback. Advertised external and internal URLs become user-facing connection metadata. Homestead keeps an OAuth/server-identity anchor internally, selecting the remote URL when available and otherwise the local URL, but does not present it as a third Home Assistant setting. Server settings use staged toolbar editing so Cancel cannot partially change a live connection.

Local routing is optional and explicit. When a Remote Address exists, Homestead prefers the Local Address only if the current Wi-Fi name matches one of the saved local-network names. If the current Wi-Fi name is unavailable, permission is denied, or the current network is not saved, Homestead starts with the Remote Address. The legacy home-network-name value migrates to the saved Wi-Fi list for existing local preferences.

iCloud key-value storage remains appropriate for the small payload. Version 2 timestamps connection, dashboard, action-confirmation, and appearance sections independently, identifies the source device, merges remote changes by section, and requires explicit resolution before replacing differing local preferences or an active server identity.

## Consequences

- OAuth credentials, tokens, caches, widgets, mobile-app secrets, and wallpaper files remain device-local.
- Enabled sync is automatic and debounced; Sync Now is a two-way merge and recovery action.
- Local Network permission appears only after Find Home Assistant is selected.
- Reading the current Wi-Fi name requires Location permission and the Wi-Fi Information entitlement, so production signing must keep that capability enabled.
- Mac Designed for iPad uses the same adaptive setup flow.
- Bonjour permission denial, delayed iCloud delivery, OAuth handoff, Wi-Fi-name detection, window resizing, and Mac widget availability still require manual device testing.
