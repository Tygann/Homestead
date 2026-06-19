# Homestead Development Workflow

This document captures the working agreement for agentic coding sessions. Keep it practical and update it only when the workflow changes.

## Start Of Work

- Read `AGENTS.md` first.
- For product work, also read `Docs/PRODUCT_ROADMAP.md`, `Docs/API_CAPABILITY_INVENTORY.md`, and `Docs/NEXT_STEPS.md`.
- Inspect the worktree before editing and preserve unrelated user changes.
- Prefer small, self-contained implementation chunks that can be verified and committed cleanly.

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

- For Swift app code changes, run:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'generic/platform=iOS Simulator' build
```

- For state, mapping, service, persistence, or presentation-helper changes, also run focused Swift tests where practical:

```sh
xcodebuild -project Homestead.xcodeproj -scheme Homestead -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:HomesteadTests test
```

- If the named simulator is unavailable, inspect local simulators and choose an installed iPhone runtime.
- Docs-only changes do not require a build.

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
- Check light and dark appearance when changing surfaces, rows, cards, toolbars, sheets, or navigation transitions.
- Check small-screen behavior when text, rows, segmented controls, tab items, or toolbar clusters change.
- Avoid heavy materials, large shadows, and implicit animations in scrolling dashboard grids unless profiling supports the change.
- Mention any UI verification that was not practical in the final response.

## Commit Behavior

- Keep commits focused and name the user-visible or architectural outcome.
- Commit completed, verified, self-contained work by default.
- Do not commit if the work is exploratory, unfinished, failing verification, or mixed with unrelated user changes.
- If not committing a completed change, explain why.
