# Homestead Development Workflow

This document captures the working agreement for agentic coding sessions. Keep it practical and update it only when the workflow changes.

## Start Of Work

- Read `AGENTS.md` first.
- For product work, also read `Docs/PRODUCT_ROADMAP.md`, `Docs/API_CAPABILITY_INVENTORY.md`, and `Docs/NEXT_STEPS.md`.
- Inspect the worktree before editing and preserve unrelated user changes.
- Prefer small, self-contained implementation chunks that can be verified and committed cleanly.

## Primary Development Surface

Codex desktop is the primary development environment for Homestead. Xcode, Simulator, the terminal, and the in-app browser are supporting tools; the workflow does not assume VS Code or another editor is open, nor does it depend on an external editor noticing file changes.

For an authorized implementation, use this default loop:

1. Read the durable context, inspect the worktree, and trace the relevant source of truth.
2. Make the smallest coherent code or documentation change while preserving unrelated work.
3. Compile early when Swift types, routing, or project integration could fail.
4. For visible UI work, launch the narrowest deterministic sample screen or isolated live preview and inspect the rendered result in Simulator or the in-app browser.
5. Iterate against the rendered UI, including loading, empty, unavailable, and representative content states when relevant.
6. Run focused tests proportional to the behavior changed, then run required Xcode storage hygiene after tests.
7. Review the final diff, update only durable docs whose status changed, and commit a verified self-contained result.

Use XcodeBuildMCP when available for simulator discovery, session defaults, build/run, screenshots, logs, and semantic UI interaction. Before its first build, run, or test operation in a session, inspect its active defaults; then set the Homestead project, scheme, configuration, and explicit simulator UDID when needed. Shell `xcodebuild`, `xcrun simctl`, and repository scripts remain the fallback when plugin tooling is unavailable or a lower-level diagnostic is more appropriate.

The trusted project configuration in `.codex/config.toml` enables the Build iOS Apps plugin and keeps multi-agent work bounded to four total threads with no nested delegation. Reasoning effort remains user- and task-controlled so the composer can select an appropriate level before the first message. The repo-owned `homestead-ios-verify` skill under `.agents/skills` turns the completion loop into an implicitly discoverable workflow instead of relying on repeated prompt instructions.

## Delegation And Review

- Use bounded subagents for independent read-heavy exploration, source tracing, test-gap analysis, log analysis, or final review when parallel work materially helps.
- Keep writes single-owner unless the work is cleanly partitioned into non-overlapping files and coordination is clearly beneficial.
- Do not run concurrent Xcode builds, tests, or simulator mirrors against the same destination.
- For substantial multi-file changes, run a final read-only review before committing. Prioritize behavior regressions, Home Assistant API/source-of-truth violations, SwiftUI observation ownership, missing tests, visual evidence, and unrelated diffs.
- Ordinary one-file fixes and documentation-only edits should remain single-agent.

## Token Budget Defaults

- Start from `AGENTS.md` and `Docs/NEXT_STEPS.md`; read roadmap/API docs only when the task touches product direction or Home Assistant API choices.
- Prefer targeted `rg`, `sed`, and file reads over broad repository scans.
- Summarize discovered context instead of repeatedly rereading large files.
- Keep implementation chunks small enough to verify and commit in one pass.
- Avoid expanding into adjacent roadmap items unless the user asks or the current change requires it.
- For docs-only or low-risk workflow edits, skip builds and say why.
- Ask before doing broad external research, large refactors, long-running verification, or multi-feature implementation.
- When context gets large, update `Docs/NEXT_STEPS.md` with the handoff instead of relying on chat history.

## Fresh Chat Handoffs

Recommend starting a fresh chat when it would likely save meaningful context or token usage, especially after a self-contained chunk is committed, after a long planning discussion, before starting a different roadmap item, after major docs/handoff updates, or when the current thread has accumulated lots of obsolete exploration.

When answering "what's next?" after a completed chunk, explicitly say whether to continue in the current chat or start a fresh one. If recommending a fresh chat, include the copy-paste prompt and the recommended reasoning level. If continuing in the current chat is better, say why.

Before recommending a fresh chat:

- Make sure the worktree is clean or clearly explain any uncommitted state.
- Update `Docs/NEXT_STEPS.md` if the next task or acceptance notes changed.
- Commit completed self-contained work when safe.
- Provide a short copy-paste prompt for the new chat.

Default fresh-chat prompt:

```text
Continue Homestead from Docs/NEXT_STEPS.md. First read AGENTS.md and Docs/DEVELOPMENT_WORKFLOW.md, then inspect only the files needed for the next chunk. Be token-conscious, follow the roadmap/API inventory when relevant, run appropriate verification, update durable docs only if status or direction changes, and commit completed self-contained work.
```

## Reasoning Level Guide

Codex may not always be able to see the current UI-selected reasoning level. At the start of substantial work, recommend a level if the task appears under- or over-provisioned, but do not block on the user changing it unless the task risk is high.

| Reasoning level | Use for |
| --- | --- |
| Low | Docs-only edits, quick status checks, tiny copy changes, and obvious one-file fixes. |
| Medium | Normal SwiftUI polish, straightforward Settings rows, small refactors, and focused test updates. |
| High | Multi-file app changes, navigation/data-flow changes, API clients, persistence changes, and debugging failures. |
| Extra High | Architecture decisions, auth, notifications, iCloud sync, background behavior, performance work, unclear bugs, and major migrations. |

Default to High for active roadmap implementation unless `Docs/NEXT_STEPS.md` says otherwise. Use Medium for contained UI polish and Low for documentation-only changes.

## Definition Of Done

