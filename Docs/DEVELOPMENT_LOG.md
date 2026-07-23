# Development Log

This is a short project memory log for future maintainers and coding agents. It should capture durable decisions and checkpoints, not every edit.

## 2026-07-23

### Thermostat Detail Instrument

- Replaced climate target rows at standard Dynamic Type sizes with a compact 240-degree thermostat instrument that keeps current temperature in the hero and editable setpoints in Controls.
- Single-target modes use one semantically tinted handle; Heat/Cool uses independently selectable blue low and warm high handles with a selected-span gradient, direct dragging, unified precision controls, and step haptics.
- Refined the thermostat readout and controls with degree-free visual setpoint values, one cohesive precision capsule, and an adaptive three-across Mode/Fan/Preset row; constrained widths fall back to the prior stacked composition and accessibility sizes retain native rows with complete temperature units.
- Preserved Home Assistant service, clamping, optimistic-update, and pending-state behavior; accessibility sizes retain the native row composition, while every handle exposes a labeled adjustable value.
- Expanded the deterministic Climate reference fixture to cover the more demanding Heat/Cool range and verified light, dark, pending, unavailable, direct manipulation, and accessibility-size behavior.

## 2026-07-22

### Inline History And Native Control Rows

- Returned History ranges and content to the entity detail, with eight initial discrete entries, compact total/hidden-count disclosure, and view-local Show All state that resets when the detail or range changes.
- Flattened secondary controls into native rows within the single Controls surface, removing nested section-like labels and backgrounds from position, brightness, speed, climate options, media source, and alarm actions.
- Renamed Weather supporting context to Conditions and rebuilt Daily/Hourly Forecast presentation around the same shared-scale temperature-range bar used by the large dashboard Weather card.
- Tightened the combined forecast hierarchy with compact flush-leading Hourly content, localized hour-only labels and denser columns, no redundant interval subtitles, Today labeling, a current-temperature range marker, and one retry state when all supported forecast subscriptions fail.

### Entity Detail Controls And History Contract

- Consolidated writable capabilities outside each hero into one Controls surface, using dividers and compact sublabels for level, position, setpoint, mode, preset, playback, source, and access groups.
- Standardized numeric trends, state transitions, presence changes, and workflow runs on the visible title History. Main details show a compact 24-hour preview and Show All row; full destinations own 6H/24H/7D/30D range selection and expanded content.
- Expanded state-history previews to every capability profile that declares activity support, while retaining Automation traces and omitting unsupported or misleading History surfaces.
- Moved Weather condition, humidity, and wind into Current Conditions, aligned Person with the shared inline History pattern, and restyled Entity Details as a regular accent-tinted navigation row.

### Entity Detail Hero Contract

- Standardized heroes on identity plus one trailing current readout or primary control: Sensor, Cover, Climate, and Weather align their current values, while Script, Scene, and Button use a compact system-bordered action.
- Removed generic numeric warning pills while preserving semantic icon/value color and explicit VoiceOver status; exceptional connection, availability, pending, and failure states continue through the shared state presentation.
- Consolidated Climate HVAC mode into the first Options menu beside Fan and Preset, kept temperature/brightness/position precision controls in dedicated first sections, and retained explicit Cover Open/Close/Stop commands.
- Replaced Person's inline Home Assistant metadata section with the same Entity Details diagnostics navigation used by other entity families while preserving the shared Settings > People Form.

### Canonical Entity Detail Composition

- Unified Person navigation and Settings > People on one native Form detail, preserving mapped presence data, operational state, tracker navigation, and a focused Recent Activity destination.
- Made Sensor details independent of their originating dashboard card: the hero now carries one compact current value without embedded gauge chrome, every numeric History uses one canonical height, and unlabeled latest-sample timestamps were removed in favor of local scrub context.
- Simplified Climate to current temperature in the hero, native granular target steppers, one authoritative Mode section, and secondary option menus; removed duplicated target and mode summaries.
- Moved Script, Scene, and Button momentary actions into compact labeled hero buttons, standardized Recent Activity on 6H/24H/7D/30D with failure-only Retry, and added a deterministic Momentary Action reference family.

### Entity Detail Hierarchy And Control Consistency

- Moved persistent binary controls for lights, switches, fans, and automations into the shared hero as independently accessible native toggles, removing redundant one-action Control cards while retaining explicit action groups for covers and other multi-action or security-sensitive domains.
- Standardized passive time-range selection on native segmented pickers, kept HVAC and preset service commands as capability-aware mode grids, and simplified numeric History to one neutral Min/Average/Max strip with local touch-selection feedback and a nonduplicated timestamp footer.
- Replaced the full Sensor detail gauge instrument with a large reading plus compact bounded-range bar, removed duplicate cover position progress when an editable slider exists, and consolidated Weather humidity/wind into its hero with quiet provider attribution below Forecast.
- Added a deterministic Light family to the entity-detail reference gallery so live, pending, unavailable, stale, failure, extrema, and long-content behavior remain inspectable through the existing preview route.

### Native Contextual Card Editor

- Replaced the one-item detail toolbar menu with a direct pencil action that opens the originating card editor in one tap.
- Reworked Edit Card around a local transactional draft: Cancel discards, Done applies the exact referenced card update once, and entity changes notify the still-open canonical detail only after the save succeeds.
- Separated card identity editing from rendering: one unlabeled proportional preview stage renders every production card non-interactively, while conventional Name, Icon, Entity, Size, and capability-specific rows own one transactional draft. Large now renders at its natural height and the same full width as Wide; Gauge Scale and expandable Zone controls are inline without a redundant second preview or save boundary. Size choices pair proportional artwork with one user-facing shape name instead of exposing grid dimensions; compact previews use tighter spacing, Done is change-aware, and removal says Remove from Dashboard. Removed editor hooks from Control, Status, Gauge, Chart, Camera, Weather, Media, and Action renderers, and made card-specific editor rows catalog capabilities.
- Polished the editor with standard labeled Name and Icon rows, balanced climate stepper columns for both single and dual setpoints, proportional custom size artwork in the picker, and a centered native destructive removal row. Extended deterministic editor fixtures across all implemented card families and retained the dual-setpoint thermostat fixture for transient-menu and light/dark inspection.
- Kept card-specific settings conditional, added atomic exact-reference update coverage, and visually verified the deterministic editor/detail routes in light and dark appearances.

## 2026-07-21

### Entity-First Details And Contextual Card Editing

- Replaced dashboard-specific detail kinds with one `EntityDetailDestination` carrying entity identity, canonical initial focus, transition identity, and an optional exact dashboard/item reference.
- Made capability routing the only detail implementation selector, moved Browse to push navigation, and separated canonical detail presentation from `DashboardEntityPresentation` across all detail families.
- Added a unified dashboard card editor reachable from dashboard-origin details, covering live preview, entity replacement, size, name, icon, Gauge/Chart settings, and removal while retaining long press as a shortcut.
- Added precise cross-dashboard item mutations and stale-reference handling so contextual editing cannot target the wrong saved dashboard when selection changes or item IDs collide.
- Added deterministic card-editor and contextual-detail preview routes plus focused route, presentation-boundary, and configuration tests.

### Recoverable Dashboard Schema Migrations

- Replaced exact-version-or-reset dashboard loading with ordered schema migrations shared by local, profile-scoped, Canvas preview, and iCloud persistence paths.
- Added the v5-to-v6 `.graph` to `.chart` migration while preserving dashboard identity, ordering, metadata, items, and selected-dashboard state.
- Added last-known-good document backups, rejected-payload quarantine, lossy card/dashboard recovery, and newer-schema write protection so one invalid record or a newer app payload cannot erase otherwise valid saved dashboards.
- Made iCloud snapshot application compatibility-aware and transactional across profile dashboard bundles; rejected payloads no longer advance the dashboard sync timestamp.
- Verified with a Simulator build, all 38 `DashboardConfigurationXCTests`, and guarded Xcode storage hygiene.

### Mixed Sensor Board Widget

- Made Chart canonical throughout the beta codebase: dashboard schema v6 persists `.chart`, the Sensor App Intent persists `.chart`, WidgetKit uses `HomesteadSensorChartWidget`, shared chart types and Sensor Board configuration use Chart naming, and Debug previews accept `chart`.
- Added a stable medium Sensor Board WidgetKit kind alongside the existing Gauge Grids, with two independently named compact sensor slots and one dedicated six-hour numeric chart.
- Generalized Sensor Board into three equal interchangeable slots whose App Intent display choice dynamically reveals a compatible Sensor or numeric Chart Sensor picker; retained Automatic / Automatic / Chart defaults and the original third-slot chart parameter identities for configured-widget continuity.
- Aligned the single Sensor Chart widget with the dashboard Chart card composition, then gave Sensor Board a dedicated compact density so its chart keeps the shared Swift Charts rendering while balancing its plot, typography, latest-sample emphasis, and six-hour context against neighboring gauges.
- Compact slots support Automatic, Gauge, or Reading presentation; Automatic prefers mapped gauge metadata, and explicit Gauge safely falls back to Reading when the sensor is not gauge-capable.
- Restricted the chart picker to numeric sensor snapshots, reused documented Home Assistant REST history and live WebSocket state refresh, deep-linked every configured region, and kept the rendered face shared with the deterministic widget preview.
- Replaced the Sensor Board's initial boxed path sparkline with the same shared Swift Charts plot used by dashboard Chart cards, including stabilized value domains, protected headroom, gradient fill, and sensor-semantic smooth or linear interpolation persisted into widget snapshots.
- Verified the medium mixed layout in dark and light Simulator appearances plus focused Sensor Board, shared catalog, and Gauge Grid tests.

### Durable Live Preview Dashboards

- Moved `Live Home Assistant` dashboard definitions from the ordinary Canvas-local defaults suite into Homestead's existing App Group while retaining per-server profile keys and keeping normal app dashboards isolated.
- Added one-way migration that preserves existing App Group values, plus an optional ignored `PreviewDashboardLayout.json` seed that restores only missing dashboard configuration and selection keys.
- Added `Scripts/export_live_preview_dashboard.sh` to create the filtered backup from a simulator App Group without including Home Assistant credentials, URLs, widget state, or unrelated settings.
- Verified migration, backup restore, non-overwrite behavior, and unrelated-key rejection with focused tests, then confirmed a real Debug live-preview launch writes the expected profile-scoped App Group keys.

## 2026-07-20

### Chart Detail And Range Configuration

- Made dashboard Chart entry presentation-aware: Chart cards open a chart-first Sensor detail, while gauge cards and neutral routes retain the bounded gauge overview.
- Expanded numeric detail history to 6H, 24H, 7D, and 30D with time-weighted Min/Average/Max statistics, mapped display precision, semantic interpolation, and native Swift Charts touch selection that updates the compact reading hero with the selected value and timestamp.
- Added independent persisted Chart Settings for 1H, 6H, 24H, and 7D dashboard ranges, kept 6H as the migration-safe default, and preserved history access when the current Home Assistant reading is unavailable.
- Kept one-year history out of this pass because the documented raw-history endpoint is not an appropriate long-term statistics transport.
- Verified standard, compact-width, unavailable, failure, loading, and accessibility-size presentations in Simulator, then confirmed real Home Assistant history loading and touch scrubbing against the configured living-room temperature sensor.

