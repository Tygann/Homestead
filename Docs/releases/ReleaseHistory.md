# Homestead Release History

This document tracks user-facing update notes for Homestead builds uploaded to TestFlight or App Store Connect. It is not a full development changelog and should not list every commit.

Entries are newest first. Use this as the published-build boundary when preparing future release notes: compare recent project changes against the most recent entry here to identify what users have not already seen.

## Future Workflow

1. Before uploading a new TestFlight or App Store build, ask Codex to compare project changes since the latest release-history entry.
2. Generate concise user-facing update notes from meaningful product, reliability, performance, and polish changes. Prioritize the few changes with the most tester value instead of summarizing every workstream.
3. Append the finalized notes to this file with the version, build number, release date, and optional internal source notes.
4. Commit the release-history update with the build-related changes.
5. Optionally, later introduce git tags to mark shipped builds and improve release-note generation accuracy:
   - `testflight-YYYY-MM-DD`
   - `tf-version-build`

Keep entries human-readable and focused on what testers or App Store users should know. Internal summaries are useful only when they help future release-note generation.

## Note Style

Write notes for the audience and channel:

- TestFlight notes may include a short `Please test` section because testers are being asked to exercise specific flows.
- Public App Store notes should skip tester instructions and focus on what changed, what is new, and what improved.
- Lead with new features or the highest-value user-visible changes. Put polish, performance, reliability, and bug fixes after that unless they are the main reason for the release.
- Avoid generic "bug fixes and improvements" when significant product changes shipped. Name the changes in plain user-facing language.
- Default to one short introductory sentence and 3-5 bullets total. Combine related work and omit implementation details, minor iterations, and exhaustive lists.
- For TestFlight, add only 2-4 targeted test prompts covering the riskiest or most important flows. Do not repeat every release-note bullet.
- Keep each bullet to one line where practical, start with the user benefit, and use direct language without marketing filler.
- Aim for roughly 60-120 words of pasteable TestFlight copy. Go longer only when testers need essential setup or safety instructions.

## Entry Template

```markdown
## Version X.Y (Build N)

- Release Date: YYYY-MM-DD
- Channel: TestFlight or App Store

### User-Facing Release Notes

This update adds [new/highest-value changes] and improves [main improvement area].

- ...
- ...

Please test:

- [2-4 focused flows for TestFlight only]

### Internal Summary

Optional notes about the major source changes covered by this release.
```

## Version 1 (Build 122)

- Release Date: 2026-08-03
- Channel: TestFlight

### User-Facing Release Notes

This build makes widgets easier to configure and improves Home Assistant updates, apps, activity, and Homestead+ plans.

- Choose widget entities more reliably, including when shared Home Assistant data is still loading
- Find Supervisor apps faster with search, clearer status rows, and update availability that adapts to each app
- See updates grouped by their Home Assistant source, with more polished fallback artwork
- Read geolocation activity with friendlier state descriptions
- Review and change Homestead+ plans in a clearer layout, including subscription renewal dates

Please test:

- Adding or editing several widgets immediately after launching the app
- Searching Home Assistant apps and reviewing available app and system updates
- Switching Homestead+ plans, confirming purchase actions, and checking renewal information

### Internal Summary

Build 122 covers widget entity-picker loading resilience; source-aware update grouping and fallback artwork; Supervisor app search, status, and update-availability refinements; formatted geolocation activity states; and a redesigned Homestead+ plan-selection experience with intentional plan changes and subscription renewal dates after Build 121.

## Version 1 (Build 121)

- Release Date: 2026-07-31
- Channel: TestFlight

### User-Facing Release Notes

This build adds per-dashboard personalization and richer Home Assistant management in Settings.

- Give each dashboard its own wallpaper, including separate appearance and blur choices
- Review Home Assistant updates and apps in polished detail screens with release notes, version information, and security details when available
- Explore a redesigned Activity timeline with clearer context, filtering, and loading states
- Enjoy more consistent dashboard cards and widgets, plus more reliable Homestead+ entitlement and iCloud profile recovery
- Find simpler notification, permission, iCloud sync, and safety settings

