# regional-check — agent notes

**Pilot lab** for iOS Engineering Runtime. Full instructions for agents:

→ **[docs/agent-pilot-brief.md](docs/agent-pilot-brief.md)** (read first)

## Project

- Product: Drive Check (display name); App Store Name: DriveCheckUA
- Repo / scheme: `regional-check` / `RegionalCheck` (see `Tooling/runtime.yml`)
- Context: `.cursor/project-context` → `personal`
- Simulator: `iPhone 17`
- Runtime: `Tooling/` (ios-agent-harness **0.2.2**)

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

## Release / TestFlight

- **Next release:** **2.0** / build **1** (app + widget extension aligned). Checklist: [docs/release-2.0.md](docs/release-2.0.md).
- New marketing version → reset `CURRENT_PROJECT_VERSION` to **1**.
- Same marketing version → bump `CURRENT_PROJECT_VERSION` above the highest build already uploaded for that version.
- App Group entitlements require refreshed profiles before first 2.0 Archive.
- Symptom if versions diverge: ASC validation fails on extension/container mismatch.

## Notes

- Prefer `just …` over raw `xcodebuild`.
- Install repository Git hooks once with `./scripts/install-hooks.sh` — commit-msg = Conventional Commits, pre-commit = `just format`+`just lint`, pre-push = smoke tests.
- App-local scripts under root `scripts/`: `capture-app-store-screenshots.sh`, `install-hooks.sh`, `smoke-tests.sh`.
- `.cursor/` local only; `AGENTS.md` may be committed.
- Ask before build, test, commit, push.

## StoreKit 2 (Pro)

Shipped in **2.0**: [docs/storekit-subscription-plan.md](docs/storekit-subscription-plan.md), [docs/surfaces.md](docs/surfaces.md), [README_Subscriptions.md](README_Subscriptions.md). Notifications not included.
