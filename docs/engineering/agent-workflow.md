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
- **Before claiming.** `ListAgents` for live `regional-check-*` sessions, then
  the brief header. A claimed brief whose assignee is live is not started again.

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
   as stale. Reply `INTEGRATING`.
2. If `main` is not an ancestor of the branch, rebase it inside its worktree.
   Rewriting a local, unpublished task branch needs no force push.
3. In the worktree: `just verify`; for a release-prep commit also
   `just release --check`. Failure → `REJECTED`.
4. In the primary checkout: `git merge --ff-only <branch>`, then
   `git push origin main`. Standing owner authorization (2026-09-17) covers this
   fast-forward push of `main` after green `just verify` and pre-push checks.
   It does not cover force pushes, tags, `testflight`, or `release`; those stay
   with the owner.
5. Release-prep commit (see
   [release-process.md](../operations/release-process.md)): push it alone as
   the head of its push, then push nothing else to `main` until its
   "Tests and coverage" run succeeds. Other `READY` branches wait.
6. Remove the worktree (lifecycle step 5) and send `LANDED`.

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
5. **Remove immediately after landing** — integrator, right after `LANDED`:

   ```bash
   just prune-worktrees          # dry run: what would be removed and why
   just prune-worktrees --apply
   ```

   `scripts/prune-worktrees.sh` fetches with `--prune`, then removes a
   worktree, its branch, and its `RegionalCheck-<hash>` DerivedData (matched by
   `info.plist` `WorkspacePath`) only when the tree is clean, the branch has
   commits, and every commit is in `main` (fast-forward or cherry-pick). It
   never forces. Ignored files such as a copied `Tooling/backend/build/` do not
   block removal. It keeps and reports a dirty tree, a branch with unlanded
   commits, a detached HEAD, and a fresh branch with no commits yet (it sits at
   the tip of `main` and would otherwise look landed). A branch with no commits
and no worktree is removed as unused. Do not use `just reset`
   for DerivedData: it clears every checkout.
6. **Audit** at the start of every integrator session: `just prune-worktrees`.
   Remove what it marks landed. A kept worktree with no live assignee is
   reported to the owner, not deleted.

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

Kept under root `scripts/` (not Runtime): `capture-app-store-screenshots.sh`, `install-hooks.sh`, `prune-worktrees.sh`, `smoke-tests.sh`.
