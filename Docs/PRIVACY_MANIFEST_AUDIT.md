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

Both target directories use Xcode filesystem-synchronized groups with only `Info.plist` excluded. Each target owns its own `PrivacyInfo.xcprivacy`; no project-file membership workaround is necessary. WebRTC 155.0.0 is the sole pinned package and is linked only into the app. Its supplier manifest remains separate from the app's first-party declarations.

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
