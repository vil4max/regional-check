# Agent Task — TestFlight publishes from a tag, not from every merge

Assignee: cloud session `regional-check-f6` (Claude Code on the web) — work finished, branch pushed
State: ready for integration — branch `claude/testflight-publish-logic-ho4h0g`, not merged
Requested by: owner (direct, 2026-09-17, Claude Code on the web): "Нужно изменить логику публикаций в тестфлай. Сейчас тригирится на каждый Мердж и лимиты в апсторкннект исчерпаны. Нужно только когда тегнем что этот коммит готов к ТФ."
Evidence: no `just verify` — this session runs on Linux with no Xcode. The change touches no app code (`.github/workflows/`, `scripts/`, `docs/`). The two promotion scripts were exercised in a throwaway Git repository with a stubbed `gh`: happy path, re-run, lightweight tag, version mismatch, mixed `MARKETING_VERSION`, commit off `main`, and each test-run state (success, failure, cancelled, pending, missing). The integrator still runs `just verify` before landing.
Parent: [ADR 0012](../decisions/0012-tag-gated-testflight-builds.md), which supersedes the `testflight` row of [ADR 0010](../decisions/0010-gated-testflight-and-tag-releases.md)
Requirements: `docs/operations/release-process.md` invariants 1-4 and 7
Changes a requirement: yes. Invariant 3 now requires a `tf-` tag; invariant 4 drops the `testflight` containment check. ADR 0012 is **Proposed** — the owner accepts or rejects the tag shape.
Owned files: `.github/workflows/testflight.yml`, `.github/workflows/tests.yml` (promotion job only), `scripts/promote-testflight.sh`, `scripts/lib/promote.sh`, `scripts/promote-release.sh`, `docs/decisions/0012-tag-gated-testflight-builds.md`, `docs/operations/release-process.md`, `docs/README.md`, `docs/lessons.md`, `AGENTS.md` (Versioning), this brief
Out of scope: app code, the Xcode Cloud start conditions (unchanged), Sonar, the runner image, `CURRENT_PROJECT_VERSION` handling
Failure conditions: a merge to `main` still produces a TestFlight build; a `tf-` tag promotes a commit whose "Tests and coverage" run did not succeed; either branch is moved other than by fast-forward; the release path stops working because it no longer checks `testflight`

## What changed

| Before | After |
|---|---|
| `tests.yml` job `promote-testflight` fast-forwarded `testflight` on every green push to `main` | `tests.yml` promotes nothing |
| — | `testflight.yml` promotes on an annotated `tf-MAJOR.MINOR.PATCH-BUILD` tag (`scripts/promote-testflight.sh`) |
| `promote-release.sh` also required the tagged commit to be on `testflight` | It does not: the commit's own green run is the gate, and requiring containment would cost two Xcode Cloud builds per release |
| Tag checks lived in `promote-release.sh` | They live in `scripts/lib/promote.sh`, shared by both promotions |
| — | `just tf-check` runs those checks locally before the owner tags, and prints the tag command with the next free `BUILD` |
| A promotion that moved nothing printed `already contains` | It also says Xcode Cloud starts no build, and points at Start Build for a rebuild |

The `tf-` tag is checked exactly like a release tag: annotated, on `main`,
`MAJOR.MINOR.PATCH` equal to the commit's own `MARKETING_VERSION`, and a
successful "Tests and coverage" run for a push of that exact commit to `main`.
`BUILD` counts TestFlight rounds of that version and starts at `1`.

## For the desktop sessions

- **A merge to `main` no longer reaches testers.** A `testflight` branch that
  lags `main` is now the normal state, not a broken CI signal. Do not "fix" it
  by pushing the branch: invariant 2 still holds.
- **Tags stay with the owner.** Standing authorization covers the fast-forward
  push of `main` only (`docs/engineering/agent-workflow.md`, "Integrator"). No
  session creates a `tf-` or `v` tag.
- **A release tag needs no `tf-` tag first.** Release steps are unchanged apart
  from the removed `git ls-remote origin testflight` wait in step 3.
- **Release-prep pushes still go alone**, as the head of their push. Invariant 7
  now serves both tags: a commit buried in a multi-commit push can be tagged for
  neither.

## Owner steps after this lands

1. App Store Connect → Xcode Cloud → "Internal TestFlight (verified main)":
   edit the **description** only. It still says it archives every verified `main`
   commit. The start condition (branch changes on `testflight`) is correct as is,
   and no other setting changes.
2. First round after landing, to confirm the path end to end:

   ```bash
   just tf-check     # prints the exact tag command, or what blocks it
   ```

   then run the two lines it prints. The "TestFlight" workflow ends with
   `testflight -> tf-X.Y.Z-N (<sha>)`; Xcode Cloud then builds the branch as
   before. While the ITMS-90382 cap is still spent, the archive runs and the
   upload fails — so on the first day, check only that the workflow reached
   `testflight -> …`.
3. Accept or reject ADR 0012, in particular the tag shape
   `tf-MAJOR.MINOR.PATCH-BUILD`. A different shape is a one-line change to the
   pattern in `scripts/promote-testflight.sh` plus the docs.

## Follow-ups (proposed, not implemented)

Each needs the owner; none blocks landing this branch.

- **Reconsider "Auto-cancel builds" for the two Xcode Cloud workflows.** It is
  `On`, which was right when every merge built: the newest verified commit
  superseded the ones queued behind it. Now every build is an explicit request,
  and two tags pushed close together would silently drop the older round. The
  trade-off is real in both directions — leaving it on still gets testers the
  newest build, and a dropped round costs a tag, not data — so this is the
  owner's call, not an obvious fix. Affects only App Store Connect.
- **Say in the runbook whether a release candidate must have had a TestFlight
  round.** Invariant 4 no longer requires it, which is correct mechanically: the
  gate is the commit's own green run. But "may skip" and "should skip" are
  different, and only the owner decides whether a version may go to App Review
  without a human having run that exact build. If the answer is "must have had
  one", it belongs in the release steps as a checklist line, not in
  `promote-release.sh`, which would bring back the two-builds-per-commit cost.
- **Decide what happens to `tf-` tags of a shipped version.** They accumulate one
  per round and are pure history once `vX.Y.Z` is out. Keeping them costs
  nothing and records what testers saw; pruning them keeps `git tag` readable
  and stops a `tf-` tag being the nearest tag to a commit for anything that
  reads `git describe` (nothing in this repository does today — checked
  2026-09-17). A decision either way should be written down before the tag list
  grows.