Please test:

- Assigning different wallpapers to multiple dashboards, then switching, editing, and relaunching
- Opening Home Assistant update and app details, including release notes and available actions
- Filtering Activity across several event types and time ranges
- Restoring Homestead+ access and iCloud-synced profiles after a fresh launch or reinstall

### Internal Summary

Build 121 covers per-dashboard wallpaper persistence and controls; native update release notes and unified Supervisor app/update detail presentation; the redesigned Activity timeline; shared dashboard/widget presentation architecture; specialized card refinements; TestFlight entitlement recovery; iCloud profile restoration; registry-decoding resilience; and Settings polish for notifications, permissions, iCloud sync, and action confirmations after Build 116.

## Version 1 (Build 116)

- Release Date: 2026-07-28
- Channel: TestFlight

### User-Facing Release Notes

This build introduces Homestead+ and makes entity details feel more consistent.

- Start a Homestead+ trial or choose a monthly, annual, or lifetime plan
- Unlock additional dashboards and Home Assistant servers, iCloud dashboard sync, and the full Sensor Board widget lineup
- Keep everyday Home Assistant control, your first dashboard and server, and wallpaper personalization free
- See cleaner, more consistent status placement across entity details

Please test:

- Starting a trial or purchase, restoring purchases, and confirming Homestead+ access updates correctly
- Adding extra dashboards and servers, enabling iCloud sync, and opening each Sensor Board widget size
- Confirming existing premium configurations remain intact if Homestead+ access ends

### Internal Summary

Build 116 covers the StoreKit 2 Homestead+ entitlement and purchase experience, cached entitlement sharing with widgets, premium scale-feature gates, iCloud and widget handling, purchase-flow polish and verification, and unified entity-detail hero status placement after Build 114.

## Version 1 (Build 114)

- Release Date: 2026-07-26
- Channel: TestFlight

### User-Facing Release Notes

This build makes dashboard chips more personal and dashboard management easier to reach.

- Tap entity chips to open details, or edit their name, icon, entity, and dashboard placement
- See clearer chip and Mini card layouts, including profile photos for Person entities
- Open Manage Dashboards directly from Home to reorder and organize your dashboards
- Move between dashboards more reliably, with smoother paging and editing behavior
- Enjoy a cleaner empty-dashboard experience that adapts to your Home wallpaper

Please test:

- Opening and editing several entity chips, including a Person chip with a profile photo
- Reordering dashboards from Home's Manage Dashboards action
- Paging between dashboards, then editing cards and chips without changing pages

### Internal Summary

Build 114 covers transactional entity-chip editing and detail navigation, Person imagery, standardized Mini cards, dashboard pager sizing and edit-mode locking, direct Home dashboard management, native dashboard reordering, and wallpaper-aware empty states after Build 113.

## Version 1 (Build 113)

- Release Date: 2026-07-24
- Channel: TestFlight

### User-Facing Release Notes

This build makes dashboards easier to move through, brings clearer controls and support options, and restores flexible Sensor Board setup.

- Swipe between multiple dashboards with native paging that keeps the content and screen chrome feeling at home on iPhone
- Choose options from clearer, more capable controls across dashboard cards and entity details
- Find Home Assistant help, diagnostics, and native permission settings in a more organized Settings experience
- Customize Sensor Board gauges again, including the individual slots in small and large widgets

Please test:

- Swiping between dashboards with one, two, and several pages, including at the top and bottom of a long dashboard
- Changing Select and Climate controls from both dashboard cards and entity details
- Opening Settings to review Home Assistant support, diagnostics, and permission access
- Configuring different gauges in the available Sensor Board widget slots

### Internal Summary

