# Entity Detail Design Contract

Entity details share one native iOS grammar while retaining domain-specific controls and information. This document is the end-state contract for new and existing Home Assistant domains.

## Screen Anatomy

Every detail screen uses this order when the corresponding content exists:

1. Navigation title: the entity's friendly name.
2. Hero: category, freshness, exceptional status, and the current value, state, progress, environment, media, or activity.
3. Controls: every writable capability outside the hero, consolidated into one grouped surface with internal labels and dividers.
4. Domain content: weather data, automation logic, media, or supporting measurements.
5. History: a capability-driven inline chart or timeline with consistent range selection and progressive disclosure.
6. Entity Details: diagnostics and Home Assistant metadata, always last.

Do not repeat the same current state in the hero and a separate read-only section. A control may repeat its editable value when the repeated value is necessary to operate that control.

## Shared Visual and Behavioral Rules

- Use grouped system surfaces, semantic colors, SF Symbols, shared spacing/radius tokens, and at least 44-point interactive targets.
- Keep content cards opaque and inexpensive. Reserve system material or glass treatment for navigation and control chrome supplied by iOS.
- Use the entity friendly name for navigation and a singular domain/device category in the hero. Identity-first domains such as Person may use a contact-style identity header instead of a category card.
- The hero contains identity plus at most one trailing current readout or one primary control. Persistent binary capabilities such as light, switch, fan power, and automation enablement use a native toggle; momentary actions such as Run, Activate, and Press use a compact system-bordered button. Multi-action and security-sensitive capabilities retain explicit labeled action sections and confirmation behavior.
- Keep every writable capability outside the hero in one `Controls` section immediately after the hero. Brightness, position, temperature setpoints, modes, presets, playback, and access controls use internal labels and dividers rather than separate peer cards.
- Omit normal badges such as `Live`, `Ready`, `Normal`, `On`, and `Off`. Advisory numeric states use semantic icon/value color plus explicit accessibility text instead of a generic pill. Show a badge or message only when text adds actionable or exceptional meaning, such as unavailable, failed, stale, or in-flight state.
- Preserve last-known content while refreshing or pending. Disable only affected controls.
- Unsupported capabilities are omitted. Unavailable and failed capabilities remain understandable and recoverable.
- Loading placeholders should match the expected information density. Preserve last-known content when available, and do not reserve chart-sized space for a compact empty or unavailable result. Cancellation is not an error.
- Pushed phone details reserve bottom scroll clearance above floating tab/search chrome. Sheets rely on their own safe area.
- Dynamic Type may expand cards vertically; never depend on fixed text height or color alone.
- Freshness uses one concise, localized-scale unit (`just now`, minutes, hours, or days) so it stays secondary and remains readable at larger text sizes.
- Long metadata such as provider attribution uses a stacked label/value row instead of compressing the value into a trailing column.
- Use `History` as the universal label for numeric trends, state transitions, presence changes, and workflow runs. Keep native range selection and history content inline in the entity detail. Use compact menu rows for mutually exclusive settings such as HVAC mode, fan mode, and preset; reserve visible button groups for genuinely separate commands or per-action availability.
- Navigation rows use regular body-weight labels, accent-tinted SF Symbols, and disclosure indicators. `Entity Details` remains the final row and does not compete visually with operational content.

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
| Positional/security | cover, lock, valve, siren, alarm | trailing position or status | primary action, position/access, activity |
| Environmental | climate, humidifier, water heater | environment | temperature/level, mode, history |
| Media/visual | media player, camera, image | media | now playing/live media, playback/source |
| Autonomous appliance | vacuum, lawn mower | activity | start/stop, return, activity |
| Action/workflow | scene, script, automation, button | compact action or status | logic, activity |
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
- A dashboard-origin detail exposes a direct pencil action for its exact card. Edit Card stages a local draft with Cancel/Done semantics, leads with one unlabeled size-faithful non-interactive production preview, keeps Name, Icon, Entity, Size, and capability-specific configuration in the same form, and applies one exact-reference update only after confirmation. Gauge Scale and expandable Zone rows edit the draft inline without adding a second preview or save boundary. Long press remains an optional dashboard shortcut.
- Browse, Areas, Summary, and management hierarchies push canonical details. Widget or external launches may create a self-contained navigation sheet when no existing hierarchy is available.
- Stale card references must not invalidate the entity detail. Editing becomes unavailable while the canonical detail remains usable.

## History Semantics

