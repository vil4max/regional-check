# Agent pilot brief — Drive Check (RegionalCheck scheme)

You are working in the **pilot lab** for the iOS Engineering Runtime (`ios-engineering-runtime`), not a greenfield app rewrite.

Product display name: **Drive Check**. Xcode scheme/target and Bundle ID stay `RegionalCheck` / `vil4max.RegionalCheck`.

Human goal: open this chat, watch what you do, and verify the Brain + Runtime workflow.

## Read first (in order)

1. This file: `docs/engineering/agent-workflow.md`
2. Root `AGENTS.md` (thin project facts)
3. `Tooling/runtime.yml` (scheme, simulator, flags)
4. `Tooling/docs/style-config.md` (SwiftLint / SwiftFormat defaults and how to tighten)
5. `.cursor/project-context` (expect `personal`)
6. Optional: `docs/engineering/architecture.md`, `docs/core.md` only if the task needs product context

Brain behavior comes from [agent-engineering-kit/AGENTS.md](../../../../agent-engineering-kit/AGENTS.md) and its portable behavior for the current host. Keep implementation, review, and publication policy there.

## Stack / facts

| Item | Value |
|------|--------|
| App path | `~/Developer/Personal/apps/regional-check` |
| Product name | Drive Check (CFBundleDisplayName) |
| Scheme / target | `RegionalCheck` |
| Tests | `RegionalCheckTests` |
| Simulator | `iPhone 17` (see `Tooling/runtime.yml`) |
| Runtime | `Tooling/`; installed content lock: `Tooling/.runtime-lock` |
| Context | `personal` |

## Definition of Ready (before Edit)

1. Run `just doctor` (and `just doctor --json` if you automate).
2. Run `just diagnose` if doctor warns about scheme/sim.
3. Confirm you read `AGENTS.md` + `Tooling/runtime.yml`.
4. Apple `xcode-tools` MCP should stay **configured**. Healthy tools need Xcode open with this project; if not healthy, still use `just build` (xcodebuild baseline).

If doctor fails, fix environment (or ask) before changing app code.

## How to run work (Runtime API)

Prefer these commands from repo root. Do **not** invent ad-hoc `xcodebuild` flags unless diagnosing a Runtime failure.

```bash
just doctor
just doctor --json
just diagnose
just format
just lint
just build
just test
just verify    # DoD: format → lint → build → test
just release --check  # Check committed contents against local verification evidence
just ci        # verify + stub CI slots
just run-sim
just scenario allClear
just paywall
```

Config truth: `Tooling/runtime.yml` (optional `Tooling/runtime.local.yml`).
Style: app-owned `Tooling/.swiftlint.yml` / `.swiftformat` — see `Tooling/docs/style-config.md`.

## Definition of Done

Technical DoD = `just verify`.

Completion reporting follows the Brain policy.

## Do / Do not

**Do**

- Use Runtime (`just …`) for doctor/build/test/format/lint.
- Treat `AGENTS.md` as usable/committable thin notes; `.cursor/` stays local.

**Do not**

- Rewrite the app “for cleanliness” without a requested task.
- Hand-edit `Tooling/scripts/` or `Tooling/backend/` — suggest `just harness-update` / harness repo instead.
- Assume XcodeBuildMCP or xcode-tools execute is required for `just build`.

## Parallel sessions

Handoff, claim, and reply contract: kit
[`docs/ai-os/agent-coordination.md`](../../../../agent-engineering-kit/docs/ai-os/agent-coordination.md).
Project facts:

- **Primary checkout = integration tree.** `main` in
  `~/Developer/Personal/apps/regional-check` receives finished task commits and
  runs release work (`.github/workflows/release.yml`,
  `scripts/promote-release.sh`, tags). A session that edits app code works in
  its own worktree and branch (lifecycle below). Only the integrator session
  writes to the primary checkout.
  Why: `.githooks/pre-commit` runs `just format` over the whole tree and
  `.githooks/pre-push` runs smoke tests against what is on disk, so one
  session's unfinished edits get reformatted into, or break, another session's
  commit and push. On 2026-09-17 a release push had to go through a throwaway
  worktree because uncommitted CarPlay code in `main` did not compile.
  Rejected: staged-only hooks alone — they do not stop a failing pre-push build.
- **Record.** Multi-step or multi-session work gets `docs/tasks/<slug>.md` with
  the coordination header and `Owned files:` (template: kit `spec-pyramid`
  `references/layers.md`). Briefs without a header are historical, not active.
- **Before claiming.** `ListAgents` for live sessions (addressed by their titles,
  for example `drivecheck-product`), then
  the brief header. A claimed brief whose assignee is live is not started again.