Build 113 covers native local dashboard paging and safe-area refinement; capability-aware option menus, entity controls, diagnostics, and Home Assistant handoff destinations; consolidated Settings support and permission presentation; and restored configurable Sensor Board gauge slots after Build 112.

## Version 1 (Build 112)

- Release Date: 2026-07-24
- Channel: TestFlight

### User-Facing Release Notes

This build refreshes entity details, weather, dashboard editing, and Sensor Board widgets.

- Control thermostats from a redesigned detail view with clearer modes, setpoints, and history
- See cleaner entity details, richer forecasts, and surfaces that adapt to your Home wallpaper
- Edit dashboard cards with an entity-first flow while keeping saved dashboards intact through upgrades
- Enjoy weather cards that adapt to time of day and load forecasts more reliably
- Build flexible Sensor Board widgets with interchangeable slots and a new large 3×3 layout

Please test:

- Opening several entity details over both plain and wallpaper dashboard backgrounds
- Adjusting thermostat modes and temperatures, then reviewing history and weather forecasts
- Editing an existing dashboard card and confirming your dashboards remain intact
- Configuring small and large Sensor Board widgets with different sensor combinations

### Internal Summary

Build 112 covers the entity-detail hierarchy and shared control/history grammar; the premium thermostat instrument; contextual wallpaper-aware detail surfaces; weather forecast and solar-phase card refinements; entity-first contextual card editing; ordered dashboard schema migration and recovery; shared chart rendering; configurable small and large Sensor Board widgets; widget consolidation; and the new widget reference gallery after Build 111.

## Version 1 (Build 111)

- Release Date: 2026-07-21
- Channel: TestFlight

### User-Facing Release Notes

This build brings richer entity details and more capable dashboard cards.

- Explore redesigned details with clearer status, activity, and history across sensors, presence, weather, and more
- View live weather forecasts and edit Number, Text, and Date & Time helpers directly in Homestead
- Use refined Chart cards with selectable ranges, deeper statistics, and touch exploration
- Add the same entity or card more than once, or change an existing card's entity without rebuilding it
- Enjoy dedicated Weather, Media, and Action card layouts with improved readability and controls

Please test:

- Opening several entity types, including Presence, Weather, and editable helpers
- Changing a Chart range, opening its detail view, and exploring history values
- Adding a duplicate card and changing an existing card to a compatible entity

### Internal Summary

Build 111 covers the capability-driven entity-detail grammar and operational-state system; live forecast subscriptions; native Presence, editable Number/Text/Date & Time, and chart-first Sensor details; dedicated Chart, Weather, Media, and Action dashboard compositions; repeatable entity-backed cards; in-place compatible entity replacement; per-card Chart ranges; and the final Weather, history, card-menu, accessibility, and visual-polish passes after Build 109.

## Version 1 (Build 109)

- Release Date: 2026-07-17
- Channel: TestFlight

### User-Facing Release Notes

This build adds multi-server support and streamlines dashboard card setup.

- Add, switch, reorder, and manage multiple Home Assistant servers without repeatedly signing out
- Keep dashboards and wallpaper settings tied to the correct server profile
- Add and configure cards in one consistent flow, with circular and bar gauges as focused individual cards
- See thermostat temperatures, available update counts, and smoother accented gauge visuals

Please test:

- Adding a second server and confirming each server keeps the correct dashboards and wallpaper
- Reordering and switching servers from Account, including returning to the original server
- Adding several dashboard card types, especially circular and bar gauges

### Internal Summary

Build 109 covers multi-server connection profiles and profile-scoped app, widget, dashboard, cache, registration, and appearance state; the Account-centered server-management flow; dashboard card configuration unification and atomic gauge cards; climate summary temperatures; Settings update counts; accented widget gauge refinements; and related Settings polish after Build 107.

## Version 1 (Build 107)

- Release Date: 2026-07-15
- Channel: TestFlight

### User-Facing Release Notes