### In-Place Dashboard Entity Replacement

- Added Change Entity to entity-card edit menus with a searchable compatible-only picker, current selection state, production-renderer preview, and explicit confirmation.
- Kept replacement atomic in `DashboardConfiguration`: card identity, order, presentation kind, layout, display-name override, and icon override remain unchanged while only the entity source changes.
- Preserved custom gauge zones only when the replacement sensor has the same normalized device class and unit; incompatible measurement semantics reset the zones and are explained before Save.
- Added a deterministic `--preview-screen dashboard-change-entity` route and verified initial and gauge-reset states in dark and light appearance, plus all 30 focused dashboard configuration tests.

### Repeatable Dashboard Entity Presentations

- Changed the dashboard item contract so an entity is a reusable data source and every add creates a new independently editable presentation, including repeated card kinds and layouts.
- Preserved repeated entity items through dashboard normalization, persistence, and iCloud snapshot application while retaining single-instance semantics for dashboard-wide summary chips.
- Replaced disabled matching entity actions with compact `On Dashboard` counts and enabled `Add Another` controls; summary-chip add actions still resolve to their existing instance.
- Verified with a Debug iPhone 17 build, all 27 `DashboardConfigurationXCTests`, guarded Xcode storage hygiene, and live Add to Dashboard inspection through the simulator browser mirror.

### Dashboard Card Completion

- Replaced the generic Chart, Weather, Media, and Action card treatments with focused typed compositions that preserve the shared dashboard shell while making each family useful at a glance.
- Followed with dedicated visual and legibility passes that standardized Chart naming across user-facing surfaces and the persisted `.chart` schema, made new Chart recommendations Wide by default, and gave Weather condition-responsive backgrounds with distinct Square current-condition, Wide hourly, and Large hourly-plus-daily layouts.
- Chart cards now reserve separate text and plot regions, split value/unit typography, use stabilized unit-aware visual ranges plus truthful linear interpolation, expose low/high/change context, extend loaded history with newer live state, retain recorded history when the current entity becomes unavailable, and provide an accessible audio-graph descriptor.
- Weather cards now apply a contrast-preserving scrim, use compact `Now`/hour labels without shrinking below the intended system text style, adapt forecast count to width and Dynamic Type, preserve the last forecast during refresh failures, and progressively remove secondary forecast content when fixed card geometry cannot hold it legibly.
- Weather forecast selection now adapts to card size from the existing entity-scoped hourly, daily, and twice-daily snapshots; compact visual temperatures omit the redundant scale letter while accessibility and detail surfaces retain the full configured unit.
- Chart cards now foreground the current reading and render a deterministic, legible six-hour linear trend; Weather cards retain shared forecast subscriptions and show adaptive multi-period high/low forecasts; Media cards expose now-playing context, play/pause, volume, and source controls where space permits; Action cards expose explicit Scene, Script, and Button triggers.
- Added consumer-aware Weather forecast subscription ownership so a dashboard card and an open detail view can share the official `weather/subscribe_forecast` stream without tearing each other down.
- Added the deterministic `--preview-screen dashboard-cards` gallery plus live `--preview-presentation` targeting, capped fixed dashboard-card typography at Extra Extra Extra Large, and verified compact/square/wide/large layouts in light/dark Simulator and the in-app browser mirror.
- Verified the new renderers against real Home Assistant Weather, numeric Sensor history, Media Player, and Script entities while keeping the existing WebSocket service and documented history contracts intact.

### Entity Detail Final Verification

- Completed the Simulator and in-app browser matrix pass for representative, loading, empty, pending, stale, failed, unavailable, compact-width, and accessibility Dynamic Type states across the entity-detail grammar.
- Expanded the deterministic gallery to cover Number, Text, and Date & Time, added direct family/state launch arguments, supplied deterministic async history/forecast fixtures, and corrected Weather's fixture to advertise the official forecast subscription capabilities instead of embedding legacy forecast attributes.
- Fixed helper-only preview overrides being discarded, made gallery controls reflow at accessibility sizes, and fixed Date & Time Save becoming enabled after programmatic draft synchronization.
- Verified one configured live Home Assistant server end to end with real Weather daily/hourly forecasts and an editable Number helper. A second configured preview credential was rejected by that server and was not used for live verification.
- Added forecast subscription lifecycle coverage, passed the focused capability, mapping, routing, service-contract, activity, and state-store tests, and retained screenshot/browser inspection as the Xcode 27 fallback when semantic snapshots could not load the relocated SimulatorKit framework.

### Codex Desktop Development Workflow

- Established Codex desktop as Homestead's primary agentic development surface, with Xcode, Simulator, terminal sessions, and the in-app browser used as supporting tools rather than assuming a VS Code-hosted workflow.
- Standardized the implementation loop around XcodeBuildMCP session defaults, early compilation, deterministic Debug launch routes, a simulator-UDID-scoped `serve-sim` mirror, rendered visual verification, focused tests, storage hygiene, and focused commits.
- Added trusted project Codex defaults that automatically enable Build iOS Apps and bound local multi-agent fan-out; reasoning effort remains user- and task-controlled so the composer can select the appropriate level before the first message. Added a repo-owned verification skill plus automatic read-heavy delegation and final-review rules so ordinary requests no longer need repeated tooling, test, visual-QA, hygiene, or commit instructions.
- Kept ignored Home Assistant preview credentials out of managed worktrees by default; deterministic preview routes remain worktree-safe while live server verification stays in Local unless credential copying is explicitly approved.
- Documented the Xcode 27 beta semantic-snapshot compatibility boundary and retained screenshots/browser inspection as the safe fallback without modifying the signed Xcode bundle.

### Native Presence Entity Details

- Routed Person and Device Tracker entities into one typed, read-only Presence detail composition while retaining the Information/content family grammar and dashboard's stable generic-detail adapter identity.
- Reused the existing registry-aware `HAPresenceRecord` and authenticated avatar loader for Home/Away/named-zone state, source tracker/person relationships, tracking method, accuracy, device context, shared Recent Activity, exceptional operational state, and final diagnostics.
- Accepted both legacy `gps_accuracy` and current `location_accuracy` tracker metadata plus the current `tracking_type` fallback, keeping all Home Assistant DTO interpretation below SwiftUI.
- Replaced the dashboard-like Person hero and fragmented one-row cards with a contact-style identity header and one consolidated Location Source section; compact loading and unavailable activity states no longer reserve an empty chart footprint.
- Added Presence to the deterministic entity-detail gallery and exposed it through `--preview-screen entity-details`. Built and rendered the route on iPhone 17 (iOS 26.5), inspected both activity transitions through the in-app simulator mirror, and passed the focused presence mapping and capability-profile tests.

### Editable Value Entity Details

- Extended the capability-driven detail grammar with native constrained-text and date/time editors while preserving the shared scaffold, hero, operational-state, confirmation, and diagnostics contracts.
- Normalized `input_number`, `input_text`, and `input_datetime` into the same app-facing families as their native counterparts, while service helpers retain Home Assistant's exact helper domains and payload shapes.
- Added typed `TextEntity` and `TemporalEntity` models so SwiftUI does not consume raw Home Assistant attributes, including text length/pattern/mode constraints and date/time capability selection from `has_date` / `has_time`.

### Live Weather Forecasts

- Replaced legacy weather-state forecast availability with Home Assistant's dedicated `weather/subscribe_forecast` WebSocket subscription for server-advertised daily, twice-daily, and hourly modes.
- Kept transport DTOs in `Core/HomeAssistant`, mapped forecast entries into app-facing models, and stored live snapshots on `HAEntityState` so forecast updates invalidate only the open entity detail.
- Added an adaptive forecast section with explicit loading, empty, cached-stale, failure, and retry behavior; compact sizes use horizontally scrolling cards while accessibility Dynamic Type uses full-width rows.
- Scoped subscriptions to the presented Weather detail and connection lifecycle, preserving the last successful snapshot across refresh failures while removing handlers on dismissal, disconnect, or server switching.

### Capability-Driven Entity Detail Grammar

- Adopted one shared detail grammar with typed domain-family composition instead of either identical screens or a type-erased universal section schema.
- Added a surface-neutral entity capability profile for family, hero, route, and semantic capability classification; detail routing now consumes it directly and dashboard routing adapts it.
- Standardized entity-name navigation, category/freshness heroes, exceptional-only status badges, grouped sections, final diagnostics, pending/unavailable behavior, and bottom chrome clearance across existing detail domains.
- Made Sensor, Cover, Climate, and Weather deterministic reference screens; added a debug gallery, meaningful bounded chart domains, linear history interpolation, partial-coverage messaging, and Audio Graph descriptors.
- Centralized live, pending, stale, unavailable, and entity-scoped failure presentation from existing `HAEntityState` and `HomeAssistantService` signals; detail controls now share the same interaction-blocking policy while keeping retryable failures actionable.
- Expanded the deterministic gallery into a family/state matrix, added regular-width content constraints and Dynamic Type reflow, and extracted reusable accessible numeric history for Sensor and Number details.
- Added a detail-surface feature provider so semantic domain capability no longer implies an unimplemented section; unsupported activity domains are omitted instead of receiving binary-sensor fallback language.
- Mapped Number value, range, step, unit, and display mode into `NumberEntity`, removing the last raw Home Assistant attribute read from production entity-detail SwiftUI.
- Consolidated state-history and Automation-trace loading into one self-loading, cancellation-aware Activity panel and migrated existing entity details plus People activity to it.
- Recorded the durable contract in `Docs/ENTITY_DETAIL_DESIGN.md` and ADR 2.

## 2026-07-17

### Atomic Dashboard Card Features

- Removed the user-facing Card Features visibility override and its persisted state. Card kind, entity capabilities, and layout now fully determine which inline content renders; compact layouts naturally suppress feature content, while Status cards provide the explicit informational alternative to Control cards.
- Kept `DashboardCardFeatureProvider` as the shared capability engine, removed the obsolete generated-view visibility workaround, renamed the dashboard action to Gauge Settings, and advanced dashboard persistence to schema v5 for the intentional beta model reset.

### Atomic Dashboard Gauge Cards

- Replaced the persisted Gauge style hierarchy with distinct Circular Gauge, Segmented Gauge, and Bar Gauge card types, and removed persisted Standard/Slider/Thermostat control styles in favor of capability-derived control rendering.
- Centralized each gauge's catalog identity, compatibility, default layout, add flow, rendering dispatch, duplicate identity, and zone-editor behavior behind its atomic card kind. Dashboard schema v4 intentionally resets incompatible beta configurations instead of maintaining migration branches.
- Standardized configuration screens around Entity plus a production-renderer Preview, backed by unmistakably synthetic fixtures until a real entity is selected.
- Corrected visual semantics: circular and bar gauges now present active progress against a secondary track, while segmented gauges retain the full zone scale and current-position marker.

