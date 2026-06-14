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
