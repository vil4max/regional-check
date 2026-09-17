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
  its own worktree and branch (lifecycle below). Only the integrating session
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
   `.agents/project-context.yaml`, `.cursor/project-context`, and
   `Tooling/runtime.local.yml` if present, then run `just doctor`. Tracked hooks
   run in linked worktrees because `agentsKit.allowTrackedHooks` lives in the
   shared repository config. Xcode keys DerivedData by project path, so each
   worktree builds from scratch into its own `RegionalCheck-<hash>` folder
   (0.6–0.8 GB observed).
3. **Work** only inside the worktree; commit there. Never check out the same
   branch in two worktrees.
4. **Land** from the clean primary checkout:

   ```bash
   git -C .claude/worktrees/<slug> rebase main
   just verify                      # in the worktree, after the rebase
   git merge --ff-only <type>/<slug>
   ```

   Fast-forward keeps `main` linear and lands exactly the commits that were
   verified. A single stray commit on a stale base may be cherry-picked instead;
   run `just verify` on `main` afterwards. Push stays an owner decision.
5. **Remove immediately after landing**, so stale trees do not pile up:

   ```bash
   git worktree remove .claude/worktrees/<slug>
   git branch -d <type>/<slug>
   git worktree prune
   ```

   Do not use `--force` or `branch -D` to get past a refusal: a dirty worktree
   or an unmerged branch means work has not landed — ask the owner. Exception:
   after a cherry-pick, `branch -d` refuses although the change landed; use
   `-D` only when `git cherry main <branch>` prints nothing but `-` lines.
   Then delete the worktree's DerivedData folder, found by its
   `info.plist` `WorkspacePath`:

   ```bash
   for d in ~/Library/Developer/Xcode/DerivedData/RegionalCheck-*; do
     plutil -extract WorkspacePath raw "$d/info.plist" | grep -q '/.claude/worktrees/<slug>/' && rm -rf "$d"
   done
   ```

   Do not use `just reset` for this: it clears DerivedData for every checkout.
6. **Audit** at session start: `git worktree list` and
   `git branch --no-merged main`. A worktree with no live assignee in its brief
   and no unlanded commits is removed; one with unlanded commits is reported to
   the owner, not deleted.

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

Kept under root `scripts/` (not Runtime): `capture-app-store-screenshots.sh`, `install-hooks.sh`, `smoke-tests.sh`.
