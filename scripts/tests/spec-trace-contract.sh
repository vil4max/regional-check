#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/spec-trace.sh"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/spec-trace-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Do not let the caller's trace checkout or CI environment affect these fixtures.
unset CI GITHUB_ACTIONS IOS_AGENTIC_SDLC_ROOT IOS_AGENT_PROFILE_ROOT IOS_AGENT_RUNTIME_ROOT GITHUB_STEP_SUMMARY TRACE_EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
git init -q "$FIXTURE/repository"
cd "$FIXTURE/repository"
TRACE_ROOT="$(pwd -P)"

status=0
CI=true bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "CI outside GitHub Actions without a trace root must exit 2, got $status"

status=0
GITHUB_ACTIONS=true bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "GitHub Actions without CI=true must exit 2, got $status"

CI=true GITHUB_ACTIONS=true bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" \
  || fail 'GitHub Actions without a trace root must exit 0'
grep -q '^TRACE NOT CHECKED:' "$FIXTURE/stderr" || fail 'GitHub Actions must report the unchecked trace on stderr'
{ printf '::warning::'; cat "$FIXTURE/stderr"; } >"$FIXTURE/expected-annotation"
cmp -s "$FIXTURE/expected-annotation" "$FIXTURE/stdout" || fail 'stdout must contain only the matching GitHub warning annotation'

printf 'Existing summary\n' >"$FIXTURE/summary"
CI=true GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY="$FIXTURE/summary" bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'GitHub Actions with a step summary must exit 0'
{ printf 'Existing summary\n'; cat "$FIXTURE/stderr"; } >"$FIXTURE/expected-summary"
cmp -s "$FIXTURE/expected-summary" "$FIXTURE/summary" || fail 'GitHub Actions must append the stderr warning to the step summary'

status=0
bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "a local run without a trace root must exit 2, got $status"
grep -q '^Set IOS_AGENTIC_SDLC_ROOT to the absolute path of the requirement-trace tools checkout$' "$FIXTURE/stderr" || fail 'the local missing-root message must be preserved'

tools="$FIXTURE/sdlc/tools/spec"
mkdir -p "$tools"
cat >"$tools/spec_trace.py" <<'STUB'
import json, os, sys
with open(os.environ["ARGS_LOG"], "a") as log:
    log.write(json.dumps(["trace", *sys.argv[1:]]) + "\n")
sys.exit(int(os.environ.get("TRACE_EXIT", "0")))
STUB
cat >"$tools/brief_lint.py" <<'STUB'
import json, os, sys
with open(os.environ["ARGS_LOG"], "a") as log:
    log.write(json.dumps(["briefs", *sys.argv[1:]]) + "\n")
print("briefs: 0  problems: 0")
STUB
export ARGS_LOG="$FIXTURE/args.log"

IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a configured trace without task briefs must exit 0'
printf 'brief lint: no docs/tasks, nothing to check\n' >"$FIXTURE/expected-skip"
cmp -s "$FIXTURE/expected-skip" "$FIXTURE/stdout" || fail 'missing task briefs must produce one nothing-to-check line'
IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash "$WRAPPER" --briefs >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail '--briefs without task briefs must exit 0'
cmp -s "$FIXTURE/expected-skip" "$FIXTURE/stdout" || fail '--briefs without task briefs must report nothing to check'
status=0
TRACE_EXIT=7 IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
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
CI=true GITHUB_ACTIONS=true IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a configured trace must run in GitHub Actions'
results="$FIXTURE/results with spaces.xcresult"
IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash "$WRAPPER" --results "$results" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a configured local trace must forward results'
IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash "$WRAPPER" --briefs >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || fail 'a configured local trace must list brief problems'
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
CI=true GITHUB_ACTIONS=true TRACE_EXIT=7 IOS_AGENTIC_SDLC_ROOT="$FIXTURE/sdlc" bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 7 ]] || fail "a failing configured trace must retain its exit code, got $status"
[[ "$(wc -l <"$ARGS_LOG" | tr -d ' ')" -eq 1 ]] || fail 'a failed trace must stop before brief lint'

mkdir -p "$FIXTURE/incomplete/tools/spec"
cp "$tools/spec_trace.py" "$FIXTURE/incomplete/tools/spec/spec_trace.py"
status=0
CI=true GITHUB_ACTIONS=true IOS_AGENTIC_SDLC_ROOT="$FIXTURE/incomplete" bash "$WRAPPER" >"$FIXTURE/stdout" 2>"$FIXTURE/stderr" || status=$?
[[ "$status" -eq 2 ]] || fail "a configured root missing a tool must exit 2 even in CI, got $status"
grep -Fxq "Missing requirement-trace tool: $FIXTURE/incomplete/tools/spec/brief_lint.py" "$FIXTURE/stderr" || fail 'the missing-tool message must be preserved'

echo "spec trace wiring contracts: passed"
