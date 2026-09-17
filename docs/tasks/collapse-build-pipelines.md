# Agent Task — Investigate collapsing the two build pipelines into one

Assignee: desktop session (worktree `zen-cori-f48f15`)
State: closed 2026-09-17 — ADR 0013 accepted (option B) and migrated
Requested by: owner (direct, 2026-09-17, Claude Code on the web): "Теперь я думаю а нужен ли отдельно тф и отдельно релиз? Гитфло выглядит поломанным и двигается только по тегам. Какие варианты?" then "Запиши это предложение в спеку и подлей в мейн. На десктопе проинвестигируем решение."
Evidence: —
Parent: [ADR 0013](../decisions/0013-one-build-pipeline-or-two.md), which lists options A-D and recommends B
Requirements: `docs/operations/release-process.md` invariants 1-4 and 7
Changes a requirement: yes, if B or C is accepted — invariant 1 (which branches Xcode Cloud builds) and invariant 4 (what a release tag does). Propose the edits; the owner accepts the ADR.
Owned files: `docs/decisions/0013-one-build-pipeline-or-two.md` and, only once the owner accepts an option, `.github/workflows/release.yml`, `scripts/promote-release.sh`, `scripts/lib/promote.sh`, `.github/workflows/testflight.yml`, `scripts/promote-testflight.sh`, `scripts/check-testflight-tag.sh`, `docs/operations/release-process.md`, `AGENTS.md` (Versioning)
Out of scope: app code; changing anything in App Store Connect (owner only); moving or deleting `testflight`, `release`, or any existing tag; ADR 0012, which is settled and orthogonal
Failure conditions: a change lands before the owner accepts an option; the "commit was verified by GitHub Actions" gate is weakened as a side effect; the investigation answers from the repository's mirror of the Xcode Cloud settings instead of from App Store Connect
Questions for the owner: the five open questions in ADR 0013; ask through the orchestrating session, not the owner directly
Builds: no Xcode build needed — this is CI, scripts, and docs. If a change does land, `just verify` still applies before handing over.

## Why now

ADR 0012 (landed 2026-09-17) stopped every merge from publishing to TestFlight.
It left the shape of the pipeline untouched: two tag namespaces, two branches
only CI moves, two GitHub workflows, two promotion scripts, two Xcode Cloud
workflows — where the two Xcode Cloud workflows appear to build the same
artifact the same way.

## Investigate, in this order

1. **Verify the premise.** Open both Xcode Cloud workflows in App Store Connect
   and compare Actions and Post-actions field by field against the table in
   `release-process.md`. The whole recommendation rests on them being identical;
   if they are not, say how they differ and stop.
2. **Answer the five open questions** in ADR 0013 (what keeps a non-triggering
   `v` tag honest, the `release` build history, the name of the remaining
   branch, outside watchers).
3. **Re-read the options with those answers** and either confirm B, argue for
   another option, or argue for keeping two pipelines. A reason to keep them is
   a real outcome, not a failure.
4. **Write the migration** the chosen option needs, as a proposal: which App
   Store Connect workflow is deleted or edited (owner does it), which files are
   removed, what `release-process.md` and `AGENTS.md` say afterwards, and what
   happens to the existing `release` branch and `v3.0.0` tag.

## Acceptance

- ADR 0013 moves from Proposed to Accepted or Rejected with the owner's decision
  quoted, its open questions answered from App Store Connect rather than from
  the repository's mirror.
- No workflow, script, or branch changed before that decision.
- If an option is accepted, its migration lands as its own commits with
  `release-process.md`, `AGENTS.md`, and the ADR updated together — the rule in
  release-process.md, "Changing the flow".

## Outcome, 2026-09-17

**Premise confirmed in App Store Connect**, read field by field in this session:
both Xcode Cloud workflows had the same Environment (Xcode and macOS "Latest
Release", no environment variables), the same Action (Archive - iOS, scheme
`RegionalCheck`, distribution preparation App Store Connect) and the same
Post-action (TestFlight Internal Testing - iOS on artifact Archive - iOS, group
Friends&Family). Only the description and the start condition differed. Manage
Workflows listed exactly two workflows; the three entries on the Builds page are
branch groups (`testflight`, `release`, `main`).

**Decision: option B**, with the branch keeping the name `testflight` and the
`v` tag keeping a mechanical check. Recorded, with the owner's words and the
five open questions answered, in
[ADR 0013](../decisions/0013-one-build-pipeline-or-two.md).

**Landed here:** `scripts/promote-release.sh` removed; `.github/workflows/release.yml`
rewritten as "Release marker" running the new `scripts/check-release-tag.sh`,
which promotes nothing; `scripts/lib/promote.sh` gained `assert_testflight_round`;
`docs/operations/release-process.md`, `docs/operations/releases/3.0.md`,
`AGENTS.md`, `docs/README.md`, `docs/lessons.md` and ADR 0010 / ADR 0012 pointers
updated with it.

**App Store Connect edits, done 2026-09-17** on the owner's instruction and in
their browser: the workflow "App Store candidate (release tag)" is deleted (its
builds remain in TestFlight; App Store Connect only stops showing them by
default), and the stale ADR 0010 description of "Internal TestFlight (verified
main)" is replaced with the text in the configuration table. Manage Workflows
now lists one workflow.

**Left alone:** the `release` branch (frozen at `v3.0.0`) and every existing tag.
The gate is unchanged: a commit is still buildable only through a `tf-` tag whose
commit has its own successful "Tests and coverage" run.
