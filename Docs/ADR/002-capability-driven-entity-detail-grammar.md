# ADR 2: Capability-Driven Entity Detail Grammar

## Status

Accepted

## Context

Entity details grew as domain-specific screens. Repeating one universal layout made specialized controls awkward, while independently designed screens drifted in navigation, hierarchy, status semantics, safe-area behavior, and metadata placement. Dashboard-named capability metadata also became an inappropriate routing dependency for non-dashboard surfaces.

## Decision

Homestead uses one entity-detail grammar rather than one universal layout. Navigation titles, hero semantics, section order, grouped surfaces, operational states, touch targets, bottom clearance, history periods, and final Entity Details placement are shared. Domain families retain typed compositions for their distinct controls and content.

`EntityCapabilityProfile` is the surface-neutral registry for domain family, hero kind, detail route, and semantic capabilities. Entity detail routing reads it directly. `EntityDetailDestination` carries stable entity identity and an optional canonical initial section without introducing card-type routes. Dashboard-only card styling, status formatting, actions, and configuration remain surface-owned.

When a dashboard card initiates navigation, the destination may retain an exact `{dashboardID, itemID}` reference solely to expose contextual card editing. This reference never changes canonical entity presentation. Detail families consume `EntityDetailPresentationModel`; they do not construct `DashboardEntityPresentation`.

Rich domain views compose reusable capability components. Homestead will not introduce an `AnyView`-driven mega-schema for all possible sections.

## Consequences

- New Home Assistant domains can usually join an existing family before requiring a new screen architecture.
- Dashboard and detail surfaces share capability truth without sharing visual layout.
- Different cards for the same entity open the same detail implementation; Chart may initially focus History while other current card families open Overview.
- Dashboard-origin details can edit the originating card without making dashboard customization part of Home Assistant entity state.
- Some domain screens remain intentionally different, but deviations occur after the shared hero/order/state contract.
- Preview fixtures and focused profile tests become part of extending domain coverage.
