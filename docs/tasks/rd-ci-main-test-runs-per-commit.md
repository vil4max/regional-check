# Agent Task — RD-CI: A later push never cancels a release commit's test run

Assignee: drivecheck-release
State: open
Requested by: owner (direct, 2026-09-17): CI per-commit concurrency is a separate task after RD-1 (ruling recorded in `docs/tasks/redesign.md` §12 and the RD-1 brief). Owner approval (wave 2): "утверждаю" (I approve), owner direct, 2026-09-17, in drivecheck-product, answering "утверждаете запуск RD-2, RD-15A и RD-CI?".
Evidence: —
Parent: `docs/tasks/redesign.md` (task RD-CI); phase 3 entry criterion 4 in `agent-engineering-kit/knowledge/experiments/spec-pyramid-and-agent-coordination-shakedown.md`
Requirements: `docs/operations/release-process.md` rules 3–4 (a commit reaches `testflight` and `release` only after its own successful "Tests and coverage" run on `main`)
Changes a requirement: no. It makes the existing release rules reliable.
Owned files: `.github/workflows/tests.yml` (the `concurrency` block and anything strictly needed for it), `docs/operations/release-process.md` only through a report to drivecheck-product (do not edit docs yourself)
Out of scope: runner image, Xcode version, destinations (RD-1, done), `release.yml`, `scripts/promote-release.sh` unless research proves a change is required (then stop and report first), Xcode Cloud settings
Failure conditions: a push to `main` can still cancel an in-progress `main` run; pull-request runs lose their cancel-older-runs behavior without a reason; the release workflow can no longer find a tagged commit's own successful run; an unverified workflow change lands
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; run raw `xcodebuild` as `./scripts/build-slot.sh run xcodebuild …`; for Xcode MCP use `just build-slot acquire <label>` and `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.

## Why

Today `tests.yml` uses `group: tests-${{ github.ref }}` with
`cancel-in-progress: true`. Two quick pushes to `main` put both runs in the
same group, so the second push cancels the first. If the first commit is the
release-prep commit, it never gets its own successful run, `testflight` does
not move to it, and `promote-release.sh` reports `cancelled` for the tag. The
integrator currently has to hold pushes behind a release-prep run by hand.

## Research first

1. Read `tests.yml`, `release.yml`, `scripts/promote-release.sh` and
   `docs/operations/release-process.md`; list every consumer of the
   "Tests and coverage" run (testflight promotion job, Sonar, release check).
2. Confirm in GitHub documentation how `concurrency.group` and
   `cancel-in-progress` expressions evaluate for `push` vs `pull_request`, and
   whether a per-SHA group for `main` pushes still queues or runs in parallel
   on the preview `xcode-27` runner.
3. Decide the shape, for example: a group keyed by commit SHA for pushes to
   `main` with `cancel-in-progress: false`, and the current ref-keyed,
   cancelling group for pull requests. Record why and the rejected options.
4. Check whether the testflight fast-forward job needs ordering protection
   when two `main` runs finish out of order (an older commit must never move
   `testflight` backwards); report it if so.

## Acceptance

- Two pushes to `main` in quick succession both complete (neither is
  cancelled); demonstrate with two real `main` runs or, if the owner does not
  want test pushes, with `act`/workflow-lint evidence plus a written trace of
  the expression values. Ask drivecheck-product before creating extra commits
  on `main` purely for the demonstration.
- Pull-request pushes still cancel the older run of the same pull request.
- `promote-release.sh` logic still finds the tagged commit's own run.
- `just verify` passes; `READY` to drivecheck-integrator (branch, SHA,
  worktree, this brief, verify result, `release-prep: no`).
- Agent Result to drivecheck-product with the proposed text for
  `release-process.md` (drivecheck-product writes it).