This build adds multi-gauge Home Screen widgets and brings more consistent presentation across Homestead's dashboards and widgets.

- New medium widget for monitoring three gauges at a glance
- New large widget with room for up to nine gauges
- Tap supported widgets to open the related content in Homestead
- Cleaner dashboard loading and empty states, refined entity details, and better icon sizing

Please test:

- Adding and configuring the new medium and large gauge widgets with different gauge counts
- Tapping widgets to open Homestead and confirming the expected destination appears
- Reviewing dashboard loading, empty states, entity details, and the add-to-dashboard flow

### Internal Summary

Build 107 covers the medium and large gauge-grid widgets, shared app/widget feature presentation and deep links, dashboard skeleton and empty-state polish, entity-detail refinements, Material Design icon optical sizing, add-confirmation dismissal, and final gauge readout alignment work after Build 104.

## Version 1 (Build 104)

- Release Date: 2026-07-13
- Channel: TestFlight

### User-Facing Release Notes

This build refines gauge widgets and dashboard readouts for a cleaner, more legible glance at your Home Assistant data.

- Easier-to-read gauge values and units with improved spacing and hierarchy
- Better handling of longer gauge readouts across dashboard and widget layouts
- Corrected the activity icon shown in presence history

Please test:

- Checking short and long gauge values and units in dashboard cards and widgets
- Reviewing gauges at different sizes and with different zone configurations
- Opening presence history and confirming the activity icon is correct

### Internal Summary

Build 104 covers the gauge readout layout and spacing pass across `GaugePresentationView` and `WidgetGaugeInstrumentView`, plus the presence-history activity icon fix.

## Version 1 (Build 103)

- Release Date: 2026-07-13
- Channel: TestFlight

### User-Facing Release Notes

This build adds more control and context to dashboards, widgets, and Home Assistant automation details.

- Give individual sensor widgets their own display names for clearer at-a-glance information
- Customize gauge zone names and colors, with automatic mode keeping the presentation focused
- See clearer script targets, automation conditions, actions, and choice branches
- Smoother dashboard browsing and more reliable Appearance and avatar refresh behavior

Please test:

- Renaming sensor widgets and checking the names in dashboard and widget views
- Editing gauge zone names and colors in both manual and automatic modes
- Opening automations and scripts with grouped conditions, actions, and targets
- Switching Appearance settings and refreshing account/avatar content

### Internal Summary

Build 103 covers per-widget sensor display names, custom gauge zone names and colors with automatic-mode handling, expanded automation/script target and branch presentation, SwiftUI browsing/dashboard update optimization, and appearance/avatar refresh fixes after Build 101.

## Version 1 (Build 101)

- Release Date: 2026-07-10
- Channel: TestFlight

### User-Facing Release Notes

This build makes dashboards easier to personalize and adds richer ways to view Home Assistant data.

- Redesigned Add to Dashboard flow with clearer, live card previews
- New and refined gauge styles, including configurable zones and expanded sensor widget displays
- More useful automation details with readable conditions, actions, and choice branches
- Refreshed app icon, appearance controls, and Home Assistant management navigation

Please test:

- Adding and configuring dashboard cards, especially gauges and zone ranges
- Sensor widgets and automation detail views
- Devices & Services navigation and Appearance settings

### Internal Summary

Build 101 covers the post-Build 16 dashboard presentation and add-flow redesign, gauge and widget consolidation, configurable segmented gauge zones, automation overview and branch presentation, Home Assistant-style management organization, appearance color controls, refreshed app icon, shared Xcode Cloud scheme, and Xcode 27 Cloud compatibility fixes.

## Version 1.0 (Build 16)

- Release Date: 2026-06-26
- Channel: TestFlight

### User-Facing Release Notes

This update adds remote Home Assistant notifications and further polishes saved-dashboard setup and customization.

What's new:

- Home Assistant notifications can now arrive when Homestead is not open
- Notification setup now registers the device for remote delivery through Home Assistant