### Account-Centered Server Management

- Made Account the canonical server-management entry and removed the duplicate top-level Settings > Servers row.
- Simplified Servers into a direct selection/add/removal surface: rows no longer drill into duplicate details or expose Homestead-only Rename/Reorder actions, and a successful switch returns to the refreshed Account screen.
- Removed local server aliases from connection profiles. Homestead now caches Home Assistant's own instance name per profile, ignores legacy local aliases during migration, and uses the server-derived name for Account, selection, switching, and widget presentation.
- Renamed Account's `Server Name` row to `Name`, gave it a distinct tag icon, and added a focused editor backed by Home Assistant's admin-only WebSocket `config/core/update` command followed by a `get_config` refresh.
- Made each Servers row a single native selection action and removed its duplicate long-press menu; removal remains available through a labeled, non-full-swipe destructive action.
- Added host-disambiguated removal confirmation, kept inactive-server removal in place, and returns active-server removal or successful add to the refreshed Account screen after the app-wide context update.
- Made final-server removal explicitly explain the setup transition and close Settings once the connection facade enters setup state; rename rejection remains recoverable without replacing Home Assistant's last confirmed name.

## 2026-07-15

### Multiple Home Assistant Servers

- Added app-owned server profiles with one active WebSocket, profile-scoped OAuth/mobile-app Keychain records, transactional generation-guarded switching, isolated dashboards/state caches, and legacy single-server migration without a new sign-in.
- Kept the toolbar avatar as a direct Settings button and placed discovery/manual add, rename, reauthentication, switching, inspection, and revoking removal under Settings > Servers.
- Extended the ignored Debug `PreviewCredentials.json` format to accept multiple named servers and long-lived preview tokens, with stable preview profile identities and backward compatibility for the original single-server shape.
- Polished the native Settings hierarchy by moving Servers into the Home Assistant section, separating active and other server rows, middle-truncating long hosts, consolidating detail actions, adding explicit connection status, and moving rename/full-route information into focused interactions.
- Made server details authentication-aware with concise Connected, Connecting, Offline, Ready to Switch, and Sign-In Required states; actions now appear only when relevant, and the switch action uses explicit wording.
- Fixed Add Server on physical devices by presenting its flow from the Servers screen instead of attempting to replace the already-presented Settings sheet destination.
- Added profile-aware widget/deep-link and notification routing, kept existing widgets pinned to their original migrated profile, and extended iCloud v2 with optional credential-free server metadata and per-server dashboard bundles.
- Verified with a generic simulator build and five focused multi-server migration/isolation tests.

### Card And Widget Catalog Hardening

- Added shared feature relationships for dashboard presentations and all WidgetKit kinds, including gallery metadata, supported-family metadata, required configuration, and related widget kinds without changing stable WidgetKit identifiers.
- Extended shared presentation defaults through dashboard control/status/action adapters and widget light/switch/fan/cover/lock/presence/action snapshot adapters while keeping surface-specific names, layouts, families, actions, ranges, and zones independent.
- Added Suggested dashboard catalog filtering, entity search across domain, area, device, ID, display name, and state, and made planned gallery metadata debug-only rather than production-discoverable.
- Centralized widget gallery display names and descriptions, added privacy-sensitive handling for person status, and retained explicit WidgetBundle registration and family-specific rendering.
- Verified with generic simulator build-for-testing plus focused shared-presentation, deep-link, and Gauge Grid tests. Manual widget-gallery/device verification remains the next validation step.

## 2026-07-14

### Medium And Large Gauge Grid Widgets

- Added separate stable WidgetKit kinds for a three-gauge medium grid and nine-gauge large grid so existing installed configurations remain isolated and safe.
- Kept all per-gauge App Intent controls, including custom names, display style, automatic/custom scale, endpoints, and up to five configurable color zones.
- Shared the app-group snapshot entry builder, ordered item mapping, adaptive 3-column grid, gauge tile, and gauge canvas across both sizes; Large renders the same instruments in a 3×3 layout rather than introducing a second visual implementation.
- Verified with a generic simulator build plus the focused `WidgetGaugeGridTests` and `WidgetGaugeLargeGridTests` suites.

## 2026-07-13

### Script Logic Detail

- Added a read-only native Script Logic panel to script detail surfaces using Home Assistant's `script/config` WebSocket command and the existing app-facing automation-step mapper.
- Script sequences now show mapped service actions, legacy condition blocks, inline Conditions / Then Do / Otherwise branches, and named entity, area, device, floor, or label targets sourced from Home Assistant's modern `target` and legacy `data` / `service_data` shapes. Climate actions also show their selected preset or HVAC mode. Script editing remains in Home Assistant.

### SwiftUI Scrolling And Search Performance Cleanup

- Kept `EntityBrowserList` parent rendering on stable structural indexes for ordinary scrolling and moved row-specific detail/accessory observation into the row boundary; live entity state still updates the affected row, while filters and search retain their existing dynamic behavior.
- Consolidated Add to Dashboard source derivation into one app-facing presentation pass per render and reused the existing summary workspace. The original source/presentation membership set later evolved into source and presentation counts when entity-backed cards became independently repeatable.
- Cached dashboard summary membership classification and its workspace across ordinary live state updates, invalidating only when registry, entity membership, device-class, charging, or entity-collection inputs change; Security detail status remains dynamically recomputed from its per-entity state.
- Removed the repeated device-summary pass used only to build the Devices label menu and moved camera snapshot decoding/downsampling out of the SwiftUI render path before image presentation.
- Verified with a generic simulator build and 25 focused `DashboardConfigurationXCTests`; physical-device scrolling/search profiling remains the next evidence step.

## 2026-07-10

### Configurable Segmented Zone Gauges

- Added a shared segmented zone-dial style for dashboard and Sensor widgets using the circular gauge's 240-degree geometry, fully colored proportional zones, and a current-value dot.
- Kept Home Assistant-provided min/max metadata as the preferred overall range, with device-class-aware fallback ranges and semantic zone defaults when HA does not expose thresholds.
- Added validated gauge zone overrides for minimum, maximum, and interior decimal boundaries: dashboard cards persist them with dashboard customization, while segmented Sensor widgets expose optional App Intent fields and safely inherit omitted values from recommendations.
- Added a native Gauge Zones editor with an inline live preview and focused range/persistence regression coverage.

### Automation Detail Alignment

- Replaced automation REST state-history activity with Home Assistant WebSocket execution traces, so the native detail shows real Triggered, Failed, and Stopped runs rather than repeated Enabled/Unavailable state transitions.
- Added a read-only, app-facing automation configuration mapper for the official `automation/config` response. The detail presents compact native When, And If, and Then Do sections while retaining editing and full trace inspection in Home Assistant.
- Standardized automation state semantics across the detail surface as Enabled/Disabled, without changing switch or other entity state wording.
- Extended automation action presentation to retain Home Assistant `choose` branches: options now show their trigger conditions and nested target actions, with occupancy, condition, branch, and light icons resolved through the shared HA MDI/SF icon system.

## 2026-07-08

### WidgetKit Surface Consolidation

- Kept widgets as native WidgetKit/App Intents surfaces rather than reusing dashboard card views directly.
- Moved the widget bundle entry point into its own file, kept the public widget gallery focused on Control, Status, Sensor Chart, and Action, and removed the retired standalone Light, Switch, Fan, Cover, Lock, Presence, and Sensor widget files.
- Added shared widget presentation primitives for icon badges and compact text tiles so active widgets share the same small/rectangular visual language while preserving family-specific WidgetKit layouts.
- Evolved the public sensor widget from chart-only to a configurable Sensor surface with Reading, Chart, Gauge - Circular, and Gauge - Bar displays. Its WidgetKit kind is `HomesteadSensorChartWidget`, while the gallery-facing name remains Homestead Sensor.
- Replaced the circular sensor widget's older semicircle composition with a shared dashboard-inspired 240-degree instrument gauge and added a Debug-only gauge-widget comparison screen for side-by-side simulator verification.

## 2026-07-07

### Browser Simulator Preview Workflow

- Added a Debug-only `--preview-screen appearance` simulator launch route that uses sample dependencies and skips normal startup so Codex/browser-simulator UI checks can rebuild directly into Appearance without accidentally returning to onboarding.
- Documented the live browser simulator workflow: keep `serve-sim` pinned to one simulator, preserve `--live-preview` and focused preview launch arguments across rebuilds, and reserve empty launch arguments for intentional normal-startup testing.

## 2026-07-02

### Intentional Dashboard Setup And Empty States

- Added an explicit per-saved-dashboard setup state for never chosen, suggested, manual, and intentionally empty layouts. Existing non-empty dashboards migrate as manual, existing empty dashboards remain intentionally empty, and local reconciliation no longer treats emptiness as permission to reseed.
- Unified first setup and restore behind a deterministic suggested-layout selector capped at eight high-value controls. It excludes hidden, unavailable, categorized, duplicate, technical, random-switch, and low-value sensor candidates while preserving catalog-recommended card presentations.
- Replaced the crowded empty/edit-empty action row with stacked native actions, exposed Add Cards and Add Section from a dedicated dashboard toolbar menu outside edit mode, and added focused XCTest coverage for setup transitions, no-reseed behavior, and suggestion quality/order.

### Dashboard Presentation Styles

- Added typed, persisted presentation styles beneath broad card families. Control records its source-derived Standard, Slider, or Thermostat style; Gauge supports real Circular and Bar renderers and exposes a style picker only because both are meaningful.
- Kept family choice above style and layout: direct Add saves the catalog-recommended style and layout, while optional customization selects style before layout.
- Changed duplicate identity to source + family + style, deliberately excluding layout, and advanced the clean pre-release dashboard schema to v3 so stale v2 local or iCloud dashboard data resets instead of decoding into an incomplete configuration.

## 2026-07-01

### Source-First Dashboard Configuration

- Replaced the pre-release dashboard item option bag with one versioned source + presentation model. Cards own their valid layout/options, and a shared catalog drives compatibility, recommendations, duplicate identity, default seeding, and both add paths.
- Rebuilt Add to Dashboard as native Items-first and Cards-first navigation while preserving one-tap recommended add. Summaries now live alongside entities as sources rather than under a separate Chip mode.
- Chose a clean schema reset: old, corrupt, or unsupported local and iCloud dashboard definitions are discarded safely, local selection resets, and unrelated synced preferences remain untouched.
- Made dashboard card rendering explicit for Control, Status, Gauge, Chart, Camera, Weather, Media, and Action presentations and disabled network/action side effects in previews.
- Followed with a focused polish pass that made supported layouts a single catalog rule, rejected invalid catalog factories, removed obsolete pre-schema helpers, added searchable card-first source selection, and clarified preview, Added, and accessibility states.
- Shifted the normal add path from choosing a layout to adding each presentation's catalog default directly. Rich style previews and card-first review screens now expose Add first, with alternate layouts behind an explicit secondary customization action.

