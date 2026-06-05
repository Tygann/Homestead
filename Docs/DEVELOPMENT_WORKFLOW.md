# Homestead Development Workflow

This document captures the working agreement for agentic coding sessions. Keep it practical and update it only when the workflow changes.

## Start Of Work

- Read `AGENTS.md` first.
- For product work, also read `Docs/PRODUCT_ROADMAP.md`, `Docs/API_CAPABILITY_INVENTORY.md`, and `Docs/NEXT_STEPS.md`.
- Inspect the worktree before editing and preserve unrelated user changes.
- Prefer small, self-contained implementation chunks that can be verified and committed cleanly.

## Definition Of Done

- The requested behavior is implemented end to end, not just sketched.
- Relevant build and tests pass, or skipped verification is explicitly explained.
- SwiftUI views do not consume Home Assistant transport DTOs directly.
- Home Assistant API usage follows the official API family documented for that feature.
- Roadmap/API docs are updated if feature status, priority, API confidence, or deferred scope changed.
- `Docs/DEVELOPMENT_LOG.md` is updated for meaningful architecture, performance, feature, or workflow milestones.
- The work is committed after verification when it is self-contained and safe to commit.

## Verification Defaults

- For Swift app code changes, run:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'generic/platform=iOS Simulator' build
```

- For state, mapping, service, persistence, or presentation-helper changes, also run focused Swift tests where practical:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:HomesteadTests test
```

- If the named simulator is unavailable, inspect local simulators and choose an installed iPhone runtime.
- Docs-only changes do not require a build.

## UI Verification

- Use previews, sample data, simulator runs, or screenshots when touching visible app structure, navigation, dashboard cards, Settings, or reusable chrome.
- Check light and dark appearance when changing surfaces, rows, cards, toolbars, sheets, or navigation transitions.
- Check small-screen behavior when text, rows, segmented controls, tab items, or toolbar clusters change.
- Avoid heavy materials, large shadows, and implicit animations in scrolling dashboard grids unless profiling supports the change.
- Mention any UI verification that was not practical in the final response.

## Commit Behavior

- Keep commits focused and name the user-visible or architectural outcome.
- Commit completed, verified, self-contained work by default.
- Do not commit if the work is exploratory, unfinished, failing verification, or mixed with unrelated user changes.
- If not committing a completed change, explain why.
