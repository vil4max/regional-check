# Release closure execution

Assignee: Codex release-closure
State: claimed
Requested by: owner direct, 2026-09-19: commit the updates and begin implementation; owner confirmed this is the sole active session
Evidence: `16a3353`, `fc3acd1`; verification results below; shared artifacts task `redesign-3-0-release-closure`
Parent: `docs/planning/redesign-release-closure.md`
Requirements: REQ-SURF-001, REQ-LAUNCH-001 through REQ-LAUNCH-005, REQ-PROVIDER-002
Owned files: the seven existing AX5 diff files, focused regression tests, related snapshot baselines; release-closure planning/operations documents
Worktree: `.claude/worktrees/release-closure`, branch `fix/release-closure`
Out of scope: new features, Runtime changes, push, tags, App Store submission

## Execution checklist

These checkboxes summarize evidence; the GitHub Project remains the execution-status source.

- [x] Commit scope-approval policy and release closure plan (`7e1d39f`).
- [x] Commit feature version assignments (`85e8d6e`).
- [x] Inspect current board, worktrees and latest published CI log.
- [x] Confirm exclusive ownership with the owner.
- [x] Check project setup and Runtime doctor: READY / ok; host conformance ATTENTION remains separately recorded.
- [ ] Reconcile remaining board fields with completed work and acceptance evidence.
- [x] Reproduce Unavailable regression: serial run reports two failed assertions (Checking instead of Unavailable).
- [x] Transfer the preserved AX5 diff into the isolated execution worktree.
- [x] Implement Unavailable/AX5 fixes with failing regression evidence and passing verification (`16a3353`, `fc3acd1`); full live acceptance remains below.
- [ ] Complete RD-12 live accessibility acceptance.
- [ ] Close provider and cold-start measurement gaps.
- [ ] Complete CarPlay, widget and Live Activity manual checks.
- [ ] Align release documents and resolve ADR 0011 decision provenance.
- [ ] Accept RD-13 screenshots.
- [ ] Freeze candidate and complete RD-17 plus exact-SHA gates.
- [ ] Complete owner TestFlight manual pass and authorized submission.

## Current evidence

Published CI run 35346243886 for `10adb09` succeeded; its log reports 30 snapshot
tests with zero failures. This is historical evidence, not verification of the
new local commits. The original AX5 and RD-13 worktrees are preserved.

## Focused regression scenarios

- Known clear/alert and stale status retain their approved full-form titles.
- Error and missing-region states use unavailable wording, never Checking.
- Visible and VoiceOver titles agree; retry details remain actionable.
- Accessibility text can wrap inside region pills and bottom tabs.
- Error to refresh to known-status transitions do not retain unavailable wording.
- Title projection is synchronous; no new concurrency behavior is introduced.

## Verification results

- `just verify` passed before and after the baseline update (`verify.log`,
  `verify-final.log`). The last successful run includes the final app and test changes.
- Focused serial tests: 24 tests in two suites passed (`unavailable-green.log`).
- Snapshot suite: 30 tests passed with zero failures (`snapshots-green.log`).
  Nine reviewed baselines changed only within tab-label/pill text bounds;
  before/after copies are preserved in the shared artifact directory.
- Live simulator capture `unavailable-live.png` shows Unavailable and the
  retry instruction on the built app. This does not prove missing-region
  localization at AX5 or VoiceOver behavior.
- Defect-first review of the actual source diff and changed baselines: No findings.
- The initial parallel regression run stalled before assertions and was stopped.
  The serial red run produced the expected two failed assertions, then stalled
  in finalization and was stopped (exit 143). It proves the wording failure,
  not a successful test-command completion. Subsequent green tests and Runtime
  verification completed normally.

## Remaining acceptance and environment limits

RD-12 is still in progress: live VoiceOver, AX5 localization, Reduce Motion and
Reduce Transparency checks remain. REQ-PROVIDER-002 remains the sole uncovered
requirement in the 31/32 trace report; a citation alone would not close it.
Cold-start timing, CarPlay, widget/Live Activity acceptance, final screenshots,
ADR 0011 provenance, final candidate gates, and owner TestFlight pass remain.

All new commits are local. Original AX5 and RD-13 worktrees remain untouched;
no push, release tag, or App Store Connect action has occurred.