### Deterministic And Live UI Verification

- Added dedicated light/dark Square, Wide, and Large gauge-card previews using deterministic sample battery data.
- Added a Debug-only `--live-preview` simulator launch path that consumes the existing ignored `PreviewCredentials.json`, bypasses onboarding, uses preview-specific preferences, and keeps mobile-app registration disabled without changing production OAuth startup.
- Added optional `--preview-entity`, `--preview-size`, and `--preview-appearance` arguments so focused live cards can be rendered and captured in light or dark appearance without altering the user's normal dashboard configuration.

## 2026-06-30

### Gauge-First Dashboard Cards

- Replaced the standard icon/title/subtitle header on gauge-only Square, Wide, and Large dashboard cards with a dedicated instrument composition inspired by Apple's automotive gauge hierarchy.
- The new card gives the entity name its own quiet centered row above a 240-degree range dial, sizes the underlying circle against its rendered arc rather than an unused full-circle box, places the unit beside the current value, and uses an explicit bottom legend for numeric bounds plus the resolved entity glyph while retaining accessibility and tap-to-open-detail behavior. The active arc carries semantic status color while the inactive track stays neutral, and the endpoint caps, bounds, and glyph share one optical bottom anchor. Instrument arcs use exact vector paths, and value changes use a short numeric-text transition that disables under Reduce Motion without animating the full dial.
- Row gauges remain horizontal, Mini and Compact cards remain simple, and Large cards that combine a gauge with other features retain the standard header and feature stack.

## 2026-06-25

### Push Registration App Integration

- Added app-side APNs remote-notification registration through the existing SwiftUI app lifecycle and app delegate bridge.
- Generated and persisted a stable Keychain-backed Homestead relay token, registered APNs tokens with the deployed Worker, and included Home Assistant mobile-app `app_data.push_url`/`app_data.push_token` registration fields without changing the OAuth `connect.homesteadcontrol.com` client identifier.
- Corrected an initial registration-shape bug where push metadata was top-level and local push was advertised; Homestead now omits `push_websocket_channel` for the remote-push path and updates existing registrations through `update_registration`.
- Kept Settings > Notifications user-facing copy native and non-sensitive while showing only high-level permission, Home Assistant setup, and background-delivery state.

### Push Relay Backend Scaffold

- Added a top-level `api/` Cloudflare Worker project named `homestead-api` for Home Assistant `push_url` notification relay and the OAuth/connect metadata page.
- The Worker serves `api.homesteadcontrol.com` for API/push routes, serves `connect.homesteadcontrol.com` for the static auth page with `rel="redirect_uri"`, stores app-generated relay-token to APNs-token mappings in the `HOMESTEAD_PUSH_TOKENS` KV binding, relays Home Assistant payloads to sandbox or production APNs using Worker secrets, and includes a protected admin test-push route.
- Kept APNs credentials in Worker secrets only, with no committed secrets or private keys.

### Dashboard Names And Titles

- Split saved dashboard management names from main Dashboard titles. Settings and dashboard-management rows use the saved dashboard `name`, while the active Dashboard navigation title comes from `displayTitle`.
- New/default dashboards use `Dashboard` for both labels. Duplicates keep the source Dashboard Title and ask only for the new management Name, without changing the active dashboard.

## 2026-06-22

### Connection Policy And Dashboard Summary Reuse

- Extracted Home Assistant reconnect/fallback timing and classification into a small recovery policy so the UI-facing service no longer owns pure retry rules inline.
- Added a reusable dashboard summary workspace plus cached summary membership context in `HAStateStore`, reducing repeated registry metadata mapping and summary classification across dashboard chips, Areas, Add Item, and summary detail views.
- Reduced area summary recomputation by creating entity presentations once per area when calculating active totals and domain chips.

## 2026-06-19

### Automated XCTest Storage Hygiene

- Added a repository helper that reports XCTestDevices, DerivedData, and CoreSimulator sizes after tests, then automatically clears only XCTestDevices when it exceeds 5 GB and no Xcode test process is active.
- Updated the durable agent workflow to run the helper after every `xcodebuild test`; DerivedData and normal Simulator storage remain report-only and require explicit approval for cleanup.

### Camera Snapshot Reliability

- Reworked dashboard camera previews around a shared session-memory snapshot store: recent stills render immediately, stale stills remain visible for up to 30 minutes with a clear Last view badge, and successful detail-view snapshots feed the same cache.
- Added bounded dashboard snapshot concurrency plus jittered 2/6/15-second retries before the normal refresh cadence, preventing a transient Home Assistant snapshot failure from leaving a card blank for nearly a minute.
- Kept live HLS frame capture out of the dashboard path so camera cards do not start background streams or persist sensitive camera imagery; snapshot failures now produce private diagnostic logs for troubleshooting.

## 2026-06-15

### Account Server UX

- Refined Settings > Account into a more native user-facing surface: the header now shows only avatar, user name, and a friendly status chip, never raw connection error strings.
- Reworked Server rows around icon, label, and value for Server Name, Internal URL, External URL, and Active Connection, with Internal URL and External URL opening focused native editors instead of an Account-wide edit mode.
- Moved trusted Wi-Fi network management under the Internal URL editor, removed inline Account editing state, and kept read-only Home Assistant environment rows for installation method, Core, Supervisor, and OS where the official APIs provide them.

### SSID-Gated Local Routing

- Added optional saved Wi-Fi names in Settings > Account > Server so Homestead uses the Local Address only on known local networks when a Remote Address is available.
- Added current Wi-Fi name lookup through `NEHotspotNetwork`, the Wi-Fi Information entitlement, and an in-context Location permission request from the server editor's Use Current Wi-Fi action.
- Migrated the legacy single home-network preference into the saved local-network list and included the list in iCloud connection sync without restoring credentials or tokens.
- Updated route selection and focused tests so unknown, denied, or unlisted Wi-Fi starts with the Remote Address instead of timing out on `homeassistant.local`.

## 2026-06-14

### Mobile App Registration Safeguards

- Stopped live Home Assistant Xcode previews from automatically registering Homestead as a Home Assistant Mobile App device; previews can still connect and render live HA state without mutating the Mobile App integration.
- Added a Keychain-backed stable mobile-app `device_id` for normal app registration so losing or refreshing local registration metadata does not create repeated cloned devices with the same simulator/device name.
- Preserved explicit in-app mobile-app registration and connected-session WebSocket notification registration for normal app runs.

### Unified Setup, Discovery, and iCloud Restore

- Gated startup behind a read-only iCloud bootstrap so a clean device cannot seed or upload defaults over an existing dashboard.
- Added explicit restore/new-home choices, user-triggered Home Assistant Bonjour discovery, manual sign-in fallback, and device-local OAuth after restore.
- Upgraded preference sync to section-level v2 records with v1 migration, automatic debounced uploads, two-way refresh, and explicit conflict resolution.
- Removed SSID metadata from first-run setup and redesigned Server settings around sign-in, local, remote, and active addresses. Local route SSID gating was later restored as an explicit Server setting.
- Recorded the durable architecture in `Docs/ADR/001-unified-setup-discovery-and-icloud-bootstrap.md`.

### iPad and Apple Silicon Mac Support

- Confirmed both app and widget targets support iPhone and iPad and that the existing adaptive card grid, regular-width Security sidebar, and native List/Form surfaces provide the shared iPad layout without a navigation rewrite.
- Confirmed Apple silicon Mac support through Designed for iPad and intentionally left Mac Catalyst disabled until Homestead needs desktop-specific menus, keyboard commands, multiwindow behavior, or Intel Mac distribution.
- Made onboarding, notification, permission, privacy, and About copy device-neutral and updated diagnostics to distinguish iPhone, iPad, and Mac (Designed for iPad).
- Preserved existing bundle identifiers, entitlements, signing capabilities, orientations, and widget embedding; Mac widget availability and full pointer/window behavior still require manual verification before marking App Store Connect compatibility as verified.

### Settings Placeholder Completion

- Replaced Settings > Devices & Services > Integrations with a read-only integration-platform overview derived from documented entity registry display metadata and existing state/device registry context, with cached light/dark brand icons loaded through Home Assistant's local Brands API when available.
- Aligned integration detail navigation with Home Assistant's registry hierarchy: integrations now list their associated devices alphabetically, devices drill into their entities, and entities without a device remain available in a separate fallback section.
- Replaced Settings > Devices & Services > Helpers with a read-only browser for helper entity domains exposed by Home Assistant state/registry data.
- Removed the Blueprints, Widgets, and Live Activities placeholder rows from production Settings; Blueprints still needs an official external API before native browsing/import/management, while widgets are configured from the Home Screen and Live Activities are not implemented yet.
- Added opt-in Settings > iCloud Sync backed by Apple iCloud key-value storage for small Homestead-owned preferences, intentionally excluding credentials, tokens, Home Assistant state/cache, registry metadata, mobile-app registration secrets, widget snapshots, wallpaper files, and generated user data.
- Aligned Settings management organization with Home Assistant: Automations, Scenes, Scripts, and Helpers now consume scoped Categories; entities consume direct/device area relationships; labels filter Devices, Entities, Helpers, Automations, Scenes, and Scripts; and automation/scene/script lists can sort by recent activity when timestamps are available.
- Replaced generic Area and Category group-header symbols with registry-provided Home Assistant icons rendered through the shared native-first MDI-to-SF icon resolver, preserving semantic area and folder fallbacks when no icon is assigned.

### UX Cleanup and Fan Controls

- Removed the legacy Browse/Devices star affordance and stale quick-access presentation metadata so Dashboard customization is the only quick-access model.
- Added fan percentage sliders as reusable dashboard card level features backed by Home Assistant `fan.set_percentage`, including off-as-0% presentation and percentage-step support.
- Kept raw connection failure details out of the Account profile header; detailed errors remain available in server/diagnostic surfaces.

### Wallpaper

- Added a local-only Homestead appearance setting for one optimized wallpaper image stored in Application Support, with no Home Assistant upload, API surface, or wallpaper image-file sync.
- Scoped wallpaper images, enabled state, and revision metadata to Home Assistant server profiles so each server can have an independent wallpaper; switching or removing a server now activates or cleans up the matching wallpaper data while global appearance choices remain shared.
- Added Settings > Appearance with photo picking, preview, enable/disable, and removal controls.
- Applied the shared wallpaper background only behind Home, Areas, and area detail scroll surfaces, preserving opaque dashboard cards and avoiding material/blur effects in live scrolling grids.
- Extended wallpaper support to dashboard summary views and replaced the flat settings preview with a phone-shaped preview using the same wallpaper crop/overlay behavior as daily-use surfaces.
- Standardized wallpaper-aware dashboard surfaces around a lightweight soft-glass treatment: translucent dark fills, subtle strokes, and toned-down active control fills instead of per-card material blur.
- Tuned the first wallpaper pass after visual review: reduced wallpaper dimming, lightened wallpaper-aware card/chip/control fills, stopped climate cards from using the active-card highlight, and compacted the Appearance preview so the settings page stays in one screen.
- Revised the wallpaper card direction again toward stable darker translucent surfaces with icon-first active state, removing full-card/large-control blue washes in wallpaper mode and fixing launch-time wallpaper layout so the image cannot momentarily render as a narrow strip.
- Switched wallpaper-mode dashboard surfaces to reuse standard adaptive grouped fills with opacity instead of dark-only custom fills, improving light-mode text/icon contrast while keeping dashboard cards off live material/glass effects for now.
- Ran the next wallpaper surface experiment with `.thinMaterial` for wallpaper-mode card and chip backgrounds, while keeping active state out of full-card fills so emphasis stays on active icon wells and feature sliders.
- Polished Settings > Appearance so the phone-shaped preview remains the focal point, with a quieter Change action for existing wallpapers, a softer grouped panel, and empty-state-only helper text.
- Unified dashboard active-state styling across wallpaper and standard backgrounds: card bodies and borders remain neutral while icon wells and meaningful feature controls carry the accent color.