Improvements:

- Saved dashboards now keep their Settings name separate from the title shown on the dashboard
- Dashboard previews and detail actions in Settings have a cleaner, more consistent layout
- Notification registration and reconnect handling are more reliable

Please test:

- Allowing notifications during setup or from Settings > Notifications
- Receiving a Home Assistant notification while Homestead is closed or in the background
- Existing notification setups after updating from an earlier build
- Renaming a saved dashboard separately from its displayed dashboard title
- Dashboard previews and detail actions in Settings

### Internal Summary

Build 16 covers the post-Build 15 remote-push pass: app-side APNs registration, Home Assistant mobile-app `push_url` registration and repair, the deployed push relay and connect page, plus saved-dashboard name/title separation and focused Settings dashboard preview/detail polish.

## Version 1.0 (Build 15)

- Release Date: 2026-06-24
- Channel: TestFlight

### User-Facing Release Notes

This update adds multiple saved dashboards and refines Settings so dashboard management, Appearance, and Home Assistant administration feel clearer and more native.

What's new:

- Create and manage multiple saved dashboards from Settings
- Choose the active dashboard and edit dashboard names, grouping, and visibility with a more visual preview
- Dashboard grouping preferences now persist across launches and iCloud Sync

Improvements:

- Settings has a cleaner organization for Dashboard, Appearance, permissions, sync, and Home Assistant management
- Home Assistant management lists now show more useful metadata and more consistent grouping
- Appearance settings have been simplified with clearer wallpaper, tab, and navigation controls
- User-facing connection, notification, sync, and support wording is less technical
- Home Assistant OAuth now uses the updated Homestead client domain

Please test:

- Creating, renaming, switching, and removing saved dashboards in Settings
- Dashboard grouping and visibility choices after relaunching the app
- Settings > Appearance, including wallpaper, tab, and navigation preferences
- Settings > Devices & Services management lists and metadata
- Home Assistant sign-in and reconnect behavior

### Internal Summary

Build 15 covers the June 23-24 settings and dashboard-management pass after Build 14: multiple saved `DashboardConfiguration` records, active-dashboard selection, saved dashboard persistence through iCloud Sync, dashboard settings preview extraction and polish, management list metadata/grouping improvements, persisted grouping preferences for entity and management lists, Settings information-architecture cleanup, Appearance settings simplification, less technical user-facing copy, and the updated Home Assistant OAuth client domain.

## Version 1.0 (Build 14)

- Release Date: 2026-06-23
- Channel: TestFlight

### User-Facing Release Notes

This update focuses on faster, calmer startup and reconnect behavior, with more stable dashboard summaries and extra polish across widgets, cameras, wallpapers, and setup.

What's new:

- Cached Home Assistant state now appears sooner at launch, so the app can show your dashboard while it reconnects
- Homestead now retries cold-launch connection setup automatically when the first attempt hits a transient failure
- Dashboard summary chips and summary views now keep a more stable Home Assistant-style order
- Sensor gauge widgets now support the same glanceable gauge presentation used in the app

Improvements:

- Reduced startup flicker, including unnecessary onboarding flashes and transient reconnect banners
- Improved dashboard summary performance and reduced repeated summary recalculation
- Camera previews and authenticated Home Assistant images are more resilient during temporary snapshot or network failures
- Areas and area details better match Home Assistant's floor, area, and device organization
- Wallpaper card controls, area chips, climate controls, sliders, and widget snapshots received visual and reliability polish
- OAuth sign-in, mobile app registration naming, and visible error wording are more consistent

Please test:

- Launching the app from a signed-in cold start, especially after force quit or poor network conditions
- Cached dashboard behavior while Home Assistant reconnects
- Dashboard summary chip ordering, summary detail views, and Areas organization
- Camera cards, image-heavy views, and sensor gauge widgets
- Setup/sign-in retry behavior and Account connection status wording

### Internal Summary

