# ADR 2: Capability-Driven Entity Detail Grammar

## Status

Accepted

## Context

Entity details grew as domain-specific screens. Repeating one universal layout made specialized controls awkward, while independently designed screens drifted in navigation, hierarchy, status semantics, safe-area behavior, and metadata placement. Dashboard-named capability metadata also became an inappropriate routing dependency for non-dashboard surfaces.

## Decision

Homestead uses one entity-detail grammar rather than one universal layout. Navigation titles, hero semantics, section order, grouped surfaces, operational states, touch targets, bottom clearance, history periods, and final Entity Details placement are shared. Domain families retain typed compositions for their distinct controls and content.

`EntityCapabilityProfile` is the surface-neutral registry for domain family, hero kind, detail route, and semantic capabilities. Entity detail routing reads it directly. Dashboard presentation adapts its route to the legacy dashboard detail kind while dashboard-only card styling, status formatting, and actions remain surface-owned.

Rich domain views compose reusable capability components. Homestead will not introduce an `AnyView`-driven mega-schema for all possible sections.

## Consequences

- New Home Assistant domains can usually join an existing family before requiring a new screen architecture.
- Dashboard and detail surfaces share capability truth without sharing visual layout.
- Some domain screens remain intentionally different, but deviations occur after the shared hero/order/state contract.
- Preview fixtures and focused profile tests become part of extending domain coverage.
- Legacy helper names may remain as compatibility adapters while call sites migrate; they must delegate to the shared primitives.
