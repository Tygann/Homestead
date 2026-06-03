# Homestead

Homestead is a native SwiftUI iOS frontend for Home Assistant.

Home Assistant remains the backend and source of truth for integrations, devices, entities, automations, scenes, scripts, and service calls. Homestead focuses on being a polished Apple-style mobile interface for the parts of Home Assistant you use most.

## Current Status

Homestead currently includes:

- WebSocket-first Home Assistant connection flow
- Native Home Assistant OAuth2/IndieAuth sign-in with refresh-token storage through Keychain
- Live entity state updates through `state_changed` events
- Optimistic light toggles and brightness updates
- Dashboard membership with editable ordering
- Devices/Entities list grouped by Home Assistant domain
- Live Home Assistant Xcode previews for local development
- A small reusable SwiftUI design system

## Architecture

The app is intentionally small and feature-oriented:

- `Homestead/App`: app entry points, previews, and root view composition
- `Homestead/Core`: Home Assistant client, state store, models, mapping, credentials, utilities
- `Homestead/Features`: Dashboard, Devices, and Settings screens
- `Homestead/DesignSystem`: shared spacing, radius, card, icon, and button primitives
- `Docs`: project architecture and development notes

More detail lives in [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md).

## Local Development

Open `Homestead.xcodeproj` in Xcode and run the `Homestead` scheme.

Useful command-line checks:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:HomesteadTests test
```

The simulator destination may need to change if your installed simulator differs.

## Live Preview Credentials

Live Home Assistant previews are supported, but credentials should stay local. See [Docs/PREVIEW_CREDENTIALS.md](Docs/PREVIEW_CREDENTIALS.md).

Never commit Home Assistant tokens, local scheme files containing tokens, or generated Xcode user data.

## Agent Notes

Future coding-agent context lives in [AGENTS.md](AGENTS.md) and the short project log in [Docs/DEVELOPMENT_LOG.md](Docs/DEVELOPMENT_LOG.md).
