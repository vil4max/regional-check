# regional-check — agent notes

**Pilot lab** for iOS Engineering Runtime. Full instructions for agents:

→ **[docs/agent-pilot-brief.md](docs/agent-pilot-brief.md)** (read first)

## Project

- Product: Drive Check (display name); App Store Name: DriveCheckUA
- Repo / scheme: `regional-check` / `RegionalCheck` (see `Tooling/runtime.yml`)
- Context: `.cursor/project-context` → `personal`
- Simulator: `iPhone 17`
- Runtime: `Tooling/` (ios-engineering-runtime **0.2.2**)

## Config

Source of truth for scheme / simulator / backend: [`Tooling/runtime.yml`](Tooling/runtime.yml) (overrides: `Tooling/runtime.local.yml`).

Style (app-owned): [`Tooling/.swiftlint.yml`](Tooling/.swiftlint.yml), [`Tooling/.swiftformat`](Tooling/.swiftformat) — how to change: [`Tooling/docs/style-config.md`](Tooling/docs/style-config.md).

## Definition of Done

```bash
just verify
```

Technical DoD only (Runtime). Before commit: Brain runs defect-first **automatically**, reports findings, fixes only after owner OK.

## Commit policy

- Every agent-authored commit **must** use Conventional Commits:
  `type(scope): imperative summary` (scope is optional).
- Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `build`, `ci`, `chore`, `revert`.
- Use lowercase scopes; comma-separated scopes are allowed when one atomic change
  genuinely spans multiple areas, for example `fix(data,xcode): ...`.
- Keep commits atomic. Do not mix unrelated fixes, cleanup, documentation, or
  release changes in one commit.
- Before committing, inspect the staged diff, run defect-first, and validate the
  proposed subject against `.githooks/commit-msg`. Never bypass hooks with
  `--no-verify`.

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
just run-sim
just scenario allClear
just scenario alertActive
just paywall
just screenshots
```

App-local recipes live in the root `justfile` (`import 'Tooling/justfile'`). Do not hand-edit `Tooling/scripts/` / `Tooling/backend/` — use `just harness-update`.

## Notes

- Prefer `just …` over raw `xcodebuild`.
- Install repository Git hooks once with `./scripts/install-hooks.sh` — commit-msg = Conventional Commits, pre-commit = `just format`+`just lint`, pre-push = smoke tests.
- App-local scripts under root `scripts/`: `capture-app-store-screenshots.sh`, `install-hooks.sh`, `smoke-tests.sh`.
- `.cursor/` local only; `AGENTS.md` may be committed.
- Ask before build, test, commit, push.

## Documentation

- Start at [docs/README.md](docs/README.md).
- Product boundaries: [docs/product-charter.md](docs/product-charter.md).
- Current and target architecture: [docs/architecture.md](docs/architecture.md).
- Historical release plans are not current implementation instructions.
