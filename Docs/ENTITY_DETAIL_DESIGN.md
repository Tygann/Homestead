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
- Use the entity friendly name for navigation and a singular domain/device category in the hero. Identity-first domains such as Person may use a contact-style identity header instead of a category card.
- Omit normal badges such as `Live`, `Ready`, `Normal`, `On`, and `Off`. Show a badge only for an actionable mode, warning, unavailable state, failure, or in-flight update.
- Preserve last-known content while refreshing or pending. Disable only affected controls.
- Unsupported capabilities are omitted. Unavailable and failed capabilities remain understandable and recoverable.
- Loading placeholders should match the expected information density. Preserve last-known content when available, and do not reserve chart-sized space for a compact empty or unavailable result. Cancellation is not an error.
- Pushed phone details reserve bottom scroll clearance above floating tab/search chrome. Sheets rely on their own safe area.
- Dynamic Type may expand cards vertically; never depend on fixed text height or color alone.
- Freshness uses one concise, localized-scale unit (`just now`, minutes, hours, or days) so it stays secondary and remains readable at larger text sizes.
- Long metadata such as provider attribution uses a stacked label/value row instead of compressing the value into a trailing column.

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
| Information/content | weather, calendar, todo, update, person, device tracker | environment/activity/status | domain content, relationships, activity |
| Generic | unknown domains | status | server-advertised actions, activity |

`EntityCapabilityProfile` is the surface-neutral source for these families, hero kinds, routes, and semantic capabilities. Dashboard and detail surfaces adapt the profile without sharing layout-specific presentation types.

`EntityDetailFeatureProvider` is the detail-surface availability layer. It combines the semantic profile with the mapped state actually present for an entity and exposes only features Homestead can render correctly today. Domain views remain typed and own section ordering; the provider does not generate or type-erase their layouts.

## Dashboard Entry And Editing

- `EntityDetailDestination` is the surface-neutral navigation contract. It carries the stable entity ID, an optional initial section, optional transition identity, and an optional `{dashboardID, itemID}` reference when a specific dashboard card initiated navigation.
- Entity state, controls, history, activity, media, and Home Assistant context remain canonical regardless of which card opened the detail. Card size, display-name/icon overrides, Gauge zones, Chart range, and other dashboard customization never redefine entity-detail content.
- Card presentation may choose only the initial canonical section. Chart opens History with its configured starting range; other current card families open Overview.
- Details use `EntityDetailPresentationModel`, derived from mapped entity state and capability metadata. They must not construct `DashboardEntityPresentation`.
- A dashboard-origin detail exposes a direct pencil action for its exact card. Edit Card stages a local draft with Cancel/Done semantics, keeps name and icon editing in one card-independent Appearance section, renders the production card as a size-faithful non-interactive preview, uses in-sheet navigation for entity and richer Gauge configuration, and applies one exact-reference update only after confirmation. Long press remains an optional dashboard shortcut.
- Browse, Areas, Summary, and management hierarchies push canonical details. Widget or external launches may create a self-contained navigation sheet when no existing hierarchy is available.
- Stale card references must not invalidate the entity detail. Editing becomes unavailable while the canonical detail remains usable.

## History Semantics

- Continuous numeric detail history uses 6H, 24H, 7D, and 30D. Dashboard Chart cards may persist a focused 1H, 6H, 24H, or 7D range independently; 6H remains the default.
- Discrete recent activity keeps 1H, 6H, and 24H.
- Gauges use the meaningful absolute scale of a bounded measurement; battery is 0–100.
- History charts use a padded sample-adaptive domain constrained by any trustworthy absolute bounds. This preserves meaningful variation without implying values outside the entity's valid range.
- Unbounded measurements use the same padded sample-adaptive domain without absolute clamping.
- App-facing sensor semantics choose Catmull-Rom interpolation for naturally continuous measurements and linear interpolation for totals, bounded/step-like values, and ambiguous sensors. The mapped history samples remain the statistical and accessibility source of truth.
- Charts preserve extrema and mapped display precision when sampling, expose an accessibility chart descriptor, use range-appropriate natural time ticks, and only mention partial coverage when the returned samples demonstrably begin after the requested interval. Expanded charts support direct touch scrubbing with a selected rule, point, value, timestamp, and range statistics.
- Numeric domains reuse `EntityNumericHistoryPanel`; sensors and editable Number entities currently opt in with their mapped unit and meaningful bounded range.
- A dashboard Chart card opens a chart-first Sensor detail with a compact current/selected reading instead of a gauge. Gauge cards and neutral entity entry points retain the overview composition. A configured Chart remains a history surface when the current Home Assistant state is temporarily unavailable.
- Discrete domains reuse the self-loading `EntityActivityPanel`, which owns range selection, cancellation, retry, and either documented state history or Automation trace loading.
- Never fall back to generic binary-sensor language for an unmapped activity domain. Omit Activity until its states or event source have an explicit semantic mapping.

## Adaptive and Reference Behavior

- The shared scaffold constrains readable content width on regular-width devices while preserving the single-column section order used on iPhone.
- Hero identity and exceptional status reflow vertically when horizontal space or Dynamic Type requires it.
- The Debug reference gallery renders real detail compositions for Metric, Position, Climate, Weather, Presence, Number, Text, and Date & Time from deterministic fixtures across live, loading, empty, pending, unavailable, stale, failed, minimum, maximum, and long-content variants. Async history and forecast fixtures must not contact the sample Home Assistant URL.
- Launch the gallery directly with `--preview-screen entity-details` for simulator and browser-mirror review without onboarding or live-server dependencies. Add `--preview-detail-family <value>` and `--preview-detail-state <value>` to launch a specific matrix cell without manual picker interaction.
- Treat the reference gallery as a state matrix, not a substitute for device verification. New domain families should add representative fixtures before introducing a new visual grammar.
- A visually complete detail-view change includes a rendered simulator pass of its representative fixture and relevant loading/empty state. A successful compile alone is a draft-quality verification for visual work.
- Weather forecast cards keep readable system text, snap one item at a time when horizontally scrolled, and may use compact degree-only visual temperatures while retaining full-unit accessibility values.

## Adding a Domain

1. Add or confirm the mapped app-facing entity model and service intents.
2. Assign the domain to an `EntityCapabilityProfile` family, hero kind, route, and capability set.
3. Prefer an existing family composition. Add a specialized view only when the domain requires materially different content or controls.
4. Reuse `EntityDetailScaffold`, `EntityDetailHeroCard`/`EntityDetailHeader`, `EntityDetailSection`, shared controls, history/activity, and metadata disclosure.
5. Add deterministic preview fixtures for minimum, maximum, pending, unavailable, and representative live states.
6. Verify light/dark appearance, compact/regular width, Dynamic Type, and VoiceOver labels.

Avoid a type-erased universal section schema. Typed SwiftUI domain views remain the appropriate place for rich domain-specific composition.

Editable Number details consume `NumberEntity` for current value, bounds, step, unit, and Home Assistant display mode. SwiftUI must not read the raw entity attributes to reconstruct those constraints.

Person and Device Tracker details share the typed Presence composition. Person uses a quiet contact-style identity header that prioritizes authenticated imagery or the mapped entity icon plus Home/Away/named-zone state, without repeating a `Person` category card. Location source, tracking method, accuracy, battery, device context, and navigable person/tracker relationships are consolidated into one supporting section when available. Registry area assignment must not be presented as live physical location. Presence remains read-only and uses discrete Recent Activity ranges; loading, empty, and failed activity results remain compact until actual events need the timeline footprint.
