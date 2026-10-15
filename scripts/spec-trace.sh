#!/usr/bin/env bash
# Requirement trace, using the tool in scripts/spec/.
# Every approved requirement must be cited by a tracked test; with --results the
# citing tests must also have run and passed.
set -euo pipefail

results=()
while (($#)); do
  case "$1" in
    --results) results=(--results "${2:?--results needs an .xcresult bundle or test-results JSON}"); shift ;;
    -h | --help)
      echo "usage: spec-trace.sh [--results <bundle.xcresult|tests.json>]"
      echo "Fails when an approved requirement is not cited by a tracked test."
      echo "--results also requires the citing tests to have run and passed."
      exit 0
      ;;
    *) echo "usage: spec-trace.sh [--results <bundle.xcresult|tests.json>]" >&2; exit 2 ;;
  esac
  shift
done

# SPEC_TOOLS_DIR exists for the wiring contract test, which substitutes a stub tool.
tools="${SPEC_TOOLS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/spec}"
[[ -f "$tools/spec_trace.py" ]] || { echo "Missing requirement-trace tool: $tools/spec_trace.py" >&2; exit 2; }

root="$(git rev-parse --show-toplevel)"
python3 "$tools/spec_trace.py" --root "$root" --approved-only --strict \
  --tests 'RegionalCheckTests/**/*.swift' --tests 'Packages/**/*.swift' \
  ${results[@]+"${results[@]}"}
