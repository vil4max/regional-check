# Agent Task — Siri Refresh Shortcut

## Role and backlog context

Backlog item **SIRI-4** of the `Siri behind the wheel` epic (`docs/backlog.md`), targeting release **2.9**.

- Product: Drive Check
- Repository: `regional-check`
- Worktree / branch: assigned at implementation time

Work only inside the assigned worktree. This task exposes the existing `RefreshStatusIntent` as a spoken Siri phrase and Shortcuts action. It changes no fetch, persist, or scheduling logic.

## Required reading

Before editing, read these files in order:

1. `AGENTS.md`
2. `docs/agent-pilot-brief.md`
3. `Tooling/runtime.yml`
4. `docs/architecture.md`
5. `docs/product-charter.md`
6. `docs/surfaces.md`
7. `RegionalCheckWidgets/DriveCheckShortcuts.swift`
8. `Packages/DriveCheckKit/Sources/DriveCheckKit/RefreshStatusIntent.swift`
9. This task contract

Repository instructions are authoritative. If this contract conflicts with them, stop and report the conflict.

## Objective

Add a second `AppShortcut` for `RefreshStatusIntent` alongside the existing check shortcut, with spoken phrases in English, Ukrainian, and Russian. After this change the Shortcuts app lists both `Check alert status` and `Refresh status`, and Siri resolves refresh phrases with the application name.

## Authorization and boundaries

You are authorized to inspect repository files and Git state, modify files required for this feature and its tests, run `just doctor`, focused Runtime checks, and `just verify`, and format only files within the feature diff.

You must not:

- commit, push, merge, rebase, stash, or change branches;
- modify unrelated files;
- add dependencies;
- change fetch, persist, WidgetKit reload, polling, or retry behavior;
- paywall refresh or its shortcut (the safety signal stays free per `docs/surfaces.md` principle 1);
- change the existing check shortcut's phrases, titles, or behavior;
- silently fix unrelated defects.

## Mandatory research phase

Before coding:

1. Inspect `DriveCheckShortcuts.swift` and the string-catalog keys behind `intent.check.*`; follow the same localization pattern (`String(localized:bundle: .module)` in DriveCheckKit, en/ru/uk coverage).
2. Confirm every new phrase interpolates `\(.applicationName)` as required for `AppShortcut` phrases.
3. Check whether `RefreshStatusIntent.title` needs a parameter summary for the Shortcuts editor (it takes no parameters; keep it parameterless).
4. Run `git status --short --branch` and confirm the worktree contains no unexpected changes.
5. Write a concise implementation plan in your working response before editing.

Proceed without another approval only if the plan stays within this contract. Otherwise stop with `BLOCKED_CORRECTLY`.

## Architecture invariants

- `DriveCheckShortcuts` stays a thin declarative provider: no logic, no state, no I/O.
- `RefreshStatusIntent.perform()` keeps its exact fetch → `saveSnapshot` → `reloadAllTimelines` ordering.
- New localization keys follow the existing `intent.*` namespace and ship in all three locales. Missing-locale fallback must never surface an untranslated key to Siri.

## Required behavior

- `DriveCheckShortcuts.appShortcuts` returns two shortcuts: the existing check shortcut (unchanged) and a new refresh shortcut.
- Refresh phrases (each containing `\(.applicationName)`):
  - English: `Refresh status in …`
  - Ukrainian: `Онови статус в …`
  - Russian: `Обнови статус в …`
- The refresh shortcut has its own `shortTitle` localization key and a distinct `systemImageName` (must differ from the check shortcut's `exclamationmark.circle`).
- The check shortcut's phrases, short title, and icon are untouched.
- Refresh remains free on all surfaces; no entitlement check is added to the intent or the shortcut.

## Required test scenarios

This change is declarative (provider + strings), so per `docs/testing-strategy.md` verification is `just verify` plus checks:

1. `just build` succeeds for the app and widget extension targets (phrase interpolation is compile-checked).
2. All new localization keys resolve in en, uk, and ru (no raw key leaks; verify via catalog inspection and, where tooling allows, a locale-matrix preview or test).
3. Shortcuts app on simulator lists both Drive Check actions with correct titles and icons (manual checklist in the final report, or blocker with evidence).
4. Existing tests show no regression in `just test`.

If the implementation adds any logic beyond declaration (it should not), that logic must be extracted into a testable type and covered with Swift Testing tests.

## Acceptance criteria

- Siri resolves `Refresh status in Drive Check` (and UK/RU equivalents) and runs a refresh.
- Shortcuts app shows both actions with distinct titles and icons.
- All user-facing strings are localized in three locales.
- Refresh behavior, scheduling, and Pro gating are unchanged.
- `just verify` succeeds, or an exact environmental/product blocker is reported.
- The Git diff contains only feature-related production code and localization.

## Failure conditions

The task fails if any phrase lacks `\(.applicationName)`; a key is missing in any locale; the check shortcut changes; refresh gains an entitlement gate; fetch/persist behavior changes; unrelated changes appear; or commands are claimed without evidence.

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
Scenarios covered and material gaps (including the manual Shortcuts checklist result).

## Commands executed
Exact commands, including failed commands.

## Verification results
Pass/fail result for each check. Do not summarize an unexecuted command as passing.

## Risks
Residual correctness, localization, or review risks (e.g. Siri phrase approval).

## Open questions
Only unresolved decisions requiring human input. Write `None` if there are none.
```

The report will be compared with the actual Git diff and command evidence. Accuracy and transparency matter more than presenting the work as successful.
