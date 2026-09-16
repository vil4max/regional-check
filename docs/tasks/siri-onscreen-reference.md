# Agent Task — Siri On-Screen Region Reference

## Role and backlog context

Backlog item **SIRI-3** of the `Siri behind the wheel` epic (`docs/planning/backlog.md`), targeting release **2.9**.

- Product: Drive Check
- Repository: `regional-check`
- Worktree / branch: assigned at implementation time

Work only inside the assigned worktree. This task annotates the Regions list so Siri can resolve `this region` while the user looks at it. It changes no selection logic, no navigation, and no status behavior.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/engineering/agent-workflow.md`
3. `Tooling/runtime.yml`
4. `docs/engineering/architecture.md`
5. `docs/core.md`
6. `RegionalCheck/Views/RegionsView.swift`
7. `RegionalCheck/Views/RegionsViewModel.swift`
8. `Packages/DriveCheckKit/Sources/DriveCheckKit/AlertRegionAppEntity.swift`
9. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop and report the conflict.

## Objective

Attach the corresponding `AlertRegion` entity identifier to each Regions tab row via the `appEntityIdentifier(_:)` view modifier (iOS 18.4+), so Siri can resolve references like `this region` or `the third region in the list` while the list is on screen.

Below iOS 18.4 the UI renders exactly as today.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required for this feature and its tests, run `just doctor`, focused Runtime checks, and `just verify`, and format only files within the feature diff.

You must not:

- commit, push, merge, rebase, stash, or change branches;
- modify unrelated files;
- add dependencies;
- change region selection, manual pin, follow-location, or secondary-region (Pro) behavior;
- change alert calculation, refresh scheduling, or status presentation;
- access persistence, networking, or platform singletons directly from views (see architecture dependency rules);
- silently fix unrelated defects.

## Mandatory research phase

Before coding:

1. Inspect `RegionsView` row construction and confirm which view represents one region row.
2. Confirm the `EntityIdentifier` initializer available on the deployment target for the `AlertRegion` entity (`EntityIdentifier(for:identifier:)`), and the `ID` type the entity uses.
3. Confirm the minimum deployment target: the modifier must be gated with `if #available(iOS 18.4, *)` (or equivalent) with an unmodified fallback.
4. Run `git status --short --branch` and confirm the worktree contains no unexpected changes.
5. Write a concise implementation plan in your working response before editing.

Proceed without another approval only if the plan stays within this contract. Otherwise stop with `BLOCKED_CORRECTLY`.

## Architecture invariants

- The identifier is a display-only annotation. Selection, pinning, and status resolution keep flowing through `RegionsViewModel` → `StatusController` as today.
- Views receive everything through existing bindings/injected state; the annotation derives the identifier from the already-present `AlertRegion` value.
- No new ViewModel state, no new service, no new protocol: this is layout annotation, not logic.

## Required behavior

- Each Regions list row carries `appEntityIdentifier` for its own `AlertRegion` on iOS 18.4+.
- Pre-18.4 rendering, layout, and behavior are pixel- and behavior-identical to today.
- Row identity is stable: the identifier for a region never changes across list updates (use the entity identifier, not the row index).
- Pro-gated rows (secondary-region pin affordance) keep their existing gating; the annotation adds no paywall surface.
- No visual change on any OS version: no new text, icons, or layout.

## Required test scenarios

Per `docs/engineering/testing-strategy.md`, pure UI layout is not unit-tested; verification is `just verify` plus a manual checklist. Document the manual checklist in the final report:

1. On iOS 18.4+ simulator with the Regions tab open, Siri resolves `this region` / row-ordinal references to the visible row.
2. On pre-18.4 runtime (or availability-gated preview), the list renders and selects exactly as before.
3. Existing region selection, manual pin, and follow-location flows show no regression in `just test`.
4. No new SwiftLint/SwiftFormat violations in touched files.

If any logic is extracted into a testable helper during implementation (e.g. identifier construction), cover it with Swift Testing unit tests instead of leaving it unverified.

## Acceptance criteria

- Rows are annotated on 18.4+ with stable per-region identifiers; older systems are unaffected.
- Zero visual or behavioral change apart from Siri reference resolution.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- Manual Siri checklist is executed (device/simulator where Siri is available) or its blocker is reported with evidence.
- The Git diff contains only feature-related production code.

## Failure conditions

The task fails if selection or pin behavior changes; views gain direct persistence/network access; pre-18.4 behavior changes; visual layout changes; unrelated changes appear; or commands are claimed without evidence.

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
Scenarios covered and material gaps (including the manual Siri checklist result).

## Commands executed
Exact commands, including failed commands.

## Verification results
Pass/fail result for each check. Do not summarize an unexecuted command as passing.

## Risks
Residual correctness, lifecycle, or OS-version risks.

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy and transparency matter more than presenting the work as successful.
