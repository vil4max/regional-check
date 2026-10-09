#!/usr/bin/env bash
# Wiring contract of scripts/spec-trace.sh: which tool runs with which arguments, and which
# exit code survives. The tools themselves are stubbed here; their own contracts are in
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
cat >"$tools/spec_trace.py" <<'STUB'
import json, os, sys
with open(os.environ["ARGS_LOG"], "a") as log:
    log.write(json.dumps(["trace", *sys.argv[1:]]) + "\n")
sys.exit(int(os.environ.get("TRACE_EXIT", "0")))
STUB
export SPEC_TOOLS_DIR="$tools"
export ARGS_LOG="$FIXTURE/args.log"

status=0
bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "a tools directory missing a tool must exit 2, got $status"
grep -Fxq "Missing requirement-trace tool: $tools/brief_lint.py" "$FIXTURE/stderr" || fail 'the missing-tool message must name the tool'

cat >"$tools/brief_lint.py" <<'STUB'
import json, os, sys
with open(os.environ["ARGS_LOG"], "a") as log:
    log.write(json.dumps(["briefs", *sys.argv[1:]]) + "\n")
print("briefs: 0  problems: 0")
STUB

bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a trace without task briefs must exit 0'
printf 'brief lint: no docs/tasks, nothing to check\n' >"$FIXTURE/expected-skip"
cmp -s "$FIXTURE/expected-skip" "$FIXTURE/stdout" || fail 'missing task briefs must produce one nothing-to-check line'
bash "$WRAPPER" --briefs >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail '--briefs without task briefs must exit 0'
cmp -s "$FIXTURE/expected-skip" "$FIXTURE/stdout" || fail '--briefs without task briefs must report nothing to check'
status=0
TRACE_EXIT=7 bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 7 ]] || fail "a failing trace without task briefs must retain its exit code, got $status"
python3 - "$ARGS_LOG" "$TRACE_ROOT" <<'CHECK'
import json, sys
from pathlib import Path
calls = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
trace = ["trace", "--root", sys.argv[2], "--approved-only", "--strict",
         "--tests", "RegionalCheckTests/**/*.swift", "--tests", "Packages/**/*.swift"]
assert calls == [trace, trace, trace], calls
CHECK

mkdir -p docs/tasks
: >"$ARGS_LOG"
results="$FIXTURE/results with spaces.xcresult"
bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a trace with task briefs must exit 0'
bash "$WRAPPER" --results "$results" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a trace must forward results'
bash "$WRAPPER" --briefs >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a trace must list brief problems'
python3 - "$ARGS_LOG" "$TRACE_ROOT" "$results" <<'CHECK'
import json, sys
from pathlib import Path
calls = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
trace = ["trace", "--root", sys.argv[2], "--approved-only", "--strict",
         "--tests", "RegionalCheckTests/**/*.swift", "--tests", "Packages/**/*.swift"]
briefs = ["briefs", "--root", sys.argv[2]]
assert calls == [trace, briefs, trace + ["--results", sys.argv[3]], briefs,
                 trace, briefs + ["--board"]], calls
CHECK

: >"$ARGS_LOG"
status=0
TRACE_EXIT=7 bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 7 ]] || fail "a failing trace must retain its exit code, got $status"
[[ "$(wc -l <"$ARGS_LOG" | tr -d ' ')" -eq 1 ]] || fail 'a failed trace must stop before brief lint'

echo "spec trace wiring contracts: passed"
