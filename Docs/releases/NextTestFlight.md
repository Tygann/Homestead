# TestFlight Notes: 1.0 (133)

Prepared October 16, 2026 for version 1.0 build 133 from `c6ddd27` plus build-number metadata, covering changes since build 132 (`e0d02a1`). Build 133 was uploaded with user authorization after live numbering verification; it is now the release-history boundary. See [candidate 133 validation](c6ddd27-133-validation.md) for processing and acceptance status.

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

The deleted-registration and static-libsodium fixes supersede the two original blockers only after the follow-up checks in the validation record. Existing reconnect, dashboard, statistics, and background-delivery evidence remains scoped to its recorded build/device. Candidate 133 now has user-confirmed production-push Ad Hoc device acceptance for foreground/locked delivery, plain-notification app opening, saved dashboard preservation, and process-relaunch delivery/readiness. See its separate validation record for limits. The authorized upload and Apple processing completed. Build 133 is Ready to Submit for external testing, its What to Test notes are saved, and the existing one-person Internal Testers group attached automatically. TestFlight installation remains distinct from the accepted Ad Hoc install. Build 133 is now the uploaded release-history boundary. External tester distribution and the current App Store submission were not changed.
