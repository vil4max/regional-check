#!/usr/bin/env bash
# Requirement trace and task brief lint, using the agent kit's spec-pyramid scripts.
# Every approved requirement must be cited by a tracked test; with --results the
# citing tests must also have run and passed. Brief lint only reports: open briefs
# of live sessions are not this command's to fail.
set -euo pipefail

results=()
briefs=false
while (($#)); do
  case "$1" in
    --results) results=(--results "${2:?--results needs an .xcresult bundle or test-results JSON}"); shift ;;
    --briefs) briefs=true ;;
    *) echo "usage: spec-trace.sh [--results <bundle.xcresult|tests.json>] [--briefs]" >&2; exit 2 ;;
  esac
  shift
done

# A linked worktree resolves the kit from the primary checkout, where the sibling layout holds.
primary="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
kit="${AGENTS_KIT_ROOT:-$primary/../../agent-tools/agent-engineering-kit}"
tools="$kit/skills/spec-pyramid/scripts"
if [[ ! -f "$tools/spec_trace.py" || ! -f "$tools/brief_lint.py" ]]; then
  # The kit is a private sibling checkout and is absent on CI. Say so every time:
  # a trace that silently does nothing would read as a pass.
  echo "spec trace: SKIPPED — agent kit not found at $kit (set AGENTS_KIT_ROOT)" >&2
  [[ "${TRACE_REQUIRE_KIT:-0}" == 1 ]] && exit 3
  exit 0
fi

root="$(git rev-parse --show-toplevel)"
python3 "$tools/spec_trace.py" --root "$root" --approved-only --strict \
  --tests 'RegionalCheckTests/**/*.swift' --tests 'Packages/**/*.swift' \
  ${results[@]+"${results[@]}"}
# One summary line by default so the gate output stays readable; --briefs lists each problem.
if $briefs; then
  python3 "$tools/brief_lint.py" --root "$root" --board
else
  python3 "$tools/brief_lint.py" --root "$root" | tail -1
fi