## 2026-06-13

### Area Icons

- Decoded Home Assistant area registry icon metadata from `config/area_registry/list` and carried it through area summaries so Area cards prefer HA-provided room icons when Homestead has a conservative SF Symbol equivalent.
- Expanded local name inference for common rooms such as entryways, dining rooms, laundry, hallways, patios, media/game rooms, closets, and nurseries, with unsupported HA icons falling through to inference and then a neutral `house` fallback.

### Security Summary Activity

- Added a Home Assistant-style Security activity surface backed by Homestead's existing documented REST logbook client, without introducing private frontend endpoints or a second activity model.
- Compact layouts use a native bottom Devices/Activity segmented control; regular-width layouts keep activity visible in a dedicated sidebar beside the existing Security card grid.
- Filtered the 24-hour logbook response locally to the Security summary entities plus every `person.*` entity, matching Home Assistant's Security strategy, grouped the newest 50 events by explicit date, retained cached rows during refresh failures, and linked rows to existing entity detail views.
- Grouped summary device views by floor and then area using Home Assistant registry metadata; floor headings remain informational while area headings navigate to Homestead's native area views.
- Refined Security activity to decode logbook state changes into HA-style narrative rows, use authenticated cached person avatars, and remove redundant generic status text; floor headings no longer imply a generic house icon when no faithful floor icon mapping exists.
- Added a shared session-memory Security activity cache with stale-while-refresh behavior so reopening the summary presents recent rows immediately, and removed duplicated in-content summary titles in favor of the native navigation title.
- Removed the compact Security tab-switch hitch by isolating segmented-control state from the summary parent, resolving person records once per activity presentation, and lazily constructing activity rows instead of rebuilding summary grouping and every row on each tab selection.
- Added Home Assistant logbook context attribution to Security activity rows, including trigger descriptions, user names when HA supplies `context_user_id`/`context_name`, and lock/unlock-specific activity icons.
- Expanded Security activity attribution to resolve `context_user_id` through existing `person.*` / People data, switched activity icons to historical state-aware lock/door/cover symbols, and removed the local 50-row cap so the full 24-hour activity response can scroll.

### First-Run Onboarding

- Replaced the signed-out dashboard setup card with an app-level Home Assistant onboarding surface that lets new users enter their server URL and start the existing OAuth sign-in directly.
- Kept setup intentionally focused: no Bonjour discovery, wizard, alternate auth path, or new Home Assistant API surface; optional internal/external URL and home-network routing metadata lives behind an Advanced Setup sheet.
- Polished the first-run surface toward native iOS setup patterns with a compact centered hero, grouped server entry, quiet footer/status behavior, and a bottom Continue action.
- Kept Advanced Setup visually aligned with Settings by using grouped Form sections for optional addresses and home-network metadata.
- Added app-facing onboarding presentation tests for fresh install, URL-entered, signing-in, failed/retry, and signed-in transition states.

## 2026-06-12

### Settings Apps

- Added a native Settings > Apps page backed by Home Assistant Core's WebSocket `supervisor/api` bridge to the official Supervisor `/addons` endpoint.
- Mapped Supervisor app/add-on DTOs into app-facing installed app rows with description, installed/latest version, update availability, and Running/Stopped/Unknown status labels.
- Kept Supervisor management actions out of scope and render non-Supervisor or unreachable installs as unavailable/retry states rather than using private frontend endpoints.
- Corrected the first implementation from a direct native-client `/addons` HTTP call to the Core WebSocket bridge, because external OAuth clients cannot access Supervisor's internal `http://supervisor` API or `SUPERVISOR_TOKEN` directly.
- Added Supervisor app artwork loading through Home Assistant Core's `/api/hassio/addons/<slug>/icon` and `/logo` proxy paths, and moved descriptions into a simple read-only app detail page so the Apps list stays scannable.

### Dashboard Icon Picker

- Replaced the limited nested dashboard icon menu with a dedicated searchable grid picker shared by dashboard cards and chips.
- Expanded icon choices into a curated 180-symbol SF Symbols catalog with smart-home categories, friendly search tags, and recommendations based on entity domain or summary kind.
- Preserved the existing optional dashboard icon override persistence; Use Default Icon clears the override so live Home Assistant/domain-derived icons remain the fallback.
- Kept the catalog intentionally app-owned and SF Symbols-only so future picker enhancements can build on it without adding icon-pack or Home Assistant mapping complexity.

### Home Assistant Summary Alignment

- Confirmed Home Assistant does not expose direct summary-category membership through REST or WebSocket; its frontend derives membership from entity state and registry metadata.
- Centralized Homestead's Climate, Lights, Security, Media, and Maintenance filters around the current HA frontend strategies, including registry category/visibility handling, selected area climate readings, security device classes, and charging-aware battery status.
- Confirmed HA Security includes visible primary camera entities regardless of snapshot-like naming, so Homestead intentionally avoids camera-name heuristics.
- Added connected-session subscriptions for entity, device, area, and floor registry updates so summary membership metadata refreshes after Home Assistant registry changes.
- Made generated card defaults universal across summary views, area views, and Add to Dashboard: cameras default to preview-sized cards, Climate defaults to setpoint-capable cards, ordinary numeric sensors still default to chart cards, and non-feature/default status entities stay compact unless the user chooses a larger dashboard card.
- Added generated-card feature visibility defaults so humidity and other history-capable sensors that also have read-only gauge features still render their trend chart by default, matching Home Assistant's Climate summary behavior while preserving the gauge as an optional larger-card feature.
- Shifted universal generated card sizing toward Home Assistant's area-view defaults for interactive tile features: dimmable lights, covers/garage doors, climate entities with setpoints, and locks now default to Square cards with their first supported control feature visible.

### Sensor Gauges

- Added reusable app-facing gauge presentation for numeric sensor readings, including resolved range source, normalized value, warning status, and accessibility copy.
- Exposed gauges as a read-only dashboard card feature for larger cards when range metadata or safe bounded sensor classes make the reading glanceable, while preserving Mini/Compact simplicity and ordinary numeric trend cards.
- Reused the same gauge presentation in sensor detail current readings and kept raw Home Assistant DTO access inside mapping/model layers.
- Revised gauge rendering from a slider-like bar into passive HA-inspired visuals: semi-circular segmented arcs for square/large/detail contexts and a read-only segmented horizontal gauge for row cards, while keeping card header layout unchanged.
- Added a square Home Screen sensor widget Gauge display style backed by the same dashboard-eligible gauge snapshot metadata, with live refresh updating the current numeric reading when available.

## 2026-06-11

### Select Options Cards

- Added typed select option state for `select.*` and `input_select.*`, mapping both into native select presentation while preserving their distinct Home Assistant service domains.
- Added the reusable dashboard Options feature so larger select cards show a native menu row and call `select_option` through the existing WebSocket service path.

## 2026-06-10

### Settings People

- Added a native Settings > People page for presence management using existing `person.*` and `device_tracker.*` state plus registry metadata.
- Mapped presence into app-facing records and presentation helpers so SwiftUI does not read raw Home Assistant DTOs; people are related to source trackers where Home Assistant exposes the `source` attribute.
- Reused authenticated Home Assistant image loading and documented REST history timelines for person/tracker details while keeping true user/admin management and private frontend endpoints out of scope.
- Simplified Settings > People into a people-first surface: the main list now shows only person rows, custom zone state casing is preserved exactly, global tracker browsing/filter summaries are removed, and empty registry context is hidden from detail views.
- Aligned the Settings row and People landing page with Apple's Family-style overlapping avatar treatment to make the people area feel more native and household-oriented.
- Completed live-preview polish by removing the People search field, centering sparse household avatar clusters, caching authenticated avatar images, and aligning toolbar/account avatar rendering with the Settings profile treatment.

### Connection Startup

- Added a preparing connection phase for signed-in startup so cached Home Assistant state can remain visible while Homestead loads cache, refreshes tokens, selects a route, and begins the WebSocket handshake.
- Kept real failures explicit: initial connection errors still move to failed state, reconnect interruptions still surface through reconnecting/stale/failure chrome, and the app no longer publishes signed-in plus disconnected during normal launch.
- Suppressed transient cached-state bottom chrome during the preparing/connecting startup handshake so cached dashboard content remains visible without a split-second warning banner.
- Added a short foreground grace window for connection-health chrome so brief socket recovery after returning from the Home Screen does not flash reconnecting/interrupted banners while real failures still surface after the grace period.

## 2026-06-09

### Notifications

- Investigated Home Assistant automation notification delivery end to end and added the connected-session WebSocket notification decoder.
- Hardened mobile-app WebSocket notification decoding so Homestead accepts both the documented root-level event payload and nested `event.data` payload variants before presenting a local notification and confirming delivery.
- This connected-session work was later superseded for background delivery by the APNs `push_url` relay through `homestead-api`.

### Dashboard Mini Tiles

- Polished Mini dashboard cards into glanceable accessory tiles with a compact icon and readable two-line entity name while preserving the existing quick-action icon and detail-opening card behavior.
- Reused app-facing `DashboardEntityPresentation` state for active, inactive, unavailable, and accent styling without adding any Home Assistant API surface.
- Parameterized the shared card icon/container styling so the mini tile language can later inform larger accessory grids if device testing supports it.

### Widget Gallery Polish

