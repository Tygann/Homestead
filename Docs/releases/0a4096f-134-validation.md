# Local Release Candidate: 1.0 (134)

October 16, 2026. Production source: `0a4096f` (including reliability implementation `588b68c` and relay source `5b5dce2`) plus build-number metadata. All ten target configurations use 134; marketing version remains 1.0 and minimum iOS remains 26.5. No production source, dependency, asset, or dashboard schema changes were needed during candidate preparation.

## Artifacts and signing

- Signed Release archive: `/tmp/Homestead-0a4096f-134-Release.xcarchive`. Automatic development provisioning succeeded, including the newly embedded notification content extension.
- Local App Store Connect export: `/tmp/Homestead-0a4096f-134-Export/Homestead.ipa`. Export options explicitly set `destination=export`, `manageAppVersionAndBuildNumber=false`, and `method=app-store-connect`. No upload occurred. Xcode emitted its existing missing account-token warning but completed export with distribution provisioning for all three bundles.
- IPA SHA-256: `93706f5ab9e68a4d5027d3b951624390209e9c9bf5b1e7d00707d54604b24674`.
- Archive and extracted IPA passed `codesign --verify --deep --strict`; each app/extension also passed individual strict verification. Bundle identifiers, team identifiers, profile application-ID coverage, expiration, version, and deployment target checks passed. Exported profiles expire May 21, 2027, have no device list/all-device provisioning, and disable debugging. The app has `aps-environment=production`; app/widget retain `group.com.tyler.Homestead`. The content extension requires no shared container or push entitlement.
- Exported notification extension metadata identifies `com.apple.usernotifications.content-extension`, `HomesteadNotificationContent.NotificationViewController`, and category `HomesteadDynamic`. This establishes packaging/signing, not actual expanded system notification behavior.
- `python3 Scripts/prepare_webrtc_symbols.py /tmp/Homestead-0a4096f-134-Release.xcarchive` installed exact matching pinned WebRTC 155.0.0 symbols before export. Archive and exported binaries match all four arm64 dSYMs:

| Binary | UUID |
| --- | --- |
| Homestead | `4756D4D8-B087-32E9-B1EF-A0897A4C816C` |
| HomesteadWidgets | `FDF04788-A585-3753-BD1A-238D0653FB6A` |
| HomesteadNotificationContent | `1FE55577-41CB-335D-8A04-6CEB07D95350` |
| WebRTC | `4C4C44F0-5555-3144-A190-21F9C2A35CDA` |

Both first-party privacy manifests decode identically to source in archive and IPA; WebRTC's supplier manifest is present. The notification content extension only renders notification text/actions and introduces no apparent required-reason API use. The app imports arc4random and does not import `_fstat`, `_stat`, `_lstat`, `_statfs`, `_fstatfs`, or `_mach_absolute_time`. Camera usage description is present; microphone usage description and bundled `PreviewCredentials.json` are absent. These are local artifact checks, not Apple processing approval.

## Verification

Debug iPhone 17 / iOS 26.5 build passed through XcodeBuildMCP, with the existing WebRTC field-trial deprecation warning. Release archive and local distribution export passed. Relay `npm test` passed all nine tests and `npm run typecheck` passed without deployment.

A single serial simulator invocation passed **176 tests, zero failures/skips**, confirmed by `xcresulttool get test-results summary`. Selected suites: `DashboardConfigurationXCTests`, `HAClientHardeningTests`, `HAWebSocketOptimizationTests`, `NativeNotificationRegistrationTests`, `RemainingRecommendationsTests`, `WidgetTargetedStateTests`, `WidgetInfrastructureContractTests`, `WidgetSensorBoardTests`, `EntityPresentationCoreTests`, `SharedFeaturePresentationTests`, `HomesteadWidgetDeepLinkTests`, `WidgetSnapshotPersistenceTests`, and `HomesteadPlusTests`. Destination: iPhone 17 / iOS 26.5 (`8B9EB520-361C-40F3-B8A3-70E331595509`), Debug, `-parallel-testing-enabled NO`, `TEST_RUNNER_HOMESTEAD_LIVE_PREVIEW=1` to isolate test-host startup from normal registration. No live acceptance harness ran. Result bundle: `/tmp/Homestead-134-tests.xcresult`.

Storage hygiene ran immediately afterward: XCTestDevices remained **0 B**, below 5 GB; no cleanup occurred. DerivedData (5.2 GB) and CoreSimulator (32 GB) remained report-only.

No visible product code changed in this preparation. The rendered light/dark dashboard, widget, entity, and Settings evidence recorded in [the reliability contracts](../HA_RELIABILITY_CONTRACTS.md) retains its original scope; no new notification UI acceptance is inferred. Independent read-only release review found no blocker in extension integration, source changes, origin isolation, or metadata. Final diff review and whitespace validation passed.

Raw artifacts remain outside Git: `/tmp/Homestead-134-{archive,symbols,archive-checks,export,export-checks,tests,hygiene,relay-tests,relay-typecheck}.log`, `/tmp/Homestead-134-tests.xcresult`, `/tmp/Homestead-134-export-options.plist`, `/tmp/homestead-134-check.py`, and `/tmp/homestead-134-tests.py`. The extracted IPA is under `/tmp/Homestead-134-IPA-check`. These temporary paths may not survive system cleanup.

## Authorization and remaining acceptance

Build 133 remains the recorded uploaded boundary; 134 is a local candidate selected from that boundary. Live App Store Connect numbering was not queried. Recheck highest uploaded/processing numbering before any later upload and rebuild/re-export if 134 has been consumed. ReleaseHistory.md is unchanged.

No relay deployment, phone installation, notification send (including simulated pushes), household action, upload, or distribution occurred. Each requires a later explicit authorization. Existing build-133 phone acceptance remains scoped to that build. Local signing/provisioning acceptance for the new extension is complete; actual expanded notification UI, background/cold-launch routing, buttons/replies/cancellation, accessibility and small-screen/Dynamic Type behavior remain device acceptance. Production origin/category forwarding still requires separately authorized relay deployment. Real partial-feature entity actions, offline rename/reconnect, and live latency remain as recorded in the reliability contracts; no performance improvement is claimed.
