# Privacy Manifest Audit

Audited October 15, 2026 against Apple's [required-reason API list and approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) and [per-bundle manifest requirements](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

## First-Party Source Audit

Scope: all Swift sources in `Homestead`, `HomesteadWidgets`, and `Shared`, including shared target membership and Debug-only code. The assessment's empty app required-reason array and missing widget manifest are corrected.

| Bundle | Category / reasons | Verified use |
| --- | --- | --- |
| Homestead.app | UserDefaults / `CA92.1` | App-owned settings, dashboards, connection profiles, appearance, and `@AppStorage` preferences; preview-only suites are app-owned too. Examples: `DashboardConfiguration`, `HAConnectionSettings`, `HomesteadAppearanceSettings`, and `ContentView`. |
| Homestead.app | UserDefaults / `1C8F.1` | `Core/Widgets/WidgetSharedStore.swift`, shared `WidgetServerSnapshotStore`, and `HomesteadPlusEntitlementCache` exchange app-owned profiles, widget snapshots, and entitlement state within `group.com.tyler.Homestead`. |
| Homestead.app | SystemBootTime / `35F9.1` | `CameraICECandidateSummary.swift` uses `ProcessInfo.systemUptime` only inside `#if DEBUG` to measure elapsed milliseconds between in-app ICE events. The single manifest covers both configurations; this is not a claim of direct Release uptime access. No raw uptime is transmitted. |
| HomesteadWidgets.appex | UserDefaults / `1C8F.1` | Extension `Infrastructure/WidgetSharedStore.swift` and shared snapshot/entitlement helpers use only the same App Group suite. No extension-local defaults reason is needed. |

No direct first-party file-timestamp, available-disk-space, or active-keyboard required-reason API calls were found. Ordinary cache/wallpaper file operations do not justify declaring those categories. `CACurrentMediaTime()` in HLS decoded-frame selection is not on Apple's enumerated required-reason API list; neither it nor Swift clock abstractions justify speculative declarations.

The app's existing Device ID / linked / App Functionality / no-tracking collection declaration is preserved. It is not copied into the widget, which does not register notification relay device identifiers. Required-reason declarations do not change collection behavior, system permission prompts, or App Store privacy responses.

## Bundle Integration And Verification

Both target directories use Xcode filesystem-synchronized groups with only `Info.plist` excluded. Each target owns its own `PrivacyInfo.xcprivacy`; no project-file membership workaround is necessary. At the October 15 audit boundary, WebRTC 155.0.0 was the sole pinned package and was linked only into the app. The October 16 swift-sodium addition requires the follow-up below. Its supplier manifest remains separate from the app's first-party declarations.

Verified locally on October 15:

- XcodeBuildMCP Debug simulator build passed for iPhone 17 / iOS 26.5.
- Signed Release device archive succeeded at `/tmp/HomesteadPrivacyReadiness-20261015.xcarchive`; both first-party manifests decode identically to their checked-in source at `Products/Applications/Homestead.app/PrivacyInfo.xcprivacy` and `Products/Applications/Homestead.app/PlugIns/HomesteadWidgets.appex/PrivacyInfo.xcprivacy`.
- Archived `Frameworks/WebRTC.framework/PrivacyInfo.xcprivacy` separately declares SystemBootTime (`35F9.1`, `8FFB.1`) and FileTimestamp (`C617.1`), with no collected data or tracking. Supplier declarations were preserved, not copied into first-party bundles.
- Deep strict code-signature verification passed; no preview credentials were bundled. The only archive compiler warning was the existing deprecated `RTCInitFieldTrialDictionary` call.
- Plist lint, exact first-party reason-set assertions, unchanged app collection/tracking assertions, independent read-only review, and `git diff --check` passed. No Swift behavior or UI changed, so XCTest and rendered UI checks were unnecessary; no XCTestDevices cleanup was triggered.
- No build was exported or uploaded, and the existing App Store submission was not accessed or altered. This correction is local and is not retroactively present in uploaded build 132 or the existing submission.