Build 14 covers the June 16-23 reliability, startup, dashboard, widget, image, and area-organization pass after Build 13: cached launch hydration before the first signed-in frame, automatic cold-launch retry, suppressed transient reconnect chrome, fallback/error presentation cleanup, dashboard summary workspace reuse and stable ordering, dashboard history caching, camera snapshot hardening, Home Assistant image caching, iOS 27 AsyncImage adoption where available, sensor gauge widgets, Home Assistant-style area sectioning, OAuth sign-in correction, mobile-app registration naming refinements, and targeted wallpaper/dashboard visual polish.

## Version 1.0 (Build 13)

- Release Date: 2026-06-15
- Channel: TestFlight

### User-Facing Release Notes

This update improves setup, restore, account settings, and multi-device support, with safer Home Assistant routing when you use both local and remote addresses.

What's new:

- New setup flow with explicit iCloud restore or new-home choices before sign-in
- User-initiated Home Assistant discovery for local servers, with manual address entry still available
- Opt-in iCloud Sync for small Homestead preferences such as dashboard layout, appearance settings, and server routing metadata
- iPad support and Apple silicon Mac availability through Designed for iPad

Improvements:

- Settings > Account now has a cleaner Server overview with focused Internal URL and External URL editors
- Local Address routing can be limited to saved Wi-Fi networks, so Homestead uses the Remote Address away from home
- Settings > Devices & Services now includes read-only Integrations and Helpers surfaces instead of placeholder rows
- Mobile App registration is more stable and avoids creating repeated cloned devices during preview/development sessions
- Dashboard active-state styling and fan percentage controls have been polished
- More Home Assistant icons now map to native SF Symbols where there is a clear match

Please test:

- Fresh setup, iCloud restore, Home Assistant discovery, and manual sign-in
- Account > Server editing for Internal URL, External URL, and saved Wi-Fi networks
- Connecting both on a saved home Wi-Fi network and away from it
- Settings > Devices & Services > Integrations and Helpers
- iPad and Apple silicon Mac layouts if available

### Internal Summary

Build 13 covers the June 14-15 setup/account/support pass after Build 12: unified setup and iCloud bootstrap, user-triggered Bonjour discovery, opt-in iCloud preference sync, SSID-gated local routing, Account Server editor polish, iPad and Designed for iPad Mac support clarification, Settings placeholder completion, preview-safe Mobile App registration identity, fan slider/dashboard active-state polish, and expanded curated MDI-to-SF icon mappings.

## Version 1.0 (Build 12)

- Release Date: 2026-06-14
- Channel: TestFlight

### User-Facing Release Notes

This update adds Homestead wallpaper personalization, a smoother first-run setup flow, and more polished Home Assistant summary views.

What's new:

- New Settings > Appearance page for choosing a local wallpaper for Homestead
- Wallpapers appear behind Home, Areas, area details, and summary views without uploading anything to Home Assistant
- New first-run setup experience for entering your Home Assistant server and starting sign-in
- Security summary now includes a native activity view with recent locks, doors, cameras, people, and related events

Improvements:

- Dashboard cards, chips, and controls now use a more adaptive material style that works better with wallpapers, light mode, and dark mode
- Area cards now use Home Assistant area icons when available, with better room icon fallbacks
- Generated Home Assistant-style cards now choose better defaults across summaries, area views, and Add to Dashboard
- Summary views better match Home Assistant grouping for floors, areas, and device categories

Please test:

- Choosing, changing, disabling, and removing a wallpaper in Settings > Appearance
- Home, Areas, area detail, and summary views in both light and dark mode with a wallpaper enabled
- Fresh install setup and Home Assistant sign-in
- Security activity, area icons, and generated card defaults

### Internal Summary

Build 12 covers the June 13-14 personalization and polish pass after Build 11: global local-only wallpaper support, wallpaper-aware material card surfaces, Appearance preview polish, first-run onboarding, Security activity presentation/caching/attribution, area icon resolution, summary hierarchy alignment, and generated-card default refinements.

