# regional-check — agent notes

**Pilot lab** for iOS Engineering Runtime. Full instructions for agents:

→ **[docs/engineering/agent-workflow.md](docs/engineering/agent-workflow.md)** (read first)

## Project

- Product: Drive Check (display name); App Store Name: DriveCheckUA
- Repo / scheme: `regional-check` / `RegionalCheck` (see `Tooling/runtime.yml`)
- Context: `.cursor/project-context` → `personal`
- Simulator: `iPhone 17`
- Runtime: `Tooling/`; installed content is identified by `Tooling/.runtime-lock`.

## Config

Source of truth for scheme / simulator / backend: [`Tooling/runtime.yml`](Tooling/runtime.yml) (overrides: `Tooling/runtime.local.yml`).

Style (app-owned): [`Tooling/.swiftlint.yml`](Tooling/.swiftlint.yml), [`Tooling/.swiftformat`](Tooling/.swiftformat) — how to change: [`Tooling/docs/style-config.md`](Tooling/docs/style-config.md).

## Versioning

- Use three-component marketing versions: `MAJOR.MINOR.PATCH`. All three are
  integers, not decimal fractions.
- A feature release increases `MINOR` and resets `PATCH` to `0`: `2.8.0` →
  `2.9.0`, and `2.9.0` → `2.10.0`. A fix-only release with no new features
  increases `PATCH` instead: `2.9.0` → `2.9.1`. Change `MAJOR` only when
  explicitly requested.
- Keep app and widget marketing versions aligned in Debug and Release configurations.
- Reset the local build number to `1` for a new marketing version; increment it for
  subsequent builds of that version. Xcode Cloud may assign its own build number.
- An annotated tag `vMAJOR.MINOR.PATCH` (for example `v3.0.0`) on the verified
  release-prep commit requests the App Store candidate build; only the owner
  creates release tags. Never move or reuse a pushed release tag. Follow
  [docs/operations/release-process.md](docs/operations/release-process.md).

## Definition of Done

```bash
just verify
```

Before handing a committed revision to Cloud, `just release --check` requires a clean working tree and matching successful verification evidence. It does not start a build.

Technical DoD only (Runtime). Implementation, review, and publication follow the canonical [agent-engineering-kit Brain policy](../../agent-engineering-kit/AGENTS.md).

## Commit policy

- Keep commits atomic. Do not mix unrelated fixes, cleanup, documentation, or
  release changes in one commit.
- Before committing, inspect the staged diff and run defect-first. Never bypass
  hooks with `--no-verify`.

## Commands

```bash
brew bundle --file=Tooling/Brewfile
just doctor
just doctor --json
just diagnose
just format
just lint
just build
just test
just verify
just release --check
just run-sim
just scenario allClear
just scenario alertActive
just paywall
just screenshots
just prune-worktrees --apply
```

App-local recipes live in the root `justfile` (`import 'Tooling/justfile'`). Do not hand-edit `Tooling/scripts/` / `Tooling/backend/` — use `just harness-update`.

## Notes

- Prefer `just …` over raw `xcodebuild`.
- Install repository Git hooks once with `./scripts/install-hooks.sh`; wrappers always use the current `.githooks/` — pre-commit = `just format`+`just lint`, pre-push = smoke tests for branch updates.
- App-local scripts under root `scripts/`: `capture-app-store-screenshots.sh`, `install-hooks.sh`, `prune-worktrees.sh`, `smoke-tests.sh`, `verify-slot.sh`.
- `.cursor/` local only; `AGENTS.md` may be committed.

## Spec pyramid

Start from [`docs/core.md`](docs/core.md). Layers: core → `docs/requirements/`
+ `docs/decisions/` → tests named with `REQ-<AREA>-NNN` → code. Index:
[`docs/README.md`](docs/README.md). Method: kit skill `spec-pyramid`.

- Change starts at the highest affected layer; propose, do not approve, core
  or requirement edits.
- Bug → failing spec with a REQ ID first, then the fix.
- Record a lesson only when a check or upper layer changed:
  [`docs/lessons.md`](docs/lessons.md).
- Historical release notes and plans are not current implementation instructions.