For future releases, archive locally and compare the decoded resources rather than relying only on source membership:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/HomesteadPrivacyReadiness.xcarchive archive
python3 - /tmp/HomesteadPrivacyReadiness.xcarchive <<'PY'
import plistlib
import sys
from pathlib import Path

app = Path(sys.argv[1]) / 'Products/Applications/Homestead.app'
for source, bundled in [
    (Path('Homestead/PrivacyInfo.xcprivacy'), app / 'PrivacyInfo.xcprivacy'),
    (Path('HomesteadWidgets/PrivacyInfo.xcprivacy'),
     app / 'PlugIns/HomesteadWidgets.appex/PrivacyInfo.xcprivacy'),
]:
    assert plistlib.loads(source.read_bytes()) == plistlib.loads(bundled.read_bytes()), bundled
    print(f'Verified {bundled}')
assert (app / 'Frameworks/WebRTC.framework/PrivacyInfo.xcprivacy').is_file()
PY
```

This checks resource inclusion and equality, not Apple processing or review acceptance. Follow the existing WebRTC symbol preparation workflow before any later export/upload; a privacy audit itself requires neither.

## October 16 Candidate Follow-Up: swift-sodium

Candidate `8095e34` adds swift-sodium 0.11.0 and its static Clibsodium binary (bundled header reports libsodium 1.0.22). All three archived manifests still pass inclusion/equality checks, but the earlier dependency audit does not establish this candidate's complete required-reason coverage.

`xcrun nm -u` on the signed Release app reports `_fstat`; `nm -A -u` on the package's device `libsodium.a` locates it in the sysrandom/internal-random objects. The package has no supplier privacy manifest, and the app has no FileTimestamp declaration. The Swift wrapper source scan found no additional defaults/uptime/file-metadata calls. Upstream [sysrandom source](https://github.com/jedisct1/libsodium/blob/1.0.22-RELEASE/src/libsodium/randombytes/sysrandom/randombytes_sysrandom.c) uses `fstat` to validate the random device's `st_mode`.

Apple [lists fstat in required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). Resolve this binary dependency's use against an applicable approved reason or a reviewed dependency/build alternative before release. Do not silently add app-container reason `C617.1` for `/dev/random` access; the scope differs. No speculative declaration or binary replacement was made during validation. This is a privacy readiness gap, not an observed App Store rejection; successful local export does not establish Apple validation acceptance. See [candidate evidence](releases/8095e34-validation.md).

### Resolution: pinned source rebuild

The follow-up replaces swift-sodium's prebuilt C library with the local package at `Vendor/Sodium`. Its Swift sources remain upstream 0.11.0; `Scripts/rebuild_sodium.sh` builds unmodified libsodium 1.0.22 with normal upstream configure and `CPPFLAGS=-DHAVE_SAFE_ARC4RANDOM` for iOS arm64 and simulator arm64/x86_64. This selects libsodium's existing `arc4random`/`arc4random_buf` backend instead of its random-device metadata check. Apple's [system RNG documentation](https://developer.apple.com/documentation/swift/systemrandomnumbergenerator) identifies `arc4random_buf` as its Apple-platform implementation. Normal `sodium_init()`, secretbox authentication, nonce generation, and the Swift API are preserved.

No FileTimestamp reason is added for `/dev/random`. The first-party manifests and WebRTC supplier manifest retain their existing declarations. The unused internal-RNG archive member may still reference `fstat`; the acceptance boundary is the linked Release executable. Recheck its imports on every dependency update, rather than treating the XCFramework's presence or manifest equality as sufficient. Source provenance, checksum, target scope, and rebuild instructions are recorded in `Vendor/Sodium/README.md`.

Follow-up verification results are appended to [the candidate validation record](releases/8095e34-validation.md); the original October 16 failure evidence above is retained as the pre-fix boundary.
