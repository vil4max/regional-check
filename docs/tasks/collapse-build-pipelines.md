# Agent Task — Investigate collapsing the two build pipelines into one

Assignee: unassigned — for a desktop session
State: open
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
