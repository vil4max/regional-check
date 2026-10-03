#!/usr/bin/env bash
# Requirement trace and task brief lint, using the declared SDLC repository.
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

sdlc="${IOS_AGENT_RUNTIME_ROOT:?Set IOS_AGENT_RUNTIME_ROOT to the ios-agentic-sdlc checkout}"
tools="$sdlc/tools/spec"
for tool in spec_trace.py brief_lint.py; do
  [[ -f "$tools/$tool" ]] || { echo "Missing SDLC tool: $tools/$tool" >&2; exit 2; }
done

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
