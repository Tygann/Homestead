# Release Candidate: 1.0 (133)

October 16, 2026. Production source: `c6ddd27223779bc8e3fd92a5cf8b43a2774024f0` plus build-number metadata changed from 1 to 133. No production Swift, dashboard schema, or dependency changes. Initial preparation produced a local candidate; subsequent authorized device acceptance and TestFlight upload are recorded below.

## Numbering And Evidence Boundary At Preparation

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

## Device-Notification Checklist At Preparation

This was the checklist at the local preparation boundary. See the authorized device follow-up below for subsequent acceptance. No notification send, phone install, or upload was performed during candidate preparation.

1. After an explicit install request, upgrade the existing phone installation to the identified candidate without deleting its app data, Home Assistant entry, or Keychain credentials. Record app version/build, iOS version, and Home Assistant version. Confirm the intended server/profile, iOS notification authorization, and Homestead notification registration status. Do not infer a successful migration from simulator mocks or the old installed build.
2. With Homestead open in the foreground, send a uniquely labeled test through the phone's actual Home Assistant notification service after notification sending is authorized. Confirm visible delivery on the phone and record the label/time and user confirmation; check banner/list/sound against the phone's enabled settings and Focus state. A successful HA service response alone is insufficient. Source requests banner/list/sound/badge in `HomesteadAppDelegate.willPresent`, but that is not delivery evidence.
3. Background/lock the candidate installation and send a distinct labeled notification. Confirm actual receipt on this build. The earlier user-confirmed background message applies only to the previous installed build. Where a supported destination is included, tap it and verify the intended profile/entity opens.
4. Relaunch the candidate (process restart), confirm registration returns ready, and repeat a labeled notification. Check that the existing registration remains usable and no unintended duplicate was created. Earlier isolated Keychain reopen/upgrade/recovery evidence does not substitute for the installed-device upgrade/restart path. Do not delete the user's HA registration to exercise recovery.
5. Record foreground/background results and any platform suppression separately. Keep distribution export success distinct from Apple upload validation, processing, and tester availability. Only a later explicit upload request authorizes those steps; recheck numbering first.

At preparation, candidate-device notification acceptance and foreground delivery remained open. Physical-device reconnect/control/performance checks remain separately scoped; no speedup is claimed.


## Authorized Device Acceptance Follow-Up

October 16, 2026. User authorized proceeding with the candidate upgrade and notification checks. Wi-Fi device connection recovered on retry after an initial connection reset; no USB connection was needed. Device reported iPhone 15 Pro / iOS 27.0.1 and existing Homestead 1.0 (132).

- Prepared a separate `release-testing` export from the same validated archive: `/tmp/Homestead-c6ddd27-133-DeviceExport/Homestead.ipa`. Initial offline export lacked Ad Hoc profiles; retry with automatic provisioning succeeded despite the existing stale-account warning. Both app and widget profiles cover this phone, `get-task-allow=false`, and app `aps-environment=production`. Strict signatures, manifest/source equality, forbidden import checks, version/minimum OS, and all three dSYM UUIDs passed again. Binary UUIDs equal the archive/App Store export. This Ad Hoc package exercises production push but is separate from the App Store IPA and does not establish TestFlight installation/processing acceptance.
- Device IPA SHA-256: `a3fb0be666b8f89cc75c568570d3e1c6fb67ba11c298d8330a43cff3bbe10dfb`.
- Installed over the existing app without uninstalling or clearing data. `devicectl` confirmed installed version 1.0 (133), then successfully launched it. Device install/launch evidence: `/tmp/Homestead-133-phone-{before,install,launch}.json`; install log `/tmp/Homestead-133-phone-install.log`.
- Home Assistant still reports 2026.10.1. Sent only to the existing Homestead Tyler iPhone notification service; no other household device was targeted. Foreground label “Homestead 133 foreground check” returned HA HTTP 200 at 12:10:52 CDT. User confirmed it appeared while Homestead was open and Notifications showed ready. This closes candidate foreground delivery/readiness; source presentation options alone were not treated as acceptance.
- Captured the post-upgrade mobile-entry ID set (14 entries) locally before the planned process-relaunch check. There was no pre-upgrade entry snapshot in this session, so this cannot prove the upgrade created no duplicate registration. No personal registration was manually removed or reset.

