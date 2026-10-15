@AGENTS.md

## Claude Code

The `ios-dev` plugin is enabled at local scope: its stage skills are
`/ios-dev:specify`, `/ios-dev:plan` and `/ios-dev:implement`, and the
gate is `ios-verify` (commands in AGENTS.md). Specs live in `specs/<KEY>-<slug>/`, and the
backlog is `docs/planning/backlog.md`.

A full `ios-verify` run outlasts the Bash tool's 2-minute limit: use `run_in_background` and wait,
or `timeout: 600000`. If `ios-verify` is not found, the plugin is not enabled in this checkout.