- Polished the experience-first Home Screen widget previews so unconfigured add-widget gallery snapshots use curated sample data instead of whichever real entity happens to be first.
- Tightened small widget bodies by hiding generic labels such as Sensor, Script, and 6H Chart while preserving meaningful status copy like unavailable or setup guidance.
- Removed automatic first-entity defaults from the public unified widget intents so the add-widget gallery stays sample-based and unconfigured widgets do not silently bind to a real Home Assistant entity.
- Further tightened Status widgets by hiding routine sensor subtitles like Temperature, while keeping alert/recovery text, and made Action widgets read as commands through a purple play-badged icon treatment instead of extra face text.
- Aligned compact Control and Status second-line typography and simplified Action widget command icons to a single play-circle glyph after gallery review.
- Added searchable App Intent entity queries for the public widgets and enriched compact widget snapshots with optional area/device context so the system picker can show cleaner room/type subtitles without changing widget faces.
- Returned sectioned App Intent picker collections with entity SF Symbol images for public widgets, and made curated Control/Action gallery placeholders non-actionable so sample taps do not attempt fake Home Assistant service calls.
- Tightened widget picker rows so sectioned entities show context-shortened names, keep subtitles to the entity kind, and leave raw entity IDs searchable but hidden from the default row presentation.
- Aligned unconfigured Home Screen widget faces around shorter `Choose Control/Status/Sensor/Action` setup copy and removed placeholder data glyphs like `--` from setup states.
- Removed routine domain subtitles from public widget picker rows so grouped entity lists rely on room/device section headers, icons, and shortened entity names while keeping domain and entity IDs searchable.

### Experience-First Widgets

- Reworked the public Home Screen widget gallery from domain-first widgets into Control, Status, Chart, and Action widget kinds.
- Added a unified Control widget that lets users pick a light, switch, fan, cover, or lock entity, then renders the appropriate state and safe action for that domain.
- Added a unified Status widget for sensor and person state so users pick the status entity directly instead of choosing separate sensor or presence widget kinds.

### Widget Cover Fan Lock Controls

- Added Home Screen cover, fan, and lock widgets using compact app-group snapshots and widget-side WebSocket `get_states` refresh.
- Kept widget actions on official Home Assistant WebSocket service calls: `cover.open_cover` / `cover.close_cover` / `cover.stop_cover`, `fan.turn_on` / `fan.turn_off`, and conservative `lock.lock` only.
- Extended app-owned widget snapshots to covers, fans, and locks while keeping widget views app-facing and raw Home Assistant state parsing inside the widget action client.

### Widget Status And Actions

- Added Home Screen sensor and person/presence widgets using compact app-group snapshots and widget-side WebSocket `get_states` refresh.
- Added a configurable scene/script action widget using the existing shared OAuth credential path and official WebSocket `call_service` for `scene.turn_on` / `script.turn_on`.
- Added a Home Screen numeric sensor chart widget using compact numeric sensor snapshot metadata and Home Assistant's documented REST history endpoint over the shared OAuth credential path.
- Kept widget views app-facing while raw Home Assistant state parsing stays inside the widget action client.

## 2026-06-08

### Switch Widget

- Added a Home Screen switch widget beside the existing light widget using the same shared OAuth/app-group credential pattern.
- Kept widget actions on official Home Assistant WebSocket paths: `get_states` for compact timeline refresh and `call_service` for `switch.turn_on` / `switch.turn_off`.
- Extended app-owned widget snapshots to switches while keeping widget views app-facing and raw Home Assistant state parsing inside the widget action client.

### Trust And Recovery

- Added native Settings > Permissions for Notifications, Local Network, Location, and Camera.
- Kept platform permissions in app-owned native services: notifications use UserNotifications, camera uses AVFoundation authorization, location uses CoreLocation authorization, and Local Network is shown as iOS-managed because there is no direct read-only status API.
- Added the required iOS usage descriptions for Camera, Location When In Use, and Local Network.
- Improved service-call and reconnect recovery feedback in `HomeAssistantService` and app chrome so reconnecting can be retried immediately and action failures can explain automatic reconnect recovery without scattering error UI through individual views.
- Added a non-blocking notification setup prompt after Home Assistant sign-in and mobile-app registration so users can grant notification permission without first finding Settings.

### Roadmap Handoff Reset

- Moved entity history/timelines out of the active workstream after multiple completed passes.
- Set expanded WidgetKit/App Intents support beyond the current light widget as the next recommended active focus.

## 2026-06-07

### Dashboard Add Flow Organization

- Replaced the Add to Dashboard card picker with a card-type-aware flow grouped by Home Assistant registry device when available, falling back to domain groups.
- Added local filtering for Homestead card styles such as Controls, Values, Status, Media, Cameras, Actions, and Other without adding any new Home Assistant API surface.
- Kept list rows clean with plus-button quick add, and moved size/feature choice into a row-tap chooser that previews real card layouts and can hide inline features before adding.
- Added durable UI guidance to prefer user-facing product surfaces and visual previews over development-style explanatory copy.
- Kept generated card sizing intact so camera previews and numeric sensor chart cards still default to Square, and added focused regression tests for grouping, filtering, search, availability, suggested sizes, and size-choice summaries.

### Dashboard Direct Editing

- Added edit-mode drag reordering for dashboard cards and section headers directly in the `CardGrid`, keeping chips in the existing chip reorder sheet for now.
- Preserved the flat Homestead-owned dashboard item order instead of storing grid coordinates; the existing grid layout still computes placement from order and card spans.
- Changed drag behavior to use a transient preview order so cards and section headers visually reflow while dragging, while persisted dashboard order still updates only on drop.
- Rendered the lifted card/header as a floating drag preview over a stable opacity-hidden grid placeholder so the item follows the finger without fighting the grid reflow animation or dropping the active drag gesture.
- Added a quiet, non-interactive corner grip badge to cards and headers while keeping the whole card as the drag target.
- Reserved card/header long-press in edit mode for dragging by removing edit-mode context menus from draggable grid items; normal-mode context menus still expose card/header customization actions.
- Added visible-grid reorder coverage so chip slots stay fixed and hidden/unavailable configured items are not moved by visible-card drag operations.

### Connection Routing

- Added automatic internal/external Home Assistant URL selection in `HomeAssistantService` using saved Settings > Account > Server route metadata and iOS network state.
- Preserved OAuth refresh, state-cache scope, and mobile-app registration identity by separating the active route URL from the signed-in server identity in `HAConnectionConfiguration`.
- Added route fallback for transport-style failures and regression coverage for resolver behavior, WebSocket connect routing, documented HTTP handoff, and mobile-app registration handoff.

### Weather

- Added a native read-only Weather pass for `.weather` entities using Home Assistant entity state attributes.
- Added typed app-facing weather mapping and presentation helpers for condition, temperature, humidity, wind, forecast availability, and attribution.
- Routed Weather through `HAStateStore` / `HAEntityState`, dashboard presentation metrics, and a native detail surface so SwiftUI stays off raw Home Assistant DTOs.
- Kept weather service calls out of scope until an official service-backed user intent is confirmed.

### History And Charts

- Added a focused numeric sensor history pass backed by Home Assistant's documented REST history API.
- Added typed history request/response models, fixed 1H/6H/24H range helpers, app-facing chart series mapping, authenticated HTTP/service handoff, and focused regression tests for URL shape, decoding, filtering, range construction, and OAuth handoff.
- Added a native Swift Charts history panel to the existing sensor detail surface while keeping raw Home Assistant DTOs out of SwiftUI and chart formatting outside `HAStateStore`.
- Expanded numeric sensor history into dashboard chart cards for Square, Wide, and Large card sizes with a fixed 6H range, preserving compact value cards and routing requests through `HomeAssistantService`.
- Added dashboard history eligibility/request helpers, chart-card presentation mapping, generated-card size behavior for numeric sensors, and focused regression tests for the card/service handoff.
- Added the first non-numeric history timeline slice for `binary_sensor.*` detail surfaces, using the same documented REST history and authenticated service handoff to map on/off and availability changes into app-facing Recent Activity timeline entries.
- Extended the detail-surface timeline pattern to `lock.*` entities, reusing the documented REST history handoff and shared Recent Activity panel while mapping lock states into app-facing timeline entries outside SwiftUI.
- Extended detail-surface timelines to switches, automations, covers, people, and device trackers through the same REST history/service path, keeping dashboard timeline cards and raw history DTOs out of SwiftUI.

### Updates

- Added a native Settings > Updates page backed by Home Assistant `.update` entities.
- Added typed update entity mapping and presentation helpers for installed/latest versions, title/name, release summary or release notes URL, skipped state, in-progress/unavailable state, entity/device/area/floor context, grouping, filtering, and search.
- Added official `update.install`, `update.skip`, and `update.clear_skipped` service actions over WebSocket `call_service`, gated through the loaded service catalog, with install confirmation choices for backup behavior.
- Kept repairs, system health, admin details, and extra update metadata endpoints out of scope because Homestead is not using private frontend APIs for this surface.

## 2026-06-05

### Logbook

- Added a read-only Settings > Logbook page backed by Home Assistant's documented REST logbook API.
- Added typed logbook request/DTO support, app-facing activity row models, grouped/searchable presentation helpers, date range controls, and entity/domain filtering.
- Kept server calls to the documented start timestamp, `end_time`, and `entity` API shape, with domain filtering and search handled locally.

### Notifications

- Added native iOS notification permission/status models and a `NativeNotificationService` that is separate from Home Assistant mobile-app registration state.
- Replaced the Settings > Notifications placeholder with a real setup/status page for iOS permission state, Home Assistant account/mobile-app readiness, WebSocket delivery readiness, and recovery actions.
- Polished Settings > Notifications into a simpler user-facing status screen with clear permission/readiness summaries, an iOS Settings handoff, and lower-level delivery details behind disclosure.
- Added Home Assistant's official mobile-app WebSocket notification delivery by registering `push_websocket_channel`, subscribing over the active Home Assistant WebSocket connection, presenting local iOS notifications, and sending HA confirmation IDs after local presentation.
- Later APNs relay work stopped advertising `push_websocket_channel` in the active mobile-app registration so Home Assistant uses the remote `push_url` path.

### Server Configuration Foundation

- Added typed WebSocket `get_config` support for the nested Settings > Account > Server page, exposing Home Assistant version, status, location/time zone, unit summary, and official internal/external URL values when returned.
- Extended Homestead-owned connection settings with saved internal URL, external URL, and home network metadata while keeping the current base URL as the only active connection route.
- Kept automatic URL switching deferred to future connection lifecycle work instead of implementing routing in SwiftUI.

### Settings Information Architecture

- Reorganized Settings into native Home Assistant and Homestead sections while preserving the top-level account card and Home Assistant account/server header.
- Replaced segmented Devices & Services and Automations & Scenes management pages with overview rows that push to focused registry/detail pages.
- Added honest placeholders for planned Settings destinations whose backend or official API support is not implemented yet.
- Renamed the account/server destination to Account and removed the duplicate root Server row so the profile card owns account and server setup.
- Split Account identity/session concerns from Server connection concerns by nesting a dedicated Server page inside Account, preserving existing connection recovery actions while preparing for richer URL/version/route metadata.

## 2026-06-03

### Product Roadmap Memory

