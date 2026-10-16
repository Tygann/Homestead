# Next TestFlight Draft

Prepared October 16, 2026 for local version 1.0 build 133 from `c6ddd27` plus build-number metadata, using version 1.0 build 132 (`e0d02a1`) as the last published boundary. No upload or distribution is recorded by this draft. See [candidate 133 validation](c6ddd27-133-validation.md); recheck live App Store Connect numbering before any later upload.

## What to Test

```text
This build improves dashboard reliability and sensor history.

- Keep saved dashboard cards when devices temporarily become unavailable, with controls returning as devices recover
- Explore 30-day measurement charts with older hourly averages where Home Assistant provides compatible statistics
- More reliable reconnection, sign-in renewal, and notification registration, including recovery after a Home Assistant registration is deleted

Please test:

- Return after a connection interruption and check dashboard cards, order, and selected dashboard
- Upgrade an existing installation and check notification delivery while open and in the background
- Compare 30-day charts for measurement sensors and check gaps where history is missing
```

## Release Gates

See [8095e34 validation evidence](8095e34-validation.md). Keep unresolved acceptance items explicit; do not infer delivery from a successful Home Assistant service call or App Store readiness from a development-signed archive.

The deleted-registration and static-libsodium fixes supersede the two original blockers only after the follow-up checks in the validation record. Existing reconnect, dashboard, statistics, and background-delivery evidence remains scoped to its recorded build/device. Foreground notification delivery and candidate-device acceptance remain open. Local candidate 133 has a separate validation record; its export does not establish device acceptance or Apple processing. Build 132 remains the published boundary. This task does not upload or distribute a build.
