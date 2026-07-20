# Entity Detail Design Contract

Entity details share one native iOS grammar while retaining domain-specific controls and information. This document is the end-state contract for new and existing Home Assistant domains.

## Screen Anatomy

Every detail screen uses this order when the corresponding content exists:

1. Navigation title: the entity's friendly name.
2. Hero: category, freshness, exceptional status, and the current value, state, progress, environment, media, or activity.
3. Primary interaction: the most common control or action.
4. Secondary capabilities: level, position, modes, presets, source, or other typed controls.
5. Insights or domain content: weather data, automation logic, media, or supporting measurements.
6. History or recent activity.
7. Entity Details: diagnostics and Home Assistant metadata, always last.

Do not repeat the same current state in the hero and a separate read-only section. A control may repeat its editable value when the repeated value is necessary to operate that control.

## Shared Visual and Behavioral Rules

- Use grouped system surfaces, semantic colors, SF Symbols, shared spacing/radius tokens, and at least 44-point interactive targets.
- Keep content cards opaque and inexpensive. Reserve system material or glass treatment for navigation and control chrome supplied by iOS.
- Use the entity friendly name for navigation and a singular domain/device category in the hero.
- Omit normal badges such as `Live`, `Ready`, `Normal`, `On`, and `Off`. Show a badge only for an actionable mode, warning, unavailable state, failure, or in-flight update.
- Preserve last-known content while refreshing or pending. Disable only affected controls.
- Unsupported capabilities are omitted. Unavailable and failed capabilities remain understandable and recoverable.
- Loading placeholders keep the final section footprint stable. Cancellation is not an error.
- Pushed phone details reserve bottom scroll clearance above floating tab/search chrome. Sheets rely on their own safe area.
- Dynamic Type may expand cards vertically; never depend on fixed text height or color alone.

## Operational States

The shared state vocabulary is:

- `live`: current Home Assistant state; no badge by default.
- `pending`: a command awaits Home Assistant confirmation; preserve last-known data and show `Updating`.
- `stale`: cached or old data remains visible with freshness context.
- `unavailable`: the entity cannot currently report or act; show `Unavailable` and disable affected controls.
- `failed`: an attempted refresh or action failed; keep content and expose a concise retry when possible.
- `unsupported`: omit the capability or section.

Home Assistant remains the source of truth. Detail views observe `HAEntityState` and issue intents through `HomeAssistantService`; they do not decode transport DTOs.

`EntityDetailStatePresentation` is the single presentation resolver for this vocabulary. It derives state from entity availability, the entity's pending command, connection/data freshness, and entity-scoped service feedback. Domain views consume the result for their hero and control availability rather than reinterpreting transport or connection state independently. Unavailable takes precedence over pending, then a matching action failure, then stale data, then live.

## Family Grammar

| Family | Typical domains | Hero | Typical sections |
| --- | --- | --- | --- |
| Metric | sensor, binary sensor, air quality | metric or status | history or activity |
| Simple control | light, switch, fan, remote | status | primary toggle, level, presets |
| Positional/security | cover, lock, valve, siren, alarm | progress or status | primary action, position/access, activity |
| Environmental | climate, humidifier, water heater | environment | temperature/level, mode, history |
| Media/visual | media player, camera, image | media | now playing/live media, playback/source |
| Autonomous appliance | vacuum, lawn mower | activity | start/stop, return, activity |
| Action/workflow | scene, script, automation, button | activity or status | action/control, logic, activity |
| Editable value | number, select, text, date/time | metric or status | native editor, constraints, history/activity |
| Information/content | weather, calendar, todo, update, person | environment/activity/status | domain content, activity |
| Generic | unknown domains | status | server-advertised actions, activity |

`EntityCapabilityProfile` is the surface-neutral source for these families, hero kinds, routes, and semantic capabilities. Dashboard and detail surfaces adapt the profile without sharing layout-specific presentation types.

## History Semantics

- Continuous numeric history uses 24H, 7D, and 30D.
- Discrete recent activity keeps 1H, 6H, and 24H.
- Bounded measurements use their meaningful fixed scale; battery is 0–100.
- Unbounded measurements use a padded dynamic domain.
- Continuous measurements use linear interpolation so the chart does not invent overshoot.
- Charts preserve extrema when sampling, expose an accessibility chart descriptor, and only mention partial coverage when the returned samples demonstrably begin after the requested interval.
- Numeric domains reuse `EntityNumericHistoryPanel`; sensors and editable Number entities currently opt in with their mapped unit and meaningful bounded range.

## Adaptive and Reference Behavior

- The shared scaffold constrains readable content width on regular-width devices while preserving the single-column section order used on iPhone.
- Hero identity and exceptional status reflow vertically when horizontal space or Dynamic Type requires it.
- The Debug reference gallery renders real detail compositions from deterministic fixtures across live, pending, unavailable, stale, failed, minimum, maximum, and long-content variants.
- Treat the reference gallery as a state matrix, not a substitute for device verification. New domain families should add representative fixtures before introducing a new visual grammar.

## Adding a Domain

1. Add or confirm the mapped app-facing entity model and service intents.
2. Assign the domain to an `EntityCapabilityProfile` family, hero kind, route, and capability set.
3. Prefer an existing family composition. Add a specialized view only when the domain requires materially different content or controls.
4. Reuse `EntityDetailScaffold`, `EntityDetailHeroCard`/`EntityDetailHeader`, `EntityDetailSection`, shared controls, history/activity, and metadata disclosure.
5. Add deterministic preview fixtures for minimum, maximum, pending, unavailable, and representative live states.
6. Verify light/dark appearance, compact/regular width, Dynamic Type, and VoiceOver labels.

Avoid a type-erased universal section schema. Typed SwiftUI domain views remain the appropriate place for rich domain-specific composition.