- Added `Docs/PRODUCT_ROADMAP.md` as durable product memory for existing Homestead features, likely next work, later candidates, API confidence, and intentionally deferred directions.
- Pointed `AGENTS.md` at the roadmap so future coding agents can distinguish product direction from architecture rules and the chronological development log.
- Added `Docs/API_CAPABILITY_INVENTORY.md` to track current API coverage, near-term API targets, research-needed surfaces, and the policy of mapping feature-sized official API slices instead of prebuilding every possible Home Assistant model.
- Added a near-term API mapping queue and default Codex commit guidance so self-contained verified changes are committed without requiring a separate follow-up prompt.
- Added `Docs/NEXT_STEPS.md`, `Docs/DEVELOPMENT_WORKFLOW.md`, and `Docs/ADR/README.md` so future coding sessions have a tactical handoff, Definition of Done, UI verification defaults, and a place for durable architecture decisions.
- Added token budget and reasoning-level guidance for Codex-heavy development sessions.
- Added fresh-chat handoff guidance so Codex can recommend new chats at clean boundaries and provide a restart prompt.

### Dashboard Detail Views

- Introduced a shared dashboard detail scaffold with compact status headers, restrained action buttons, and collapsed Home Assistant metadata disclosures.
- Migrated action, toggle, lock, sensor, vacuum, light, fan, cover, climate, media-player, and camera detail surfaces toward the shared structure while keeping domain-specific safety behavior explicit, including lock unlock confirmation and camera live/snapshot handling.
- Reused a Homestead-style filled level slider across detail controls, tightened climate temperature nudges into compact icon buttons, made camera previews fill their media panel, and moved media now-playing text out of the compact header.
- Added fullscreen camera preview access, moved secondary climate options into compact menu rows, and kept dashboard detail sheets on the shared medium-to-large presentation behavior.
- Added native detail views for alarm control panels, buttons, selects, and numbers while keeping these helper-style domains out of accidental card-level primary actions.
- Preserved separate domain detail files instead of centralizing detail rendering into a conditional mega-view; richer domains can migrate incrementally when their controls are redesigned.
- Routed Devices through the same native entity detail sheet used by Dashboard and Areas, renamed the old raw Home Assistant entity view to diagnostics, and exposed diagnostics from each native detail view's Home Assistant disclosure.
- Moved shared entity detail views and helper components out of the Dashboard feature folder into `Features/EntityDetails`, keeping dashboard-specific card and route types in Dashboard.

## 2026-06-02

### Dashboard Rendering Performance

- Profiled dashboard scrolling and navigation on a physical iPhone with Instruments Animation Hitches; the bad frames were render/GPU-bound with high offscreen-pass counts rather than state recomputation.
- Replaced repeated card drop shadows and camera-preview material overlays with lightweight strokes and flat overlays, preserving the native grouped-card look while eliminating the observed hitch rows in a follow-up trace.
- Kept matched zoom navigation transitions enabled after confirming they were not the primary source of the dashboard sluggishness.

### Architecture Cleanup

- Removed pre-release dashboard compatibility scaffolding for old card-size migrations, summary aliases, and entity display-name migrations; current dashboard persistence now stores only the active schema.
- Split the dashboard shell from add-item, reorder/loading/empty, and summary-detail views so future dashboard work can land in focused files.
- Organized Dashboard feature files into AddItem, Cards, Details, Summary, and Support subfolders while keeping domain detail views separate instead of centralizing them into a conditional mega-view.
- Renamed remaining internal Devices membership vocabulary to dashboard membership and added lock-card regression coverage for inline unlock confirmation and unlocked/unlocking status labels.

## 2026-06-01

### Dashboard Card Features

- Moved interactive dashboard card controls into reusable card feature models and renderers, keeping card views focused on composition and Home Assistant service wiring.
- Added stable feature keys for brightness, climate setpoints, cover movement, and cover position so future per-card feature visibility can persist against feature identity instead of view structure.
- Added adaptive feature layout rules: Mini and Compact cards stay informational, Row cards can host a trailing feature, Square/Wide cards show one stacked feature, and Large cards can show multiple features.
- Added lock/unlock as a reusable command feature and kept feature cards visually consistent while dashboard edit mode disables interaction.
- Added native long-press customization shortcuts for normal-mode dashboard cards and chips while reusing the same edit actions.
- Added cover device-class icon mapping, simplified edit-mode reorder access, and let area views upgrade feature-capable entities from Compact to Square cards.
- Added summary chips to the main Areas view and grouped area detail entities through the shared summary categories for Lights, Climate, Security, Media Players, and Maintenance before falling back to raw domains.
- Added Home Assistant Floor registry metadata and grouped the Areas overview by floor only when it improves scanning, preserving Areas as the primary room-browsing surface.
- Simplified Areas presentation by removing redundant floor/card/detail counts and letting active domain chips surface the most relevant room capabilities.
- Added Automations as a first-class mapped entity domain, rendering them as enabled/disabled toggle controls through Home Assistant's `automation.turn_on` / `automation.turn_off` services rather than accidental trigger actions.
- Switched area detail entity sections to the shared card grid so mixed Compact and Square cards align consistently with dashboard layout behavior.
- Tightened summary category filtering toward Home Assistant's frontend strategies, including area-selected temperature/humidity readings for Climate summaries and feature-aware Square cards in summary sheets.
- Added entity-category awareness from Home Assistant's compact entity registry so summaries can exclude hidden/secondary entities while preserving HA's diagnostic tamper exception for Security.
- Replaced the Homestead-specific Batteries summary with Home Assistant-style Maintenance, including numeric battery sensors and primary binary low-battery sensors.
- Scoped dashboard card name/icon customization to dashboard surfaces, kept generated area views canonical and feature-rich, added per-card feature visibility controls under Card Features, and made ordinary active/inactive icons stable with filled defaults while preserving semantic state icons and Home Assistant switch device-class icons.
- Expanded display-only Home Assistant `device_class` interpretation for cover, binary sensor, sensor, and media-player presentation without adding any path that mutates Home Assistant metadata.
- Expanded first-class Home Assistant domain recognition for common display-only/status entities such as remotes, buttons, selectors, updates, alarm panels, weather, calendars, people, valves, sirens, and image entities while keeping unsafe primary actions disabled by default.
- Added regression coverage for feature provider output and card-size feature gating.

## 2026-05-30

### Smart-Home Summary Chips

- Replaced addable door, lock, and camera summary chips with a higher-level Security summary.
- Added summary-detail models so the provider can return chip text plus filtered, grouped, and sorted entity rows for summary views.
- Added lightweight native Summary Views opened from dashboard summary chips, with rows that can open existing domain detail sheets and show simple available primary actions.
- Expanded summaries beyond domain-only counts: Security aggregates entry points, locks, garage/gate covers, cameras, alarm entities, and security-like sensors; Climate includes climate, fan, temperature, and humidity items.
- Added binary sensor `device_class` mapping so summaries can distinguish doors, windows, locks, motion, alarms, moisture, and other binary sensor types without relying on entity-name guesses.
- Refined summary views to group by area, prefer current temperature for Climate chip text, and use prioritized Security issue wording such as `1 unlocked` or `2 open`.
- Added thermostat auto-mode temperature range support by mapping `target_temp_low` / `target_temp_high`, showing dual heat/cool controls, and sending Home Assistant's `climate.set_temperature` range payload.
- Aligned Summary Views with Area detail by rendering filtered entities in the shared `CardGrid` using fixed compact dashboard cards instead of bespoke summary rows.
- Moved entity display-name overrides from dashboard-item state to global Homestead preferences keyed by `entity_id`, with migration for older dashboard card overrides and contextual area-name trimming for area/summary cards.
- Moved add-card and add-section actions to the main dashboard menu so edit mode can stay focused on item editing and reorder.
- Added regression coverage for modern summary chip ordering and filtered summary detail sections.

## 2026-05-29

### Settings Diagnostics And Release Polish

- Expanded Home Assistant settings into a production support surface with privacy-safe diagnostics for account, auth, connection, state freshness, network, mobile-app registration, app version, device software, and cache counts.
- Added cache metadata tracking without exposing cache file paths or Home Assistant tokens.
- Added sign-out confirmation copy so credential and mobile-app registration removal is harder to trigger accidentally.
- Tightened About app/build details and support navigation, and improved accessibility for global connection/status accessories.
- Simplified the primary Home Assistant settings flow so normal users see account, server, and recovery actions first, with registration and operational diagnostics moved behind progressive disclosure.
- Trimmed About and Diagnostics so support details stay nested under Home Assistant settings, with only lightweight connection/state information visible before advanced disclosure.

### Dashboard Chips And Icon Overrides

- Added first-class dashboard chip items alongside cards and headers, with summary and entity chip variants persisted in dashboard metadata.
- Added a reusable dashboard summary provider for glanceable chips such as lights, doors, locks, climate, maintenance, cameras, and media.
- Added curated SF Symbol icon overrides for dashboard cards and chips while keeping live Home Assistant entity state separate from layout/customization metadata.
- Rendered chips as a lightweight horizontally scrolling summary row above the dashboard grid so they do not compete visually with cards.

### iPhone Production Readiness Pass

- Added pending-state handling for stateless Home Assistant actions such as scenes, scripts, media play/pause, cover stop, and vacuum commands.
- Preserved last-known state timestamps while refreshing so stale/retry UI can show trustworthy data age.
- Hardened WebSocket setup/recovery cleanup and persisted confirmed live state before optional metadata enrichment so cold launch caches refresh sooner.
- Added shared dashboard detail status, action, and control components and migrated common detail sheets onto them.
- Tightened Home Assistant settings recovery for server mismatches and mobile-app registration status.

### Expanded Native Domain Controls

- Added fan and media-player domain models so dashboard views can read typed Home Assistant state instead of raw attributes.
- Added native fan and lock dashboard detail flows, with lock/unlock guarded behind a detail confirmation instead of an accidental card tap.
- Expanded media-player details with volume and source controls, and climate details with fan-mode and preset-mode controls.
- Added WebSocket service helpers and request-shape tests for fan percentage/preset, media volume/source, and climate fan/preset changes.
- Updated preview Home Assistant data so fan, lock, media, and climate controls can be exercised in native previews.

### Service Feedback And Reconnect UX

- Added a dashboard freshness notice for cached, refreshing, and stale Home Assistant state with contextual refresh/reconnect actions.
- Made reconnect retry taps interrupt the backoff loop and attempt a connection immediately.
- Improved service-call failure copy when an action failure also starts socket recovery.
- Added lightweight haptics for dashboard control taps and service success/failure feedback.

### Dashboard Accessibility And Reduced Motion

- Added domain-aware VoiceOver labels for dashboard detail buttons and primary Home Assistant actions.
- Added explicit accessibility labels and values for dashboard detail sliders and context rows.
- Respected Reduce Motion for card press feedback, service banners, and dashboard skeleton loading.

### Home Assistant Service Discovery

- Added WebSocket `get_services` support so Homestead can discover the active Home Assistant service catalog.
- Stored service metadata separately from live entity state and treated it as optional startup metadata.
- Began using discovered services to hide unsupported optional detail controls once the catalog is loaded.

### OAuth Widgets And Dashboard State Cleanup

- Updated the widget control path to read the shared OAuth credential and refresh short-lived Home Assistant access tokens instead of looking for the removed long-lived token account.
- Added dashboard card display-name overrides while keeping Home Assistant entity names as the source data.
- Collapsed Devices dashboard membership into the main dashboard configuration and removed the separate membership store.
- Preserved last cached/live state timestamps when connection state becomes stale so UI can show the age of displayed Home Assistant data.
- Added basic network reachability monitoring to reconnect promptly when iOS reports connectivity returning.

