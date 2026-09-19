# Release closure execution

Assignee: Codex release-closure
State: claimed
Requested by: owner direct, 2026-09-19: commit the updates and begin implementation; owner confirmed this is the sole active session
Evidence: `16a3353`, `fc3acd1`; verification results below; shared artifacts task `redesign-3-0-release-closure`
Parent: `docs/planning/redesign-release-closure.md`
Requirements: REQ-SURF-001, REQ-LAUNCH-001 through REQ-LAUNCH-005, REQ-PROVIDER-002
Owned files: existing AX5 fixes and snapshots; StatusController, ColdStart overlay/settling/sequence and their regression tests; provider fixture tests; release-closure planning/operations documents
Worktree: `.claude/worktrees/release-closure`, branch `fix/release-closure`
Out of scope: new features, Runtime changes, push, tags, App Store submission

## Execution checklist

Report this checklist in chat after each attempted item, then stop before starting
the next item. Keep the GitHub Project synchronized with the evidence below.

- [x] Commit scope-approval policy and release closure plan (`7e1d39f`).
- [x] Commit feature version assignments (`85e8d6e`).
- [x] Inspect current board, worktrees and latest published CI log.
- [x] Confirm exclusive ownership with the owner.
- [x] Check project setup and Runtime doctor: READY / ok; host conformance ATTENTION remains separately recorded.
- [ ] Reconcile remaining board fields with completed work and acceptance evidence.
- [x] Reproduce Unavailable regression: serial run reports two failed assertions (Checking instead of Unavailable).
- [x] Transfer the preserved AX5 diff into the isolated execution worktree.
- [x] Implement Unavailable/AX5 fixes with failing regression evidence and passing verification (`16a3353`, `fc3acd1`); full live acceptance remains below.
- [ ] Deferred, optional for 3.0 by owner decision (2026-09-19): complete RD-12 live accessibility acceptance.
- [x] Complete the provider/cold-start code slice under reduced verification scope; unresolved acceptance is tracked below.
- [ ] Resolve provider trigger-list proposal and device timing acceptance (not another simulator measurement loop).
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

### RD-12 live acceptance attempt, 2026-09-19

- Captured Regions at system AX5 in English, Russian and Ukrainian on iPhone 17
  / iOS 27. The installed executable matches the previously verified build.
  Evidence: `rd12-live/regions-ax5-{en,ru,uk}-settled.png` in the shared artifacts.
  Earlier captures include the launch overlay and are not acceptance evidence.
- Visible labels wrap without ellipsis in these captures. The current-region
  card becomes very tall, especially in Russian; scrolling and access beneath
  the bottom bar still require interaction checks. These captures do not accept
  the complete layout or other screens and states.
- Runtime accessibility snapshots succeeded after opening the workspace in
  Xcode, following an initial remote-automation timeout. The Ukrainian hierarchy
  is saved as `rd12-live/hierarchy-uk.json`. Region/status and search labels are
  present. Repeated tab nodes and a nested unlabeled switch require VoiceOver
  focus inspection; the hierarchy alone does not prove an audible defect.
- VoiceOver focus/speech, scrolling, Reduce Motion, Reduce Transparency and the
  Accessibility Inspector audit were not completed. Xcode's interaction route
  requests an unavailable `device-interaction` skill; the exposed XcodeBuildMCP
  tools provide snapshots but no tap/swipe tools in this session. The Xcode
  interaction session was closed. No tool installation or configuration change
  was made. RD-12 remains In progress and unchecked.
- No app code changed in this attempt; `just verify` was not rerun. Previous
  successful verification remains historical evidence, not a new test result.

RD-12 is deferred and optional for 3.0 by the owner's later decision on
2026-09-19. Its unperformed checks remain unaccepted, with existing fixes retained.
The earlier 31/32 trace count predates the new provider fixture test; adding a
citation does not establish complete provider acceptance.
Cold-start timing, CarPlay, widget/Live Activity acceptance, final screenshots,
ADR 0011 provenance, final candidate gates, and owner TestFlight pass remain.

