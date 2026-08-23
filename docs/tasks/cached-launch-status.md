# Hermes Agent Task — Cached Launch Status

## Role and experiment context

You are Hermes, working in a controlled AI engineering experiment inside an existing production-style SwiftUI/iOS repository.

- Product: Drive Check
- Repository: `regional-check`
- Worktree: `regional-check-worktrees/cached-launch-status`
- Branch: `feature/cached-launch-status`
- Starting feature-contract commit: `98d3efd`

Work only inside this worktree. The objective is not to produce the largest change. The objective is to make a correct, minimal, verifiable change while respecting the repository's architecture and governance.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/agent-pilot-brief.md`
3. `Tooling/runtime.yml`
4. `docs/architecture.md`
5. `docs/product-charter.md`
6. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop and report the conflict.

## Objective

On cold launch, show the latest known regional status before the first network refresh completes.

The cached snapshot is temporary launch state. Network data remains authoritative. A successful network refresh must replace the cached state.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required for this feature and its tests, run `just doctor`, focused Runtime checks, and `just verify`, and format only files within the feature diff.

You must not:

- commit, push, merge, rebase, stash, or change branches;
- modify unrelated files;
- add dependencies;
- change project or Runtime configuration unless the task is blocked and you explain why;
- bypass existing architecture or validation;
- invent APIs, backend behavior, product behavior, or a second status source;
- make `SharedStore` authoritative;
- change alert calculation, region mapping, refresh scheduling, or Widget/App Intent ownership;
- silently fix unrelated defects.

If the requirements or existing architecture are insufficient, stop and explain the uncertainty. Do not guess.

## Mandatory research phase

Before coding:

1. Inspect `StatusController`, `SharedStore`, `AppContainer`, `StatusStateResolver`, `DataFreshness`, and current status-related tests.
2. Trace app construction and the first refresh on cold launch.
3. Trace snapshot persistence and WidgetKit reload ordering.
4. Identify how phone, CarPlay, widgets, controls, and App Intents consume status.
5. Inspect current test doubles and dependency-injection conventions.
6. Run `git status --short --branch` and confirm the worktree contains no unexpected changes.
7. Write a concise implementation plan in your working response before editing.

Proceed without another approval only if the plan stays within this contract. Otherwise stop with `BLOCKED_CORRECTLY`.

## Architecture invariants

Preserve this ownership model:

```text
Network provider
      |
      v
StatusController --------> authoritative in-process state
      |
      v
SharedStore snapshot ----> widgets / controls / App Intents
```

Cold launch must behave as follows:

```text
App construction
      |
      v
Load latest persisted snapshot
      |
      v
Resolve temporary cached state for the selected region
      |
      v
Run the existing network refresh
      |
      v
Replace cached state with fresh network state
```

Use a protocol-backed persistence/loading boundary and initializer injection. Reuse the existing freshness calculation rather than adding a second freshness policy.

## Required behavior

- If no cached snapshot exists, preserve the existing initial loading and refresh behavior.
- If a cached snapshot exists, resolve it for the selected region during status-session construction so useful state is available before the network request completes.
- Cached data may be shown even when stale because it is the latest known state, but stale data must never be presented as fresh.
- A successful network response always replaces cached state, persists the new snapshot, and reloads WidgetKit only after persistence completes.
- If the first network refresh fails after cached state is shown, retain the useful cached status instead of replacing it with `.error`.
- If no useful cached state exists and refresh fails, preserve the existing error behavior.
- Region changes must continue to resolve from the latest available snapshot and trigger the existing refresh flow.
- Do not add a second cache, duplicate observable status, or move persistence into SwiftUI views.

## Required test scenarios

Add or extend deterministic Swift Testing coverage for:

1. No cached snapshot: initial behavior remains unchanged.
2. Fresh cached snapshot: status is available immediately.
3. Stale cached snapshot: status is available and reported as stale.
4. Network success: fresh response replaces cached state.
5. Network failure with cache: cached status remains visible.
6. Network failure without cache: existing error behavior remains.
7. Cached snapshot without the selected region: region-unavailable behavior is explicit and safe.
8. Successful refresh still persists before WidgetKit reload.
9. Region change continues to use the latest snapshot and refresh.

Use existing test conventions and injected clocks where time affects freshness.

## Acceptance criteria

- Cold launch exposes the latest persisted regional status before network completion.
- Cache never overrides a successful fresh response.
- Offline launch preserves useful cached state.
- Staleness uses the existing freshness policy and remains identifiable.
- Existing phone, CarPlay, WidgetKit, control, App Intent, polling, and region-selection behavior is not intentionally changed.
- Focused tests cover the required scenarios.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- The Git diff contains only feature-related production code and tests.

## Failure conditions

The task fails if `SharedStore` becomes the source of truth, cached data wins over successful network data, network failure discards a useful cache, cache logic is owned by a view, a second freshness/status model is introduced without necessity, persistence happens after WidgetKit reload, unrelated changes appear, or commands are claimed without evidence.

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
Residual correctness, concurrency, lifecycle, persistence, or integration risks.

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy and transparency matter more than presenting the work as successful.
