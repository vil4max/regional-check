#!/usr/bin/env bash
# Wiring contract of scripts/spec-trace.sh: which tool runs with which arguments, and which
# exit code survives. The tool itself is stubbed here; its own contract is in
# scripts/spec/tests/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/spec-trace.sh"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/spec-trace-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

unset TRACE_EXIT SPEC_TOOLS_DIR GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
git init -q "$FIXTURE/repository"
cd "$FIXTURE/repository"
TRACE_ROOT="$(pwd -P)"

bash "$WRAPPER" --help >"$FIXTURE/stdout" || fail '--help must exit 0'
grep -q '^usage: spec-trace.sh' "$FIXTURE/stdout" || fail '--help must print the usage'
status=0
bash "$WRAPPER" --unknown >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "an unknown option must exit 2, got $status"

tools="$FIXTURE/tools"
mkdir -p "$tools"
export SPEC_TOOLS_DIR="$tools"
export ARGS_LOG="$FIXTURE/args.log"

status=0
bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "a tools directory missing the tool must exit 2, got $status"
grep -Fxq "Missing requirement-trace tool: $tools/spec_trace.py" "$FIXTURE/stderr" || fail 'the missing-tool message must name the tool'

cat >"$tools/spec_trace.py" <<'STUB'
import json, os, sys
with open(os.environ["ARGS_LOG"], "a") as log:
    log.write(json.dumps(["trace", *sys.argv[1:]]) + "\n")
sys.exit(int(os.environ.get("TRACE_EXIT", "0")))
STUB

results="$FIXTURE/results with spaces.xcresult"
bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a passing trace must exit 0'
bash "$WRAPPER" --results "$results" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a trace must forward results'
python3 - "$ARGS_LOG" "$TRACE_ROOT" "$results" <<'CHECK'
import json, sys
from pathlib import Path
calls = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
trace = ["trace", "--root", sys.argv[2], "--approved-only", "--strict",
         "--tests", "RegionalCheckTests/**/*.swift", "--tests", "Packages/**/*.swift"]
assert calls == [trace, trace + ["--results", sys.argv[3]]], calls
CHECK

status=0
TRACE_EXIT=7 bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 7 ]] || fail "a failing trace must retain its exit code, got $status"

echo "spec trace wiring contracts: passed"
