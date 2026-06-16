# Agent Instructions

This file is durable context for coding agents working on Homestead. Keep it short, practical, and current.

## Project Shape

Homestead is a native SwiftUI iOS frontend for Home Assistant. Home Assistant owns backend logic, integrations, devices, entities, automations, scenes, scripts, and service execution. Homestead should stay a focused native UI.

Use Home Assistant's expected API shape whenever possible. The app is WebSocket-first for core state, events, registries, and service calls. Do not add REST, mobile-app/webhook, or custom URL paths unless a specific Home Assistant feature is officially exposed that way.

For product direction, existing feature inventory, likely next work, and intentionally deferred ideas, read `Docs/PRODUCT_ROADMAP.md`.

For tactical handoff, definition of done, token budget guidance, fresh-chat handoffs, reasoning-level defaults, UI verification expectations, and major decision records, read `Docs/NEXT_STEPS.md`, `Docs/DEVELOPMENT_WORKFLOW.md`, and `Docs/ADR/README.md`.

## Important Architecture

- `HAWebSocketClient` owns socket transport, authentication, request/response routing, state snapshots, event subscription, and service calls.
- `HomeAssistantService` is the UI-facing controller for connection state and user intents.
- `HAStateStore` is the single source of truth for entity state.
- DTOs in `Core/HomeAssistant` should not be read directly by SwiftUI views.
- `EntityMapper` converts Home Assistant DTOs into domain models.
- Dashboard cards should observe per-entity state through `HAEntityState` where possible to avoid broad store invalidation.
- Live Home Assistant updates are batched before touching SwiftUI state. Preserve that unless profiling proves it is unnecessary.
- Use documented Home Assistant APIs in their intended roles: WebSocket for the main data/control plane, HTTP for documented media or auth surfaces, and native-app/mobile-app registration only for companion-app capabilities that require it.

## UI Direction

Aim for a polished native iOS feel inspired by Apple Home:

- Soft grouped surfaces
- Large comfortable touch targets
- Minimal chrome
- SF Symbols
- Clear typography hierarchy
- Smooth interactions
- Prefer user-facing product surfaces over development or explanation surfaces. Avoid visible labels, helper text, badges, or descriptions that explain implementation details, layout mechanics, API capabilities, or why a control exists unless the user needs that information to decide.
- When a visual preview, familiar control, or direct manipulation communicates the choice, prefer that over explanatory copy. Dashboard customization should feel like choosing and arranging Home controls, not configuring schema.

Be careful with `.regularMaterial`, `.thinMaterial`, large shadows, and implicit animations inside scrolling grids. These caused real dashboard lag with live Home Assistant data.

## Credentials

Do not commit Home Assistant URLs, tokens, personal Xcode schemes, or generated user data. Live preview setup is documented in `Docs/PREVIEW_CREDENTIALS.md`.

## Useful Commands

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:HomesteadTests test
```

If the named simulator is unavailable, inspect local simulators and choose an installed iPhone runtime.

Prefer focused tests over broad simulator test suites unless the change truly needs a broad run. After any `xcodebuild test`, check Xcode storage growth with the commands in `Docs/DEVELOPMENT_WORKFLOW.md`, mention unusual `~/Library/Developer/XCTestDevices` growth in the summary, and recommend cleanup instead of deleting caches silently.

For repeatable physical-device performance profiling, use `Docs/PERFORMANCE_PROFILING.md`.

## Git Hygiene

- Preserve user-made asset changes unless explicitly asked to modify them.
- Do not revert unrelated work.
- Keep commits focused.
- After completing a self-contained requested change, default to committing it once relevant verification passes, unless the user asks not to commit, the work is exploratory or unfinished, verification fails, or unrelated user changes would make a focused commit unsafe.
- If a completed change is not committed, explain why and leave the worktree state clear.
- Update `Docs/DEVELOPMENT_LOG.md` only for meaningful architecture, performance, feature, or workflow milestones.

## Current Priorities

Likely next product work is tracked in `Docs/PRODUCT_ROADMAP.md`. Keep this file short and update the roadmap when priorities or feature direction meaningfully change.

When completing roadmap/API-related work, update `Docs/PRODUCT_ROADMAP.md` and `Docs/API_CAPABILITY_INVENTORY.md` if feature status, priority, API confidence, or deferred scope changed.

When completing or changing the active workstream, update `Docs/NEXT_STEPS.md` so the next chat can resume without relying on chat history.