- **Build slots.** At most `BUILD_SLOTS` (default 2) Xcode builds or test runs
  run at once on this machine, across all worktrees
  (`scripts/build-slot.sh`, slots under the Git common directory). `just
  verify`, `just build`, `just test`, `just run-sim` (and `scenario`,
  `paywall`), `just screenshots`, `just coverage-pyramid`, and the pre-push
  smoke tests each hold one slot while they run. Anything else that builds
  goes through the wrapper too:

  ```bash
  ./scripts/build-slot.sh run xcodebuild …        # raw xcodebuild
  token=$(just build-slot acquire rd-5-preview 20)  # before Xcode MCP BuildProject / RunSomeTests / RenderPreview
  just build-slot release "$token"                  # when the MCP work is done
  just build-slot status                            # who holds the slots
  ```

  A waiting run prints the holders every minute. A slot whose holder died, or
  whose `acquire` timer expired (default 30, at most 60 minutes), is reclaimed.
  Never kill another session's build and never raise `BUILD_SLOTS` without
  the owner. Count holders from the slot files, not `pgrep xcodebuild`, which
  also matches the xcodebuildmcp server processes.
  Why: on 2026-09-17 about ten sessions built in parallel at load averages of
  500–900; `StatusControllerConcurrencyTests` sat at 0 % CPU for 12 minutes and
  timed out although only one `just verify` ran, because ad-hoc builds, test
  runs, and Xcode MCP work were not limited. Owner ruling: "2 параллельные
  сборки, согласен". Rejected: longer test time limits (they hide real hangs),
  a slot for `just verify` only (the earlier `verify-slot.sh`, which left other
  builds unlimited), and message-only scheduling (nothing enforces it).

### Owner approval gate

The owner approves every start. Exactly one orchestrating session (for a
feature epic, its managing agent) proposes the roadmap and each task launch to
the owner and delegates a task only after the owner's explicit approval of
that task or of a named batch that contains it. Task sessions start only on a
delegation that quotes that approval; the integrator lands only work from an
approved task.

- Not approval: the owner's silence, an answer to a narrower question, an
  instruction relayed by another session, a prompt that says tasks "can run in
  parallel", or an integrator `LANDED`.
- Delegation messages carry `Owner approval: <quote, date>`; a task session
  without it replies `DECLINED` and asks the orchestrator.
- The task brief records the approval in `Requested by`.

Why: on 2026-09-17 the redesign's managing agent delegated RD-1 and RD-3
before the owner had approved the roadmap, relying on a relayed prompt that
allowed parallel start, the integrator's "you can delegate now", and the
owner's silence. Rejected: letting each session judge readiness (no single
point where the owner sees what starts).

### Integrator

One session, named by the owner, is the integrator; the owner tells task
sessions its name, and a task session asks the owner when unsure. It is the only session that
merges into `main`, pushes `main`, and removes landed worktrees. Task sessions
never merge, push, rebase onto `main` after handoff, or force-push anything.
If no integrator is live, a task session stops at `READY` and tells the owner.

Why: on 2026-09-17 sessions pushed to `main` independently: one push carried
another session's local commits, a concurrent push failed with
`cannot lock ref`, and a pre-push build failed on foreign code. Separate
landers race on `main`, cancel each other's "Tests and coverage" runs (`cancel-in-progress`),
and can bury a release-prep commit in the middle of a push. Rejected: every
session lands its own work (no ordering, no single owner of push timing) and
GitHub pull requests for each task (review and CI cost on top of `just verify`
for a single-owner repository).

Messages, first word first (kit reply contract applies on top):

| Word | From → to | Content |
|---|---|---|
| `READY` | task → integrator | branch, head SHA, worktree path, brief, `just verify` result, whether it is a release-prep commit |
| `INTEGRATING` | integrator → task | the SHA taken; the branch is frozen for the task session from here |
| `LANDED` | integrator → task | new `main` SHA, checks run, CI run link; worktree and branch are removed |
| `REJECTED` | integrator → task | failing command and output; the branch returns to the task session, which fixes it and sends `READY` again |

Integrator loop, one branch at a time in `READY` order:

1. `git fetch`; the branch head must equal the SHA in `READY`, else `REJECTED`
   as stale. A branch whose task has no recorded owner approval is `REJECTED`
   too. Reply `INTEGRATING`.
2. If `main` is not an ancestor of the branch, rebase it inside its worktree.
   Rewriting a local, unpublished task branch needs no force push.
3. Snapshot baselines: if the diff changes a view listed in `.prefire.yml`
   `sources`, the branch must also update the matching
   `RegionalCheckTests/__Snapshots__/PreviewTests.generated/*` baselines, else
   `REJECTED`. `just verify` cannot catch this — the default test plan skips
   `PreviewTests`, while CI runs them as a separate "Snapshot tests" job, so a
   missing re-record turns `main` red after the landing (RD-7, 2026-09-17).
4. In the worktree: `just verify`; for a release-prep commit also
   `just release --check`. Failure → `REJECTED`. Then `git status --short`
   must be empty: `just verify` runs `just format` first and still passes when
   the formatter rewrites a file, so a dirty tree means the branch carries
   unformatted code → `REJECTED` (the task session commits the formatter's
   change and sends `READY` again). Why: on 2026-09-17 RD-2 landed one line
   SwiftFormat rewrites, and every later `just verify` left that file modified
   in unrelated worktrees until 552c066.
