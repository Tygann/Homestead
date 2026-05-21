# Agent Instructions

This file is durable context for coding agents working on Homestead. Keep it short, practical, and current.

## Project Shape

Homestead is a native SwiftUI iOS frontend for Home Assistant. Home Assistant owns backend logic, integrations, devices, entities, automations, scenes, scripts, and service execution. Homestead should stay a focused native UI.

The app is WebSocket-first. Do not add a REST layer unless a specific Home Assistant feature clearly requires it.

## Important Architecture

- `HAWebSocketClient` owns socket transport, authentication, request/response routing, state snapshots, event subscription, and service calls.
- `HomeAssistantService` is the UI-facing controller for connection state and user intents.
- `HAStateStore` is the single source of truth for entity state.
- DTOs in `Core/HomeAssistant` should not be read directly by SwiftUI views.
- `EntityMapper` converts Home Assistant DTOs into domain models.
- Dashboard cards should observe per-entity state through `HAEntityState` where possible to avoid broad store invalidation.
- Live Home Assistant updates are batched before touching SwiftUI state. Preserve that unless profiling proves it is unnecessary.

## UI Direction

Aim for a polished native iOS feel inspired by Apple Home:

- Soft grouped surfaces
- Large comfortable touch targets
- Minimal chrome
- SF Symbols
- Clear typography hierarchy
- Smooth interactions

Be careful with `.regularMaterial`, `.thinMaterial`, large shadows, and implicit animations inside scrolling grids. These caused real dashboard lag with live Home Assistant data.

## Credentials

Do not commit Home Assistant URLs, tokens, personal Xcode schemes, or generated user data. Live preview setup is documented in `Docs/PREVIEW_CREDENTIALS.md`.

## Useful Commands

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:HomesteadTests test
```

If the named simulator is unavailable, inspect local simulators and choose an installed iPhone runtime.

## Git Hygiene

- Preserve user-made asset changes unless explicitly asked to modify them.
- Do not revert unrelated work.
- Keep commits focused.
- Update `Docs/DEVELOPMENT_LOG.md` only for meaningful architecture, performance, feature, or workflow milestones.

## Current Priorities

Likely next product work:

- Improve dashboard card detail flows
- Add better entity filtering and dashboard organization
- Expand domain-specific cards for sensors, covers, climate, scenes, and scripts
- Add user-facing error handling for service calls and reconnects
- Profile with Instruments before doing another large performance pass
