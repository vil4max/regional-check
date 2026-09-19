# Redesign 3.0 release closure plan

Implementation authorized by the owner on 2026-09-19: commit the updates and
begin implementation. This covers local release-closure work, checks, and
in-scope repairs. It does not authorize push, tags, or App Store submission.
Execution status and approvals remain in the GitHub Project linked from
[the backlog](backlog.md); this plan defines sequencing and acceptance only.

## Execution and decision boundary

The owner approves global decisions, not each task start (clarification,
2026-09-19). Within the authorized release-closure scope, reconciliation,
implementation, tests, review, and targeted repairs proceed without repeated
approval. Preserve existing ownership; do not duplicate active work. Resolve
historical per-start gates under the updated
[coordination policy](../engineering/agent-workflow.md#owner-approval-gate).

Escalate scope expansion, requirement/architecture changes, dependencies or
toolchain changes, destructive actions, and publication without existing
explicit authorization. Reuse prior decisions when their scope still applies.
Unresolved evidence is a blocker to acceptance, not a reason to ask for
permission to investigate it.

Each slice starts from the preceding exit criteria and ends with evidence.
Before editing, claim the existing task record and concrete files; implementation
uses its own worktree. Keep verification and defect-first review in each
implementation slice; the integrator retains the final integration gate.

## Objective and evidence boundary

Close the remaining product acceptance gaps for one identifiable 3.0.0
candidate, then improve the release cycle using evidence from that release.
Reuse existing RD tasks and unfinished work rather than recreating the redesign.

The supplied review reports successful CI for `10adb09`, incomplete manual
acceptance, stale board entries, and unfinished worktrees. These are review
observations, not freshly verified remote state. Local inspection for this plan
found a clean primary checkout at `1179ef6`, four linked worktrees, an advisory
snapshot step in `.github/workflows/tests.yml`, ADR 0011 still Proposed, and
the hero title still derived from its visual accent. Remote CI, board state,
worktree diffs, and verification receipts must be refreshed before execution.
No build or test was run to prepare this plan.

## Ordered delivery slices

### 1. Reconcile scope and ownership

Responsible role: product orchestrator with the integrator.

- Compare each RD board item with its brief, landed commit, review evidence,
  acceptance evidence, and remaining work. Inspect active ownership before
  touching the AX5, RD-12, or RD-13 worktrees.
- Distinguish code landed from product acceptance complete. Repair stale board
  fields using evidence; preserve recorded approvals without inferring new ones.
- Treat briefs as contracts and the board as the current execution record.
  Replace misleading brief status fields with a link to the authoritative item.
- Check current project and host preflight, Git state, and verification receipt.
  Diagnose host drift separately; do not silently change shared configuration.

Exit: one explicit remaining release scope, one assignee per item, linked
evidence for completed items, and named blockers for incomplete ones.

### 2. Finish the existing correctness and accessibility work

Responsible role: current AX5/RD-12 owners; integration by the integrator only.

- Inspect and finish the existing Unavailable/AX5 diff. First reproduce the
  incorrect title in a failing test linked to the applicable requirement.
  Verify visible and VoiceOver titles distinguish Checking, Unavailable, and
  Region Unavailable without using color selection as the semantic source.
- Complete [RD-12](../tasks/rd-12-accessibility.md): VoiceOver order and labels,
  AX5 layouts, Reduce Motion, Reduce Transparency, contrast, and non-color cues.
- Validate relevant languages, long region names, and real running screens;
  update only affected snapshot baselines and inspect their visual differences.
- Run `just verify`, then defect-first review of the actual diff. A READY
  handoff must include base/head SHA, commands and results, review outcome,
  resolved/unresolved findings, and acceptance evidence references.

Exit: scoped fixes verified and reviewed, then landed; RD-12 has a result and
evidence for each acceptance condition. Integration changes require review
and affected checks again; an earlier branch receipt is not sufficient.

### 3. Close behavior evidence gaps

Responsible role: QA with the relevant implementation owner.

- Audit all four clauses of REQ-PROVIDER-002 in
  [the provider contract](../requirements/aerial-alerts-provider.md).
  Reuse valid tests and add missing behavior assertions, not citations alone:
  one shared timer, enumerated triggers with no render-driven requests,
  aggregate request counts across phone/CarPlay/widget fixtures, and HTTP 429
  backoff plus scheduled refresh suppression. State the counting window and
  expected requests for the fixture's exercised triggers explicitly.
- Measure REQ-LAUNCH-002 from known-status availability to the fully visible
  Status screen, using a timestamped event and correlated recording. Record
  environment, repeated runs, individual durations, and measurement uncertainty.
  If uncertainty prevents proving the 400 ms ceiling, retain INCONCLUSIVE.
- Exercise fresh cache, stale cache with a held refresh, no cache, errors,
  Reduce Motion, and VoiceOver. REQ-LAUNCH-003 skips the sweep for both fresh
  and stale cache; REQ-LAUNCH-005 specifies the accessibility transition.
- Complete CarPlay map layout/readability checks for the smallest and widest
  supported test configurations, including failure/fallback states. Record
  unavailable real-car evidence as a limitation requiring an explicit decision.
- Check widget and Live Activity visual states, stale/error presentation,
  interactions, and Pro entitlement transitions on the running surfaces.

Exit: missing tests have passed and manual evidence is conclusive, or each
remaining gap is an explicit release blocker. Traceability counts alone do
not satisfy behavior acceptance.

### 4. Align decisions, screenshots, and release documentation

Responsible role: product/documentation owner with the screenshot owner.

- Resolve ADR 0011 using the implemented Variant B and its acceptance evidence.
  Record the owner's decision or approved deviation; implementation alone
  does not authorize changing Proposed to Accepted.
- Align `testflight-readiness.md`, the release handoff, and Brain links with
  current repository layout and ADR 0013. Remove obsolete GUI-only Icon
  Composer guidance while preserving RD-15C's unresolved feasibility questions.
- Complete RD-13 from the final visual implementation. Inspect the existing
  recapture work before reusing it; include About and Paywall, check the full
  English set, and record owner acceptance against the source SHA and assets.

Exit: no conflicting release instructions; decisions have provenance;
screenshots match the accepted build. Later visual changes invalidate affected
screenshots and acceptance evidence.

### 5. Freeze and accept one candidate

Responsible role: integrator and QA, with owner release decisions.

1. Land all scoped code, tests, baselines, release metadata, and documentation.
   Freeze the resulting full candidate SHA on `main` before final acceptance.
   The integrator holds unrelated landings until the candidate's own CI run
   finishes; no evidence from an earlier revision is silently substituted.
2. On that clean committed candidate run `just verify`, defect-first review,
   and `just release --check`. Publish through the authorized integrator flow
   and require that SHA's own successful main CI run.
3. Inspect the snapshot test step's actual outcome and test summary/log for
   the same SHA and run attempt. Require successful execution with a positive
   test count and no failures; skipped, missing, cancelled, and inconclusive
   results block acceptance. Record the run/job URLs and preserve the log.
   Inspect the result bundle when available, but do not require a successful
   run's bundle: current CI uploads it only on failure. A green workflow alone
   is insufficient. This manual release gate leaves advisory CI unchanged.
4. Complete [RD-17](../tasks/rd-17-release-check.md) on this frozen candidate,
   including live safe-area/fade checks and the full surface regression matrix.
   Confirm RD-12 evidence and the approved screenshot set apply to this SHA;
   earlier captures need an explicit reviewed diff proving the relevant UI is
   unchanged, otherwise recapture. Record every result in the record below.
5. Run `just tf-check` for the candidate. The owner requests its TestFlight
   build under the existing release process. Record version, build number,
   tag, and full source SHA. Complete the device manual pass on that exact
   build before submission; a local simulator pass does not replace it.
6. A failure causes a targeted repair and a new candidate/build as needed.
   Keep the failed candidate's record, re-run affected acceptance and all
   required candidate gates, and explicitly justify any reusable evidence.
   Submit only the accepted TestFlight build under publication authorization;
   the owner then marks the submitted commit under the release process.

### Single acceptance record

Resolve `just artifacts task redesign-3-0-release-closure`. Within that shared
ignored directory, the canonical record is `candidates/<full-SHA>/acceptance.md`.
The integrator maintains it from QA and reviewer results; contributors write
separate evidence files to avoid concurrent record edits. The board links to
the candidate SHA and record location; it remains the execution-status source.
Do not paste private evidence into the public repository or board.

The record contains:

- Candidate SHA, version, environment, date, responsible roles, and scope.
- RD-12 and RD-17 rows: check/REQ ID, procedure, expected and actual result,
  PASS/FAIL/BLOCKED/INCONCLUSIVE, tester, timestamp, and evidence reference.
- REQ-PROVIDER-002 clauses and REQ-LAUNCH-001 through REQ-LAUNCH-005 evidence,
  including timing samples and measurement uncertainty.
- Verification commands/results and receipt references; review base/head SHA,
  outcome, findings and their resolution; CI run/attempt and snapshot log.
- Screenshot manifest with source SHA, file hashes, and acceptance evidence.
- TestFlight tag/build/source SHA and the device manual-pass results.
- Open blockers, explicitly approved permitted deviations, publication
  authorization reference, and the final acceptance decision.

Create the record during execution with checks initially BLOCKED (not yet
run). It lives outside tracked candidate contents so recording results does
not dirty or change the SHA being accepted. Preserve it under the artifact
lifecycle contract; ignored storage is not a backup. Any later public summary
is a separate documentation change and does not redefine the tested SHA.

Exit: every required acceptance item is satisfied or has an explicitly approved
permitted deviation; there are no unresolved correctness blockers. Technical
verification, manual acceptance, and publication authorization remain separate.

## Follow-up after 3.0

Use the completed release record to specify small, separately approved tasks:

| Slice | Scope | Acceptance |
|---|---|---|
| Status reconciliation | Evidence-driven LANDED to board update, preserving the distinction between integration and acceptance | Replaying an update is idempotent; failed publication is visible; acceptance is never inferred from a merge |
| Review handoff | Persist base/head, review outcome, findings, and checks in the existing coordination flow | Missing or stale review evidence cannot pass handoff validation |
| Acceptance gate | Read candidate-bound regression, snapshot, screenshot, and manual-pass evidence | Fixtures with missing, stale, failed, or inconclusive evidence are rejected; valid evidence passes without publishing anything |
| Snapshot CI policy | Evaluate stable runner/baseline settings before making the check blocking | Known pixel regression fails the gate; environment differences are diagnosed rather than hidden |

Shared coordination policy belongs in the Brain; app release checks belong in
this repository; Runtime execution changes belong upstream in the Runtime.
Do not patch installed Runtime scripts or add a new process framework to close
these gaps.

RD-15C, grouped-card unification, fold glass, and PRO-VIS-1/2 remain outside
3.0 closure. The [backlog](backlog.md#planned-feature-versions) assigns fold
glass to 3.1.0, PRO-VIS-1 icons to 3.2.0, and PRO-VIS-2 launch to 3.3.0.
Each feature update increments MINOR and resets PATCH to zero; fix-only
releases increment PATCH. The Pro visual idea follows release acceptance: select icon and
launch concepts, research platform/entitlement constraints, approve its spec,
then implement while preserving REQ-LAUNCH-001 through REQ-LAUNCH-005.