- The requested behavior is implemented end to end, not just sketched.
- Relevant build and tests pass, or skipped verification is explicitly explained.
- SwiftUI views do not consume Home Assistant transport DTOs directly.
- Home Assistant API usage follows the official API family documented for that feature.
- Roadmap/API docs are updated if feature status, priority, API confidence, or deferred scope changed.
- `Docs/DEVELOPMENT_LOG.md` is updated for meaningful architecture, performance, feature, or workflow milestones.
- The work is committed after verification when it is self-contained and safe to commit.

## Verification Defaults

- For Swift app code changes, prefer an XcodeBuildMCP simulator build after confirming its session defaults. The shell fallback is:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'generic/platform=iOS Simulator' build
```

- For state, mapping, service, persistence, or presentation-helper changes, also run focused Swift tests where practical. Select the smallest relevant test identifiers rather than the entire target when possible. The shell fallback is:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:HomesteadTests test
```

- If the named simulator is unavailable, inspect local simulators and choose an installed iPhone runtime.
- Docs-only changes do not require a build.

## Live Browser Simulator

- Homestead is an Xcode project rather than an importable Swift package, so browser preview changes require rebuilding and relaunching the app; package-only hot reload does not apply.
- When the in-app browser is mirroring the iOS Simulator through `serve-sim`, keep the mirror pinned to one simulator UDID and reuse that same simulator for rebuilds.
- Start the mirror in a long-lived terminal with scoped cleanup:

```sh
HOMESTEAD_SIMULATOR_UDID="<simulator-udid>"
cleanup_serve_sim() {
  npx --yes serve-sim@latest --kill "$HOMESTEAD_SIMULATOR_UDID" >/dev/null 2>&1 || true
}
trap cleanup_serve_sim EXIT INT TERM HUP
cleanup_serve_sim
npx --yes serve-sim@latest "$HOMESTEAD_SIMULATOR_UDID"
```

- Open the exact local URL printed by `serve-sim` in the Codex in-app browser. A loaded page is not sufficient proof; verify that a real simulator frame is updating.
- Do not call `build_run_sim` with empty launch arguments during preview-oriented browser work unless the user explicitly asks to test the normal app launch or onboarding path.
- For live Home Assistant preview work, rebuild and relaunch with `--live-preview`. Preserve any focused arguments such as `--preview-entity`, `--preview-size`, and `--preview-appearance` across rebuilds.
- For UI-only sample-data checks, use the Debug-only `--preview-screen` routes cataloged in `Docs/PREVIEW_CREDENTIALS.md` instead of temporarily editing `HomesteadApp` or navigating through onboarding.
- After visible SwiftUI edits, refresh the browser preview automatically by rebuilding and relaunching the app with the current preview launch arguments. Leave the existing `serve-sim` process and browser tab running; they should only be restarted when the mirror is unhealthy.
- After each rebuild, verify a real simulator frame in the browser mirror or capture a simulator screenshot before reporting UI results.
- When finished, stop the long-lived terminal and wait for its cleanup trap to exit. Never use an unscoped `serve-sim --kill`, because another task may own a different simulator.
- Codex-managed worktrees do not receive the ignored `PreviewCredentials.json` file. Use deterministic sample routes in worktrees and keep live Home Assistant preview work in Local unless the user explicitly approves adding that credential file to `.worktreeinclude`.

### Xcode 27 Beta UI Inspection

The current Xcode 27 beta stores `SimulatorKit.framework` under Xcode's `Contents/SharedFrameworks` directory, while some XcodeBuildMCP semantic snapshot paths still expect the older private-framework location. If accessibility-tree capture fails for that reason, do not treat it as an app failure and do not modify or symlink files inside the signed Xcode bundle. Continue with screenshots, the live browser mirror, focused tests, and explicit accessibility identifiers where applicable; retry semantic capture after the tool gains Xcode 27 compatibility.

## Xcode Storage Hygiene

- Prefer focused tests over broad simulator test suites unless broad coverage is needed for the change.
- After running `xcodebuild test`, run the repository hygiene helper:

```sh
Scripts/xcode_storage_hygiene.sh
```

- The helper reports `XCTestDevices`, DerivedData, and CoreSimulator sizes.
- With the user's standing approval, it automatically clears only `~/Library/Developer/XCTestDevices/*` when that directory exceeds 5 GB and no `xcodebuild` or XCTest process is active.
- The threshold can be overridden with `XCTEST_DEVICES_CLEANUP_THRESHOLD_GB`. Use `--check-only` to report without deleting anything.
- Report whether cleanup occurred and the resulting size in the completion summary.
- Never automatically delete DerivedData, normal Simulator data, or other user/cache folders. Those still require explicit approval.
- Manual equivalent, only when Xcode tests are idle:

```sh
rm -rf ~/Library/Developer/XCTestDevices/*
```

## UI Verification

- Use previews, sample data, simulator runs, or screenshots when touching visible app structure, navigation, dashboard cards, Settings, or reusable chrome.
- A successful compile alone is not completion evidence for visual work. Inspect the rendered screen and the relevant transient or empty state before reporting the change complete.
- Check light and dark appearance when changing surfaces, rows, cards, toolbars, sheets, or navigation transitions.
- Check small-screen behavior when text, rows, segmented controls, tab items, or toolbar clusters change.
- Avoid heavy materials, large shadows, and implicit animations in scrolling dashboard grids unless profiling supports the change.
- Mention any UI verification that was not practical in the final response.

## Commit Behavior

- Keep commits focused and name the user-visible or architectural outcome.
- Commit completed, verified, self-contained work by default.
- Do not commit if the work is exploratory, unfinished, failing verification, or mixed with unrelated user changes.
- If not committing a completed change, explain why.
