# Agent Task — Siri Action Donations

## Role and backlog context

Backlog item **SIRI-2** of the `Siri behind the wheel` epic (`docs/backlog.md`), targeting release **2.9**.

- Product: Drive Check
- Repository: `regional-check`
- Worktree / branch: assigned at implementation time

Work only inside the assigned worktree. This task teaches the system that the user actually checks and refreshes status, so Siri can suggest those actions. It changes no status logic and no UI.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/agent-pilot-brief.md`
3. `Tooling/runtime.yml`
4. `docs/architecture.md`
5. `docs/product-charter.md`
6. `docs/surfaces.md`
7. `Packages/DriveCheckKit/Sources/DriveCheckKit/CheckAlertStatusIntent.swift`
8. `Packages/DriveCheckKit/Sources/DriveCheckKit/RefreshStatusIntent.swift`
9. `Packages/DriveCheckKit/Sources/DriveCheckKit/SharedStore.swift`
10. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop and report the conflict.

## Objective

Donate the performed action (not just the entity) via `IntentDonationManager` after it succeeds:

- `CheckAlertStatusIntent` donates after the status dialog is resolved, carrying the resolved region.
- `RefreshStatusIntent` donates after the snapshot is persisted and WidgetKit timelines are reloaded.

Donation happens once per completed action. List renders, timeline reloads, and background polls never donate.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required for this feature and its tests, run `just doctor`, focused Runtime checks, and `just verify`, and format only files within the feature diff.

You must not:

- commit, push, merge, rebase, stash, or change branches;
- modify unrelated files;
- add dependencies;
- change alert calculation, region mapping, refresh scheduling, dialog content, or persistence ordering;
- donate on failure paths;
- donate from view bodies, list renders, or widget timelines;
- include anything beyond the region identifier in donated data;
- silently fix unrelated defects.

## Mandatory research phase

Before coding:

1. Trace every call site of `CheckAlertStatusIntent` and `RefreshStatusIntent` (app, widgets, controls, Shortcuts).
2. Identify the exact success point in each `perform()`: dialog resolved for check; snapshot persisted + `reloadAllTimelines()` requested for refresh.
3. Determine the `IntentDonationManager` API available on the deployment target and its actor isolation.
4. Decide the smallest testable seam: the donate-or-skip decision must live in a testable type with an injected boundary; the raw `IntentDonationManager.shared` call stays at the thin edge. No test doubles of production types (see `docs/testing-strategy.md` fake rules).
5. Run `git status --short --branch` and confirm the worktree contains no unexpected changes.
6. Write a concise implementation plan in your working response before editing.

Proceed without another approval only if the plan stays within this contract. Otherwise stop with `BLOCKED_CORRECTLY`.

## Architecture invariants

Preserve this ownership model:

```text
Intent perform()
      |
      v
existing success path (dialog / persist + reload, unchanged)
      |
      v
donation decision (testable type, injected boundary)
      |
      v
IntentDonationManager (thin system edge, fire-and-forget)
```

- Donation is a fire-and-forget side effect: it must not change the intent result, error behavior, or persistence ordering.
- Donation failure (e.g. system denies) must not fail the intent.
- `SharedStore` remains the App Group snapshot for widgets/controls/intents; donation adds no second state.

## Required behavior

- Successful check donates a `CheckAlertStatusIntent` carrying the actually resolved region (explicit parameter or `SharedStore` fallback, whichever was used).
- Successful refresh donates a `RefreshStatusIntent` only after `saveSnapshot` and the WidgetKit reload request complete.
- Failed check/refresh never donates.
- No donation originates from SwiftUI view bodies, `getTimeline`, or background polling paths.
- Donation carries no payload beyond what the intent already holds (region identifier at most).

## Required test scenarios

Add deterministic Swift Testing coverage for:

1. Check success requests exactly one donation carrying the resolved region.
2. Check with explicit region donates that region; check without parameter donates the `SharedStore` fallback region.
3. Check failure requests no donation and still returns the existing error behavior.
4. Refresh success requests exactly one donation after persist + reload request.
5. Refresh failure requests no donation and preserves existing error behavior.
6. Donation-boundary failure does not change the intent result.
7. Existing status resolution, dialog content, and refresh/persist ordering do not regress.

Use protocol-conforming fakes for the donation boundary. No live `IntentDonationManager` in unit tests. No timing-dependent sleeps.

## Acceptance criteria

- Every completed check/refresh is donated exactly once; failures and renders donate nothing.
- Intent results, dialog copy, persistence ordering, and refresh scheduling are unchanged.
- Donation edge cannot fail the intent.
- Focused tests cover the required scenarios.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- The Git diff contains only feature-related production code and tests.

## Failure conditions

The task fails if donation changes intent results; failures donate; renders or timelines donate; persistence ordering changes; region-external payload is donated; unrelated changes appear; or commands are claimed without evidence.

## Completion procedure

1. Inspect final `git diff` and `git status`.
2. Run the smallest focused checks useful during development.
3. Run `just verify` once for final technical verification.
4. Do not commit or push.
5. Return one final report using the exact structure below.

## Required final report

```markdown
# Agent Result

## Outcome
COMPLETED | BLOCKED_CORRECTLY | FAILED

## Summary
What changed or why implementation stopped.

## Research findings
Existing flow, relevant ownership boundaries, and evidence used.

## Files changed
Each file and why it changed.

## Architecture decisions
Decisions made, alternatives rejected, and how invariants were preserved.

## Tests added or changed
Scenarios covered and material gaps.

## Commands executed
Exact commands, including failed commands.

## Verification results
Pass/fail result for each check. Do not summarize an unexecuted command as passing.

## Risks
Residual correctness, concurrency, lifecycle, or privacy risks.

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy and transparency matter more than presenting the work as successful.
