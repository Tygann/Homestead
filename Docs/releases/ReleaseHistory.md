# Homestead Release History

This document tracks user-facing update notes for Homestead builds uploaded to TestFlight or App Store Connect. It is not a full development changelog and should not list every commit.

Entries are newest first. Use this as the published-build boundary when preparing future release notes: compare recent project changes against the most recent entry here to identify what users have not already seen.

## Future Workflow

1. Before uploading a new TestFlight or App Store build, ask Codex to compare project changes since the latest release-history entry.
2. Generate concise user-facing update notes from meaningful product, reliability, performance, and polish changes. Lead with new user-visible features, then meaningful improvements, then reliability or fix notes.
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
- Keep the final App Store copy short enough to scan on a phone. A brief intro plus a few bullets is usually enough.

## Entry Template

```markdown
## Version X.Y (Build N)

- Release Date: YYYY-MM-DD
- Channel: TestFlight or App Store

### User-Facing Release Notes

This update adds [new/highest-value changes] and improves [main improvement area].

What's new:

- ...
- ...

Improvements:

- ...
- ...

Please test:

- Include this section for TestFlight builds only.
- Omit this section for public App Store release notes.

### Internal Summary

Optional notes about the major source changes covered by this release.
```

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
