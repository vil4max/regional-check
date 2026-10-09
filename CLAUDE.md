@AGENTS.md

## Claude Code

The `ios-agentic-sdlc` plugin is enabled at local scope: its stage skills are
`/ios-agentic-sdlc:specify`, `/ios-agentic-sdlc:plan` and `/ios-agentic-sdlc:implement`, and the
gate is `ios-verify` (commands in AGENTS.md). Specs live in `specs/<KEY>-<slug>/`, and the
backlog is `docs/planning/backlog.md`.

A full `ios-verify` run outlasts the Bash tool's 2-minute limit: use `run_in_background` and wait,
or `timeout: 600000`. If `ios-verify` is not found, the plugin is not enabled in this checkout.
