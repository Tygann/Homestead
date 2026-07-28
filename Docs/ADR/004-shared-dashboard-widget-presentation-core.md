# ADR 4: Shared Dashboard And Widget Presentation Core

## Status

Accepted

## Context

Dashboard cards and WidgetKit render the same Home Assistant entities under different interaction, refresh, layout, and process constraints. Earlier implementations shared some visual primitives but retained parallel decisions for availability, active state, capability eligibility, number precision, gauge colors, entity identity, and server routing. Those decisions could drift, and raw widget entity IDs could be resolved against the wrong server after a profile change.

## Decision

Homestead uses a surface-neutral presentation core under `Shared/EntityPresentation` for:

- Server-scoped entity identity.
- Entity domains and capability profiles.
- Availability, semantic/active state, affordances, presentation eligibility, number precision, unit normalization, icons, and gauge-zone colors.

Dashboard code maps `HAEntityState` into this core and then adds live dashboard interaction and container behavior. Widget code receives compact, server-scoped snapshots, optionally refreshes through profile-scoped Home Assistant clients, and adapts the same semantics into WidgetKit timelines and families. Dashboard gauge resolution remains the authoritative producer of automatic gauge specifications; the serialized widget gauge model is a rendering/timeline adapter, and exact zone colors cross that boundary without remapping.

Widget kinds remain stable. Widget entity selections are encoded as `profile UUID + entity ID`; unscoped beta selections are intentionally invalid rather than silently adopting the active server. App Intent configuration remains native. Sensor Board retains flat, repeated App Intent declarations because WidgetKit cannot host an arbitrary custom editor in the system configuration sheet, but both sizes adapt those declarations into one slot model and one batched entry builder.

Entitlement policy never deletes configuration or snapshots. A locked premium widget renders the existing Plus restoration path until access returns.

## Consequences

- Semantic changes should be made in `Shared/EntityPresentation` and tested once before surface adapters change.
- Dashboard and widget top-level views remain deliberately separate.
- Widget timelines, app-group persistence, App Intents, margins, families, buttons, refresh policy, and failure presentation remain WidgetKit-owned.
- Dashboard navigation, live controls, editor drafts, history consumers, and card containers remain app-owned.
- Beta widgets with raw entity selections must have their entity reselected.
- Native Sensor Board configuration remains lengthy despite progressive disclosure. An in-app board editor could improve preview and bulk editing later, but would add a second configuration system and is not part of the current product.