- Background label “Homestead 133 background check” returned HA HTTP 200 at 12:11:56 CDT after the user confirmed the phone was locked. User confirmed receipt, tapping it opened Homestead, and the saved dashboard remained intact. This checks app opening from a plain notification; no entity-specific notification destination was included or accepted.
- Relaunch: the combined terminate/launch command initially failed to report a PID; a plain launch retry succeeded. The original process was PID 60609, the new process PID 60650, and a subsequent process query confirmed it running. This supplies process-restart evidence, not device-reboot evidence. The post-relaunch HA mobile-entry ID set exactly matched the post-upgrade baseline (14 entries), so no new entry appeared across this restart. Relaunch label “Homestead 133 relaunch check” returned HA HTTP 200 at 12:12:39 CDT; user confirmed receipt after restart, Notifications still ready, and the dashboard intact.

**Gate status after Ad Hoc acceptance:** candidate 133 Ad Hoc production-push upgrade, foreground delivery, locked/background delivery, plain-notification app opening, and process-relaunch delivery/readiness passed on this iPhone with user confirmation. Entity-specific tap routing, device reboot, physical-device performance, and TestFlight installation are not inferred. Next release step is live App Store Connect numbering verification followed by an explicitly authorized upload and Apple processing/tester-readiness checks. No upload or tester distribution occurred. Original `8095e34` evidence and the App Store IPA remain unchanged. Documentation-only follow-up passed `git diff --check`; no new build/tests or storage cleanup were needed.


## Authorized TestFlight Upload

October 16, 2026. User authorized continuing with the TestFlight upload. Live App Store Connect showed 132 as the highest build and highest completed upload before submission; no newer pending upload was present. The existing App Store version 1.0 submission was Waiting for Review with build 125 and was left unchanged. Build 132 was observed Testing with existing internal and external groups; that does not imply candidate 133 external distribution.

- Re-ran `prepare_webrtc_symbols.py`; the archive already contained exact matching WebRTC symbols. Rechecked archive version, signatures, privacy/imports, and dSYM matches. The retained App Store IPA SHA-256 remained `c4b5ee82abb25c3e0e9636bc63a6983cad26181cbca0576d2c4bd3d437ee0d60`.
- Uploaded from the same validated archive using `xcodebuild -exportArchive`, `method=app-store-connect`, `destination=upload`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`, and automatic provisioning. Upload succeeded at **1:14 PM CDT**. Raw log: `/tmp/Homestead-c6ddd27-133-upload.log`; options: `/tmp/Homestead-133-upload-options.plist`. Existing stale-account warning did not block upload; no missing-WebRTC-symbol warning was emitted in the upload log.
- App Store Connect initially showed **1.0 (133), Processing**, created October 16 at 1:14 PM. Processing subsequently reached **Complete**; build status is **Ready to Submit** for external testing. Build ID: `b7885899-3506-4309-b584-15e30b4c3311`.
- Prepared What to Test copy from `NextTestFlight.md` was saved; the UI showed Saved and a reload verified the full copy persisted. The existing **Internal Testers** group attached automatically, with one tester. No new tester/group was created, no external group was attached, and no beta-review submission or App Store submission change was made. TestFlight installation itself remains unverified.
- [App Store Connect build 133](https://appstoreconnect.apple.com/teams/c58dd4a6-87c7-40b5-8990-7e83a354c675/apps/6771905390/testflight/ios/b7885899-3506-4309-b584-15e30b4c3311). Build 133 is the new uploaded release-history boundary.