- Continuous numeric detail history uses 6H, 24H, 7D, and 30D. Dashboard Chart cards may persist a focused 1H, 6H, 24H, or 7D range independently; 6H remains the default.
- Discrete History uses the same inline 6H, 24H, 7D, and 30D ranges. Range changes refresh automatically; manual refresh chrome stays out of the normal state and a labeled Retry appears only after failure.
- Timelines initially show eight entries. A clear `Show 20 More` footer expands long results in bounded batches and reports the remaining count; local expansion resets when the detail is reopened or its range changes. Numeric History keeps its complete canonical chart inline.
- Gauges use the meaningful absolute scale of a bounded measurement; battery is 0–100.
- Canonical Sensor details use one compact trailing current value in the identity hero. Gauge instruments and progress bars remain dashboard/widget presentation choices rather than being repeated beside History.
- Numeric thresholds tint the hero icon and value while retaining their semantic status in accessibility output. They do not add a generic visual status pill when the value itself already communicates the condition.
- History charts use a padded sample-adaptive domain constrained by any trustworthy absolute bounds. This preserves meaningful variation without implying values outside the entity's valid range.
- Unbounded measurements use the same padded sample-adaptive domain without absolute clamping.
- App-facing sensor semantics choose Catmull-Rom interpolation for naturally continuous measurements and linear interpolation for totals, bounded/step-like values, and ambiguous sensors. The mapped history samples remain the statistical and accessibility source of truth.
- Charts preserve extrema and mapped display precision when sampling, expose an accessibility chart descriptor, use range-appropriate natural time ticks, and only mention partial coverage when the returned samples demonstrably begin after the requested interval. Canonical charts share one detail height and support direct touch scrubbing with a selected rule, point, value, timestamp, and range statistics.
- Keep one visible Min/Average/Max summary. Touch selection presents its historical value and timestamp locally over the chart; the chart footer appears only for meaningful partial-coverage context.
- Numeric domains reuse the inline `EntityNumericHistoryPanel`; sensors and editable Number entities currently opt in with their mapped unit and meaningful bounded range.
- Chart, Gauge, and neutral entry points open the same canonical Sensor composition. A Chart card may provide the initial History range, and remains a history surface when the current Home Assistant state is temporarily unavailable, but card presentation does not change hero content, chart height, or detail sections.
- Discrete domains reuse `EntityActivityPreview` and the self-loading `EntityActivityPanel`, which own cancellation, retry, full-range selection, and either Home Assistant state history or Automation trace loading.
- Omit History when Home Assistant does not provide data Homestead can present honestly; consistency means shared placement and behavior, not an empty section on every domain.

## Adaptive and Reference Behavior

- The shared scaffold constrains readable content width on regular-width devices while preserving the single-column section order used on iPhone.
- Hero identity and exceptional status reflow vertically when horizontal space or Dynamic Type requires it.
- The Debug reference gallery renders real detail compositions for Simple Control, Momentary Action, Metric, Chart, Position, Climate, Weather, Presence, Number, Text, and Date & Time from deterministic fixtures across live, loading, empty, pending, unavailable, stale, failed, minimum, maximum, and long-content variants. Async history and forecast fixtures must not contact the sample Home Assistant URL.
- Launch the gallery directly with `--preview-screen entity-details` for simulator and browser-mirror review without onboarding or live-server dependencies. Add `--preview-detail-family <value>` and `--preview-detail-state <value>` to launch a specific matrix cell without manual picker interaction.
- Treat the reference gallery as a state matrix, not a substitute for device verification. New domain families should add representative fixtures before introducing a new visual grammar.
- A visually complete detail-view change includes a rendered simulator pass of its representative fixture and relevant loading/empty state. A successful compile alone is a draft-quality verification for visual work.
- Weather forecast cards keep readable system text, snap one item at a time when horizontally scrolled, and may use compact degree-only visual temperatures while retaining full-unit accessibility values.
- Weather details keep only the current temperature as the trailing hero readout. Condition, humidity, and wind live in a compact `Conditions` section before Forecast, and provider attribution remains quiet footer context. Daily Forecast uses native row hierarchy with a shared-scale low/high temperature range bar; Hourly uses one continuous horizontal strip rather than nested cards.

## Adding a Domain

1. Add or confirm the mapped app-facing entity model and service intents.
2. Assign the domain to an `EntityCapabilityProfile` family, hero kind, route, and capability set.
3. Prefer an existing family composition. Add a specialized view only when the domain requires materially different content or controls.
4. Reuse `EntityDetailScaffold`, `EntityDetailHeroCard`/`EntityDetailHeader`, `EntityDetailSection`, shared controls, history/activity, and metadata disclosure.
5. Add deterministic preview fixtures for minimum, maximum, pending, unavailable, and representative live states.
6. Verify light/dark appearance, compact/regular width, Dynamic Type, and VoiceOver labels.

Avoid a type-erased universal section schema. Typed SwiftUI domain views remain the appropriate place for rich domain-specific composition.

Editable Number details consume `NumberEntity` for current value, bounds, step, unit, and Home Assistant display mode. SwiftUI must not read the raw entity attributes to reconstruct those constraints.

Person uses one canonical native Form composition shared by Settings > People and every entity-detail entry point. It prioritizes authenticated imagery or the mapped entity icon plus Home/Away/named-zone state, exposes compact Details and Context rows, keeps trackers navigable, shows the same inline ranged History and progressive disclosure as other discrete domains, and ends with the shared Entity Details diagnostics navigation instead of exposing raw Home Assistant metadata inline. Device Tracker retains its tracker-oriented detail while reusing the same mapped presence records and relationships. Registry area assignment must not be presented as live physical location. Presence remains read-only; loading, empty, and failed History results stay compact until actual events need the timeline footprint.
