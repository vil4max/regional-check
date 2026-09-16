# Agent Task — Siri Region Disambiguation (EntityStringQuery)

## Role and backlog context

Backlog item **SIRI-1** of the `Siri behind the wheel` epic (`docs/planning/backlog.md`), targeting release **2.9**.

- Product: Drive Check
- Repository: `regional-check`
- Worktree / branch: assigned at implementation time

Work only inside the assigned worktree. This task makes voice region resolution unambiguous without changing status logic, UI, or navigation.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/engineering/agent-workflow.md`
3. `Tooling/runtime.yml`
4. `docs/engineering/architecture.md`
5. `docs/core.md`
6. `docs/requirements/region-model.md`
7. `Packages/DriveCheckKit/Sources/DriveCheckKit/AlertRegion.swift`
8. `Packages/DriveCheckKit/Sources/DriveCheckKit/AlertRegionAppEntity.swift`
9. `Packages/DriveCheckKit/Sources/DriveCheckKit/CheckAlertStatusIntent.swift`
10. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop and report the conflict.

## Objective

Extend `AlertRegionEntityQuery` with `EntityStringQuery` so Siri and Shortcuts can filter the 25 canonical regions as the user types or speaks, and ask `Which one?` on ambiguous input.

The motivating case: `Kyiv` must resolve to both `.kyivCity` and `.kyivOblast` (mirroring the `Park North` vs `Park South` disambiguation in the Walk Mate iOS 27 series), instead of silently picking one.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required for this feature and its tests, run `just doctor`, focused Runtime checks, and `just verify`, and format only files within the feature diff.

You must not:

- commit, push, merge, rebase, stash, or change branches;
- modify unrelated files;
- add dependencies;
- change alert calculation, region mapping, refresh scheduling, or Widget/App Intent ownership;
- perform network or persistence I/O inside the query;
- change `entities(for:)` behavior;
- index anything into Spotlight (regions are a static catalog, not user content);
- silently fix unrelated defects.

## Mandatory research phase

Before coding:

1. Inspect `AlertRegion.title(locale:)`, the DriveCheckKit string catalogs (en/uk/ru), and how `apiKey` relates to display titles.
2. Confirm the `ID` type used by `AlertRegion` as an `AppEntity` and that `entities(for:)` round-trips it.
3. Run `git status --short --branch` and confirm the worktree contains no unexpected changes.
4. Write a concise implementation plan in your working response before editing.

Proceed without another approval only if the plan stays within this contract. Otherwise stop with `BLOCKED_CORRECTLY`.

## Architecture invariants

Preserve this ownership model:

```text
AlertRegion (static catalog, DriveCheckKit)
      |
      v
AlertRegionEntityQuery (pure, in-memory filtering over allCases)
      |
      v
CheckAlertStatusIntent (reads SharedStore snapshot, unchanged)
```

- The query stays pure: no network, no `SharedStore` reads or writes, no date/clock dependency.
- `DriveCheckKit` gains no UIKit/SwiftUI imports.
- Matching logic lives in a testable type (e.g. a pure matcher over region + query), not inline in the query, per the UI-adjacent extraction pattern in `docs/engineering/testing-strategy.md`.

## Required behavior

- Conform `AlertRegionEntityQuery` to `EntityStringQuery`.
- `entities(matching:)` returns regions whose localized title **or** `apiKey` contains the query using `localizedStandardContains`.
- Matching covers titles in English, Ukrainian, and Russian (e.g. `Lviv`, `Львівська область`, `Львов` all resolve to `.lviv`).
- Empty/blank query returns all 25 regions (same as `suggestedEntities()`).
- Unmatched query returns an empty array (Siri then asks `Which one?` or falls back gracefully; the intent must not crash or pick a random region).
- `Kyiv` (any supported locale/case variant) returns at least `.kyivCity` and `.kyivOblast`.
- `suggestedEntities()` and `entities(for:)` behavior is unchanged.

## Required test scenarios

Add deterministic Swift Testing coverage for:

1. `Kyiv` matches both `.kyivCity` and `.kyivOblast`.
2. Latin, Ukrainian, and Russian spellings of one oblast resolve to the same region.
3. Empty string returns all 25 canonical regions.
4. Gibberish query returns an empty array.
5. `entities(for:)` round-trips raw-value identifiers, unchanged.
6. Matching is case- and diacritic-tolerant per `localizedStandardContains` semantics.

Wrap locale-sensitive assertions with the existing `TestLocale` pattern so they pass on non-English simulator hosts.

## Acceptance criteria

- Voice/typing `Kyiv` surfaces both Kyiv regions for disambiguation instead of silently picking one.
- All three locales resolve their own spellings to the same region.
- No I/O, no new dependencies, no Spotlight indexing.
- Focused tests cover the required scenarios.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- The Git diff contains only feature-related production code and tests.

## Failure conditions

The task fails if the query performs I/O; `entities(for:)` behavior changes; matching is hardcoded to one locale; Spotlight indexing is introduced; unrelated changes appear; or commands are claimed without evidence.

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
Residual correctness, concurrency, lifecycle, or localization risks.

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy and transparency matter more than presenting the work as successful.