## Version 1.0 (Build 11)

- Release Date: 2026-06-13
- Channel: TestFlight

### User-Facing Release Notes

This update adds a native Apps/Add-ons status page, more dashboard customization, and better Home Assistant summary views.

What's new:

- New Settings > Apps page for installed Home Assistant Supervisor apps/add-ons
- App rows show running/stopped status, versions, update availability, and add-on artwork when available
- New dashboard icon picker with searchable SF Symbols and smart-home recommendations
- New gauge-style dashboard and detail visuals for supported numeric sensors

Improvements:

- Dashboard summary groups now more closely match Home Assistant's own Climate, Lights, Security, Media, and Maintenance behavior
- Select option controls are easier to tap and use
- Settings organization and Apps detail pages have been cleaned up for easier scanning

Please test:

- Settings > Apps on Home Assistant Supervisor installs
- Apps/Add-ons artwork, status, detail pages, and unavailable state handling
- Dashboard icon picker search/recommendations and sensor gauge cards

### Internal Summary

Build 11 covers the June 12-13 feature/polish pass after Build 10: Supervisor Apps via Home Assistant Core's `supervisor/api` bridge and add-on artwork proxy paths, dashboard icon picker, Home Assistant summary alignment, reusable sensor gauges, select-option tap refinements, and Settings reordering.

## Version 1.0 (Build 10)

- Release Date: 2026-06-11
- Channel: TestFlight

### User-Facing Release Notes

This build adds Home Screen widgets, richer Settings pages, entity history, and smoother dashboard customization.

What's new:

- Home Screen widgets for controls, status, graphs, scenes, and scripts
- New Settings pages for Updates, Logbook, Permissions, Notifications, and People
- History charts and recent activity timelines for more entity types
- Native Weather support and expanded entity detail views

Improvements:

- Better dashboard editing, drag reordering, mini cards, and add-card customization
- More polished widget setup, previews, and entity pickers
- Improved startup, reconnect behavior, notification delivery, and internal/external URL switching

Please test:

- Adding and configuring Home Screen widgets
- Dashboard editing and card reordering
- Settings pages and entity history views
- Reconnect behavior after app launch or returning from the Home Screen

## Version 1.0 (Build 8)

- Release Date: 2026-06-02
- Channel: TestFlight

### User-Facing Release Notes

- Drastically improved overall app speed
- Added camera cards
- Improved navigation transitions
- Expanded known entity/domain types

## Version 1.0 (Build 7)

- Release Date: 2026-06-01
- Channel: TestFlight

### User-Facing Release Notes

This build focuses on dashboard customization, reusable card controls/features, performance optimization, and overall native iOS polish.

Please test:

- Dashboard card/chip editing and layout customization
- Card feature controls (brightness, climate, locks, covers, etc.)
- Areas browsing and quick controls
- Scrolling/navigation smoothness and responsiveness
- Home Assistant reconnect/state update reliability

Recent improvements:

- Cleaner dashboard edit interactions
- New reusable card feature system
- Improved Areas/Dashboard feature behavior
- Performance optimizations across Areas, Dashboard, and Devices
- More consistent Home Assistant-native naming/icon behavior

## Version 1.0 (Build 5)

- Release Date: 2026-05-30
- Channel: TestFlight

### User-Facing Release Notes

This build focuses on dashboard refinement, Home Assistant connection reliability, diagnostics/support UX, and overall native iOS polish.

Please test:

- Home Assistant sign-in and reconnect behavior
- Dashboard cards, chips, and layout customization
- Entity controls and detail screens
- Settings/Diagnostics flows
- General responsiveness and UI consistency

Known limitations:

- Some entity domains may still have basic card/detail experiences
- iPad-specific layout polish is still in progress
- UI/interaction refinement is ongoing based on real-world usage
