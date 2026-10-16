# Release Candidate: 1.0 (133)

October 16, 2026. Production source: `c6ddd27223779bc8e3fd92a5cf8b43a2774024f0` plus build-number metadata changed from 1 to 133. No production Swift, dashboard schema, or dependency changes. This is a local candidate, not an uploaded or fully accepted release.

## Numbering And Evidence Boundary

- `ReleaseHistory.md` records version 1.0 build 132 (`e0d02a1`) as the last published build. All eight Debug/Release target settings now use 133; marketing version stays 1.0. This avoids relying on Organizer to renumber a build-1 archive.
- 133 is selected from the repository boundary. Live App Store Connect availability could not be verified: the existing Firefox tab could not be selected because computer automation stalled. Recheck the highest uploaded/processing build before any future upload; rebuild/re-export with a higher number if 133 has been consumed.
- [Original validation and follow-up](8095e34-validation.md) remain unchanged. Their reconnect, dashboard, statistics, isolated encrypted registration recovery, Keychain reopen, cleanup, and installed-phone background delivery results retain their original source/device scope. They do not become new physical-device evidence for 133.
- The old archives/IPA are retained separately. `ReleaseHistory.md` remains unchanged because nothing was uploaded. Draft tester copy remains in `NextTestFlight.md`.

## Local Artifact Validation

- Debug iPhone 17 / iOS 26.5 build passed through XcodeBuildMCP. Signed Release archive passed at `/tmp/Homestead-c6ddd27-133-Release.xcarchive`; archive uses development provisioning. Both app and widget contain version 1.0 build 133; minimum iOS is 26.5.
- Ran `Scripts/prepare_webrtc_symbols.py` before export; pinned WebRTC 155.0.0 symbols installed successfully. Matching arm64 UUIDs: app `4AE75513-6FB0-3B75-91C4-697BD811AC5F`, widget `5E81DF2B-7214-3A06-88C6-9109B19C9959`, WebRTC `4C4C44F0-5555-3144-A190-21F9C2A35CDA`.
- Local `app-store-connect` export passed: `/tmp/Homestead-c6ddd27-133-Export/Homestead.ipa`. Export options explicitly used `destination=export` and `manageAppVersionAndBuildNumber=false`. No upload, Apple processing, or distribution was performed. Xcode logged the existing missing account-token warning but completed export with available signing assets.
- IPA SHA-256: `c4b5ee82abb25c3e0e9636bc63a6983cad26181cbca0576d2c4bd3d437ee0d60`.
- Both archived and extracted exported apps pass `codesign --verify --deep --strict`. Exported entitlements contain `aps-environment=production`, `beta-reports-active=true`, and `get-task-allow=false`. Exported app/widget/framework binaries match the archive dSYMs.
- Both first-party privacy manifests decode identically to source in archive and IPA; WebRTC's separate manifest is present. App executable imports the arc4random backend and does not import `_fstat`, `_stat`, `_lstat`, `_statfs`, `_fstatfs`, or `_mach_absolute_time`. This confirms the prior dependency fix remains in this artifact; it is not a blanket Apple privacy approval.
- Camera usage declaration is present; microphone usage declaration and `PreviewCredentials.json` are absent in both app bundles. Existing WebRTC field-trial deprecation warning remains.
- Logs and scratch checks stay outside Git: `/tmp/Homestead-c6ddd27-133-{archive,symbols,archive-checks,export,tests,hygiene}.log`, `/tmp/Homestead-c6ddd27-133-imports.txt`; extracted IPA under `/tmp/Homestead-c6ddd27-133-IPA-check`.

## Verification Scope

Passed **92 tests**: 21 client-hardening, 62 dashboard-configuration, eight statistics, and one notification-registration test, with zero failures. Focused simulator selectors: `HomesteadTests/HAClientHardeningTests`, `HomesteadTests/HAStatisticsTests`, `HomesteadTests/DashboardConfigurationXCTests`, and `HomesteadTests/NativeNotificationRegistrationTests`. Serial iPhone 17 / iOS 26.5 run with `TEST_RUNNER_HOMESTEAD_LIVE_PREVIEW=1` to isolate test-host startup from normal registration. Result bundle: `/tmp/Homestead-c6ddd27-133-tests.xcresult`. No new disposable live registration harness or rendered UI run was needed for metadata-only changes; the prior scoped acceptance remains preserved.

Storage hygiene ran after the test invocation: XCTestDevices remained zero, below the 5 GB threshold; no cleanup ran. DerivedData (6.2 GB) and CoreSimulator (32 GB) were report-only. Final review and `git diff --check` passed; the only project changes are the eight build-number settings. Historical validation and release-history files remain untouched.

## Remaining Device-Notification Acceptance

These are later user-authorized steps; no notification send, phone install, or upload was performed during candidate preparation.

1. After an explicit install request, upgrade the existing phone installation to the identified candidate without deleting its app data, Home Assistant entry, or Keychain credentials. Record app version/build, iOS version, and Home Assistant version. Confirm the intended server/profile, iOS notification authorization, and Homestead notification registration status. Do not infer a successful migration from simulator mocks or the old installed build.
2. With Homestead open in the foreground, send a uniquely labeled test through the phone's actual Home Assistant notification service after notification sending is authorized. Confirm visible delivery on the phone and record the label/time and user confirmation; check banner/list/sound against the phone's enabled settings and Focus state. A successful HA service response alone is insufficient. Source requests banner/list/sound/badge in `HomesteadAppDelegate.willPresent`, but that is not delivery evidence.
3. Background/lock the candidate installation and send a distinct labeled notification. Confirm actual receipt on this build. The earlier user-confirmed background message applies only to the previous installed build. Where a supported destination is included, tap it and verify the intended profile/entity opens.
4. Relaunch the candidate (process restart), confirm registration returns ready, and repeat a labeled notification. Check that the existing registration remains usable and no unintended duplicate was created. Earlier isolated Keychain reopen/upgrade/recovery evidence does not substitute for the installed-device upgrade/restart path. Do not delete the user's HA registration to exercise recovery.
5. Record foreground/background results and any platform suppression separately. Keep distribution export success distinct from Apple upload validation, processing, and tester availability. Only a later explicit upload request authorizes those steps; recheck numbering first.

Candidate-device notification acceptance and foreground delivery remain open. Physical-device reconnect/control/performance checks remain separately scoped; no speedup or new device/UI acceptance is claimed.