### Provider and cold-start evidence, 2026-09-19

- Provider fixture: one logical session with phone Refresh, CarPlay Refresh and
  widget timeline reload makes exactly three JSON requests. Ten subsequent
  presentation/synchronization passes add none. The fixture exercises no timer
  ticks or map triggers; it does not claim an aggregate rate limit test.
- Existing timer/ref-count, adaptive interval, HTTP 429 Retry-After and scheduled
  suppression tests were rerun by `just verify`. Official Ubilling documentation
  was checked: the published limit remains 2 requests/second/host and HTTP 429.
- REQ-PROVIDER-002 clause 2 needs an owner decision: current phone/CarPlay entry,
  region changes and map variant changes issue requests beyond its literal list.
  Proposed resolution: enumerate those existing triggers explicitly, retain the
  current UX, and expand aggregate counting accordingly. The requirement has not
  been silently amended. The three-request fixture does not close all clauses.
- Fixed cold-start ordering: the bounded status wait runs concurrently with the
  checking sweep, then cancels it. Previously the sweep ran before that timeout
  and could add up to 300 ms of polling delay or continue indefinitely.
- Cached launches now hand off immediately. Non-cached launches budget from the
  first known status, including startup work, with a 50 ms display reserve.
  Optional Debug-only `-MeasureColdStart` logging records monotonic timestamps;
  it is absent from Release and inactive in ordinary Debug runs.
- Recorded three samples per repair stage on iPhone 17 / iOS 27. Known-status to
  removal-request durations changed from 587.497 / 577.656 / 581.592 ms to
  176.668 / 183.728 / 176.837 ms. Full logs, videos, recording-start brackets and
  reviewed contact sheets: `cold-start-measurement/measurement.md` in shared
  artifacts. These are process relaunches with cache, not cold filesystem runs.
- REQ-LAUNCH-002 remains INCONCLUSIVE for the fully presented frame: recording
  startup uncertainty is about 150-170 ms and contact-sheet sampling is 100 ms.
  No-cache, controlled stale-cache/held-refresh and error recordings remain.
- `just verify` passed after the final code changes
  (`provider-launch-final-verify.log`); `just doctor --json` returned ok.
  Defect-first review of the repaired diff: No findings. Snapshot suite not rerun:
  no listed Prefire view or baseline changed; runtime handoff has video evidence.
- This was the earlier acceptance gap; the later reduced-scope decision below separates code completion from remaining acceptance.

All new commits are local. Original AX5 and RD-13 worktrees remain untouched;
no push, release tag, or App Store Connect action has occurred.

## Reduced-scope code completion

Owner decision, 2026-09-19: reduce verification effort and continue. No additional
simulator timing measurements were run. Device timing remains INCONCLUSIVE until
the device pass; the optional RD-12 audit stays deferred.

The aggregate fixture now drives three JSON requests (phone Refresh, CarPlay
Refresh, widget reload) and four map requests (phone appear, CarPlay appear,
CarPlay variant change, phone map Refresh). Each trigger adds one request;
repeated appearances, identical variants and presentation reads add none. The
429 fixture now verifies suppression immediately before Retry-After and permits
the scheduled refresh exactly at the deadline. Neither fixture claims a
host-wide requests-per-second guarantee.

No production code changed in this step. The proposed trigger-list clarification
is recorded in `docs/requirements/aerial-alerts-provider.md`, explicitly pending
rather than approved. The code slice is complete; requirement acceptance and
device timing are still open, with no implied PASS.

Next: one core-surface smoke pass, then candidate/release preparation. Approximate
remaining code work: 5-10 percent, assuming the trigger clarification preserves
current behavior; smoke findings or a different requirement decision can change
that estimate. Remaining release work includes requirement decisions and owner
device acceptance. These estimates are not measured completion metrics.

Validation log: `provider-scope-final-verify.log` in shared artifacts. The first
attempt completed tests but its receipt was rejected because documentation was
edited during verification; the final attempt must run without concurrent edits.
Defect-first review of the test and documentation diff: No findings.
