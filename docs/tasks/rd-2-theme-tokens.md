# Agent Task — RD-2: Redesign theme tokens and glass helpers

Assignee: unassigned
State: open
Requested by: owner (direct, 2026-09-17, redesign epic); delegated by regional-check-47 (managing agent)
Evidence: —
Parent: `docs/tasks/redesign.md` (task RD-2; spec sections 5.1–5.5, 11)
Requirements: `docs/core.md` (P1 driver attention), `docs/requirements/surfaces-and-pro-gating.md` (principle 3: honest age markers)
Decisions: ADR 0008 (MVVM boundaries); owner ruling R6 (dark only)
Changes a requirement: no. Tokens are added next to the existing ones; no screen changes color in this task.
Owned files: `RegionalCheck/App/Theme.swift`, a new `RegionalCheck/App/Theme+Redesign.swift` if `Theme.swift` would exceed the lint length, new unit tests for pure token or fallback logic under `RegionalCheckTests/`, this brief
Out of scope: migrating any view to the new tokens (RD-4 … RD-10), removing old tokens, widget colors in `RegionalCheckWidgets/` (RD-10), a light palette (R6), asset catalog changes, strings
Failure conditions: any existing view, widget, or snapshot baseline changes; a light-mode variant is added; a token value differs from section 5.1 without a recorded reason; glass has no Reduce Transparency fallback; a dependency is added

## Objective

Add the "instrument cluster" design language from `docs/tasks/redesign.md`
sections 5.1–5.5 to `Theme` so later tasks can adopt it screen by screen:
colors, status tints, typography roles, spacing and sizes, glass surfaces with
a Reduce Transparency fallback, and motion rules. Existing tokens stay until
the last view stops using them.

## Why additive

Replacing `Theme.Colors.normal` and friends in place would repaint every
screen at once, re-record every snapshot, and collide with RD-4 … RD-10,
which each own their views. New tokens next to the old ones keep this task
free of visual change and let each UI task switch its own screen.

## Authorization and boundaries

You may edit the owned files, run focused builds and tests, and
`just verify`. `Theme.swift` belongs to this task only; later tasks request
token changes through `regional-check-47`.

`just verify` runs one at a time across all worktrees
(`docs/engineering/agent-workflow.md`, "Verification slots"). Expect to wait;
never stop another session's run; do not raise `VERIFY_SLOTS`.

## Research first

1. Read `Theme.swift` and list every current token with its call sites, so
   the report maps old → new (section 5.1 "Replaces today" column). Note that
   `normal` and `unavailable` come from the asset catalog, and that
   `tabSelected` and `unavailable` have no entry in section 5.1: propose their
   mapping in the report, do not remove them.
2. Check Apple documentation for `glassEffect` on iOS 26+ and
   `accessibilityReduceTransparency` / `accessibilityReduceMotion`
   environment values; cite what you use.
3. Confirm how the widget target mirrors `Theme.Colors`
   (`RegionalCheckWidgets/DriveCheckStatusWidgetView.swift`) and record it for
   RD-10; do not change it.

## Required behavior

- New color tokens with the exact values in section 5.1 (`background`,
  `statusClear`, `statusAlert`, `statusStale`, `statusChecking`, `accentPro`,
  `textPrimary`, `textBody`, `textSecondary`, `textTertiary`, `surface`,
  `surfaceStroke` card and round-button variants, `separator`, `barGlass`,
  `alertGroupFill`, `alertGroupStroke`) under a clearly separate namespace
  (for example `Theme.Redesign.Colors`).
- A status accent function for the new palette covering every `StatusState`
  plus the stale state, and derived tints `soft` 14%, `edge` 40%, `glow` 20%,
  `shadow` 30%.
- Typography roles from 5.2 built on text styles with `.rounded` design so
  Dynamic Type scales them; tabular digits helper for times.
- Spacing, radii and size constants from 5.3.
- Glass surface modifiers for the tab bar, round buttons, and cards: glass on
  iOS 26+ APIs, solid `#1C1F24` when Reduce Transparency is on.
- Motion: reuse `Theme.Motion` and `Theme.Haptics`; add only what 5.5 needs
  that is missing, with Reduce Motion falling back to cross-fade.
- Dark only (R6).

## Tests

- Unit tests for pure logic only: the status accent mapping covers every
  state, and the fallback choice returns the solid fill when Reduce
  Transparency is on.
- No snapshot baseline changes. If one changes, stop and report.

## Acceptance criteria

- Section 5.1–5.5 tokens exist with matching values; the report has an
  old → new token table.
- `git diff` touches only owned files.
- `just verify` passes with no snapshot changes.

## Completion

Commit atomically in your own worktree and branch
(`git worktree add .claude/worktrees/rd-2-theme -b feat/rd-2-theme main`),
run `just verify`, then send `READY` to `regional-check-d5` with branch, head
SHA, worktree path, this brief, the `just verify` result, and
`release-prep: no`. Copy the report below to `regional-check-47`. Never merge,
push, or tag.

## Required final report

```markdown
# Agent Result

## Outcome
COMPLETED | BLOCKED_CORRECTLY | FAILED

## Summary
## Research findings
## Old → new token map
## Files changed
## Tests added
## Commands executed
## Verification results
## Risks
## Open questions
```