## 2026-05-28

### Four-Column Dashboard Grid

- Replaced the dashboard's implicit two-column card layout with model-driven card spans on a 4-column grid foundation.
- Added mini, compact, square, wide, and large dashboard card sizes with reusable column/row metadata.
- Removed pre-release dashboard layout migration scaffolding so current card sizes persist directly.
- Promoted the card grid layout into the design system so non-dashboard card surfaces can share the same 4-column sizing model.
- Moved Areas summary cards onto the shared grid as square `2x2` cards while keeping their area-specific renderer.

### Dashboard Density Simplification

- Removed global Comfortable, Balanced, and Compact dashboard density modes so persisted card sizes are the single source of truth for grid layout.
- Removed the active-device dashboard filter and simplified the dashboard menu to editing only, with manual refresh handled by native pull-to-refresh.
- Reduced suggested first-run dashboard seeding to 10 cards to preserve the previous balanced starting footprint without a runtime visibility cap.

### Cached Registry Metadata

- Expanded the Home Assistant startup cache to include entity, device, and area registry metadata alongside entity state snapshots.
- Areas and device grouping now restore from cached registry metadata on relaunch instead of briefly treating everything as unassigned.
- Added native pull-to-refresh to Areas and entity browser lists, with refreshes updating both state and registry-backed organization.

## 2026-05-27

### Native OAuth Login

- Replaced manual long-lived access-token login with Home Assistant's OAuth2/IndieAuth native-app flow.
- Added `/auth/authorize` URL construction, `ASWebAuthenticationSession` callback handling, `/auth/token` authorization-code exchange, refresh-token grant support, and Keychain persistence for refresh tokens plus access-token expiry metadata.
- `HomeAssistantService` now refreshes short-lived access tokens before WebSocket connects/reconnects and documented HTTP calls, while transport clients still receive a current token through `HAConnectionConfiguration`.
- Settings now has a native Sign in with Home Assistant flow, signed-in/signed-out/expired/refresh-failed status, and sign-out cleanup for OAuth credentials plus mobile-app registration metadata.
- Mobile-app registration now runs automatically after OAuth sign-in when no matching registration is saved for the current Home Assistant server.

### Native App Registration And Auth Direction

- Added Home Assistant mobile/native app registration groundwork using the official `/api/mobile_app/registrations` HTTP surface while preserving WebSocket as Homestead's primary data/control plane.
- Persisted returned mobile-app registration metadata, especially `webhook_id`, outside SwiftUI so official companion-app handoffs such as `stream_camera` can be layered in without private frontend URLs.
- Reaffirmed the auth direction: HTTP remains for documented media/auth surfaces, mobile-app registration is only for official companion-app capabilities, and Homestead should use Home Assistant's OAuth2/refresh-token native app flow.

### Camera Capability Discovery

- Added Home Assistant `camera/capabilities` WebSocket support so Homestead can choose future live renderers from HA-reported frontend stream types instead of guessing.
- Camera details now surface discovered live modes alongside the authenticated snapshot path.

### Camera Snapshot Loading Foundation

- Added an authenticated HTTP camera snapshot path through `HomeAssistantService`, keeping SwiftUI views away from Home Assistant transport details.
- Camera details now attempt to load `/api/camera_proxy/{entity_id}` snapshots with a lightweight refresh control and graceful unavailable state.

### Media, Camera, And Vacuum Detail Flows

- Added native dashboard detail sheets for media players, cameras, and vacuums on top of the domain presentation registry.
- Added focused service actions for media play/pause and vacuum start, stop, and return-to-base while leaving cameras read-only until authenticated image loading is designed.

### Sensor Detail Flow

- Added native read-only dashboard detail sheets for sensors and binary sensors, preserving the generic raw entity detail for Devices.
- Routed sensor-style domains through the domain presentation registry and added preview sample data for binary sensors.

### Entity Domain Presentation Registry

- Added a central dashboard domain capability registry for common Home Assistant domains, covering card style, primary action, detail routing, status formatting, accent behavior, secondary actions, and service intent metadata.
- Kept dashboard cards per-entity observed while moving domain-specific presentation policy out of card routing.
- Added regression coverage for action, toggle, read-only, media, camera, vacuum, and fallback domain presentation behavior.

## 2026-05-26

### Area Detail And Toggle Controls

- Added domain counts to area summaries so Areas can show the leading Home Assistant domains in each area.
- Upgraded area detail pages with an overview card and domain-grouped entity sections.
- Added first-class detail sheets for switches, fans, and locks using existing Home Assistant service actions.

### Connection-Scoped Dashboard Organization

- Added Home Assistant data-source scoping so switching servers clears old cached/live state before showing the next source.
- Expanded first-class domain presentation for switches, fans, locks, media players, cameras, binary sensors, and vacuums.
- Added area registry metadata and made the Areas view use Home Assistant area names as source of truth, with unassigned entities grouped separately.
- Preserved dashboard items for temporarily missing entities while keeping visible cards limited to currently available entity IDs.
- Cleaned dashboard card edit controls and removed tracked Xcode user scheme management data.

### Cached Startup And Dashboard Foundation

- Added scoped Home Assistant state caching so the app can render last-known entities before live WebSocket sync completes.
- Added data freshness tracking for cached, refreshing, live, stale, and empty states.
- Kept startup state buffering, reconnect handling, registry metadata, service feedback, and per-entity `HAEntityState` from current `main`.
- Added persistent dashboard density, active-device filtering, dashboard membership controls, and an Areas tab.
- Centralized dashboard entity presentation metadata so cards, dashboard membership, areas, and devices do not branch on raw entity ID prefixes.
- Added regression coverage for cache scoping, preference and dashboard membership persistence, area grouping, and presentation routing.

## 2026-05-22

### Sensor Cards And Add-Card Filtering

- Compact dashboard cards now show headline values, making sensor readings visible without resizing cards.
- Sensor domain models now identify low-battery and alert-style states such as water, gas, and problem sensors.
- Alerting sensors use active card styling and clearer dashboard subtitles.
- The add-card sheet now has domain filters and hides unavailable entities by default while preserving the shared entity browser.

### Climate Dashboard Controls

- Added dashboard climate detail controls for target temperature and HVAC mode.
- Mapped Home Assistant climate metadata such as HVAC modes, min/max temperature, step, and unit into the domain model.
- Climate cards and generic entity details now present target/current temperature through the climate model.
- Added regression coverage for climate mapping and `set_temperature` request encoding.

### Cover Dashboard Controls

- Added dashboard actions and a focused detail sheet for Home Assistant cover entities.
- Covers now use WebSocket service calls for open, close, stop, and position changes.
- Dashboard cards and generic entity details show cover position/state through the cover domain model.
- Added regression coverage for cover mapping and `set_cover_position` request encoding.

### Scene And Script Dashboard Actions

- Added dashboard actions for Home Assistant scenes and scripts through the existing WebSocket service-call path.
- Scene and script card actions now surface success and failure through the global service feedback banner.
- Added sample preview scene/script entities and regression coverage for action-entity mapping.

### Dashboard Header Items

- Replaced separate dashboard entity and size storage with one ordered dashboard item list.
- Added user-created header items as full-width dashboard row breakers for lightweight grouping.
- Added an edit-mode reorder sheet backed by the ordered item list.
- Kept entity cards backed by Home Assistant state while header items remain local-only dashboard organization.
- Added regression tests for item persistence, header rename/removal, stale entity reconciliation, and addable entity filtering.

### Home Assistant Pending Confirmation Hardening

- Pending commands now clear only when a confirmed Home Assistant state satisfies the expected state and attributes.
- Stale snapshots can update confirmed state without dismissing pending UI feedback prematurely.
- Recoverable WebSocket request failures during service calls or refreshes now trigger reconnect handling.
- Kept broad entity projections fresh when live per-entity state changes.
- Added regression tests for stale snapshot handling, attribute confirmation, and cached projection updates.

### In-Place Dashboard Editing

- Replaced the separate dashboard edit sheet with an in-place edit mode on the dashboard.
- Cards now show lightweight corner controls for remove and size changes only while editing.
- Added a reusable entity browser list so Devices and the add-card sheet share grouping and search behavior.
- Live Home Assistant previews now keep dashboard card selection and sizing in preview-specific persistent defaults.

## 2026-05-21

### Added Project Memory Docs

- Added a root `README.md` with project purpose, structure, development commands, and credential guidance.
- Added `AGENTS.md` as durable coding-agent context.
- Added this development log.

### Dashboard Performance Pass

- Batched Home Assistant `state_changed` events before applying them to SwiftUI-observed state.
- Added per-entity observable state boxes so cards and rows can observe one entity instead of broad store dictionaries.
- Split stable entity catalog/grouping from live entity values.
- Moved Devices rows to per-entity observation.
- Replaced expensive dashboard material layers and heavy shadows with cheaper grouped iOS surfaces.
- Removed card-level active-state animation that could fire while scrolling.
- Verified with `xcodebuild` build and `HomesteadTests`.

Reason: live Home Assistant data with many entities made dashboard scrolling and light detail presentation laggy. The largest visible improvement came from reducing material/shadow compositing in dashboard cards.

### Live Home Assistant Previews

- Added a debug-only live Home Assistant preview path.
- Preferred credential source is local Keychain data entered through the app.
- Historical note: early live previews allowed environment-variable credentials before OAuth became the only supported login path.
- Preview credential setup is documented in `Docs/PREVIEW_CREDENTIALS.md`.

### Dashboard Customization And Light Controls

- Added dashboard membership configuration with editable ordering.
- Added light cards with tap-to-toggle behavior.
- Added a light detail sheet for brightness and power controls.
- Added optimistic updates for light state and brightness after successful service calls.

### Home Assistant Real-Time State Refactor

- Changed initial WebSocket sync to subscribe to `state_changed` before applying the `get_states` snapshot, buffering live events during the snapshot fetch.
- Removed optimistic writes from confirmed entity state; service calls now set pending UI command state and wait for Home Assistant state confirmation.
- Added monotonic state application, stable `HAEntityState` identity across snapshots, entity removal for `new_state: null`, WebSocket request timeouts, ping heartbeat, and foreground resume refresh.
- Added regression tests for stale update prevention, stable boxes, removal events, and pending command clearing.

### Home Assistant Foundation

- Established WebSocket-first architecture.
- Added `HAWebSocketClient`, `HomeAssistantService`, DTOs, domain models, `EntityMapper`, and `HAStateStore`.
- Kept SwiftUI views behind domain models instead of raw Home Assistant JSON.

## Maintenance Rules

- Add entries for major feature, architecture, performance, credential, or workflow decisions.
- Keep entries concise and dated.
- Do not include secrets, personal tokens, private network details, or long command output.
- Prefer links to docs and source files over repeating large explanations.
