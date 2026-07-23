---
name: homestead-ios-verify
description: Verify Homestead Swift, SwiftUI, Home Assistant mapping/service, documentation, and visible UI changes end to end. Use for implementation or bug-fix work in the Homestead repository that needs compilation, focused tests, simulator or in-app browser inspection, Xcode storage hygiene, final diff review, or commit-readiness evidence; also use the lightweight path for documentation-only changes.
---

# Homestead iOS Verify

Follow the smallest verification path that proves the requested outcome. Read `AGENTS.md` and `Docs/DEVELOPMENT_WORKFLOW.md` before acting when they have not already been loaded.

## Classify the change

- Treat Markdown-only and instruction-only changes as documentation work.
- Treat Swift, project, mapping, service, state, persistence, test, or build-setting changes as code work.
- Treat visible SwiftUI, navigation, card, widget, Settings, or reusable-chrome changes as visual work in addition to code work.
- Expand verification only when the risk or user request requires it.

## Verify documentation work

1. Run `git diff --check`.
2. Inspect the final diff for accuracy, stale references, duplicated guidance, and accidental secret or generated-file inclusion.
3. Skip the app build unless documentation changed a command, route, or file contract that must be verified from source.

## Verify code work

1. Compile early. Prefer XcodeBuildMCP when the Build iOS Apps plugin is available:
   - Inspect session defaults before the first build, run, or test operation.
   - Set `/Users/tyler/Developer/Homestead/Homestead.xcodeproj`, scheme `Homestead`, configuration `Debug`, and an explicit installed simulator when needed.
   - Use `build_sim` for compilation or `build_run_sim` when runtime proof is required.
2. Fall back to:

   ```sh
   xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'generic/platform=iOS Simulator' build
   ```

3. Run the smallest focused test selectors covering the changed behavior. Use an installed iPhone runtime rather than assuming a missing destination. Do not start with the full suite unless the change or user explicitly requires it.
4. After every `xcodebuild test` or XcodeBuildMCP test operation, run `Scripts/xcode_storage_hygiene.sh` and report whether its guarded `XCTestDevices` cleanup ran. Never automatically delete DerivedData or normal Simulator data.
5. Finish with `git diff --check`.

## Verify visual work

1. Choose the narrowest Debug launch path:
   - `--preview-screen appearance` for Appearance.
   - `--preview-screen entity-details` for the entity-detail family/state gallery.
   - `--preview-screen widgets` for the complete widget family/state gallery.
   - `--live-preview` only for real Home Assistant state, authenticated media, or server-specific capabilities.
2. Reuse one explicit simulator UDID. Homestead is an Xcode project, so rebuild and relaunch after edits; do not assume package hot reload.
3. When browser inspection improves the task, start a simulator-scoped `serve-sim` process using the cleanup contract in `Docs/DEVELOPMENT_WORKFLOW.md`, then open its exact URL in the Codex in-app browser.
4. Verify a real rendered frame, not only a successful launch or loaded browser page.
5. Inspect representative content plus relevant loading, empty, unavailable, pending, or failed state. Check light/dark, small-screen, or Dynamic Type behavior when the changed surface makes those risks material.
6. If Xcode 27 semantic snapshots fail because `SimulatorKit.framework` moved, use screenshots and the browser mirror; do not modify the signed Xcode bundle.

## Review and hand off

1. Inspect all changed files and separate unrelated user work.
2. For substantial multi-file work, perform a final read-only review for correctness, Home Assistant contract violations, SwiftUI state ownership, missing tests, visual gaps, and accidental scope expansion. Resolve actionable findings before committing.
3. Update `Docs/NEXT_STEPS.md`, the roadmap/API inventory, or `Docs/DEVELOPMENT_LOG.md` only when their durable status actually changed.
4. Commit a verified, self-contained result by default. Do not commit exploratory, incomplete, failing, or mixed-scope work.
5. Report the build, exact test scope, rendered UI evidence, storage hygiene result, commit, and any remaining limitation.

Keep verification proportional. A successful compile alone is not completion evidence for visible work, but documentation-only changes do not need an app build.
