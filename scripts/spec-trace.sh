#!/usr/bin/env bash
# Requirement trace and task brief lint, using the tools in scripts/spec/.
# Every approved requirement must be cited by a tracked test; with --results the
# citing tests must also have run and passed. Brief lint only reports and
# never fails this command.
set -euo pipefail

results=()
briefs=false
while (($#)); do
  case "$1" in
    --results) results=(--results "${2:?--results needs an .xcresult bundle or test-results JSON}"); shift ;;
    --briefs) briefs=true ;;
    -h | --help)
      echo "usage: spec-trace.sh [--results <bundle.xcresult|tests.json>] [--briefs]"
      echo "Fails when an approved requirement is not cited by a tracked test."
      echo "--results also requires the citing tests to have run and passed."
      echo "--briefs lists every task brief problem instead of the summary line."
      exit 0
      ;;
    *) echo "usage: spec-trace.sh [--results <bundle.xcresult|tests.json>] [--briefs]" >&2; exit 2 ;;
  esac
  shift
done

# SPEC_TOOLS_DIR exists for the wiring contract test, which substitutes stub tools.
tools="${SPEC_TOOLS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/spec}"
for tool in spec_trace.py brief_lint.py; do
  [[ -f "$tools/$tool" ]] || { echo "Missing requirement-trace tool: $tools/$tool" >&2; exit 2; }
done

root="$(git rev-parse --show-toplevel)"
python3 "$tools/spec_trace.py" --root "$root" --approved-only --strict \
  --tests 'RegionalCheckTests/**/*.swift' --tests 'Packages/**/*.swift' \
  ${results[@]+"${results[@]}"}
# One summary line by default so the gate output stays readable; --briefs lists each problem.
if [[ ! -d "$root/docs/tasks" ]]; then
  echo "brief lint: no docs/tasks, nothing to check"
elif $briefs; then
  python3 "$tools/brief_lint.py" --root "$root" --board
else
  python3 "$tools/brief_lint.py" --root "$root" | tail -1
fi
