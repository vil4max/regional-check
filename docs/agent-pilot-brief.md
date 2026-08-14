# Agent pilot brief — Drive Check (RegionalCheck scheme)

You are working in the **pilot lab** for the iOS Engineering Runtime (`ios-engineering-runtime`), not a greenfield app rewrite.

Product display name: **Drive Check**. Xcode scheme/target and Bundle ID stay `RegionalCheck` / `vil4max.RegionalCheck`.

Human goal: open this chat, watch what you do, and verify the Brain + Runtime workflow.

## Read first (in order)

1. This file: `docs/agent-pilot-brief.md`
2. Root `AGENTS.md` (thin project facts)
3. `Tooling/runtime.yml` (scheme, simulator, flags)
4. `Tooling/docs/style-config.md` (SwiftLint / SwiftFormat defaults and how to tighten)
5. `.cursor/project-context` (expect `personal`)
6. Optional: `docs/architecture.md`, `docs/product-charter.md` only if the task needs product context

Brain (behavior) comes from global Cursor rules/skills (`agents-kit`). Do not copy kit policy into this repo.

## Stack / facts

| Item | Value |
|------|--------|
| App path | `~/Developer/GitHub/vil4labs/regional-check` |
| Product name | Drive Check (CFBundleDisplayName) |
| Scheme / target | `RegionalCheck` |
| Tests | `RegionalCheckTests` |
| Simulator | `iPhone 17` (see `Tooling/runtime.yml`) |
| Runtime | `Tooling/` (ios-engineering-runtime 0.2.2) |
| Context | `personal` |

## Definition of Ready (before Edit)

1. Run `just doctor` (and `just doctor --json` if you automate).
2. Run `just diagnose` if doctor warns about scheme/sim.
3. Confirm you read `AGENTS.md` + `Tooling/runtime.yml`.
4. Apple `xcode-tools` MCP should stay **configured**. Healthy tools need Xcode open with this project; if not healthy, still use `just build` (xcodebuild baseline).
5. Ask the user before build, test, commit, or push.

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
just ci        # verify + stub CI slots
just run-sim
just scenario allClear
just paywall
```

Config truth: `Tooling/runtime.yml` (optional `Tooling/runtime.local.yml`).
Style: app-owned `Tooling/.swiftlint.yml` / `.swiftformat` — see `Tooling/docs/style-config.md`.

## Definition of Done

Technical DoD = `just verify` when the user asks for full verification.

Host-specific summaries (Cursor markdown fence) follow kit `task-completion-response` when finishing an implementation task.

## Do / Do not

**Do**

- Use Runtime (`just …`) for doctor/build/test/format/lint.
- Keep changes small; ask before business-logic or root project file changes.
- Treat `AGENTS.md` as usable/committable thin notes; `.cursor/` stays local.
- Before **push** on a fresh/new setup: check `AGENTS.md`, project-context, Runtime presence; summarize; wait for confirmation.

**Do not**

- Rewrite the app “for cleanliness” without a requested task.
- Hand-edit `Tooling/scripts/` or `Tooling/backend/` — suggest `just harness-update` / harness repo instead.
- Assume XcodeBuildMCP or xcode-tools execute is required for `just build`.
- Auto-push, force-push, merge, or rebase.
- Auto-build/test unless the user asked.

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
