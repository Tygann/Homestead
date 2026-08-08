# App Store Screenshots

## Recommended Upload Set

The version 1.0 App Store Connect page requests the 6.5-inch slot, so upload `iPhone-6.5-Marketing` in filename order:

1. `01-home.jpg` — Your home, beautifully organized
2. `02-areas.jpg` — Every room at a glance
3. `03-history.jpg` — Understand what changed
4. `04-customize.jpg` — Dashboards made for you
5. `05-widgets.jpg` — Powerful widgets, right where you need them
6. `06-homestead-plus.jpg` — More home with Homestead+

Each file is a `1284 x 2778` JPEG without an alpha channel. The first three communicate the core product before the customization and paid-feature story. `iPhone-6.9-Marketing` retains the equivalent `1320 x 2868` set for future slots that accept Apple's newer 6.9-inch sizes.

The required iPad slot uses `iPad-13/01-home.jpg`, a `2064 x 2752` JPEG without alpha. It presents the same fictional Home dashboard in Homestead's adaptive four-column iPad layout.

## Source Set

`iPhone-6.9` contains clean simulator captures at the same accepted dimensions. Keep these as the fallback if App Review requests screenshots without headline treatments.

## Regeneration

Run the composer with the bundled Codex Python runtime or any Python environment that provides Pillow:

```sh
python3 Scripts/compose_app_store_screenshots.py
```

The composer preserves the source UI and only adds the background, headline, framing, and shadow.
