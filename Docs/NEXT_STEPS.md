# Homestead Next Steps

This is the tactical handoff for the current active workstream. Keep it short and update it when a chunk completes, priorities change, or a new chat should pick up somewhere different.

For broader direction, read `Docs/PRODUCT_ROADMAP.md`. For API status and API research targets, read `Docs/API_CAPABILITY_INVENTORY.md`.

## Current Focus

Settings information architecture cleanup.

Recommended reasoning level: High.

## Next Chunk

- Preserve the top-level Settings account card and the large Home Assistant account/server header.
- Reorganize Settings into clearer native sections:
  - Home Assistant: Server, People, Devices & Services, Automations & Scenes, Updates, Logbook.
  - Homestead: Notifications, Widgets, Live Activities, Permissions, iCloud Sync.
  - About remains available from Settings.
- Convert `Devices & Services` and `Automations & Scenes` from segmented picker destinations into overview pages with native rows that push to focused list/detail pages.
- Add honest placeholders for destinations whose backend/API support is not implemented yet.

## Acceptance Notes

- Settings should feel like an iOS account/settings hub, not a mini app with nested segmented controls.
- Browse remains the daily-use entity discovery/control surface.
- Settings remains the admin, registry, diagnostics, and companion-app configuration surface.
- Do not remove the account card/header unless a later design decision explicitly replaces them.
- Do not add private Home Assistant frontend APIs for unsupported management pages.

## After This Chunk

- Build the richer Server page and API mapping.
- Then move to Notifications, Logbook, Updates, Weather, and History/Charts in roadmap order unless priorities change.