5. In the primary checkout: `git merge --ff-only <branch>`, then
   `git push origin main`. Standing owner authorization (2026-09-17) covers this
   fast-forward push of `main` after green `just verify` and pre-push checks.
   It does not cover force pushes, tags, `testflight`, or `release`; those stay
   with the owner.
6. Release-prep commit (see
   [release-process.md](../operations/release-process.md)): push it alone as
   the head of its push, then push nothing else to `main` until its
   "Tests and coverage" run succeeds. Other `READY` branches wait.
7. Remove only that branch's worktree (`just prune-worktrees --apply --only
   <branch>`, lifecycle step 5) and send `LANDED`. `LANDED` reports
   facts only; it never tells the orchestrator to start or delegate work.

### Worktree lifecycle

One task = one branch = one worktree = one session. A worktree lives only until
its branch lands in `main` or the owner abandons it.

1. **Create** from the primary checkout on an up-to-date `main`:

   ```bash
   git worktree add .claude/worktrees/<slug> -b <type>/<slug> main
   ```

   `<type>` is the commit type (`feat`, `fix`, `refactor`, `docs`, …).
   `.claude/worktrees/` is listed in `.git/info/exclude` and excluded in
   `Tooling/.swiftlint.yml`, so a broken linked worktree cannot fail the primary
   checkout's pre-commit lint. The desktop host's
   worktree mode creates the same layout with a `claude/<name>` branch; both are
   valid. Record the path and branch in the task brief.
2. **Prepare.** Ignored local files are not copied into a new worktree: copy
   `Tooling/backend/build/` (the Runtime build backend, matched by the root
   `build/` ignore rule; without it `just build` fails with
   `backend/build/xcodebuild/build.sh: No such file or directory`),
   `.agents/project-context.yaml`, `.cursor/project-context`, and
   `Tooling/runtime.local.yml` if present, then run `just doctor`. Tracked hooks
   run in linked worktrees because `agentsKit.allowTrackedHooks` lives in the
   shared repository config. Xcode keys DerivedData by project path, so each
   worktree builds from scratch into its own `RegionalCheck-<hash>` folder
   (0.6–0.8 GB observed).
3. **Work** only inside the worktree; commit there. Keep the branch local; never
   check out the same branch in two worktrees. Finish with `just verify` and
   send `READY` to the integrator.
4. **Land** — integrator only (loop above). Fast-forward keeps `main` linear and
   lands exactly the commits that were verified. A single stray commit on a
   stale base may be cherry-picked instead; run `just verify` on `main`
   afterwards.
5. **Remove immediately after landing** — integrator, right after `LANDED`,
   only the branch that landed:

   ```bash
   just prune-worktrees --only <branch>            # dry run
   just prune-worktrees --apply --only <branch>
   ```

   `scripts/prune-worktrees.sh` fetches with `--prune`, then removes a
   worktree, its branch, and its `RegionalCheck-<hash>` DerivedData (matched by
   `info.plist` `WorkspacePath`) only when the tree is clean, the branch moved
   past the commit it was created from, and every commit is in `main`
   (fast-forward or cherry-pick). It never forces; ignored files such as a
   copied `Tooling/backend/build/` do not block removal. It keeps and reports a
   dirty tree, unlanded commits, a detached HEAD, and a branch still at its
   creation point (fresh, or reset back after a dropped commit). A branch with
   no worktree that never moved is removed as unused. Do not use `just reset`
   for DerivedData: it clears every checkout.
6. **Audit** at the start of every integrator session: `just prune-worktrees`,
   then `--apply` without `--only`. A full sweep also keeps any landed-looking
   worktree with Git activity in the last 120 minutes, because a live session
   may have just created or emptied it; remove such a tree only with `--only`
   after `ListAgents` and its brief show no live assignee. A kept worktree with
   no live assignee is reported to the owner, not deleted.
   Why: on 2026-09-17 a full `--apply` right after a landing removed the
   designer's live DS-3 worktree, which was clean and had been reset back to
   `main` after a dropped brief commit; nothing tracked was lost.

Order rules: task branches stay local — `origin` carries only `main`,
`testflight`, and `release`. A branch or worktree exists only while work in it
is in progress; landed means removed.

Rejected: long-lived per-agent worktrees reused across tasks — they drift from
`main`, carry leftovers between tasks, and hide unlanded commits.

## Suggested smoke script (when user says “check runtime”)

Run in order and report a short table:

1. `just doctor` / `just doctor --json`
2. `just diagnose`
3. `just format` (show whether files changed)
4. `just lint`
5. `just build`
6. `just test` (report failure clearly if tests fail)
7. `just verify` if the previous steps were green

## App-local scripts

Kept under root `scripts/` (not Runtime): `capture-app-store-screenshots.sh`, `install-hooks.sh`, `prune-worktrees.sh`, `smoke-tests.sh`, `build-slot.sh`.
